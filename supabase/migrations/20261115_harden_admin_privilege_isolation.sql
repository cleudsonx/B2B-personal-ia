-- ==============================================================================
-- Migration: 20261115_harden_admin_privilege_isolation.sql
-- Description: Blindagem definitiva contra escalação de privilégio administrativo
--   (SuperAdmin / Mission Control) em novos cadastros via WhatsApp OTP, Checkout
--   rápido ou metadados manipulados pelo cliente.
--
--   1. Revoga privilégios administrativos acidentais de contas não-canônicas
--      (ex: wa_*@mrcoach.app, aluno_*@mrcoach.app, correspondência parcial de nome).
--   2. Remove wildcards ILIKE '%mrcoach%' / '%cleudson%' e usernames mutáveis de
--      public.current_user_is_admin(), restringindo exclusivamente aos UUIDs
--      canônicos imutáveis ou à coluna protegida is_admin em contas reais.
--   3. Blinda public.handle_new_user() para JAMAIS aceitar role='admin' ou
--      is_admin=true via raw_user_meta_data no signUp público, preservando a
--      validação de convite de alunos.
--   4. Estende o trigger protect_profile_privilege_escalation para BEFORE INSERT
--      OR UPDATE em public.profiles, bloqueando auto-promoção no primeiro upsert.
--   5. Bloqueia contas sintéticas (wa_*, aluno_*, *.internal) em claim_initial_superadmin().
-- ==============================================================================

BEGIN;

-- 1. Saneamento de contas não-canônicas em public.profiles
UPDATE public.profiles p
SET
    is_admin = FALSE,
    is_vip = CASE
        WHEN EXISTS (
            SELECT 1 FROM public.subscriptions s
            WHERE s.trainer_id = p.id AND s.status = 'active' AND s.plan_id IN ('pro', 'elite', 'studio')
        ) THEN p.is_vip
        ELSE FALSE
    END,
    current_plan = CASE
        WHEN p.current_plan = 'elite' AND NOT EXISTS (
            SELECT 1 FROM public.subscriptions s
            WHERE s.trainer_id = p.id AND s.status = 'active' AND s.plan_id = 'elite'
        ) THEN 'free'
        ELSE p.current_plan
    END,
    role = CASE
        WHEN p.role = 'admin' THEN 'trainer'
        ELSE p.role
    END,
    roles = CASE
        WHEN 'admin' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[])) THEN
            CASE
                WHEN cardinality(array_remove(p.roles, 'admin')) > 0 THEN array_remove(p.roles, 'admin')
                ELSE ARRAY[CASE WHEN p.role = 'client' THEN 'client' ELSE 'trainer' END]::TEXT[]
            END
        ELSE p.roles
    END,
    updated_at = now()
WHERE p.id NOT IN (
    '6f645308-f1b2-4d73-ac45-9890c27e20d4'::UUID,
    '50c26610-8054-4b05-9274-7f414f91f52f'::UUID,
    '92dfd58c-845f-473e-b846-a2b8fdd3e508'::UUID
)
AND lower(COALESCE(p.email, '')) NOT IN (
    'cleudsonx@hotmail.com',
    'cleudsonx@gmail.com',
    'cleudsonx2021@gmail.com'
)
AND (
    lower(COALESCE(p.email, '')) LIKE 'wa_%'
    OR lower(COALESCE(p.email, '')) LIKE 'aluno_%'
    OR lower(COALESCE(p.email, '')) LIKE '%.internal'
    OR p.is_admin = TRUE
    OR p.role = 'admin'
    OR 'admin' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[]))
);

