-- ==============================================================================
-- Migration: 20261116_auth_recovery_otps_nullable_user_id.sql
-- Description: Permite que user_id seja nulo na tabela auth_recovery_otps
--              para viabilizar registro de OTPs em fluxos passwordless / novos alunos
--              antes da consolidação de conta.
-- ==============================================================================

BEGIN;

ALTER TABLE public.auth_recovery_otps
    ALTER COLUMN user_id DROP NOT NULL;

COMMIT;

