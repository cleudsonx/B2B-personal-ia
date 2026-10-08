ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS professional_document TEXT,
    ADD COLUMN IF NOT EXISTS public_directory_enabled BOOLEAN NOT NULL DEFAULT FALSE;