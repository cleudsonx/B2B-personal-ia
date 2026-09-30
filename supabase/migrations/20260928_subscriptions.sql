-- ==============================================================================
-- MIGRAÇÃO B2B PERSONAL IA: MODELAGEM DE PLANOS E ASSINATURAS SAAS
-- ==============================================================================

-- 1. Tabela de Planos Comerciais
CREATE TABLE IF NOT EXISTS public.plans (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    tagline TEXT,
    price_monthly_cents INTEGER NOT NULL DEFAULT 0,
    price_yearly_cents INTEGER NOT NULL DEFAULT 0,
    max_students INTEGER NOT NULL DEFAULT 3,
    max_ai_generations_per_month INTEGER NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Inserção dos Planos do Modelo de Negócio
INSERT INTO public.plans (id, name, tagline, price_monthly_cents, price_yearly_cents, max_students, max_ai_generations_per_month)
VALUES
    ('starter', 'Starter Trial', 'Degustação para começar sua consultoria com IA', 0, 0, 3, 10),
    ('pro', 'Personal Pro', 'O plano definitivo para o Personal Trainer de alta renda', 8900, 85200, 30, -1),
    ('elite', 'Elite Coach', 'Consultoria de alta escala com automação WhatsApp', 14900, 142800, 60, -1),
    ('studio', 'Studio Scale', 'Para assessorias esportivas e estúdios que buscam escala', 19900, 190800, 100, -1)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_monthly_cents = EXCLUDED.price_monthly_cents,
    price_yearly_cents = EXCLUDED.price_yearly_cents,
    max_students = EXCLUDED.max_students,
    max_ai_generations_per_month = EXCLUDED.max_ai_generations_per_month;

-- 2. Tabela de Assinaturas dos Treinadores
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id VARCHAR(50) NOT NULL REFERENCES public.plans(id),
    status VARCHAR(30) NOT NULL DEFAULT 'trialing' CHECK (status IN ('active', 'trialing', 'past_due', 'canceled')),
    billing_interval VARCHAR(20) NOT NULL DEFAULT 'monthly' CHECK (billing_interval IN ('monthly', 'yearly')),
    current_period_start TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now() + interval '30 days') NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    payment_provider VARCHAR(50) DEFAULT 'asaas',
    provider_subscription_id VARCHAR(150),
    provider_customer_id VARCHAR(150),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_trainer_subscription UNIQUE (trainer_id)
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_subscriptions_trainer_id ON public.subscriptions(trainer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);

-- 3. Habilitação de RLS (Row Level Security)
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso:
-- Todos podem ler os planos disponíveis
DROP POLICY IF EXISTS "Planos são públicos para leitura" ON public.plans;
CREATE POLICY "Planos são públicos para leitura" ON public.plans
    FOR SELECT USING (true);

-- Treinadores só podem ver e atualizar sua própria assinatura
DROP POLICY IF EXISTS "Treinadores leem sua própria assinatura" ON public.subscriptions;
CREATE POLICY "Treinadores leem sua própria assinatura" ON public.subscriptions
    FOR SELECT USING (auth.uid() = trainer_id);

DROP POLICY IF EXISTS "Treinadores modificam sua própria assinatura" ON public.subscriptions;
CREATE POLICY "Treinadores modificam sua própria assinatura" ON public.subscriptions
    FOR ALL USING (auth.uid() = trainer_id)
    WITH CHECK (auth.uid() = trainer_id);

-- 4. Função auxiliar para verificar cota de alunos antes de inserir novo aluno
CREATE OR REPLACE FUNCTION public.check_trainer_student_quota(p_trainer_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_max_students INTEGER;
    v_current_students INTEGER;
BEGIN
    -- Busca limite do plano ativo
    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions s
    JOIN public.plans p ON p.id = s.plan_id
    WHERE s.trainer_id = p_trainer_id
      AND s.status IN ('active', 'trialing');

    -- Se não encontrar assinatura, assume padrão trial (3 alunos)
    IF v_max_students IS NULL THEN
        v_max_students := 3;
    END IF;

    -- Conta total de alunos ativos do treinador
    SELECT COUNT(*) INTO v_current_students
    FROM public.trainer_students
    WHERE trainer_id = p_trainer_id;

    RETURN v_current_students < v_max_students;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
