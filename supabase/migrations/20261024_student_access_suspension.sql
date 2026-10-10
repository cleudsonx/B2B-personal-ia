-- ==============================================================================
-- Migration: 20261024_student_access_suspension.sql
-- Description: Status "Acesso suspenso" para alunos inadimplentes.
--   * profiles.subscription_status passa a aceitar 'suspended' (UI: "Acesso suspenso"),
--     distinto de 'canceled' ("Arquivado", que libera vaga).
--   * Aluno suspenso continua vinculado ao professor, MANTÉM a vaga (as listas de
--     liberação de vaga em enforce_trainer_student_quota, create_student_invite e
--     consume_student_invite só contêm arquivado/inativo/canceled; nada muda nelas),
--     autentica e lê o próprio perfil e o do professor vinculado, mas perde acesso a
--     treinos, anamnese, adaptações, gamificação e sessões de treino.
--   * Reativação suspended -> active não é "reativação" na trigger de cota
--     (v_is_reactivation só vale para arquivado/inativo/canceled -> ativo).
--   * Auto-alteração de status/vínculo/papéis já era bloqueada por
--     protect_profile_privilege_escalation (20261015); aqui entra uma segunda trava
--     independente de auth.role() e a policy de UPDATE passa a negar suspensos.
--   * Policies de professor NÃO são alteradas: "Trainers can view their associated
--     clients" não filtra status e continua listando alunos suspensos.
--
-- Idempotente. ROLLBACK comentado ao final do arquivo.
-- ==============================================================================

BEGIN;

-- 1. CHECK de subscription_status com 'suspended' --------------------------------
DO $$
DECLARE
    v_con RECORD;
BEGIN
    FOR v_con IN
        SELECT c.conname
        FROM pg_constraint AS c
        WHERE c.conrelid = 'public.profiles'::regclass
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) ILIKE '%subscription_status%'
    LOOP
        EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I', v_con.conname);
    END LOOP;
END;
$$;

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_subscription_status_check
    CHECK (subscription_status IN ('trial', 'active', 'past_due', 'canceled', 'suspended'));

-- 2. Função auxiliar (SECURITY DEFINER evita recursão de RLS em profiles) ---------
CREATE OR REPLACE FUNCTION public.is_student_access_suspended(p_user UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_user IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Usuário autenticado só consulta a si mesmo (sem oráculo do status de terceiros).
    IF auth.uid() IS NOT NULL AND p_user <> auth.uid() THEN
        RETURN FALSE;
    END IF;

    RETURN COALESCE((
        SELECT p.subscription_status = 'suspended'
               AND (p.role = 'client' OR 'client' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[])))
        FROM public.profiles AS p
        WHERE p.id = p_user
    ), FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.is_student_access_suspended(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_student_access_suspended(UUID) TO authenticated, service_role;

-- 3. Policies de aluno: exigem aluno NÃO suspenso --------------------------------
-- Mantidas sem alteração (necessárias para a tela de suspensão):
--   profiles: "Users can view their own profile", "Clients can view their assigned trainer".

-- profiles: suspenso não atualiza nem o próprio perfil.
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id AND public.is_current_session_valid()
           AND NOT public.is_student_access_suspended())
    WITH CHECK (auth.uid() = id AND public.is_current_session_valid()
                AND NOT public.is_student_access_suspended());

