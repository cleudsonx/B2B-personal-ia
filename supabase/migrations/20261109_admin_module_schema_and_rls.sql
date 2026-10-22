-- =============================================================================
-- Migration: 20261109_admin_module_schema_and_rls.sql
-- Purpose: Complete SuperAdmin Mission Control schema, RLS policies, RPCs,
--          operational tables, and privilege escalation guard updates.
-- =============================================================================

-- 1. Relax profiles_role_check to allow 'admin' role in addition to 'trainer' and 'client'
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profiles_role_check'
          AND conrelid = 'public.profiles'::regclass
    ) THEN
        ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
    END IF;
END $$;

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check
    CHECK (role IN ('trainer', 'client', 'admin'));

-- 2. Add SuperAdmin & Tenant governance columns to public.profiles (idempotent)
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS email TEXT,
    ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_vip BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS admin_notes TEXT,
    ADD COLUMN IF NOT EXISTS current_plan TEXT NOT NULL DEFAULT 'free',
    ADD COLUMN IF NOT EXISTS max_students INT NOT NULL DEFAULT 5,
    ADD COLUMN IF NOT EXISTS cref_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS last_sign_in_at TIMESTAMPTZ;

-- Backfill email and last_sign_in_at from auth.users where possible
DO $$
BEGIN
    UPDATE public.profiles p
    SET
        email = COALESCE(p.email, u.email),
        last_sign_in_at = COALESCE(p.last_sign_in_at, u.last_sign_in_at)
    FROM auth.users u
    WHERE p.id = u.id
      AND (p.email IS NULL OR p.last_sign_in_at IS NULL);
EXCEPTION WHEN OTHERS THEN
    -- Ignore if auth.users is not accessible in current execution context
    NULL;
END $$;

-- Update handle_new_user trigger function so email is also stored on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_role TEXT;
BEGIN
    v_role := COALESCE(new.raw_user_meta_data->>'role', 'trainer');
    IF v_role NOT IN ('trainer', 'client', 'admin') THEN
        v_role := 'trainer';
    END IF;

    INSERT INTO public.profiles (id, full_name, email, role, roles, is_admin)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', split_part(COALESCE(new.email, 'Usuario'), '@', 1)),
        new.email,
        v_role,
        ARRAY[v_role]::TEXT[],
        (v_role = 'admin' OR COALESCE((new.raw_user_meta_data->>'is_admin')::boolean, false))
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        last_sign_in_at = now();
    RETURN new;
END;
$$;

-- 3. Helper function: public.current_user_is_admin()
-- Uses SECURITY DEFINER so RLS policies on profiles and other tables can call it without recursion.
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

    SELECT (
        COALESCE(p.is_admin, FALSE) = TRUE
        OR p.role = 'admin'
        OR ('admin' = ANY(COALESCE(p.roles, ARRAY[]::TEXT[])))
    )
    INTO v_is_admin
    FROM public.profiles p
    WHERE p.id = v_uid;

    RETURN COALESCE(v_is_admin, FALSE);
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_is_admin() TO authenticated, service_role;