-- Limpa flags privilegiadas de raw_user_meta_data em contas não-canônicas no auth.users
DO $$
BEGIN
    UPDATE auth.users
    SET raw_user_meta_data = (
        COALESCE(raw_user_meta_data, '{}'::JSONB) - 'is_admin' - 'is_vip' - 'roles'
    )
    WHERE id NOT IN (
        '6f645308-f1b2-4d73-ac45-9890c27e20d4'::UUID,
        '50c26610-8054-4b05-9274-7f414f91f52f'::UUID,
        '92dfd58c-845f-473e-b846-a2b8fdd3e508'::UUID
    )
    AND lower(COALESCE(email, '')) NOT IN (
        'cleudsonx@hotmail.com',
        'cleudsonx@gmail.com',
        'cleudsonx2021@gmail.com'
    )
    AND (
        raw_user_meta_data ? 'is_admin'
        OR raw_user_meta_data ? 'is_vip'
        OR lower(COALESCE(raw_user_meta_data->>'role', '')) = 'admin'
    );
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 2. Função canônica de verificação de SuperAdmin sem NENHUM wildcard de e-mail/nome/username
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- UUIDs canônicos imutáveis do proprietário
    IF v_uid IN (
        '6f645308-f1b2-4d73-ac45-9890c27e20d4'::UUID,
        '50c26610-8054-4b05-9274-7f414f91f52f'::UUID,
        '92dfd58c-845f-473e-b846-a2b8fdd3e508'::UUID
    ) THEN
        RETURN TRUE;
    END IF;

    -- Consulta estrita à tabela profiles bloqueando contas sintéticas (wa_* / aluno_* / *.internal)
    SELECT (
        lower(COALESCE(p.email, '')) NOT LIKE 'wa_%'
        AND lower(COALESCE(p.email, '')) NOT LIKE 'aluno_%'
        AND lower(COALESCE(p.email, '')) NOT LIKE '%.internal'
        AND lower(COALESCE(p.email, '')) NOT LIKE '%.local'
        AND (
            COALESCE(p.is_admin, FALSE) = TRUE
            OR p.role = 'admin'
            OR ('admin' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[])))
        )
    )
    INTO v_is_admin
    FROM public.profiles p
    WHERE p.id = v_uid;

    RETURN COALESCE(v_is_admin, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated, service_role;

-- 3. Endurece handle_new_user() para JAMAIS conceder is_admin ou role='admin' via raw_user_meta_data
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role TEXT := lower(trim(COALESCE(NEW.raw_user_meta_data->>'role', 'trainer')));
    v_token TEXT := trim(COALESCE(NEW.raw_user_meta_data->>'invite_token', ''));
    v_meta_trainer UUID := NULLIF(NEW.raw_user_meta_data->>'trainer_id', '')::UUID;
    v_trusted BOOLEAN := COALESCE(NEW.raw_app_meta_data->>'provisioned_by_backend', '') = 'true'
                         OR session_user = 'postgres';
    v_invite public.invite_tokens%ROWTYPE;
    v_user_phone TEXT;
    v_user_digits TEXT;
    v_invited_digits TEXT;
BEGIN
    -- Bloqueia role 'admin' ou valores arbitrários no cadastro de novos usuários
    IF v_role NOT IN ('trainer', 'client') THEN
        v_role := 'trainer';
    END IF;

    IF v_role = 'client' AND NOT v_trusted THEN
        IF v_token = '' THEN
            RAISE EXCEPTION 'Cadastro de aluno exige um convite válido.' USING ERRCODE = '42501';
        END IF;

        SELECT i.* INTO v_invite
        FROM public.invite_tokens AS i
        WHERE i.token = v_token;

        IF NOT FOUND OR v_invite.used_at IS NOT NULL OR v_invite.expires_at <= now() THEN
            RAISE EXCEPTION 'Convite não encontrado, expirado ou já utilizado.' USING ERRCODE = '42501';
        END IF;

        IF v_invite.channel = 'email' THEN
            IF COALESCE(trim(v_invite.target_email), '') = ''
               OR lower(trim(COALESCE(NEW.email, ''))) <> lower(trim(v_invite.target_email)) THEN
                RAISE EXCEPTION 'Este convite foi destinado a outro e-mail.' USING ERRCODE = '42501';
            END IF;
        ELSIF v_invite.channel = 'whatsapp' THEN
            v_user_phone := COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data->>'phone');
            v_user_digits := regexp_replace(COALESCE(v_user_phone, ''), '\D', '', 'g');
            v_invited_digits := regexp_replace(COALESCE(v_invite.target_phone, ''), '\D', '', 'g');
            IF left(v_user_digits, 2) = '55' AND length(v_user_digits) > 11 THEN
                v_user_digits := substr(v_user_digits, 3);
            END IF;
            IF left(v_invited_digits, 2) = '55' AND length(v_invited_digits) > 11 THEN
                v_invited_digits := substr(v_invited_digits, 3);
            END IF;
            IF v_user_digits = '' OR v_user_digits <> v_invited_digits THEN
                RAISE EXCEPTION 'Este convite foi destinado a outro telefone.' USING ERRCODE = '42501';
            END IF;
        ELSE
            RAISE EXCEPTION 'Canal de convite inválido.' USING ERRCODE = '42501';
        END IF;

        IF v_meta_trainer IS NOT NULL AND v_meta_trainer <> v_invite.trainer_id THEN
            RAISE EXCEPTION 'O treinador informado não corresponde ao convite.' USING ERRCODE = '42501';
        END IF;
    END IF;

    INSERT INTO public.profiles (
        id, full_name, email, role, roles, is_admin, phone, trainer_id
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(COALESCE(NEW.email, 'Usuario'), '@', 1)),
        NEW.email,
        v_role,
        ARRAY[v_role]::TEXT[],
        FALSE,
        NEW.raw_user_meta_data->>'phone',
        v_meta_trainer
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = COALESCE(EXCLUDED.email, public.profiles.email),
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        last_sign_in_at = now(),
        updated_at = now();

    RETURN NEW;
