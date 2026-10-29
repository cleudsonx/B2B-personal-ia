-- =============================================================================
-- Migration: 20261110_professor_cleudson_superadmin_role_fix.sql
-- Purpose: Guarantee Professor Cleudson Cavalcante (all accounts: @mrcoach,
--          @cleudson-antigo, cleudsonx@hotmail.com, cleudsonx@gmail.com,
--          cleudsonx2021@gmail.com) has direct Trainer + SuperAdmin permissions,
--          is never treated as an uninvited student, and bypasses any invite requirement.
-- =============================================================================

BEGIN;

-- 1. Update public.profiles for all Cleudson accounts
UPDATE public.profiles
SET
    role = 'trainer',
    roles = ARRAY['trainer', 'admin']::TEXT[],
    is_admin = TRUE,
    is_vip = TRUE,
    current_plan = 'elite',
    max_students = 9999,
    trainer_id = NULL,
    status = 'active',
    is_suspended = FALSE,
    full_name = CASE
        WHEN full_name IN ('Rafinha 2026', 'Hotmail 2', 'Usuário', '') THEN 'Prof. Cleudson Cavalcante'
        ELSE full_name
    END,
    updated_at = now()
WHERE id IN (
    '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    '50c26610-8054-4b05-9274-7f414f91f52f',
    '92dfd58c-845f-473e-b846-a2b8fdd3e508'
)
OR lower(COALESCE(email, '')) IN (
    'cleudsonx@hotmail.com',
    'cleudsonx@gmail.com',
    'cleudsonx2021@gmail.com'
);

-- 2. Update auth.users metadata for all Cleudson accounts to prevent re-downgrading
UPDATE auth.users
SET raw_user_meta_data = (
    (
        COALESCE(raw_user_meta_data, '{}'::JSONB)
        || jsonb_build_object(
            'role', 'trainer',
            'roles', jsonb_build_array('trainer', 'admin'),
            'is_admin', true,
            'is_vip', true
        )
    )
    - 'invite_token'
    - 'trainer_id'
)
WHERE id IN (
    '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    '50c26610-8054-4b05-9274-7f414f91f52f',
    '92dfd58c-845f-473e-b846-a2b8fdd3e508'
)
OR lower(COALESCE(email, '')) IN (
    'cleudsonx@hotmail.com',
    'cleudsonx@gmail.com',
    'cleudsonx2021@gmail.com'
);

-- 3. Enhance public.current_user_is_admin() to include canonical Cleudson emails and UUIDs
CREATE OR REPLACE FUNCTION public.current_user_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Canonical Cleudson UUIDs
    IF v_uid IN (
        '6f645308-f1b2-4d73-ac45-9890c27e20d4'::UUID,
        '50c26610-8054-4b05-9274-7f414f91f52f'::UUID,
        '92dfd58c-845f-473e-b846-a2b8fdd3e508'::UUID
    ) THEN
        RETURN TRUE;
    END IF;

    -- Profile check
    SELECT (
        COALESCE(p.is_admin, FALSE) = TRUE
        OR p.role = 'admin'
        OR ('admin' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[])))
    )
    INTO v_is_admin
    FROM public.profiles p
    WHERE p.id = v_uid
      AND lower(COALESCE(p.email, '')) NOT LIKE 'wa_%'
      AND lower(COALESCE(p.email, '')) NOT LIKE 'aluno_%'
      AND lower(COALESCE(p.email, '')) NOT LIKE '%.internal';

    RETURN COALESCE(v_is_admin, FALSE);
END;
$$;

COMMIT;

