-- ==============================================================================
-- UPDATE V3: Gamificação, Vitrine Pública e Status de Aluno (Mr. Coach)
-- Autor: Marta (Database Architect)
-- ==============================================================================

-- 1. Campos de Gamificação (Alunos)
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS current_streak INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS daily_goal_progress FLOAT DEFAULT 0.0;

-- 2. Campos de Vitrine Pública / Negócios (Professores)
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS specialties TEXT[],
  ADD COLUMN IF NOT EXISTS public_whatsapp TEXT;

-- 3. Campos de Gestão de Alunos (Dashboard do Professor)
-- status possíveis: 'Aguardando Ativação', 'Ativo', 'Inativo', 'Pendente Confirmação'
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Aguardando Ativação',
  ADD COLUMN IF NOT EXISTS alert_message TEXT;

-- 4. Criando Índice para a Vitrine (Acelera a busca pública pelo username)
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- 5. Política de RLS para a Vitrine Pública
-- Permite leitura anônima de perfis de treinadores que possuem um username válido
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone"
    ON public.profiles FOR SELECT
    USING (role = 'trainer' AND username IS NOT NULL);
