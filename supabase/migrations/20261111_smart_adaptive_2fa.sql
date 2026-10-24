-- ==============================================================================
-- Migration: 20261111_smart_adaptive_2fa.sql
-- Description: Suporte a 2FA Adaptativo Multi-Canal (WhatsApp/E-mail OTP),
--              Dispositivos Confiáveis (30 dias) e Códigos de Reserva.
-- ==============================================================================

BEGIN;

-- 1. Campos de suporte a 2FA Multi-Canal e Dispositivos Confiáveis na tabela profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS mfa_verified_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS mfa_preferred_channel TEXT DEFAULT 'whatsapp',
    ADD COLUMN IF NOT EXISTS mfa_trusted_devices JSONB DEFAULT '[]'::JSONB,
    ADD COLUMN IF NOT EXISTS mfa_backup_codes TEXT[] DEFAULT ARRAY[]::TEXT[];

-- 2. Suporte a propósito na tabela auth_recovery_otps (mfa_challenge, recovery, etc.)
ALTER TABLE public.auth_recovery_otps
    ADD COLUMN IF NOT EXISTS purpose TEXT DEFAULT 'recovery';

-- 3. Atualização da função de verificação de permissões por papel
-- Permite que treinadores com 2FA validado via WhatsApp/E-mail OTP (mfa_verified_at)
-- ou com sessão AAL2 acessem as tabelas e recursos com segurança idêntica.
CREATE OR REPLACE FUNCTION public.current_user_has_role(p_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_has_role BOOLEAN;
    v_mfa_verified_at TIMESTAMPTZ;
BEGIN
    IF NOT public.is_current_session_valid() THEN
        RETURN FALSE;
    END IF;

    SELECT (p.role = p_role OR p_role = ANY(p.roles)), p.mfa_verified_at
    INTO v_has_role, v_mfa_verified_at
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF NOT COALESCE(v_has_role, FALSE) THEN
        RETURN FALSE;
    END IF;

    -- Se for treinador, aceita AAL2 (TOTP nativo) OU MFA Multi-Canal ativo nos últimos 30 dias
    IF p_role = 'trainer' THEN
        RETURN (auth.jwt()->>'aal' = 'aal2') 
            OR (v_mfa_verified_at IS NOT NULL AND v_mfa_verified_at > (now() - interval '30 days'));
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_has_role(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_has_role(TEXT) TO authenticated, service_role;

COMMIT;

