-- Migration: 20261110_admin_governance_rpcs.sql
-- Description: Unblocks Admin persistence for trainer VIP toggling, student transfer, role changes, and definitive deletion

-- 1. Update guard_profile_access_fields trigger to allow SuperAdmins and Service Role
CREATE OR REPLACE FUNCTION public.guard_profile_access_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Permit service role and superadmins full bypass
    IF current_setting('role', true) = 'service_role' OR public.current_user_is_admin() THEN
        RETURN NEW;
    END IF;

    IF auth.uid() IS NOT NULL AND (
        NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
        NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until OR
        NEW.trainer_id IS DISTINCT FROM OLD.trainer_id OR
        NEW.role IS DISTINCT FROM OLD.role OR
        NEW.roles IS DISTINCT FROM OLD.roles
    ) THEN
        RAISE EXCEPTION 'Status, vínculo e papéis do perfil só podem ser alterados pelo backend.'
            USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
END;
$$;

-- 2. RPC for SuperAdmin profile governance (updates is_vip, current_plan, max_students, trainer_id, role, roles, etc.)
CREATE OR REPLACE FUNCTION public.admin_governance_update_profile(
    target_user_id uuid,
    updates jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_superadmin boolean := false;
    v_updated record;
BEGIN
    -- Authorization check
    IF current_setting('role', true) = 'service_role' OR public.current_user_is_admin() THEN
        v_is_superadmin := true;
    END IF;

    IF NOT v_is_superadmin THEN
        RAISE EXCEPTION 'Acesso negado: apenas SuperAdmins podem executar operacoes de governanca.'
            USING ERRCODE = '42501';
    END IF;

    -- Execute update on profiles safely
    UPDATE public.profiles
    SET
        is_vip = CASE WHEN updates ? 'is_vip' THEN (updates->>'is_vip')::boolean ELSE is_vip END,
        current_plan = CASE WHEN updates ? 'current_plan' THEN (updates->>'current_plan') ELSE current_plan END,
        max_students = CASE WHEN updates ? 'max_students' THEN (updates->>'max_students')::integer ELSE max_students END,
        is_admin = CASE WHEN updates ? 'is_admin' THEN (updates->>'is_admin')::boolean ELSE is_admin END,
        is_suspended = CASE WHEN updates ? 'is_suspended' THEN (updates->>'is_suspended')::boolean ELSE is_suspended END,
        admin_notes = CASE WHEN updates ? 'admin_notes' THEN (updates->>'admin_notes') ELSE admin_notes END,
        trainer_id = CASE 
            WHEN updates ? 'trainer_id' THEN 
                CASE 
                    WHEN updates->>'trainer_id' IS NULL OR updates->>'trainer_id' = '' OR updates->>'trainer_id' = 'null' THEN NULL
                    ELSE (updates->>'trainer_id')::uuid 
                END
            ELSE trainer_id 
        END,
        role = CASE WHEN updates ? 'role' THEN (updates->>'role') ELSE role END,
        roles = CASE 
            WHEN updates ? 'roles' THEN 
                ARRAY(SELECT jsonb_array_elements_text(updates->'roles'))
            ELSE roles 
        END,
        status = CASE WHEN updates ? 'status' THEN (updates->>'status') ELSE status END,
        professional_document = CASE 
            WHEN updates ? 'professional_document' THEN (updates->>'professional_document')
            WHEN updates ? 'cref' THEN (updates->>'cref')
            ELSE professional_document 
        END,
        cref_verified = CASE WHEN updates ? 'cref_verified' THEN (updates->>'cref_verified')::boolean ELSE cref_verified END,
        full_name = CASE WHEN updates ? 'full_name' THEN (updates->>'full_name') ELSE full_name END,
        phone = CASE WHEN updates ? 'phone' THEN (updates->>'phone') ELSE phone END,
        session_revoked_at = CASE WHEN updates ? 'session_revoked_at' THEN (updates->>'session_revoked_at')::timestamptz ELSE session_revoked_at END,
        updated_at = NOW()
    WHERE id = target_user_id
    RETURNING * INTO v_updated;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario com id % nao encontrado na base profiles.', target_user_id
            USING ERRCODE = 'P0002';
    END IF;

    RETURN to_jsonb(v_updated);
END;
$$;

-- Grant execution to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.admin_governance_update_profile(uuid, jsonb) TO authenticated, service_role;

-- 3. RPC for SuperAdmin safe user deletion
CREATE OR REPLACE FUNCTION public.admin_governance_delete_user(
    target_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_superadmin boolean := false;
    v_caller_id uuid := auth.uid();
BEGIN
    -- Authorization check
    IF current_setting('role', true) = 'service_role' OR public.current_user_is_admin() THEN
        v_is_superadmin := true;
    END IF;

    IF NOT v_is_superadmin THEN
        RAISE EXCEPTION 'Acesso negado: apenas SuperAdmins podem excluir usuarios.'
            USING ERRCODE = '42501';
    END IF;

    -- Prevent self-deletion
    IF v_caller_id IS NOT NULL AND v_caller_id = target_user_id THEN
        RAISE EXCEPTION 'Operacao abortada: Voce nao pode excluir sua propria conta SuperAdmin.'
            USING ERRCODE = '42501';
    END IF;

    -- Clean up referencing tables where foreign keys might restrict or cascade
    DELETE FROM public.audit_log WHERE trainer_id = target_user_id;
    UPDATE public.profiles SET trainer_id = NULL WHERE trainer_id = target_user_id;

    BEGIN
        DELETE FROM public.student_invoices WHERE student_id = target_user_id OR trainer_id = target_user_id;
    EXCEPTION WHEN undefined_table THEN
        NULL;
    END;

    -- Delete from profiles
    DELETE FROM public.profiles WHERE id = target_user_id;

    -- Delete from auth.users
    DELETE FROM auth.users WHERE id = target_user_id;

    RETURN true;
END;
$$;

-- Grant execution to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.admin_governance_delete_user(uuid) TO authenticated, service_role;

