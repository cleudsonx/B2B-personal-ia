-- ==============================================================================
-- Migration: 20261004_trainer_public_profile_and_showcase.sql
-- Description: Evolução do schema de profiles para a Vitrine Pública (Landing Page B2B).
--              Adiciona username (TEXT UNIQUE), bio, specialties, public_whatsapp e photo_url.
--              Cria índices de alta performance (B-Tree, Funcional Lower e GIN)
--              e estabelece políticas de Row Level Security (RLS) seguras.
-- Idempotente: Seguro para execução repetida no Supabase SQL Editor.
-- ==============================================================================

-- 1. ADIÇÃO DE COLUNAS NA TABELA public.profiles
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS username TEXT,
    ADD COLUMN IF NOT EXISTS bio TEXT,
    ADD COLUMN IF NOT EXISTS specialties TEXT[] DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS public_whatsapp TEXT,
    ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Sincronizar photo_url com avatar_url para perfis legados
UPDATE public.profiles
SET photo_url = avatar_url
WHERE photo_url IS NULL AND avatar_url IS NOT NULL;

-- Sincronizar avatar_url com photo_url caso avatar_url seja nulo
UPDATE public.profiles
SET avatar_url = photo_url
WHERE avatar_url IS NULL AND photo_url IS NOT NULL;

-- 2. RESTRIÇÕES DE INTEGRIDADE (CONSTRAINTS)
-- Garantir constraint de unicidade no username (NULLs são permitidos, ideal para alunos)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_username_key'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_username_key UNIQUE (username);
    END IF;
END $$;

-- Validação de integridade de formato para slug/username
-- Aceita: 3 a 30 caracteres alfanuméricos, pontos, traços e underscores. Inicia com alfanumérico.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_profiles_username_format'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT chk_profiles_username_format
            CHECK (username IS NULL OR username ~* '^[a-z0-9][a-z0-9._-]{2,29}$');
    END IF;
END $$;

-- 3. ÍNDICES DE ALTA PERFORMANCE (LOOKUP & SHOWCASE)
-- Índice Único Case-Insensitive funcional (LOWER(username)):
-- Impede duplicidades como "CoachLucas" e "coachlucas" e acelera consultas na rota pública
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_lower
    ON public.profiles (LOWER(username))
    WHERE username IS NOT NULL;

-- Índice Parcial dedicado a Treinadores:
-- Otimiza a query GET /api/v1/public/trainers/{username}
CREATE INDEX IF NOT EXISTS idx_profiles_trainer_username
    ON public.profiles (username)
    WHERE role = 'trainer' AND username IS NOT NULL;

-- Índice GIN em specialties para consultas rápidas por nicho/especialidade no marketplace
CREATE INDEX IF NOT EXISTS idx_profiles_specialties_gin
    ON public.profiles USING GIN (specialties);

-- 4. ATUALIZAÇÃO DO TRIGGER DE CRIAÇÃO AUTOMÁTICA DE PERFIL (handle_new_user)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        role,
        phone,
        trainer_id,
        username,
        bio,
        specialties,
        public_whatsapp,
        photo_url,
        avatar_url
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'client'),
        NEW.raw_user_meta_data->>'phone',
        NULLIF(NEW.raw_user_meta_data->>'trainer_id', '')::UUID,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'bio',
        COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'specialties')),
            '{}'::TEXT[]
        ),
        NEW.raw_user_meta_data->>'public_whatsapp',
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url')
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        username = COALESCE(EXCLUDED.username, public.profiles.username),
        bio = COALESCE(EXCLUDED.bio, public.profiles.bio),
        public_whatsapp = COALESCE(EXCLUDED.public_whatsapp, public.profiles.public_whatsapp),
        photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- Garante que RLS está habilitado
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Política de Leitura Pública para Treinadores:
-- Permite que a vitrine pública e alunos anônimos/autenticados consultem dados de treinadores
DROP POLICY IF EXISTS "Public can view trainer profiles" ON public.profiles;
CREATE POLICY "Public can view trainer profiles"
    ON public.profiles
    FOR SELECT
    USING (role = 'trainer');

-- Política para Alunos visualizarem seu próprio treinador vinculado (caso role != trainer por algum motivo de borda)
DROP POLICY IF EXISTS "Clients can view their trainer profile" ON public.profiles;
CREATE POLICY "Clients can view their trainer profile"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        id IN (
            SELECT p.trainer_id
            FROM public.profiles p
            WHERE p.id = auth.uid() AND p.trainer_id IS NOT NULL
        )
    );

-- Política de Atualização: Usuário autenticado atualiza apenas o seu próprio perfil
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 6. VIEW PÚBLICA SANITIZADA (SECURITY BEST PRACTICE - LGPD)
-- Expõe estritamente os campos públicos de marketing, sem revelar dados sensíveis (phone pessoal, subscription_status)
CREATE OR REPLACE VIEW public.public_trainers AS
SELECT
    id,
    full_name,
    username,
    bio,
    specialties,
    public_whatsapp,
    photo_url,
    avatar_url,
    created_at
FROM public.profiles
WHERE role = 'trainer';

-- Permissão de leitura concedida aos papéis anônimo e autenticado
GRANT SELECT ON public.public_trainers TO anon, authenticated;
