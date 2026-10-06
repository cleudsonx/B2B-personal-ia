-- ==============================================================================
-- Migration: 20261008_audit_log_rls.sql
-- Description: Políticas de RLS para a tabela audit_log
-- Author: Marta (Database Architect & Supabase DBA)
-- ==============================================================================

-- 1. Habilita RLS na tabela audit_log
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- 2. Limpeza preventiva de policies antigas
DROP POLICY IF EXISTS "service_insert_audit" ON public.audit_log;
DROP POLICY IF EXISTS "admin_read_audit" ON public.audit_log;
DROP POLICY IF EXISTS "trainer_read_own_audit" ON public.audit_log;

-- 3. Inserção permitida para a service_role (Backend / Edge Functions / API)
CREATE POLICY "service_insert_audit"
    ON public.audit_log
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- 4. Treinador pode visualizar apenas os logs de convite vinculados a ele
CREATE POLICY "trainer_read_own_audit"
    ON public.audit_log
    FOR SELECT
    TO authenticated
    USING (trainer_id = auth.uid());

-- 5. Acesso administrativo total para service_role
CREATE POLICY "service_manage_audit"
    ON public.audit_log
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