END;
$$;

-- 4. Protege INSERT e UPDATE em public.profiles contra auto-atribuição de privilégios pelo cliente
CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_setting('role', true) = 'authenticated' OR auth.role() = 'authenticated' THEN
        -- Permite governança apenas a SuperAdmins já validados
        IF public.current_user_is_admin() THEN
            RETURN NEW;
        END IF;

        IF TG_OP = 'INSERT' THEN
            IF COALESCE(NEW.is_admin, FALSE) = TRUE
               OR NEW.role = 'admin'
               OR ('admin' = ANY(COALESCE(NEW.roles, ARRAY[]::TEXT[]))) THEN
                RAISE EXCEPTION 'Criação de perfil com privilégios administrativos não autorizada.';
            END IF;
            IF COALESCE(NEW.is_vip, FALSE) = TRUE
               OR COALESCE(NEW.current_plan, 'free') NOT IN ('free', 'starter') THEN
                RAISE EXCEPTION 'Atribuição direta de plano pago ou VIP não autorizada.';
            END IF;
            RETURN NEW;
        END IF;

        IF NEW.role IS DISTINCT FROM OLD.role OR NEW.roles IS DISTINCT FROM OLD.roles THEN
            RAISE EXCEPTION 'Os papéis do perfil só podem ser alterados por operações autorizadas.';
        END IF;
        IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
            RAISE EXCEPTION 'Modification of is_admin is restricted';
        END IF;
        IF NEW.is_vip IS DISTINCT FROM OLD.is_vip OR NEW.current_plan IS DISTINCT FROM OLD.current_plan THEN
            RAISE EXCEPTION 'Plano e status VIP só podem ser alterados pelo backend de faturamento.';
        END IF;
        IF NEW.session_revoked_at IS DISTINCT FROM OLD.session_revoked_at THEN
            RAISE EXCEPTION 'A revogação de sessões só pode ser realizada pelo backend.';
        END IF;
        IF NEW.trainer_id IS DISTINCT FROM OLD.trainer_id THEN
            RAISE EXCEPTION 'O vínculo de treinador só pode ser alterado por convite autorizado.';
        END IF;
        IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
           NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until THEN
            RAISE EXCEPTION 'Status e vigência de assinatura só podem ser manipulados pelo backend de faturamento.';
        END IF;
        IF NOT (OLD.role = 'trainer' OR 'trainer' = ANY(COALESCE(OLD.roles, ARRAY[]::TEXT[]))) AND (
            NEW.username IS DISTINCT FROM OLD.username OR
            NEW.bio IS DISTINCT FROM OLD.bio OR
            NEW.specialties IS DISTINCT FROM OLD.specialties OR
            NEW.public_whatsapp IS DISTINCT FROM OLD.public_whatsapp OR
            NEW.professional_document IS DISTINCT FROM OLD.professional_document OR
            NEW.public_directory_enabled IS DISTINCT FROM OLD.public_directory_enabled
        ) THEN
            RAISE EXCEPTION 'Somente treinadores podem alterar os campos da vitrine pública.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_privilege_escalation ON public.profiles;
