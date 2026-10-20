-- ==============================================================================
-- Migration: 20261105_unique_student_phone_per_trainer.sql
-- Description:
--   1. Cria a função imutável `public.normalize_phone_digits(p_phone TEXT)`
--      para higienização padronizada de números de telefone (remove não-dígitos e DDI 55).
--   2. Limpa duplicatas históricas existentes (mantendo o registro mais recente).
--   3. Cria índice único parcial garantindo que um mesmo número de telefone
--      NÃO possa ser cadastrado para mais de um aluno com o MESMO treinador,
--      mas PERMITINDO que o aluno tenha cadastros com treinadores DISTINTOS.
--   4. Trigger para validação atômica com mensagem de erro amigável em INSERT/UPDATE.
--   5. Atualiza `public.create_student_invite` para validar duplicidade de telefone
--      em relação aos alunos já ativos do treinador.
-- ==============================================================================

BEGIN;

-- 1. Função de higienização e normalização de telefone (IMMUTABLE para suporte a índice funcional)
CREATE OR REPLACE FUNCTION public.normalize_phone_digits(p_phone TEXT)
RETURNS TEXT
IMMUTABLE
LANGUAGE plpgsql
AS $$
DECLARE
    v_clean TEXT;
BEGIN
    IF p_phone IS NULL OR trim(p_phone) = '' THEN
        RETURN NULL;
    END IF;
    -- Remove todos os caracteres não numéricos
    v_clean := regexp_replace(p_phone, '\D', '', 'g');
    -- Se tiver DDI 55 com DDD + 8 ou 9 dígitos (12 ou 13 dígitos)
    IF length(v_clean) >= 12 AND left(v_clean, 2) = '55' THEN
        v_clean := substr(v_clean, 3);
    END IF;
    -- Número mínimo válido (DDD 2 dígitos + mínimo 6 dígitos)
    IF length(v_clean) < 8 THEN
        RETURN NULL;
    END IF;
    RETURN v_clean;
END;
$$;

-- 2. Limpeza graciosa de eventuais duplicatas históricas antes de criar o índice único:
-- Mantém o telefone no aluno mais recente (created_at DESC) e limpa nos anteriores para não falhar a migration
WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY trainer_id, public.normalize_phone_digits(phone)
               ORDER BY created_at DESC
           ) as rn
    FROM public.profiles
    WHERE role = 'client' 
      AND phone IS NOT NULL 
      AND public.normalize_phone_digits(phone) IS NOT NULL
      AND trainer_id IS NOT NULL
)
UPDATE public.profiles p
SET phone = NULL
FROM duplicates d
WHERE p.id = d.id AND d.rn > 1;

-- 3. Índice Único Parcial: (trainer_id, normalized_phone) para role = 'client'
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_student_phone_per_trainer 
ON public.profiles (trainer_id, public.normalize_phone_digits(phone)) 
WHERE role = 'client' 
  AND phone IS NOT NULL 
  AND phone <> '' 
  AND trainer_id IS NOT NULL;

-- 4. Trigger com validação preventiva e mensagem de erro legível
CREATE OR REPLACE FUNCTION public.check_student_phone_uniqueness()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_norm_new TEXT;
    v_existing_name TEXT;
BEGIN
    IF NEW.role = 'client' AND NEW.phone IS NOT NULL AND NEW.trainer_id IS NOT NULL THEN
        v_norm_new := public.normalize_phone_digits(NEW.phone);
        IF v_norm_new IS NOT NULL THEN
            SELECT full_name INTO v_existing_name
            FROM public.profiles
            WHERE role = 'client'
              AND trainer_id = NEW.trainer_id
              AND id <> NEW.id
              AND public.normalize_phone_digits(phone) = v_norm_new
            LIMIT 1;

            IF v_existing_name IS NOT NULL THEN
                RAISE EXCEPTION 'Este número de telefone já está cadastrado para o aluno(a) "%" neste treinador.', v_existing_name
                    USING ERRCODE = '23505';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_student_phone_uniqueness ON public.profiles;
CREATE TRIGGER trg_check_student_phone_uniqueness
BEFORE INSERT OR UPDATE OF phone, trainer_id, role
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.check_student_phone_uniqueness();

-- 5. Atualização de public.create_student_invite para impedir convite a telefone já ativo no treinador
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

    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions AS s
    JOIN public.subscription_plans AS p ON p.id = s.plan_id
    WHERE s.trainer_id = p_trainer_id
      AND s.status IN ('active', 'trialing')
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
        RAISE EXCEPTION 'Limite de alunos atingido para o plano atual (% alunos).', v_max_students
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

