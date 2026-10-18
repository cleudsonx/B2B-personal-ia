-- ==============================================================================
-- Migration: 20261101_anamnesis_expanded_history.sql
-- Description: Expande tabela anamnesis com detalhes ricos (JSONB), colunas
--              estruturadas e índice para histórico evolutivo do aluno.
-- ==============================================================================

-- 1. Garante que trainer_id seja flexível caso o aluno faça check-in pré-vínculo
ALTER TABLE public.anamnesis
    ALTER COLUMN trainer_id DROP NOT NULL;

-- 2. Adiciona colunas biométricas, rotina e preferências expandidas
ALTER TABLE public.anamnesis
    ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS biological_sex TEXT,
    ADD COLUMN IF NOT EXISTS age INT,
    ADD COLUMN IF NOT EXISTS weight NUMERIC,
    ADD COLUMN IF NOT EXISTS height NUMERIC,
    ADD COLUMN IF NOT EXISTS daily_activity TEXT,
    ADD COLUMN IF NOT EXISTS sleep_hours TEXT,
    ADD COLUMN IF NOT EXISTS stress_level TEXT,
    ADD COLUMN IF NOT EXISTS training_history TEXT,
    ADD COLUMN IF NOT EXISTS preferred_days JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS session_duration TEXT,
    ADD COLUMN IF NOT EXISTS cardio_preference TEXT,
    ADD COLUMN IF NOT EXISTS clinical_conditions JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS available_equipment JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS exercises_to_avoid TEXT,
    ADD COLUMN IF NOT EXISTS muscle_priorities JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS training_style TEXT;

-- 3. Índice para busca ultra-rápida da linha do tempo evolutiva do aluno
CREATE INDEX IF NOT EXISTS idx_anamnesis_client_created
    ON public.anamnesis(client_id, created_at DESC);

