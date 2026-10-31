-- =============================================================================
-- Migration: 20261117_user_device_sessions.sql
-- Objetivo: Rastreamento anti-fraude de sessões simultâneas, fingerprinting de
--           dispositivos, alertas de novo acesso e kill-switch remoto.
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.user_device_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id VARCHAR(128) NOT NULL,
    device_name VARCHAR(150) NOT NULL DEFAULT 'Dispositivo Desconhecido',
    platform VARCHAR(50) NOT NULL DEFAULT 'web',
    ip_address VARCHAR(64),
    location VARCHAR(150),
    user_agent TEXT,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_device UNIQUE (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user ON public.user_device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active ON public.user_device_sessions(user_id, last_active_at DESC) WHERE is_revoked = false;

-- Habilita RLS
ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;

-- Usuários podem visualizar suas próprias sessões
DROP POLICY IF EXISTS "Users can view their own device sessions" ON public.user_device_sessions;
CREATE POLICY "Users can view their own device sessions"
    ON public.user_device_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Usuários podem atualizar/revogar suas próprias sessões
DROP POLICY IF EXISTS "Users can update their own device sessions" ON public.user_device_sessions;
CREATE POLICY "Users can update their own device sessions"
    ON public.user_device_sessions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Usuários podem inserir suas próprias sessões
DROP POLICY IF EXISTS "Users can insert their own device sessions" ON public.user_device_sessions;
CREATE POLICY "Users can insert their own device sessions"
    ON public.user_device_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- SuperAdmins têm controle total para suporte e auditoria
DROP POLICY IF EXISTS "SuperAdmins have full access on user_device_sessions" ON public.user_device_sessions;
CREATE POLICY "SuperAdmins have full access on user_device_sessions"
    ON public.user_device_sessions
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (p.is_admin = TRUE OR 'admin' = ANY(p.roles) OR p.role = 'admin')
        )
    );

COMMIT;

