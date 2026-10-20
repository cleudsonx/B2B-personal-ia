BEGIN;

-- Corrige a tabela de planos na RPC create_student_invite: public.plans em vez de public.subscription_plans
-- e adiciona suporte ao status past_due durante período de tolerância.
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
    v_existing_student_name TEXT;
BEGIN
    IF p_channel NOT IN ('email', 'whatsapp') THEN
        RAISE EXCEPTION 'Canal de convite inválido.' USING ERRCODE = '22023';
    END IF;
    IF (p_channel = 'email' AND COALESCE(p_target_email, '') = '')
       OR (p_channel = 'whatsapp' AND COALESCE(p_target_phone, '') = '') THEN
        RAISE EXCEPTION 'Informe o destino do convite.' USING ERRCODE = '22023';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtextextended(p_trainer_id::TEXT, 0));

    -- Validação: Se o canal for WhatsApp, verifica se já é aluno ativo deste treinador
    IF p_channel = 'whatsapp' THEN
        SELECT full_name INTO v_existing_student_name
        FROM public.profiles
        WHERE role = 'client'
          AND trainer_id = p_trainer_id
          AND public.normalize_phone_digits(phone) = public.normalize_phone_digits(p_target_phone)
        LIMIT 1;

        IF v_existing_student_name IS NOT NULL THEN
            RAISE EXCEPTION 'O aluno(a) "%" já está cadastrado com este telefone na sua consultoria.', v_existing_student_name
                USING ERRCODE = '23505';
        END IF;
    END IF;

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
              AND public.normalize_phone_digits(i.target_phone) = public.normalize_phone_digits(p_target_phone)
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

    -- Busca a cota de alunos do plano na tabela public.plans
    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions AS s
    JOIN public.plans AS p ON p.id = s.plan_id
    WHERE s.trainer_id = p_trainer_id
      AND s.status IN ('active', 'trialing', 'past_due')
    ORDER BY s.updated_at DESC
    LIMIT 1;

    IF v_max_students IS NULL THEN
        v_max_students := 3;
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_occupied_students
    FROM (
        SELECT pr.id
        FROM public.profiles AS pr
        WHERE pr.trainer_id = p_trainer_id
          AND pr.role = 'client'
          AND COALESCE(pr.subscription_status, 'active') NOT IN ('canceled', 'archived', 'inactive')
        UNION ALL
        SELECT it.id
        FROM public.invite_tokens AS it
        WHERE it.trainer_id = p_trainer_id
          AND it.used_at IS NULL
          AND it.expires_at > now()
    ) AS occupied;

    IF v_occupied_students >= v_max_students THEN
        RAISE EXCEPTION 'Limite de alunos atingido para o plano atual (% alunos). Faça upgrade ou libere vagas arquivando alunos inativos.', v_max_students
            USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    INSERT INTO public.invite_tokens (
        token, trainer_id, channel, target_email, target_phone, target_name, objective, injuries_or_restrictions
    )
    VALUES (
        p_token, p_trainer_id, p_channel, p_target_email, p_target_phone, p_target_name, p_objective, p_injuries_or_restrictions
    )
    RETURNING public.invite_tokens.id, public.invite_tokens.token, public.invite_tokens.expires_at;
END;
$$;

COMMIT;
