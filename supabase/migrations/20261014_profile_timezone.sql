-- ==============================================================================
-- Migration: 20261014_profile_timezone.sql
-- Description: Timezone IANA do perfil (ex.: 'America/Sao_Paulo'). Default 'UTC'
--              preserva compatibilidade com usuarios existentes.
-- Idempotente e aditiva: seguro para rodar mais de uma vez.
-- ==============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';

-- CHECK nao aceita subquery; a validacao contra o catalogo IANA fica em trigger.
CREATE OR REPLACE FUNCTION public.validate_profile_timezone()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = NEW.timezone) THEN
        RAISE EXCEPTION 'Invalid IANA timezone: %', NEW.timezone
            USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_profile_timezone ON public.profiles;
CREATE TRIGGER trg_validate_profile_timezone
    BEFORE INSERT OR UPDATE OF timezone ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.validate_profile_timezone();

COMMENT ON COLUMN public.profiles.timezone IS
    'IANA timezone do usuario (validado contra pg_timezone_names). Default UTC.';
