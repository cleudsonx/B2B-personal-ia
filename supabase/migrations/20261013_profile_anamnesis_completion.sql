ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS has_completed_anamnesis BOOLEAN NOT NULL DEFAULT FALSE;