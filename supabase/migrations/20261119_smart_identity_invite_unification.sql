-- ==============================================================================
-- Migration: 20261119_smart_identity_invite_unification.sql
-- Description:
--   Unifica a jornada do Aluno entre o Modo Degustação (Aluno Explorador sem
--   personal prévio) e o Convite enviado pelo Personal Trainer:
--   1. Atualiza `public.consume_student_invite(p_token, p_student_id)` para:
--      - Validar de forma multicanal inteligente: aceita se o e-mail coincidir
--        OU se o telefone normalizado (DDD + últimos 8/9 dígitos em profiles
--        ou auth.users) coincidir OU se a conta estiver em Modo Degustação
--        (`trainer_id IS NULL`) portando o token criptográfico válido.
--      - Permitir contas Dual-Role (ex: Professor que também testa/atua como
--        Aluno de outro treinador), adicionando `'client'` ao array `roles`
--        sem sobrescrever o `role` principal de `'trainer'`.
--      - Promover automaticamente o e-mail sintético da degustação (`wa_*`,
--        `aluno_*`, `*.internal`) no perfil para o `target_email` do convite.
--   2. Atualiza `public.handle_new_user()` para aceitar convites válidos por
--      match de e-mail OU telefone normalizado, independente do campo `channel`.
-- ==============================================================================

BEGIN;

