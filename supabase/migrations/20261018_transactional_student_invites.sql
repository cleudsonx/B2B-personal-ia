ALTER TABLE public.invite_tokens
    ADD COLUMN IF NOT EXISTS target_name TEXT,
    ADD COLUMN IF NOT EXISTS objective TEXT NOT NULL DEFAULT 'Hipertrofia Muscular',
    ADD COLUMN IF NOT EXISTS injuries_or_restrictions TEXT NOT NULL DEFAULT 'Nenhuma restrição relatada.',
    ADD COLUMN IF NOT EXISTS consumed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

DROP POLICY IF EXISTS "trainer_create_own_invites" ON public.invite_tokens;

CREATE OR REPLACE FUNCTION public.create_student_invite(
    p_token TEXT,
    p_trainer_id UUID,
    p_channel TEXT,
    p_target_email TEXT,
    p_target_phone TEXT,
    p_target_name TEXT,
    p_objective TEXT,
    p_injuries_or_restrictions TEXT
)
RETURNS TABLE(id UUID, token TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_existing public.invite_tokens%ROWTYPE;
    v_max_students INTEGER;
    v_occupied_students INTEGER;
BEGIN
    IF p_channel NOT IN ('email', 'whatsapp') THEN
        RAISE EXCEPTION 'Canal de convite inválido.' USING ERRCODE = '22023';
    END IF;
    IF (p_channel = 'email' AND COALESCE(p_target_email, '') = '')
       OR (p_channel = 'whatsapp' AND COALESCE(p_target_phone, '') = '') THEN
        RAISE EXCEPTION 'Informe o destino do convite.' USING ERRCODE = '22023';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(p_trainer_id::TEXT, 0));

    SELECT i.* INTO v_existing
    FROM public.invite_tokens AS i
    WHERE i.trainer_id = p_trainer_id
      AND i.channel = p_channel
      AND i.used_at IS NULL
      AND i.expires_at > now()
      AND (
          (p_channel = 'email' AND lower(i.target_email) = lower(p_target_email))
          OR (
              p_channel = 'whatsapp'
              AND CASE
                  WHEN left(regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g'), 2) = '55'
                      THEN substr(regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g'), 3)
                  ELSE regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g')
              END
              = CASE
                  WHEN left(regexp_replace(COALESCE(p_target_phone, ''), '\D', '', 'g'), 2) = '55'
                      THEN substr(regexp_replace(COALESCE(p_target_phone, ''), '\D', '', 'g'), 3)
                  ELSE regexp_replace(COALESCE(p_target_phone, ''), '\D', '', 'g')
              END
          )
      )
    ORDER BY i.created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        UPDATE public.invite_tokens AS i
        SET target_name = COALESCE(NULLIF(p_target_name, ''), i.target_name),
            objective = COALESCE(NULLIF(p_objective, ''), i.objective),
            injuries_or_restrictions = COALESCE(NULLIF(p_injuries_or_restrictions, ''), i.injuries_or_restrictions)
        WHERE i.id = v_existing.id;
        RETURN QUERY SELECT v_existing.id, v_existing.token, v_existing.expires_at;
        RETURN;
    END IF;

    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions AS s
    JOIN public.plans AS p ON p.id = s.plan_id
    WHERE s.trainer_id = p_trainer_id
      AND s.status IN ('active', 'trialing')
    ORDER BY s.created_at DESC
    LIMIT 1;
    v_max_students := COALESCE(v_max_students, 3);

    SELECT
        (SELECT COUNT(*) FROM public.profiles AS p
         WHERE p.trainer_id = p_trainer_id
           AND p.role = 'client'
           AND lower(COALESCE(p.subscription_status, 'active'))
               NOT IN ('arquivado', 'inativo', 'canceled'))
        +
        (SELECT COUNT(*) FROM public.invite_tokens AS i
         WHERE i.trainer_id = p_trainer_id
           AND i.used_at IS NULL
           AND i.expires_at > now())
    INTO v_occupied_students;

    IF v_occupied_students >= v_max_students THEN
        RAISE EXCEPTION 'Limite de % alunos ativos atingido no seu plano.', v_max_students
            USING ERRCODE = '23514';
    END IF;

    RETURN QUERY
    INSERT INTO public.invite_tokens AS i (
        token, trainer_id, target_email, target_phone, target_name,
        channel, objective, injuries_or_restrictions
    ) VALUES (
        p_token,
        p_trainer_id,
        NULLIF(lower(trim(p_target_email)), ''),
        NULLIF(trim(p_target_phone), ''),
        NULLIF(trim(p_target_name), ''),
        p_channel,
        COALESCE(NULLIF(trim(p_objective), ''), 'Hipertrofia Muscular'),
        COALESCE(NULLIF(trim(p_injuries_or_restrictions), ''), 'Nenhuma restrição relatada.')
    )
    RETURNING i.id, i.token, i.expires_at;
END;
$$;

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
    v_trainer_name TEXT;
    v_max_students INTEGER;
    v_occupied_students INTEGER;
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
        IF v_invite.consumed_by = p_student_id THEN
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

    SELECT u.email, COALESCE(u.phone, u.raw_user_meta_data->>'phone')
    INTO v_student_email, v_student_phone
    FROM auth.users AS u
    WHERE u.id = p_student_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conta do aluno não encontrada.' USING ERRCODE = 'P0002';
    END IF;

    IF v_invite.channel = 'email'
       AND lower(trim(COALESCE(v_student_email, ''))) <> lower(trim(COALESCE(v_invite.target_email, ''))) THEN
        RAISE EXCEPTION 'Este convite foi destinado a outro e-mail.' USING ERRCODE = '42501';
    END IF;
    IF v_invite.channel = 'whatsapp' THEN
        v_student_phone_digits := regexp_replace(COALESCE(v_student_phone, ''), '\D', '', 'g');
        v_invited_phone_digits := regexp_replace(COALESCE(v_invite.target_phone, ''), '\D', '', 'g');
        IF left(v_student_phone_digits, 2) = '55' AND length(v_student_phone_digits) > 11 THEN
            v_student_phone_digits := substr(v_student_phone_digits, 3);
        END IF;
        IF left(v_invited_phone_digits, 2) = '55' AND length(v_invited_phone_digits) > 11 THEN
            v_invited_phone_digits := substr(v_invited_phone_digits, 3);
        END IF;
        IF v_student_phone_digits = '' OR v_student_phone_digits <> v_invited_phone_digits THEN
            RAISE EXCEPTION 'Este convite foi destinado a outro telefone.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT p.* INTO v_profile
    FROM public.profiles AS p
    WHERE p.id = p_student_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Perfil do aluno não encontrado.' USING ERRCODE = 'P0002';
    END IF;
    IF v_profile.role <> 'client'
       AND NOT ('client' = ANY(COALESCE(v_profile.roles, ARRAY[]::TEXT[]))) THEN
        RAISE EXCEPTION 'Esta conta não pode aceitar um convite de aluno.' USING ERRCODE = '42501';
    END IF;
    IF v_profile.trainer_id IS NOT NULL AND v_profile.trainer_id <> v_invite.trainer_id THEN
        RAISE EXCEPTION 'Esta conta já está vinculada a outro treinador.' USING ERRCODE = '23514';
    END IF;

    IF v_profile.trainer_id IS NULL THEN
        SELECT p.max_students INTO v_max_students
        FROM public.subscriptions AS s
        JOIN public.plans AS p ON p.id = s.plan_id
        WHERE s.trainer_id = v_invite.trainer_id
          AND s.status IN ('active', 'trialing')
        ORDER BY s.created_at DESC
        LIMIT 1;
        v_max_students := COALESCE(v_max_students, 3);

        SELECT
            (SELECT COUNT(*) FROM public.profiles AS p
             WHERE p.trainer_id = v_invite.trainer_id
               AND p.role = 'client'
               AND p.id <> p_student_id
               AND lower(COALESCE(p.subscription_status, 'active'))
                   NOT IN ('arquivado', 'inativo', 'canceled'))
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

    UPDATE public.profiles
    SET trainer_id = v_invite.trainer_id,
        roles = CASE
            WHEN 'client' = ANY(COALESCE(roles, ARRAY[]::TEXT[])) THEN COALESCE(roles, ARRAY[]::TEXT[])
            ELSE array_append(COALESCE(roles, ARRAY[]::TEXT[]), 'client')
        END
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

REVOKE ALL ON FUNCTION public.create_student_invite(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_student_invite(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
    TO service_role;

REVOKE ALL ON FUNCTION public.consume_student_invite(TEXT, UUID)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_student_invite(TEXT, UUID)
    TO service_role;