-- ==============================================================================
-- Migration: 20261023_require_invite_for_student_signup.sql
-- Description: Impede criar conta 'client' em auth.users sem convite válido.
--   * Roles aceitos: apenas 'trainer' e 'client' (sem default silencioso).
--   * 'client' exige metadata invite_token existente, não usado, não expirado,
--     compatível com e-mail (channel email) ou telefone (channel whatsapp) e,
--     se informado, com o trainer_id do convite.
--   * O convite NÃO é consumido aqui; continua sendo consumido por
--     public.consume_student_invite (atomicidade preservada).
--   * Contas provisionadas pelo backend (Admin API) são confiáveis somente se
--     raw_app_meta_data.provisioned_by_backend = 'true'. app_metadata não pode ser
--     definido via signUp público (só pela Admin API/service role).
--   * Execuções diretas como 'postgres' (seed/migrações/SQL editor) são confiáveis.
--
-- ROLLBACK: reaplicar a função handle_new_user() de
--   20261015_auth_capabilities_mfa_sessions.sql (copiada ao final deste arquivo).
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role TEXT := lower(trim(COALESCE(NEW.raw_user_meta_data->>'role', '')));
    v_token TEXT := trim(COALESCE(NEW.raw_user_meta_data->>'invite_token', ''));
    v_meta_trainer UUID := NULLIF(NEW.raw_user_meta_data->>'trainer_id', '')::UUID;
    v_trusted BOOLEAN := COALESCE(NEW.raw_app_meta_data->>'provisioned_by_backend', '') = 'true'
                         OR session_user = 'postgres';
    v_invite public.invite_tokens%ROWTYPE;
    v_user_phone TEXT;
    v_user_digits TEXT;
    v_invited_digits TEXT;
BEGIN
    IF v_role NOT IN ('trainer', 'client') THEN
        RAISE EXCEPTION 'Papel de conta inválido ou ausente.' USING ERRCODE = '22023';
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
        id, full_name, role, roles, phone, trainer_id, username, bio, specialties,
        public_whatsapp, photo_url, avatar_url, professional_document
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
        v_role,
        ARRAY[v_role],
        NEW.raw_user_meta_data->>'phone',
        v_meta_trainer,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'bio',
        COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'specialties')),
            '{}'::TEXT[]
        ),
        NEW.raw_user_meta_data->>'public_whatsapp',
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
        NEW.raw_user_meta_data->>'professional_document'
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        username = COALESCE(EXCLUDED.username, public.profiles.username),
        bio = COALESCE(EXCLUDED.bio, public.profiles.bio),
        specialties = CASE
            WHEN cardinality(EXCLUDED.specialties) > 0 THEN EXCLUDED.specialties
            ELSE public.profiles.specialties
        END,
        public_whatsapp = COALESCE(EXCLUDED.public_whatsapp, public.profiles.public_whatsapp),
        photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
        professional_document = COALESCE(EXCLUDED.professional_document, public.profiles.professional_document),
        updated_at = now();
    RETURN NEW;
END;
$$;

COMMIT;

-- ==============================================================================
-- ROLLBACK (função anterior, de 20261015_auth_capabilities_mfa_sessions.sql):
--
-- CREATE OR REPLACE FUNCTION public.handle_new_user()
-- RETURNS TRIGGER
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = ''
-- AS $$
-- DECLARE
--     v_role TEXT := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
-- BEGIN
--     INSERT INTO public.profiles (
--         id, full_name, role, roles, phone, trainer_id, username, bio, specialties,
--         public_whatsapp, photo_url, avatar_url, professional_document
--     )
--     VALUES (
--         NEW.id,
--         COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
--         v_role,
--         ARRAY[v_role],
--         NEW.raw_user_meta_data->>'phone',
--         NULLIF(NEW.raw_user_meta_data->>'trainer_id', '')::UUID,
--         NEW.raw_user_meta_data->>'username',
--         NEW.raw_user_meta_data->>'bio',
--         COALESCE(
--             ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'specialties')),
--             '{}'::TEXT[]
--         ),
--         NEW.raw_user_meta_data->>'public_whatsapp',
--         COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
--         COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
--         NEW.raw_user_meta_data->>'professional_document'
--     )
--     ON CONFLICT (id) DO UPDATE SET
--         full_name = EXCLUDED.full_name,
--         phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
--         username = COALESCE(EXCLUDED.username, public.profiles.username),
--         bio = COALESCE(EXCLUDED.bio, public.profiles.bio),
--         specialties = CASE
--             WHEN cardinality(EXCLUDED.specialties) > 0 THEN EXCLUDED.specialties
--             ELSE public.profiles.specialties
--         END,
--         public_whatsapp = COALESCE(EXCLUDED.public_whatsapp, public.profiles.public_whatsapp),
--         photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url),
--         avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
--         professional_document = COALESCE(EXCLUDED.professional_document, public.profiles.professional_document),
--         updated_at = now();
--     RETURN NEW;
-- END;
-- $$;
-- ==============================================================================
