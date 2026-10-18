-- ==============================================================================
-- Migration: 20261031_profiles_whatsapp_compatibility.sql
-- Description: Adiciona coluna whatsapp como compatibilidade resiliente para profiles
--              e sincroniza com public_whatsapp e phone.
-- ==============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS whatsapp TEXT;

-- Sincroniza dados existentes
UPDATE public.profiles
SET whatsapp = COALESCE(public_whatsapp, phone)
WHERE whatsapp IS NULL AND (public_whatsapp IS NOT NULL OR phone IS NOT NULL);

