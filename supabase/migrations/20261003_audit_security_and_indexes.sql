-- ==============================================================================
-- Migration: 20261003_audit_security_and_indexes.sql
-- Description: Auditoria de Banco de Dados, RLS Estrito, View Pública e Índices de Performance
-- Author: Marta (Database Architect & Supabase DBA)
-- ==============================================================================

-- 1. EXTENSÃO CITEXT PARA USERNAMES CASE-INSENSITIVE
CREATE EXTENSION IF NOT EXISTS "citext";

-- 2. ENRIQUECIMENTO DA TABELA PUBLIC.PROFILES COM NOVOS CAMPOS
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS username CITEXT,
    ADD COLUMN IF NOT EXISTS bio TEXT,
    ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS public_whatsapp TEXT;

-- 2.1 Constraint de validação de formato de username (slug limpo de 3 a 30 caracteres)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'check_profiles_username_format'
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT check_profiles_username_format
        CHECK (
            username IS NULL OR 
            (username ~ '^[a-z0-9][a-z0-9_.-]{1,28}[a-z0-9]$' AND role = 'trainer')
        );
    END IF;
END $$;

-- 3. ÍNDICES DE PERFORMANCE CRUCIAIS
-- Índice único case-insensitive para busca em Landing Page (/p/:username)
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_trainer_username_lower
ON public.profiles (LOWER(username))
WHERE role = 'trainer' AND username IS NOT NULL;

-- Índice GIN para filtragem por especialidades na Landing Page
CREATE INDEX IF NOT EXISTS idx_profiles_specialties_gin
ON public.profiles USING GIN (specialties);

-- Índice parcial que impede atomicamente a existência de mais de 1 treino ativo por aluno
CREATE UNIQUE INDEX IF NOT EXISTS idx_workouts_one_active_per_client
ON public.workouts (client_id)
WHERE is_active = true;

-- 4. TABELA DE GAMIFICAÇÃO COM MODELAGEM SEGURA E INTEGRAL
CREATE TABLE IF NOT EXISTS public.gamification_stats (
    client_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    current_streak INT NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
    best_streak INT NOT NULL DEFAULT 0 CHECK (best_streak >= 0),
    total_workouts_completed INT NOT NULL DEFAULT 0 CHECK (total_workouts_completed >= 0),
    total_points INT NOT NULL DEFAULT 0 CHECK (total_points >= 0),
    level INT NOT NULL DEFAULT 1 CHECK (level >= 1),
    last_activity_date DATE,
    badges JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice para ranking e leaderboards de alunos por treinador
CREATE INDEX IF NOT EXISTS idx_gamification_trainer_ranking
ON public.gamification_stats (trainer_id, total_points DESC, current_streak DESC);

-- Trigger de updated_at para gamificação
DROP TRIGGER IF EXISTS set_gamification_updated_at ON public.gamification_stats;
CREATE TRIGGER set_gamification_updated_at
    BEFORE UPDATE ON public.gamification_stats
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 5. TRIGGER DE PROTEÇÃO CONTRA ESCALAÇÃO DE PRIVILÉGIOS (ANTI-TAMPERING)
CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER AS $$
BEGIN
    -- Validação ativa para chamadas disparadas pelo usuário final (authenticated)
    IF (current_user = 'authenticated' OR auth.role() = 'authenticated') THEN
        -- Bloqueia alteração manual de papel (role)
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            RAISE EXCEPTION 'A alteração de papel (role) não é permitida pelo próprio usuário.';
        END IF;

        -- Bloqueia alteração de status de assinatura ou datas de validade
        IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
           NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until THEN
            RAISE EXCEPTION 'Status e vigência de assinatura só podem ser manipulados pelo backend de faturamento.';
        END IF;

        -- Bloqueia troca arbitrária de trainer_id por parte do aluno
        IF OLD.role = 'client' AND NEW.trainer_id IS DISTINCT FROM OLD.trainer_id THEN
            RAISE EXCEPTION 'O vínculo de treinador não pode ser alterado diretamente pelo aluno.';
        END IF;

        -- Bloqueia criação de username por contas de alunos
        IF OLD.role = 'client' AND NEW.username IS NOT NULL THEN
            RAISE EXCEPTION 'Apenas usuários com papel de treinador podem definir username público.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_protect_profile_escalation ON public.profiles;
CREATE TRIGGER trg_protect_profile_escalation
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profile_privilege_escalation();

-- 6. REGRAS ESTRITAS DE ROW LEVEL SECURITY (RLS)

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gamification_stats ENABLE ROW LEVEL SECURITY;

-- --- REGRAS PARA PROFILES ---
-- Visitantes públicos e usuários logados podem visualizar perfil público de treinadores
DROP POLICY IF EXISTS "Public can view trainers profile" ON public.profiles;
CREATE POLICY "Public can view trainers profile"
    ON public.profiles FOR SELECT
    USING (role = 'trainer');

-- Usuário visualiza o seu próprio perfil completo
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- Treinadores visualizam os alunos associados
DROP POLICY IF EXISTS "Trainers can view their associated clients" ON public.profiles;
CREATE POLICY "Trainers can view their associated clients"
    ON public.profiles FOR SELECT
    USING (trainer_id = auth.uid());

-- Alunos visualizam o perfil do seu professor vinculado
DROP POLICY IF EXISTS "Clients can view their assigned trainer" ON public.profiles;
CREATE POLICY "Clients can view their assigned trainer"
    ON public.profiles FOR SELECT
    USING (
        id = (SELECT p.trainer_id FROM public.profiles p WHERE p.id = auth.uid())
    );

-- Atualização restrita ao próprio usuário (garantido pelo trigger contra escalação)
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- --- REGRAS PARA WORKOUTS (ESTRITO: ALUNOS SOMENTE LEITURA) ---
-- Treinador tem controle total sobre os treinos que prescreveu
DROP POLICY IF EXISTS "Trainers manage workouts" ON public.workouts;
CREATE POLICY "Trainers manage workouts"
    ON public.workouts FOR ALL
    USING (trainer_id = auth.uid())
    WITH CHECK (trainer_id = auth.uid());

-- Aluno tem permissão ESTRITAMENTE de leitura em seus próprios treinos
DROP POLICY IF EXISTS "Clients can view their workouts" ON public.workouts;
CREATE POLICY "Clients can view their workouts"
    ON public.workouts FOR SELECT
    USING (client_id = auth.uid());

-- --- REGRAS PARA GAMIFICATION_STATS ---
-- Aluno visualiza sua própria gamificação
DROP POLICY IF EXISTS "Clients can view own gamification stats" ON public.gamification_stats;
CREATE POLICY "Clients can view own gamification stats"
    ON public.gamification_stats FOR SELECT
    USING (client_id = auth.uid());

-- Treinador visualiza a gamificação dos seus alunos
DROP POLICY IF EXISTS "Trainers can view their clients gamification stats" ON public.gamification_stats;
CREATE POLICY "Trainers can view their clients gamification stats"
    ON public.gamification_stats FOR SELECT
    USING (trainer_id = auth.uid());

-- 7. VIEW PÚBLICA SEGURA PARA A LANDING PAGE (PROTEGE DADOS PRIVADOS COMO TELEFONE E ASSINATURA)
CREATE OR REPLACE VIEW public.public_trainer_profiles AS
SELECT 
    id,
    username,
    full_name,
    avatar_url,
    bio,
    specialties,
    public_whatsapp,
    created_at
FROM public.profiles
WHERE role = 'trainer' AND username IS NOT NULL;

GRANT SELECT ON public.public_trainer_profiles TO anon, authenticated;
