-- Treat archived students (subscription_status = 'canceled') as released slots.
-- Keep the database quota trigger aligned with the API's occupied-slot count.
CREATE OR REPLACE FUNCTION public.enforce_trainer_student_quota()
RETURNS TRIGGER AS $$
DECLARE
    v_max_students INTEGER;
    v_current_students INTEGER;
    v_is_reactivation BOOLEAN := false;
BEGIN
    IF NEW.role <> 'client' OR NEW.trainer_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF LOWER(COALESCE(NEW.subscription_status, 'active')) IN ('arquivado', 'inativo', 'canceled') THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF LOWER(COALESCE(OLD.subscription_status, 'active')) IN ('arquivado', 'inativo', 'canceled') THEN
            v_is_reactivation := true;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions s
    JOIN public.plans p ON p.id = s.plan_id
    WHERE s.trainer_id = NEW.trainer_id
      AND s.status IN ('active', 'trialing')
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_max_students IS NULL THEN
        v_max_students := 3;
    END IF;

    SELECT COUNT(*) INTO v_current_students
    FROM public.profiles
    WHERE trainer_id = NEW.trainer_id
      AND role = 'client'
      AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND LOWER(COALESCE(subscription_status, 'active')) NOT IN ('arquivado', 'inativo', 'canceled');

    IF v_current_students >= v_max_students THEN
        IF v_is_reactivation THEN
            RAISE EXCEPTION 'Limite de % alunos ativos atingido no seu plano. Para reativar este aluno, faça upgrade do plano ou arquive outro aluno.', v_max_students
                USING ERRCODE = '23514';
        ELSE
            RAISE EXCEPTION 'Limite de % alunos ativos atingido no seu plano. Faça upgrade para cadastrar novos alunos.', v_max_students
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
