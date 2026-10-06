-- ==============================================================================
-- Migration: 20261010_invite_tokens_and_security.sql
-- Description: Tabela de tokens de convite intransferíveis com controle de expiração e RLS
-- Author: Marta (Database Architect & Supabase DBA)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.invite_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token TEXT NOT NULL UNIQUE,
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_email TEXT,
    target_phone TEXT,
    channel TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp')),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '24 hours'),
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT check_target_present CHECK (target_email IS NOT NULL OR target_phone IS NOT NULL)
);

-- Índices de alta performance
CREATE INDEX IF NOT EXISTS idx_invite_tokens_token ON public.invite_tokens(token);
CREATE INDEX IF NOT EXISTS idx_invite_tokens_trainer ON public.invite_tokens(trainer_id);
CREATE INDEX IF NOT EXISTS idx_invite_tokens_expires ON public.invite_tokens(expires_at);

-- Habilitar RLS
ALTER TABLE public.invite_tokens ENABLE ROW LEVEL SECURITY;

-- Limpeza preventiva de policies
DROP POLICY IF EXISTS "service_role_all_invite_tokens" ON public.invite_tokens;
DROP POLICY IF EXISTS "trainer_read_own_invites" ON public.invite_tokens;
DROP POLICY IF EXISTS "trainer_create_own_invites" ON public.invite_tokens;

-- 1. Backend (service_role) tem controle total
CREATE POLICY "service_role_all_invite_tokens"
    ON public.invite_tokens
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 2. Treinador autenticado pode consultar seus próprios convites emitidos
CREATE POLICY "trainer_read_own_invites"
    ON public.invite_tokens
    FOR SELECT
    TO authenticated
    USING (trainer_id = auth.uid());

-- 3. Treinador autenticado pode criar convites atrelados exclusivamente a si mesmo
CREATE POLICY "trainer_create_own_invites"
    ON public.invite_tokens
    FOR INSERT
    TO authenticated
    WITH CHECK (trainer_id = auth.uid());

