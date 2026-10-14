-- ==============================================================================
-- Migration: 20261026_trainer_status_message.sql
-- Description: Adiciona status_message e status_updated_at na tabela profiles
--              para permitir comunicados/recados do treinador aos alunos no mural social.
-- ==============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS status_message TEXT,
    ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ;

