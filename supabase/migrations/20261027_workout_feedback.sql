-- ==============================================================================
-- Migration: 20261027_workout_feedback.sql
-- Description: Tabela de telemetria e feedback pós-treino da aba 🧬 Bio-Hub.
--              Armazena RPE (Escala de Borg), dores articulares e notas do aluno.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.workout_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    workout_id UUID REFERENCES public.workouts(id) ON DELETE SET NULL,
    rpe NUMERIC(3, 1) NOT NULL CHECK (rpe >= 1.0 AND rpe <= 10.0),
    pain_points TEXT[] NOT NULL DEFAULT '{}',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para consultas de telemetria rápida
CREATE INDEX IF NOT EXISTS idx_workout_feedback_client_created
    ON public.workout_feedback(client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_workout_feedback_trainer
    ON public.workout_feedback(trainer_id);

-- Habilitar RLS
ALTER TABLE public.workout_feedback ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Clients insert own workout feedback" ON public.workout_feedback;
CREATE POLICY "Clients insert own workout feedback"
    ON public.workout_feedback FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients read own workout feedback" ON public.workout_feedback;
CREATE POLICY "Clients read own workout feedback"
    ON public.workout_feedback FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Trainers read their students workout feedback" ON public.workout_feedback;
CREATE POLICY "Trainers read their students workout feedback"
    ON public.workout_feedback FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = workout_feedback.client_id
              AND p.trainer_id = auth.uid()
        )
    );
