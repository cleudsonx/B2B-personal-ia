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

-- 4. Função auxiliar para verificar cota de alunos antes de inserir ou reativar aluno
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
      AND s.status IN ('active', 'trialing')
    ORDER BY s.created_at DESC
    LIMIT 1;

    -- Se não encontrar assinatura, assume padrão trial (3 alunos)
    IF v_max_students IS NULL THEN
        v_max_students := 3;
    END IF;

    -- Conta total de alunos ocupando vaga ativa do treinador (não arquivados / não inativos)
    SELECT COUNT(*) INTO v_current_students
    FROM public.profiles
    WHERE trainer_id = p_trainer_id
      AND role = 'client'
      AND LOWER(COALESCE(subscription_status, 'active')) NOT IN ('arquivado', 'inativo');

    RETURN v_current_students < v_max_students;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Trigger para impedir violação de cota em inserção ou reativação de alunos
CREATE OR REPLACE FUNCTION public.enforce_trainer_student_quota()
RETURNS TRIGGER AS $$
DECLARE
    v_max_students INTEGER;
    v_current_students INTEGER;
    v_is_reactivation BOOLEAN := false;
BEGIN
    -- Só valida para perfil de cliente com treinador associado
    IF NEW.role <> 'client' OR NEW.trainer_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Se o status for arquivado/inativo, permite salvar sem consumir vaga
    IF LOWER(COALESCE(NEW.subscription_status, 'active')) IN ('arquivado', 'inativo') THEN
        RETURN NEW;
    END IF;

    -- Verifica se é reativação (de arquivado/inativo para ativo)
    IF TG_OP = 'UPDATE' THEN
        IF LOWER(COALESCE(OLD.subscription_status, 'active')) IN ('arquivado', 'inativo') THEN
            v_is_reactivation := true;
        ELSE
            -- Não está reativando, é apenas edição de dados cadastrais
            RETURN NEW;
        END IF;
    END IF;

    -- Busca limite do plano contratado
    SELECT p.max_students INTO v_max_students
    FROM public.subscriptions s
    JOIN public.plans p ON p.id = s.plan_id
    WHERE s.trainer_id = NEW.trainer_id
      AND s.status IN ('active', 'trialing')
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_max_students IS NULL THEN
        v_max_students := 3; -- Default Starter
    END IF;

    -- Conta vagas ocupadas por outros alunos (excluindo o próprio aluno em caso de update)
    SELECT COUNT(*) INTO v_current_students
    FROM public.profiles
    WHERE trainer_id = NEW.trainer_id
      AND role = 'client'
      AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID)
      AND LOWER(COALESCE(subscription_status, 'active')) NOT IN ('arquivado', 'inativo');

    IF v_current_students >= v_max_students THEN
        IF v_is_reactivation THEN
            RAISE EXCEPTION 'Limite de % alunos ativos atingido no seu plano. Para reativar este aluno, faça upgrade do plano ou arquive outro aluno.', v_max_students
                USING ERRCODE = '23514'; -- check_violation
        ELSE
            RAISE EXCEPTION 'Limite de % alunos ativos atingido no seu plano. Faça upgrade para cadastrar novos alunos.', v_max_students
                USING ERRCODE = '23514';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_trainer_student_quota ON public.profiles;
CREATE TRIGGER trg_enforce_trainer_student_quota
    BEFORE INSERT OR UPDATE OF subscription_status ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_trainer_student_quota();