-- 4. RPC: public.claim_initial_superadmin()
-- Allows the first authenticated trainer/owner (when 0 admins exist, or if already admin)
-- to promote their account to SuperAdmin directly from the /admin Mission Control guard.
CREATE OR REPLACE FUNCTION public.claim_initial_superadmin()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_admin_count INT := 0;
    v_already_admin BOOLEAN := FALSE;
    v_roles TEXT[];
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'unauthenticated',
            'message', 'Faça login antes de reivindicar o perfil SuperAdmin.'
        );
    END IF;

    SELECT public.current_user_is_admin() INTO v_already_admin;
    IF v_already_admin THEN
        RETURN jsonb_build_object(
            'ok', true,
            'status', 'already_admin',
            'user_id', v_uid
        );
    END IF;

    SELECT COUNT(*)
    INTO v_admin_count
    FROM public.profiles
    WHERE is_admin = TRUE
       OR role = 'admin'
       OR ('admin' = ANY(COALESCE(roles, ARRAY[]::TEXT[])));

    IF v_admin_count > 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'admin_already_exists',
            'admin_count', v_admin_count,
            'message', 'Já existe um SuperAdmin configurado neste ambiente. Solicite a promoção a um administrador existente ou via SQL Editor.'
        );
    END IF;

    SELECT COALESCE(roles, ARRAY[role]::TEXT[])
    INTO v_roles
    FROM public.profiles
    WHERE id = v_uid;

    IF NOT ('admin' = ANY(COALESCE(v_roles, ARRAY[]::TEXT[]))) THEN
        v_roles := array_append(COALESCE(v_roles, ARRAY['trainer']::TEXT[]), 'admin');
    END IF;

    UPDATE public.profiles
    SET
        is_admin = TRUE,
        roles = v_roles,
        updated_at = now()
    WHERE id = v_uid;

    INSERT INTO public.audit_log (user_id, action, metadata)
    VALUES (
        v_uid,
        'admin.claim_initial_superadmin',
        jsonb_build_object('claimed_at', now(), 'roles', v_roles)
    );

    RETURN jsonb_build_object(
        'ok', true,
        'status', 'promoted',
        'user_id', v_uid,
        'roles', v_roles
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_initial_superadmin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_initial_superadmin() TO authenticated, service_role;

-- 5. Update protect_profile_privilege_escalation() so SuperAdmins can manage users & tenants
CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF current_setting('role', true) = 'authenticated' THEN
        -- Allow SuperAdmins full governance over profiles
        IF public.current_user_is_admin() THEN
            RETURN NEW;
        END IF;

        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'Modification of role is restricted';
        END IF;
        IF NEW.roles IS DISTINCT FROM OLD.roles THEN
            RAISE EXCEPTION 'Modification of roles is restricted';
        END IF;
        IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
            RAISE EXCEPTION 'Modification of is_admin is restricted';
        END IF;
        IF NEW.session_revoked_at IS DISTINCT FROM OLD.session_revoked_at THEN
            RAISE EXCEPTION 'Modification of session_revoked_at is restricted';
        END IF;
        IF NEW.trainer_id IS DISTINCT FROM OLD.trainer_id THEN
            RAISE EXCEPTION 'Modification of trainer_id is restricted';
        END IF;
        IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status THEN
            RAISE EXCEPTION 'Modification of subscription_status is restricted';
        END IF;
        IF NEW.subscription_tier IS DISTINCT FROM OLD.subscription_tier THEN
            RAISE EXCEPTION 'Modification of subscription_tier is restricted';
        END IF;
        IF NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
            RAISE EXCEPTION 'Modification of subscription_expires_at is restricted';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- 6. Add SuperAdmin RLS policies on existing core tables
DO $$
DECLARE
    v_tbl TEXT;
    v_tables TEXT[] := ARRAY[
        'profiles',
        'workouts',
        'workout_sessions',
        'anamnesis',
        'adaptation_logs',
        'gamification_stats',
        'subscriptions',
        'trainer_ai_usage',
        'checkout_sessions',
        'invite_tokens',
        'exercise_library',
        'audit_log',
        'body_metrics',
        'student_exercise_loads'
    ];
BEGIN
    FOREACH v_tbl IN ARRAY v_tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = v_tbl
        ) THEN
            EXECUTE format('DROP POLICY IF EXISTS "SuperAdmins have full access on %I" ON public.%I', v_tbl, v_tbl);
            EXECUTE format(
                'CREATE POLICY "SuperAdmins have full access on %I" ON public.%I FOR ALL TO authenticated USING (public.current_user_is_admin()) WITH CHECK (public.current_user_is_admin())',
                v_tbl, v_tbl
            );
        END IF;
    END LOOP;
END $$;

-- 7. Create Operational Admin Tables (Pricing Plans, Coupons, Affiliates, Broadcasts, Security Alerts)
CREATE TABLE IF NOT EXISTS public.admin_pricing_plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    monthly_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    annual_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    max_students INT NOT NULL DEFAULT 5,
    ai_credits_per_month INT NOT NULL DEFAULT 20,
    has_whatsapp_bot BOOLEAN NOT NULL DEFAULT FALSE,
    has_priority_support BOOLEAN NOT NULL DEFAULT FALSE,
    has_custom_branding BOOLEAN NOT NULL DEFAULT FALSE,
    active_subscribers INT NOT NULL DEFAULT 0,
    is_popular BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    features JSONB NOT NULL DEFAULT '[]'::JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_pricing_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read active pricing plans" ON public.admin_pricing_plans;
CREATE POLICY "Authenticated users can read active pricing plans"
    ON public.admin_pricing_plans FOR SELECT TO authenticated
    USING (is_active = TRUE OR public.current_user_is_admin());

DROP POLICY IF EXISTS "SuperAdmins manage pricing plans" ON public.admin_pricing_plans;
CREATE POLICY "SuperAdmins manage pricing plans"
    ON public.admin_pricing_plans FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- Seed default pricing plans if empty
INSERT INTO public.admin_pricing_plans (
    id, name, description, monthly_price, annual_price, max_students,
    ai_credits_per_month, has_whatsapp_bot, has_priority_support,
    has_custom_branding, active_subscribers, is_popular, is_active, features
) VALUES
(
    'free', 'Starter Free', 'Ideal para personal trainers iniciando na consultoria digital.',
    0.0, 0.0, 5, 15, FALSE, FALSE, FALSE, 0, FALSE, TRUE,
    '["Até 5 alunos ativos", "15 gerações IA/mês", "App do Aluno PWA & Mobile", "Biblioteca com +250 exercícios"]'::JSONB
),
(
    'pro', 'Personal Pro', 'Para treinadores em crescimento com automação de treinos e IA.',
    97.0, 970.0, 40, 250, TRUE, TRUE, FALSE, 0, TRUE, TRUE,
    '["Até 40 alunos ativos", "250 gerações IA/mês", "Bot WhatsApp Integrado", "Periodização & 1RM Automático", "Suporte Prioritário"]'::JSONB
),
(
    'elite', 'Studio & Elite', 'Operação ilimitada para assessorias esportivas e grandes treinadores.',
    197.0, 1970.0, 9999, 2000, TRUE, TRUE, TRUE, 0, FALSE, TRUE,
    '["Alunos ilimitados", "2.000 gerações IA/mês", "Multi-instâncias WhatsApp", "White-label & Relatórios PDF Pro", "Gerente de Conta Dedicado"]'::JSONB
)
ON CONFLICT (id) DO NOTHING;

