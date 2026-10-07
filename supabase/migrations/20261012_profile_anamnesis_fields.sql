-- ==============================================================================
-- Migration: 20261012_profile_anamnesis_fields.sql
-- Description: Campos de perfil/anamnese editaveis pelo proprio aluno (P0-04).
--              Antes, o app enviava 'clinical_restrictions' para uma coluna inexistente.
-- Idempotente: seguro para rodar mais de uma vez.
-- ==============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS age INT,
    ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(5,1),
    ADD COLUMN IF NOT EXISTS height_cm INT,
    ADD COLUMN IF NOT EXISTS clinical_restrictions TEXT;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_age_range;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_age_range
    CHECK (age IS NULL OR age BETWEEN 10 AND 100);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_weight_range;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_weight_range
    CHECK (weight_kg IS NULL OR weight_kg BETWEEN 20 AND 300);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_height_range;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_height_range
    CHECK (height_cm IS NULL OR height_cm BETWEEN 100 AND 250);

-- Garante que o aluno possa atualizar apenas o proprio perfil (necessario para o app).
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

