-- ==============================================================================
-- Migration: 20261013_workout_sessions.sql
-- Description: Sessoes de treino concluidas pelo aluno (P0-05).
--              Base para gamificacao real (P1-06): streak/progresso derivados daqui.
-- Idempotente: seguro para rodar mais de uma vez.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.workout_sessions (
    -- Gerado no app: permite reenvio (sync offline) sem duplicar a sessao.
    id UUID PRIMARY KEY,
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    workout_id UUID REFERENCES public.workouts(id) ON DELETE SET NULL,
    split_identifier TEXT,
    split_name TEXT,
    total_exercises INT NOT NULL CHECK (total_exercises >= 0),
    completed_exercises INT NOT NULL CHECK (completed_exercises >= 0),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT workout_sessions_completed_lte_total
        CHECK (completed_exercises <= total_exercises)
);

CREATE INDEX IF NOT EXISTS idx_workout_sessions_client_completed
    ON public.workout_sessions(client_id, completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_sessions_trainer
    ON public.workout_sessions(trainer_id);

ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients insert own sessions" ON public.workout_sessions;
CREATE POLICY "Clients insert own sessions"
    ON public.workout_sessions FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients read own sessions" ON public.workout_sessions;
CREATE POLICY "Clients read own sessions"
    ON public.workout_sessions FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Trainers read their students sessions" ON public.workout_sessions;
CREATE POLICY "Trainers read their students sessions"
    ON public.workout_sessions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = workout_sessions.client_id
              AND p.trainer_id = auth.uid()
        )
    );

