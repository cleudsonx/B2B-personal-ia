-- ==============================================================================
-- Migration: 20261031_student_body_metrics.sql
-- Description: Armazenamento e evolução de medidas corporais (Bio-Hub 2.0).
--              Antropometria confidencial visível apenas pelo aluno e seu treinador.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.student_body_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    weight_kg NUMERIC(5, 2),
    height_cm NUMERIC(5, 2),
    body_fat_pct NUMERIC(4, 1),
    waist_cm NUMERIC(5, 2),
    hip_cm NUMERIC(5, 2),
    chest_cm NUMERIC(5, 2),
    arm_right_cm NUMERIC(5, 2),
    arm_left_cm NUMERIC(5, 2),
    thigh_right_cm NUMERIC(5, 2),
    thigh_left_cm NUMERIC(5, 2),
    notes TEXT,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice composto para histórico ordenado
CREATE INDEX IF NOT EXISTS idx_body_metrics_student_date
    ON public.student_body_metrics(student_id, measured_at DESC);

-- Habilitar RLS
ALTER TABLE public.student_body_metrics ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Students manage own body metrics" ON public.student_body_metrics;
CREATE POLICY "Students manage own body metrics"
    ON public.student_body_metrics FOR ALL
    USING (student_id = auth.uid())
    WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Trainers view their students body metrics" ON public.student_body_metrics;
CREATE POLICY "Trainers view their students body metrics"
    ON public.student_body_metrics FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = student_body_metrics.student_id
              AND p.trainer_id = auth.uid()
        )
    );