-- Coupons table
CREATE TABLE IF NOT EXISTS public.admin_coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    discount_percent INT NOT NULL DEFAULT 10,
    discount_fixed NUMERIC(10, 2),
    duration TEXT NOT NULL DEFAULT 'first_month',
    duration_months INT,
    redemptions_count INT NOT NULL DEFAULT 0,
    max_redemptions INT NOT NULL DEFAULT 100,
    applicable_plans JSONB NOT NULL DEFAULT '["pro", "elite"]'::JSONB,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    revenue_generated NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SuperAdmins manage coupons" ON public.admin_coupons;
CREATE POLICY "SuperAdmins manage coupons"
    ON public.admin_coupons FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- Affiliates table
CREATE TABLE IF NOT EXISTS public.admin_affiliates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    referral_code TEXT NOT NULL UNIQUE,
    commission_percent INT NOT NULL DEFAULT 20,
    clicks_count INT NOT NULL DEFAULT 0,
    trials_count INT NOT NULL DEFAULT 0,
    active_referrals INT NOT NULL DEFAULT 0,
    total_earned NUMERIC(12, 2) NOT NULL DEFAULT 0,
    pending_payout NUMERIC(12, 2) NOT NULL DEFAULT 0,
    pix_key TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_affiliates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SuperAdmins manage affiliates" ON public.admin_affiliates;
CREATE POLICY "SuperAdmins manage affiliates"
    ON public.admin_affiliates FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- Affiliate Payouts table
CREATE TABLE IF NOT EXISTS public.admin_affiliate_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_id UUID REFERENCES public.admin_affiliates(id) ON DELETE CASCADE,
    affiliate_name TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    pix_key TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    paid_at TIMESTAMPTZ
);

ALTER TABLE public.admin_affiliate_payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SuperAdmins manage affiliate payouts" ON public.admin_affiliate_payouts;
CREATE POLICY "SuperAdmins manage affiliate payouts"
    ON public.admin_affiliate_payouts FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- Broadcasts & Changelog table
CREATE TABLE IF NOT EXISTS public.admin_broadcasts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    audience TEXT NOT NULL DEFAULT 'all_trainers',
    channel TEXT NOT NULL DEFAULT 'in_app_banner',
    type TEXT NOT NULL DEFAULT 'announcement',
    version_tag TEXT,
    cta_label TEXT,
    cta_url TEXT,
    status TEXT NOT NULL DEFAULT 'sent',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ,
    recipients_count INT NOT NULL DEFAULT 0,
    opened_count INT NOT NULL DEFAULT 0,
    clicked_count INT NOT NULL DEFAULT 0,
    created_by TEXT NOT NULL DEFAULT 'Admin'
);

ALTER TABLE public.admin_broadcasts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read sent broadcasts" ON public.admin_broadcasts;
CREATE POLICY "Authenticated users can read sent broadcasts"
    ON public.admin_broadcasts FOR SELECT TO authenticated
    USING (status = 'sent' OR public.current_user_is_admin());

DROP POLICY IF EXISTS "SuperAdmins manage broadcasts" ON public.admin_broadcasts;
CREATE POLICY "SuperAdmins manage broadcasts"
    ON public.admin_broadcasts FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());

-- Security Alerts table
CREATE TABLE IF NOT EXISTS public.admin_security_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    severity TEXT NOT NULL DEFAULT 'medium',
    type TEXT NOT NULL DEFAULT 'suspicious_login',
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT NOT NULL DEFAULT 'Usuário',
    user_email TEXT NOT NULL DEFAULT '',
    ip_address TEXT NOT NULL DEFAULT '0.0.0.0',
    location TEXT NOT NULL DEFAULT 'Brasil',
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE public.admin_security_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SuperAdmins manage security alerts" ON public.admin_security_alerts;
CREATE POLICY "SuperAdmins manage security alerts"
    ON public.admin_security_alerts FOR ALL TO authenticated
    USING (public.current_user_is_admin())
    WITH CHECK (public.current_user_is_admin());



-- 8. Grant SuperAdmin permission to Professor Cleudson Cavalcante (@mrcoach / @cleudson-antigo)
UPDATE public.profiles
SET
    is_admin = TRUE,
    is_vip = TRUE,
    current_plan = 'elite',
    max_students = 9999,
    roles = CASE
        WHEN 'admin' = ANY(COALESCE(roles, ARRAY[]::TEXT[])) THEN roles
        ELSE array_append(COALESCE(roles, ARRAY['trainer']::TEXT[]), 'admin')
    END,
    updated_at = now()
WHERE id IN (
    '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    '50c26610-8054-4b05-9274-7f414f91f52f'
)
   OR username IN ('mrcoach', 'cleudson-antigo')
   OR full_name ILIKE '%Cleudson%';
