-- ==============================================================================
-- Migration: 20261029_student_recovery_and_loads.sql
-- Description: Tabelas para Bio-Recovery (Prontidão, Sono, DOMS, Hidratação) e
--              Sobrecarga Progressiva Real (Histórico de Cargas dos Exercícios).
-- ==============================================================================

-- 1. Tabela de Registro Diário de Recovery e Prontidão
CREATE TABLE IF NOT EXISTS public.student_daily_recovery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sleep_hours NUMERIC(3, 1) NOT NULL DEFAULT 8.0 CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
    doms_level TEXT NOT NULL DEFAULT 'Leve' CHECK (doms_level IN ('Leve', 'Moderada', 'Intensa')),
    water_intake_ml INTEGER NOT NULL DEFAULT 500 CHECK (water_intake_ml >= 0),
    readiness_score NUMERIC(4, 1) NOT NULL DEFAULT 88.0 CHECK (readiness_score >= 0 AND readiness_score <= 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_recovery_client_date
    ON public.student_daily_recovery(client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_student_recovery_trainer
    ON public.student_daily_recovery(trainer_id);

ALTER TABLE public.student_daily_recovery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients insert own recovery" ON public.student_daily_recovery;
CREATE POLICY "Clients insert own recovery"
    ON public.student_daily_recovery FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients read own recovery" ON public.student_daily_recovery;
CREATE POLICY "Clients read own recovery"
    ON public.student_daily_recovery FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Trainers read student recovery" ON public.student_daily_recovery;
CREATE POLICY "Trainers read student recovery"
    ON public.student_daily_recovery FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = student_daily_recovery.client_id
              AND p.trainer_id = auth.uid()
        )
    );

-- 2. Tabela de Histórico de Cargas para Sobrecarga Progressiva Real
CREATE TABLE IF NOT EXISTS public.student_exercise_loads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_name TEXT NOT NULL,
    load_kg NUMERIC(5, 1) NOT NULL CHECK (load_kg >= 0),
    reps INTEGER CHECK (reps > 0),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_loads_client_exercise
    ON public.student_exercise_loads(client_id, exercise_name, recorded_at ASC);

ALTER TABLE public.student_exercise_loads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Clients insert own loads" ON public.student_exercise_loads;
CREATE POLICY "Clients insert own loads"
    ON public.student_exercise_loads FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients read own loads" ON public.student_exercise_loads;
CREATE POLICY "Clients read own loads"
    ON public.student_exercise_loads FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Trainers read student loads" ON public.student_exercise_loads;
CREATE POLICY "Trainers read student loads"
    ON public.student_exercise_loads FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = student_exercise_loads.client_id
              AND p.trainer_id = auth.uid()
        )
    );

