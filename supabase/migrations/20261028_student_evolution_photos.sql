-- ==============================================================================
-- Migration: 20261028_student_evolution_photos.sql
-- Description: Galeria Sigilosa de Fotos de Evolução (Antes x Depois) da aba 🧬 Bio-Hub.
--              Permite fotos confidenciais visíveis apenas pelo aluno e seu treinador.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.student_evolution_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    photo_type TEXT NOT NULL DEFAULT 'progress', -- 'before', 'after', 'progress'
    caption TEXT,
    weight_kg NUMERIC(5, 2),
    taken_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_evolution_photos_student
    ON public.student_evolution_photos(student_id, taken_at DESC);

-- Habilitar RLS
ALTER TABLE public.student_evolution_photos ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Students manage own evolution photos" ON public.student_evolution_photos;
CREATE POLICY "Students manage own evolution photos"
    ON public.student_evolution_photos FOR ALL
    USING (student_id = auth.uid())
    WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "Trainers view their students evolution photos" ON public.student_evolution_photos;
CREATE POLICY "Trainers view their students evolution photos"
    ON public.student_evolution_photos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = student_evolution_photos.student_id
              AND p.trainer_id = auth.uid()
        )
    );

