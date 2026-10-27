-- ==============================================================================
-- Migration: 20261114_fix_protect_profile_subscription_fields.sql
-- Description: Corrige a trigger function protect_profile_privilege_escalation.
--   A migration anterior referenciou erroneamente "subscription_tier" e
--   "subscription_expires_at", que NÃO existem na tabela profiles (os campos reais
--   são subscription_status e subscription_valid_until).
--   Isso impedia a atualização da Vitrine do Treinador e a submissão de avaliações
--   (anamnese) com o erro PostgrestException (code: 42703, record "new" has no field "subscription_tier").
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_setting('role', true) = 'authenticated' OR auth.role() = 'authenticated' THEN
        -- Permite que SuperAdmins executem governança completa em perfis
        IF public.current_user_is_admin() THEN
            RETURN NEW;
        END IF;

        IF NEW.role IS DISTINCT FROM OLD.role OR NEW.roles IS DISTINCT FROM OLD.roles THEN
            RAISE EXCEPTION 'Os papéis do perfil só podem ser alterados por operações autorizadas.';
        END IF;
        IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
            RAISE EXCEPTION 'Modification of is_admin is restricted';
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
