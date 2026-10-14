-- ==============================================================================
-- Migration: 20261025_allow_student_photo_update.sql
-- Description: Permite que alunos também atualizem photo_url/avatar_url no perfil.
--   Anteriormente, photo_url estava na lista de restrições de vitrine pública
--   (destinada apenas a treinadores) em protect_profile_privilege_escalation,
--   o que impedia alunos de alterarem ou salvarem sua foto de perfil.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.role() = 'authenticated' THEN
        IF NEW.role IS DISTINCT FROM OLD.role OR NEW.roles IS DISTINCT FROM OLD.roles THEN
            RAISE EXCEPTION 'Os papéis do perfil só podem ser alterados por operações autorizadas.';
        END IF;
        IF NEW.session_revoked_at IS DISTINCT FROM OLD.session_revoked_at THEN
            RAISE EXCEPTION 'A revogação de sessões só pode ser realizada pelo backend.';
        END IF;
        IF NEW.trainer_id IS DISTINCT FROM OLD.trainer_id THEN
            RAISE EXCEPTION 'O vínculo de treinador só pode ser alterado por convite autorizado.';
        END IF;
        IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
           NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until THEN
            RAISE EXCEPTION 'Status e vigência de assinatura só podem ser manipulados pelo backend de faturamento.';
        END IF;
        IF NOT (OLD.role = 'trainer' OR 'trainer' = ANY(COALESCE(OLD.roles, ARRAY[]::TEXT[]))) AND (
            NEW.username IS DISTINCT FROM OLD.username OR
            NEW.bio IS DISTINCT FROM OLD.bio OR
            NEW.specialties IS DISTINCT FROM OLD.specialties OR
            NEW.public_whatsapp IS DISTINCT FROM OLD.public_whatsapp OR
            NEW.professional_document IS DISTINCT FROM OLD.professional_document OR
            NEW.public_directory_enabled IS DISTINCT FROM OLD.public_directory_enabled
        ) THEN
            RAISE EXCEPTION 'Somente treinadores podem alterar os campos da vitrine pública.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

