-- Migration: 20261019_fix_invite_resend_channel.sql
-- Objetivo: Permitir que o professor lembre/reenvie convites pelo WhatsApp ou E-mail para alunos pendentes
-- sem que a restrição de canal gere conflito ou estoure a cota de alunos do plano.

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
    v_clean_target_phone TEXT;
    v_max_students INTEGER;
    v_occupied_students INTEGER;
    v_new_expires_at TIMESTAMPTZ;
BEGIN
    IF p_channel NOT IN ('email', 'whatsapp') THEN
        RAISE EXCEPTION 'Canal de convite inválido.' USING ERRCODE = '22023';
    END IF;
    IF (p_channel = 'email' AND COALESCE(trim(p_target_email), '') = '')
       OR (p_channel = 'whatsapp' AND COALESCE(trim(p_target_phone), '') = '') THEN
        RAISE EXCEPTION 'Informe o destino do convite.' USING ERRCODE = '22023';
    END IF;

    -- Normaliza dígitos do telefone de destino
    v_clean_target_phone := regexp_replace(COALESCE(p_target_phone, ''), '\D', '', 'g');
    IF left(v_clean_target_phone, 2) = '55' AND length(v_clean_target_phone) > 11 THEN
        v_clean_target_phone := substr(v_clean_target_phone, 3);
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(p_trainer_id::TEXT, 0));

    -- 1. Busca convite pendente existente do treinador para o mesmo aluno (por e-mail OU por telefone)
    -- Independente do canal original, para permitir que o professor lembre no WhatsApp um aluno convidado por email
    SELECT i.* INTO v_existing
    FROM public.invite_tokens AS i
    WHERE i.trainer_id = p_trainer_id
      AND i.used_at IS NULL
      AND (
          (COALESCE(trim(p_target_email), '') <> '' AND lower(trim(i.target_email)) = lower(trim(p_target_email)))
          OR (
              v_clean_target_phone <> ''
              AND CASE
                  WHEN left(regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g'), 2) = '55'
                      AND length(regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g')) > 11
                      THEN substr(regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g'), 3)
                  ELSE regexp_replace(COALESCE(i.target_phone, ''), '\D', '', 'g')
              END = v_clean_target_phone
          )
      )
    ORDER BY i.created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        v_new_expires_at := now() + INTERVAL '48 hours';
        UPDATE public.invite_tokens AS i
        SET channel = p_channel,
            target_name = COALESCE(NULLIF(trim(p_target_name), ''), i.target_name),
            target_email = COALESCE(NULLIF(lower(trim(p_target_email)), ''), i.target_email),
            target_phone = COALESCE(NULLIF(trim(p_target_phone), ''), i.target_phone),
            objective = COALESCE(NULLIF(trim(p_objective), ''), i.objective),
            injuries_or_restrictions = COALESCE(NULLIF(trim(p_injuries_or_restrictions), ''), i.injuries_or_restrictions),
            expires_at = v_new_expires_at
        WHERE i.id = v_existing.id;

        RETURN QUERY SELECT v_existing.id, v_existing.token, v_new_expires_at;
        RETURN;
    END IF;

    -- 2. Se não encontrou convite pendente prévio, valida cota de alunos do plano
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

    v_new_expires_at := now() + INTERVAL '48 hours';

    RETURN QUERY
    INSERT INTO public.invite_tokens AS i (
        token, trainer_id, target_email, target_phone, target_name,
        channel, objective, injuries_or_restrictions, expires_at
    ) VALUES (
        p_token,
        p_trainer_id,
        NULLIF(lower(trim(p_target_email)), ''),
        NULLIF(trim(p_target_phone), ''),
        NULLIF(trim(p_target_name), ''),
        p_channel,
        COALESCE(NULLIF(trim(p_objective), ''), 'Hipertrofia Muscular'),
        COALESCE(NULLIF(trim(p_injuries_or_restrictions), ''), 'Nenhuma restrição relatada.'),
        v_new_expires_at
    )
    RETURNING i.id, i.token, i.expires_at;
END;
$$;

REVOKE ALL ON FUNCTION public.create_student_invite(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_student_invite(TEXT, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT)
    TO service_role;