DROP TRIGGER IF EXISTS trg_protect_profile_escalation ON public.profiles;
CREATE TRIGGER protect_profile_privilege_escalation
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_privilege_escalation();

-- 5. Bloqueia contas sintéticas no bootstrap claim_initial_superadmin()
CREATE OR REPLACE FUNCTION public.claim_initial_superadmin()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_email TEXT;
    v_admin_count INT := 0;
    v_already_admin BOOLEAN := FALSE;
    v_roles TEXT[];
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'unauthenticated',
            'message', 'Faça login antes de reivindicar o perfil SuperAdmin.'
        );
    END IF;

    SELECT lower(COALESCE(email, '')) INTO v_email FROM public.profiles WHERE id = v_uid;
    IF v_uid NOT IN (
        '6f645308-f1b2-4d73-ac45-9890c27e20d4'::UUID,
        '50c26610-8054-4b05-9274-7f414f91f52f'::UUID,
        '92dfd58c-845f-473e-b846-a2b8fdd3e508'::UUID
    ) AND (
        v_email LIKE 'wa_%' OR v_email LIKE 'aluno_%' OR v_email LIKE '%.internal' OR v_email LIKE '%.local'
    ) THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'synthetic_account_forbidden',
            'message', 'Contas rápidas de WhatsApp não são elegíveis para SuperAdmin.'
        );
    END IF;

    SELECT public.current_user_is_admin() INTO v_already_admin;
    IF v_already_admin THEN
        RETURN jsonb_build_object(
            'ok', true,
            'status', 'already_admin',
            'user_id', v_uid
        );
    END IF;

    SELECT COUNT(*)
    INTO v_admin_count
    FROM public.profiles
    WHERE is_admin = TRUE
       OR role = 'admin'
       OR ('admin' = ANY(COALESCE(roles, ARRAY[]::TEXT[])));

    IF v_admin_count > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'admin_already_exists',
            'admin_count', v_admin_count,
            'message', 'Já existe um SuperAdmin configurado neste ambiente.'
        );
    END IF;

    SELECT COALESCE(roles, ARRAY[role]::TEXT[])
    INTO v_roles
    FROM public.profiles
    WHERE id = v_uid;

    IF NOT ('admin' = ANY(COALESCE(v_roles, ARRAY[]::TEXT[]))) THEN
        v_roles := array_append(COALESCE(v_roles, ARRAY['trainer']::TEXT[]), 'admin');
    END IF;

    UPDATE public.profiles
    SET
        is_admin = TRUE,
        roles = v_roles,
        updated_at = now()
    WHERE id = v_uid;

    INSERT INTO public.audit_log (user_id, action, metadata)
    VALUES (
        v_uid,
        'admin.claim_initial_superadmin',
        jsonb_build_object('claimed_at', now(), 'roles', v_roles)
    );

    RETURN jsonb_build_object(
        'ok', true,
        'status', 'promoted',
        'user_id', v_uid,
        'roles', v_roles
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_initial_superadmin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_initial_superadmin() TO authenticated, service_role;

COMMIT;

