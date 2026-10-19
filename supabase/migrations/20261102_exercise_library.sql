-- Migration: 20261102_exercise_library.sql
-- Catálogo oficial de exercícios e biblioteca multimídia desacoplada (multiprovedor)

CREATE TABLE IF NOT EXISTS public.exercise_library (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    normalized_slug TEXT NOT NULL UNIQUE,
    muscle_group TEXT NOT NULL,
    secondary_muscles TEXT,
    equipment TEXT NOT NULL,
    motor_pattern TEXT,
    execution_cues TEXT,
    media_source TEXT NOT NULL DEFAULT 'gdrive_initial', -- 'gdrive_initial', 'cdn', 's3', 'supabase_storage', 'custom'
    media_url TEXT NOT NULL,
    thumbnail_url TEXT,
    video_duration_seconds NUMERIC(5,2),
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de alta performance para busca e filtros rápidos
CREATE INDEX IF NOT EXISTS idx_exercise_library_slug ON public.exercise_library(normalized_slug);
CREATE INDEX IF NOT EXISTS idx_exercise_library_muscle ON public.exercise_library(muscle_group);
CREATE INDEX IF NOT EXISTS idx_exercise_library_equipment ON public.exercise_library(equipment);
CREATE INDEX IF NOT EXISTS idx_exercise_library_active ON public.exercise_library(is_active);

-- Políticas RLS (Row Level Security)
ALTER TABLE public.exercise_library ENABLE ROW LEVEL SECURITY;

-- Leitura liberada para alunos e professores autenticados e convidados
DROP POLICY IF EXISTS "Permitir leitura da biblioteca de exercícios" ON public.exercise_library;
CREATE POLICY "Permitir leitura da biblioteca de exercícios"
    ON public.exercise_library FOR SELECT
    USING (true);

-- Escrita restrita ao backend (service_role)
DROP POLICY IF EXISTS "Permitir escrita por service_role" ON public.exercise_library;
CREATE POLICY "Permitir escrita por service_role"
    ON public.exercise_library FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

