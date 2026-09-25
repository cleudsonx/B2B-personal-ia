-- ==============================================================================
-- Migration: 20260925_init_schema.sql
-- Description: Initial schema for B2B Personal IA (Idempotent: safe to run multiple times)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. PROFILES TABLE (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('trainer', 'client')),
    full_name TEXT NOT NULL,
    phone TEXT,
    trainer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'past_due', 'canceled')),
    subscription_valid_until TIMESTAMPTZ,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_profiles_trainer_id ON public.profiles(trainer_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- 3. ANAMNESIS TABLE
CREATE TABLE IF NOT EXISTS public.anamnesis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    objective TEXT NOT NULL,
    training_level TEXT NOT NULL,
    days_per_week INT NOT NULL CHECK (days_per_week BETWEEN 1 AND 7),
    workout_location TEXT NOT NULL,
    injuries_or_restrictions TEXT NOT NULL DEFAULT 'Nenhuma restrição articular relatada.',
    additional_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_anamnesis_client_id ON public.anamnesis(client_id);
CREATE INDEX IF NOT EXISTS idx_anamnesis_trainer_id ON public.anamnesis(trainer_id);

-- 4. WORKOUTS TABLE (Contains generated/approved workout sheet)
CREATE TABLE IF NOT EXISTS public.workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    anamnesis_id UUID REFERENCES public.anamnesis(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    notes_for_trainer TEXT,
    plan_json JSONB NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workouts_client_active ON public.workouts(client_id, is_active);
CREATE INDEX IF NOT EXISTS idx_workouts_trainer_id ON public.workouts(trainer_id);

-- 5. ADAPTATION LOGS TABLE (Real-time gym floor swaps audited by the trainer)
CREATE TABLE IF NOT EXISTS public.adaptation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES public.workouts(id) ON DELETE SET NULL,
    original_exercise TEXT NOT NULL,
    adapted_exercise TEXT NOT NULL,
    reason TEXT NOT NULL,
    adaptation_details JSONB,
    viewed_by_trainer BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adaptation_logs_trainer ON public.adaptation_logs(trainer_id, viewed_by_trainer);
CREATE INDEX IF NOT EXISTS idx_adaptation_logs_client ON public.adaptation_logs(client_id);

-- 6. AUTOMATIC TRIGGER FOR UPDATED_AT
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_anamnesis_updated_at ON public.anamnesis;
CREATE TRIGGER set_anamnesis_updated_at
    BEFORE UPDATE ON public.anamnesis
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_workouts_updated_at ON public.workouts;
CREATE TRIGGER set_workouts_updated_at
    BEFORE UPDATE ON public.workouts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 7. NEW USER TRIGGER: Create profile automatically upon Supabase Auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role, phone, trainer_id)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'client'),
        NEW.raw_user_meta_data->>'phone',
        (NEW.raw_user_meta_data->>'trainer_id')::UUID
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anamnesis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adaptation_logs ENABLE ROW LEVEL SECURITY;

-- --- PROFILES POLICIES ---
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Trainers can view their associated clients" ON public.profiles;
CREATE POLICY "Trainers can view their associated clients"
    ON public.profiles FOR SELECT
    USING (trainer_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- --- ANAMNESIS POLICIES ---
DROP POLICY IF EXISTS "Trainers manage anamnesis" ON public.anamnesis;
CREATE POLICY "Trainers manage anamnesis"
    ON public.anamnesis FOR ALL
    USING (trainer_id = auth.uid());

DROP POLICY IF EXISTS "Clients can view their own anamnesis" ON public.anamnesis;
CREATE POLICY "Clients can view their own anamnesis"
    ON public.anamnesis FOR SELECT
    USING (client_id = auth.uid());

-- --- WORKOUTS POLICIES ---
DROP POLICY IF EXISTS "Trainers manage workouts" ON public.workouts;
CREATE POLICY "Trainers manage workouts"
    ON public.workouts FOR ALL
    USING (trainer_id = auth.uid());

DROP POLICY IF EXISTS "Clients can view their workouts" ON public.workouts;
CREATE POLICY "Clients can view their workouts"
    ON public.workouts FOR SELECT
    USING (client_id = auth.uid());

-- --- ADAPTATION LOGS POLICIES ---
DROP POLICY IF EXISTS "Clients can create adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can create adaptation logs"
    ON public.adaptation_logs FOR INSERT
    WITH CHECK (client_id = auth.uid());

DROP POLICY IF EXISTS "Clients can view their adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can view their adaptation logs"
    ON public.adaptation_logs FOR SELECT
    USING (client_id = auth.uid());

DROP POLICY IF EXISTS "Trainers can view students adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Trainers can view students adaptation logs"
    ON public.adaptation_logs FOR SELECT
    USING (trainer_id = auth.uid());

DROP POLICY IF EXISTS "Trainers can update adaptation logs acknowledgment" ON public.adaptation_logs;
CREATE POLICY "Trainers can update adaptation logs acknowledgment"
    ON public.adaptation_logs FOR UPDATE
    USING (trainer_id = auth.uid());
