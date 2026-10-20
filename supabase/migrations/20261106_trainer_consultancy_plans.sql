-- ==============================================================================
-- Migration: 20261106_trainer_consultancy_plans.sql
-- Description:
--   FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Vitrine Pública)
--   1. Cria a tabela `public.trainer_consultancy_plans` para o personal configurar
--      seus planos de consultoria, fichas avulsas e preços.
--   2. Adiciona coluna `plan_id` opcional na tabela `student_invoices`.
--   3. Configura RLS (leitura pública para ativos; edição restrita ao treinador dono).
--   4. Seed inicial com planos de exemplo para o treinador Cleudson ('mrcoach').
-- ==============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.trainer_consultancy_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 1000), -- Mínimo R$ 10,00
    billing_period TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_period IN ('monthly', 'quarterly', 'semiannual', 'annual', 'one_time')),
    features JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Adiciona plan_id em student_invoices para rastreabilidade do plano contratado
ALTER TABLE public.student_invoices
    ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES public.trainer_consultancy_plans(id) ON DELETE SET NULL;

-- Índices de performance
CREATE INDEX IF NOT EXISTS idx_consultancy_plans_trainer 
ON public.trainer_consultancy_plans (trainer_id, is_active, sort_order);

CREATE INDEX IF NOT EXISTS idx_student_invoices_plan_id 
ON public.student_invoices (plan_id);

-- RLS (Row Level Security)
ALTER TABLE public.trainer_consultancy_plans ENABLE ROW LEVEL SECURITY;

-- 1. Qualquer usuário (anônimo ou autenticado) pode ver planos ativos na Vitrine Pública
DROP POLICY IF EXISTS "public_read_active_consultancy_plans" ON public.trainer_consultancy_plans;
CREATE POLICY "public_read_active_consultancy_plans"
ON public.trainer_consultancy_plans
FOR SELECT
USING (is_active = true);

-- 2. O treinador autenticado pode ver todos os seus planos (inclusive inativos)
DROP POLICY IF EXISTS "trainers_read_own_consultancy_plans" ON public.trainer_consultancy_plans;
CREATE POLICY "trainers_read_own_consultancy_plans"
ON public.trainer_consultancy_plans
FOR SELECT
USING (trainer_id = auth.uid());

-- 3. O treinador autenticado pode criar, atualizar e excluir seus próprios planos
DROP POLICY IF EXISTS "trainers_insert_own_consultancy_plans" ON public.trainer_consultancy_plans;
CREATE POLICY "trainers_insert_own_consultancy_plans"
ON public.trainer_consultancy_plans
FOR INSERT
WITH CHECK (trainer_id = auth.uid());

DROP POLICY IF EXISTS "trainers_update_own_consultancy_plans" ON public.trainer_consultancy_plans;
CREATE POLICY "trainers_update_own_consultancy_plans"
ON public.trainer_consultancy_plans
FOR UPDATE
USING (trainer_id = auth.uid())
WITH CHECK (trainer_id = auth.uid());

DROP POLICY IF EXISTS "trainers_delete_own_consultancy_plans" ON public.trainer_consultancy_plans;
CREATE POLICY "trainers_delete_own_consultancy_plans"
ON public.trainer_consultancy_plans
FOR DELETE
USING (trainer_id = auth.uid());

-- Seed inicial de planos de consultoria para o usuário 'mrcoach'
DO $$
DECLARE
    v_trainer_id UUID;
BEGIN
    SELECT id INTO v_trainer_id
    FROM public.profiles
    WHERE username = 'mrcoach'
    LIMIT 1;

    IF v_trainer_id IS NOT NULL THEN
        -- Plano 1: Mensal
        IF NOT EXISTS (SELECT 1 FROM public.trainer_consultancy_plans WHERE trainer_id = v_trainer_id AND name = 'Consultoria Mensal Pro') THEN
            INSERT INTO public.trainer_consultancy_plans (
                trainer_id, name, description, price_cents, billing_period, features, is_active, sort_order
            ) VALUES (
                v_trainer_id,
                'Consultoria Mensal Pro',
                'Acompanhamento individualizado com treino personalizado, suporte e ajustes no app.',
                15000, -- R$ 150,00
                'monthly',
                '["Prescrição biomecânica completa no app", "Substituição inteligente de exercícios", "Suporte tira-dúvidas via WhatsApp", "Feedback e análise de cargas semanais"]'::jsonb,
                true,
                1
            );
        END IF;

        -- Plano 2: Trimestral
        IF NOT EXISTS (SELECT 1 FROM public.trainer_consultancy_plans WHERE trainer_id = v_trainer_id AND name = 'Plano Trimestral Evolução') THEN
            INSERT INTO public.trainer_consultancy_plans (
                trainer_id, name, description, price_cents, billing_period, features, is_active, sort_order
            ) VALUES (
                v_trainer_id,
                'Plano Trimestral Evolução',
                'Foco em resultados consistentes: 3 meses de acompanhamento com desconto exclusivo.',
                39000, -- R$ 390,00 (R$ 130/mês)
                'quarterly',
                '["Periodização completa em 3 mesociclos", "Ajustes de carga e volume a cada 4 semanas", "Prioridade nas respostas do WhatsApp", "Acesso full a todas as funcionalidades do app"]'::jsonb,
                true,
                2
            );
        END IF;

        -- Plano 3: Ficha Avulsa
        IF NOT EXISTS (SELECT 1 FROM public.trainer_consultancy_plans WHERE trainer_id = v_trainer_id AND name = 'Ficha de Treino Avulsa') THEN
            INSERT INTO public.trainer_consultancy_plans (
                trainer_id, name, description, price_cents, billing_period, features, is_active, sort_order
            ) VALUES (
                v_trainer_id,
                'Ficha de Treino Avulsa',
                'Prescrição sob medida para seu objetivo específico, sem mensalidade recorrente.',
                8000, -- R$ 80,00
                'one_time',
                '["Anamnese postural e clínica", "Ficha A/B ou A/B/C montada no app", "Vídeos e instruções biomecânicas", "Validade de 6 semanas"]'::jsonb,
                true,
                3
            );
        END IF;
    END IF;
END;
$$;

COMMIT;