ALTER TABLE public.invite_tokens
    ADD COLUMN IF NOT EXISTS consumed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.consume_student_invite(
    p_token TEXT,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_invite public.invite_tokens%ROWTYPE;
    v_profile public.profiles%ROWTYPE;
    v_trainer_id UUID;
    v_student_email TEXT;
    v_student_phone TEXT;
    v_student_phone_digits TEXT;
    v_invited_phone_digits TEXT;
    v_email_matches BOOLEAN := FALSE;
    v_phone_matches BOOLEAN := FALSE;
    v_is_explorer_upgrade BOOLEAN := FALSE;
    v_trainer_name TEXT;
    v_max_students INTEGER;
    v_occupied_students INTEGER;
    v_target_email_clean TEXT;
BEGIN
    SELECT i.trainer_id INTO v_trainer_id
    FROM public.invite_tokens AS i
    WHERE i.token = p_token;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Convite não encontrado ou inválido.' USING ERRCODE = 'P0002';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(v_trainer_id::TEXT, 0));

    SELECT i.* INTO v_invite
    FROM public.invite_tokens AS i
    WHERE i.token = p_token
    FOR UPDATE;

    IF v_invite.used_at IS NOT NULL THEN
        IF v_invite.consumed_by = p_student_id
           OR EXISTS (
               SELECT 1 FROM public.profiles AS p
               WHERE p.id = p_student_id AND p.trainer_id = v_invite.trainer_id
           )
        THEN
            SELECT p.full_name INTO v_trainer_name
            FROM public.profiles AS p WHERE p.id = v_invite.trainer_id;
            RETURN jsonb_build_object(
                'status', 'consumed',
                'trainer_id', v_invite.trainer_id,
                'trainer_name', COALESCE(v_trainer_name, 'Seu Personal Trainer'),
                'target_email', v_invite.target_email,
                'target_phone', v_invite.target_phone,
                'channel', v_invite.channel
            );
        END IF;
        RAISE EXCEPTION 'Este convite já foi utilizado.' USING ERRCODE = 'P0001';
    END IF;

    IF v_invite.expires_at <= now() THEN
        RAISE EXCEPTION 'Este convite expirou.' USING ERRCODE = 'P0001';
    END IF;

    IF v_invite.trainer_id = p_student_id THEN
        RAISE EXCEPTION 'Você não pode aceitar um convite emitido por sua própria conta de treinador.' USING ERRCODE = '42501';
    END IF;

    SELECT p.* INTO v_profile
    FROM public.profiles AS p
    WHERE p.id = p_student_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil do aluno não encontrado.' USING ERRCODE = 'P0002';
    END IF;

    SELECT u.email,
           COALESCE(
               NULLIF(trim(v_profile.phone), ''),
               NULLIF(trim(v_profile.public_whatsapp), ''),
               NULLIF(trim(u.phone), ''),
               NULLIF(trim(u.raw_user_meta_data->>'phone'), '')
           )
    INTO v_student_email, v_student_phone
    FROM auth.users AS u
    WHERE u.id = p_student_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conta do aluno não encontrada.' USING ERRCODE = 'P0002';
    END IF;

    v_student_email := lower(trim(COALESCE(v_student_email, v_profile.email, '')));
    v_target_email_clean := lower(trim(COALESCE(v_invite.target_email, '')));

    v_student_phone_digits := public.normalize_phone_digits(v_student_phone);
    v_invited_phone_digits := public.normalize_phone_digits(v_invite.target_phone);

    -- 1. Match por e-mail
    IF v_target_email_clean <> '' AND v_student_email = v_target_email_clean THEN
        v_email_matches := TRUE;
    END IF;

    -- 2. Match por telefone (exato ou DDD + últimos 8 dígitos para compatibilidade 8/9 dígitos no WhatsApp)
    IF v_invited_phone_digits IS NOT NULL AND v_student_phone_digits IS NOT NULL THEN
        IF v_student_phone_digits = v_invited_phone_digits THEN
            v_phone_matches := TRUE;
        ELSIF length(v_student_phone_digits) >= 10
              AND length(v_invited_phone_digits) >= 10
              AND left(v_student_phone_digits, 2) = left(v_invited_phone_digits, 2)
              AND right(v_student_phone_digits, 8) = right(v_invited_phone_digits, 8) THEN
            v_phone_matches := TRUE;
        END IF;
    END IF;

    -- 3. Upgrade legítimo de Aluno em Modo Degustação (trainer_id IS NULL) portando o token criptográfico
    IF v_profile.trainer_id IS NULL THEN
        v_is_explorer_upgrade := TRUE;
    END IF;

    IF NOT (v_email_matches OR v_phone_matches OR v_is_explorer_upgrade) THEN
        IF v_invite.channel = 'whatsapp' THEN
            RAISE EXCEPTION 'Este convite foi destinado a outro telefone.' USING ERRCODE = '42501';
        ELSE
            RAISE EXCEPTION 'Este convite foi destinado a outro e-mail.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF v_profile.trainer_id IS NOT NULL AND v_profile.trainer_id <> v_invite.trainer_id THEN
        RAISE EXCEPTION 'Esta conta já está vinculada a outro treinador.' USING ERRCODE = '23514';
    END IF;

    -- Valida cota de alunos do treinador caso ainda não esteja vinculado a ele
    IF v_profile.trainer_id IS NULL THEN
        SELECT p.max_students INTO v_max_students
        FROM public.subscriptions AS s
        JOIN public.plans AS p ON p.id = s.plan_id
        WHERE s.trainer_id = v_invite.trainer_id
          AND s.status IN ('active', 'trialing', 'past_due')
        ORDER BY s.updated_at DESC
        LIMIT 1;
        v_max_students := COALESCE(v_max_students, 3);

        SELECT
            (SELECT COUNT(*) FROM public.profiles AS p
             WHERE p.trainer_id = v_invite.trainer_id
               AND p.role = 'client'
               AND p.id <> p_student_id
               AND lower(COALESCE(p.subscription_status, 'active'))
                   NOT IN ('arquivado', 'inativo', 'canceled', 'archived', 'inactive'))
            +
            (SELECT COUNT(*) FROM public.invite_tokens AS i
             WHERE i.trainer_id = v_invite.trainer_id
               AND i.id <> v_invite.id
               AND i.used_at IS NULL
               AND i.expires_at > now())
        INTO v_occupied_students;

        IF v_occupied_students >= v_max_students THEN
            RAISE EXCEPTION 'O limite de alunos do treinador foi atingido. Peça que ele libere uma vaga.'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- Atualiza perfil: vincula trainer_id, garante 'client' em roles (suporte Dual-Role para professor que é aluno),
    -- sincroniza telefone se vazio e promove e-mail sintético da degustação para o e-mail real do convite.
    UPDATE public.profiles
    SET trainer_id = v_invite.trainer_id,
        roles = CASE
            WHEN 'client' = ANY(COALESCE(roles, ARRAY[]::TEXT[])) THEN COALESCE(roles, ARRAY[]::TEXT[])
            ELSE array_append(COALESCE(roles, ARRAY[role]::TEXT[]), 'client')
        END,
        phone = CASE
            WHEN COALESCE(trim(phone), '') = '' AND COALESCE(trim(v_invite.target_phone), '') <> ''
                THEN trim(v_invite.target_phone)
            ELSE phone
        END,
        email = CASE
            WHEN v_target_email_clean <> ''
                 AND (
                     COALESCE(trim(email), '') = ''
                     OR lower(trim(email)) LIKE 'wa_%'
                     OR lower(trim(email)) LIKE 'aluno_%'
                     OR lower(trim(email)) LIKE '%.internal'
                     OR lower(trim(email)) LIKE '%.local'
                 )
                THEN v_target_email_clean
            ELSE email
        END,
        full_name = CASE
            WHEN (COALESCE(trim(full_name), '') IN ('', 'Aluno', 'Usuário', 'Atleta'))
                 AND COALESCE(trim(v_invite.target_name), '') <> ''
                THEN trim(v_invite.target_name)
            ELSE full_name
        END,
        updated_at = now()
    WHERE id = p_student_id;

    IF NOT EXISTS (
        SELECT 1 FROM public.anamnesis AS a WHERE a.client_id = p_student_id
    ) THEN
        INSERT INTO public.anamnesis (
            client_id, trainer_id, objective, training_level, days_per_week,
            workout_location, injuries_or_restrictions
        ) VALUES (
            p_student_id, v_invite.trainer_id, v_invite.objective, 'Iniciante', 3,
            'Academia Convencional', v_invite.injuries_or_restrictions
        );
    END IF;

    UPDATE public.invite_tokens
    SET used_at = now(), consumed_by = p_student_id
    WHERE id = v_invite.id;

    SELECT p.full_name INTO v_trainer_name
    FROM public.profiles AS p WHERE p.id = v_invite.trainer_id;

    RETURN jsonb_build_object(
        'status', 'consumed',
        'trainer_id', v_invite.trainer_id,
        'trainer_name', COALESCE(v_trainer_name, 'Seu Personal Trainer'),
        'target_email', v_invite.target_email,
        'target_phone', v_invite.target_phone,
        'channel', v_invite.channel
    );
END;
$$;

REVOKE ALL ON FUNCTION public.consume_student_invite(TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_student_invite(TEXT, UUID)
    TO service_role;

-- 2. Atualiza handle_new_user() para validar convites de forma multicanal (E-mail OU Telefone)
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
    v_email_ok BOOLEAN := FALSE;
    v_phone_ok BOOLEAN := FALSE;
BEGIN
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

        -- Validação Multicanal (E-mail OU Telefone normalizado)
        IF COALESCE(trim(v_invite.target_email), '') <> ''
           AND lower(trim(COALESCE(NEW.email, ''))) = lower(trim(v_invite.target_email)) THEN
            v_email_ok := TRUE;
        END IF;

        v_user_phone := COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data->>'phone');
        v_user_digits := public.normalize_phone_digits(v_user_phone);
        v_invited_digits := public.normalize_phone_digits(v_invite.target_phone);

        IF v_user_digits IS NOT NULL AND v_invited_digits IS NOT NULL THEN
            IF v_user_digits = v_invited_digits THEN
                v_phone_ok := TRUE;
            ELSIF length(v_user_digits) >= 10
                  AND length(v_invited_digits) >= 10
                  AND left(v_user_digits, 2) = left(v_invited_digits, 2)
                  AND right(v_user_digits, 8) = right(v_invited_digits, 8) THEN
                v_phone_ok := TRUE;
            END IF;
        END IF;

        IF NOT (v_email_ok OR v_phone_ok) THEN
            IF v_invite.channel = 'whatsapp' THEN
                RAISE EXCEPTION 'Este convite foi destinado a outro telefone.' USING ERRCODE = '42501';
            ELSE
                RAISE EXCEPTION 'Este convite foi destinado a outro e-mail.' USING ERRCODE = '42501';
            END IF;
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

COMMIT;
