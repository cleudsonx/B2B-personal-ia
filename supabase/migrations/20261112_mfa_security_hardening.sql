-- ==============================================================================
-- Migration: 20261112_mfa_security_hardening.sql
-- Description: Endurecimento do 2FA adaptativo:
--   * contador de tentativas por OTP (invalida após erros)
--   * bloqueio temporário de tentativas de código de reserva
--   * janela de mfa_verified_at reduzida de 30 dias para 12 horas
--     (a confiança de 30 dias passa a ser por dispositivo, validada no servidor)
-- Aditiva e idempotente.
-- ==============================================================================

BEGIN;

ALTER TABLE public.auth_recovery_otps
    ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_otps_user_purpose_created
    ON public.auth_recovery_otps(user_id, purpose, created_at DESC);

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS mfa_backup_failed_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS mfa_backup_locked_until TIMESTAMPTZ;

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

    -- Treinador: AAL2 (TOTP) OU verificação multi-canal nas últimas 12 horas
    IF p_role = 'trainer' THEN
        RETURN (auth.jwt()->>'aal' = 'aal2')
            OR (v_mfa_verified_at IS NOT NULL AND v_mfa_verified_at > (now() - interval '12 hours'));
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_has_role(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_has_role(TEXT) TO authenticated, service_role;

COMMIT;