DROP POLICY IF EXISTS "Clients can view their workouts" ON public.workouts;
CREATE POLICY "Clients can view their workouts" ON public.workouts
    FOR SELECT USING (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

DROP POLICY IF EXISTS "Clients can view their own anamnesis" ON public.anamnesis;
CREATE POLICY "Clients can view their own anamnesis" ON public.anamnesis
    FOR SELECT USING (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

DROP POLICY IF EXISTS "Clients can create adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can create adaptation logs" ON public.adaptation_logs
    FOR INSERT WITH CHECK (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
        AND trainer_id = public.current_user_trainer_id()
    );

DROP POLICY IF EXISTS "Clients can view their adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can view their adaptation logs" ON public.adaptation_logs
    FOR SELECT USING (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

DROP POLICY IF EXISTS "Clients can view own gamification stats" ON public.gamification_stats;
CREATE POLICY "Clients can view own gamification stats" ON public.gamification_stats
    FOR SELECT USING (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

DROP POLICY IF EXISTS "Clients insert own sessions" ON public.workout_sessions;
CREATE POLICY "Clients insert own sessions" ON public.workout_sessions
    FOR INSERT WITH CHECK (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

DROP POLICY IF EXISTS "Clients read own sessions" ON public.workout_sessions;
CREATE POLICY "Clients read own sessions" ON public.workout_sessions
    FOR SELECT USING (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND NOT public.is_student_access_suspended()
    );

-- 4. Trava contra auto-reativação / auto-alteração de campos sensíveis ------------
-- Independe de auth.role(): qualquer requisição com JWT de usuário (auth.uid() não nulo)
-- é barrada; backend (service_role, sem sub) e SQL direto (postgres) seguem permitidos.
CREATE OR REPLACE FUNCTION public.guard_profile_access_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND (
        NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
        NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until OR
        NEW.trainer_id IS DISTINCT FROM OLD.trainer_id OR
        NEW.role IS DISTINCT FROM OLD.role OR
        NEW.roles IS DISTINCT FROM OLD.roles
    ) THEN
        RAISE EXCEPTION 'Status, vínculo e papéis do perfil só podem ser alterados pelo backend.'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_profile_access_fields() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_profile_access_fields ON public.profiles;
CREATE TRIGGER trg_guard_profile_access_fields
    BEFORE UPDATE OF subscription_status, subscription_valid_until, trainer_id, role, roles
    ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.guard_profile_access_fields();

COMMIT;

-- ==============================================================================
-- ROLLBACK (executar manualmente, nesta ordem; revisão humana antes de aplicar):
--
-- BEGIN;
--
-- -- a) Remover a trava adicional.
-- DROP TRIGGER IF EXISTS trg_guard_profile_access_fields ON public.profiles;
-- DROP FUNCTION IF EXISTS public.guard_profile_access_fields();
--
-- -- b) Restaurar policies (definições de 20261015 / 20261016).
-- DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
-- CREATE POLICY "Users can update their own profile" ON public.profiles
--     FOR UPDATE USING (auth.uid() = id AND public.is_current_session_valid())
--     WITH CHECK (auth.uid() = id AND public.is_current_session_valid());
--
-- DROP POLICY IF EXISTS "Clients can view their workouts" ON public.workouts;
-- CREATE POLICY "Clients can view their workouts" ON public.workouts
--     FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- DROP POLICY IF EXISTS "Clients can view their own anamnesis" ON public.anamnesis;
-- CREATE POLICY "Clients can view their own anamnesis" ON public.anamnesis
--     FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- DROP POLICY IF EXISTS "Clients can create adaptation logs" ON public.adaptation_logs;
-- CREATE POLICY "Clients can create adaptation logs" ON public.adaptation_logs
--     FOR INSERT WITH CHECK (
--         client_id = auth.uid()
--         AND public.current_user_has_role('client')
--         AND trainer_id = public.current_user_trainer_id()
--     );
--
-- DROP POLICY IF EXISTS "Clients can view their adaptation logs" ON public.adaptation_logs;
-- CREATE POLICY "Clients can view their adaptation logs" ON public.adaptation_logs
--     FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- DROP POLICY IF EXISTS "Clients can view own gamification stats" ON public.gamification_stats;
-- CREATE POLICY "Clients can view own gamification stats" ON public.gamification_stats
--     FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- DROP POLICY IF EXISTS "Clients insert own sessions" ON public.workout_sessions;
-- CREATE POLICY "Clients insert own sessions" ON public.workout_sessions
--     FOR INSERT WITH CHECK (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- DROP POLICY IF EXISTS "Clients read own sessions" ON public.workout_sessions;
-- CREATE POLICY "Clients read own sessions" ON public.workout_sessions
--     FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
--
-- -- c) Remover a função auxiliar (nenhuma policy a referencia após o passo b).
-- DROP FUNCTION IF EXISTS public.is_student_access_suspended(UUID);
--
-- -- d) CHECK original. ANTES, decidir o destino dos alunos suspensos (dado de negócio):
-- --    UPDATE public.profiles SET subscription_status = 'past_due' WHERE subscription_status = 'suspended';
-- ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_subscription_status_check;
-- ALTER TABLE public.profiles
--     ADD CONSTRAINT profiles_subscription_status_check
--     CHECK (subscription_status IN ('trial', 'active', 'past_due', 'canceled'));
--
-- COMMIT;
-- ==============================================================================
