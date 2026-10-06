-- ==============================================================================
-- Migration: 20261011_auth_recovery_otps.sql
-- Description: Tabela de códigos OTP para recuperação segura via WhatsApp/E-mail
-- Author: Marta (Database Architect & Supabase DBA)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.auth_recovery_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier TEXT NOT NULL, -- Telefone normalizado ou E-mail
    channel TEXT NOT NULL CHECK (channel IN ('whatsapp', 'email')),
    otp_code TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '10 minutes'),
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_recovery_identifier_otp ON public.auth_recovery_otps(identifier, otp_code);
CREATE INDEX IF NOT EXISTS idx_recovery_expires ON public.auth_recovery_otps(expires_at);

-- Habilita RLS estrito
ALTER TABLE public.auth_recovery_otps ENABLE ROW LEVEL SECURITY;

-- Apenas service_role pode ler e gravar OTPs
DROP POLICY IF EXISTS "service_role_all_recovery_otps" ON public.auth_recovery_otps;
CREATE POLICY "service_role_all_recovery_otps"
    ON public.auth_recovery_otps
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
