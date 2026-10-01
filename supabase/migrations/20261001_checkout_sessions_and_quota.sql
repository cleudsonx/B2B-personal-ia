-- ==============================================================================
-- MIGRAÇÃO B2B PERSONAL IA: SESSÕES DE CHECKOUT DURÁVEIS E RESERVA ATÔMICA DE COTA IA
-- ==============================================================================

-- 1. Tabela de Sessões de Checkout Duráveis (sobrevive a restarts e troca de workers)
CREATE TABLE IF NOT EXISTS public.checkout_sessions (
    session_id VARCHAR(150) PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    provider_payment_id VARCHAR(150),
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id VARCHAR(50) NOT NULL REFERENCES public.plans(id),
    billing_interval VARCHAR(20) NOT NULL DEFAULT 'monthly',
    payment_method VARCHAR(30) NOT NULL DEFAULT 'pix',
    amount_cents INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    checkout_url TEXT,
    pix_copy_paste TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_trainer_id ON public.checkout_sessions(trainer_id);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_status ON public.checkout_sessions(status);
CREATE INDEX IF NOT EXISTS idx_checkout_sessions_ext_ref ON public.checkout_sessions(provider_payment_id);

-- RLS
ALTER TABLE public.checkout_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role gerencia sessoes de checkout" ON public.checkout_sessions;
CREATE POLICY "Service role gerencia sessoes de checkout" ON public.checkout_sessions
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Treinadores leem suas proprias sessoes" ON public.checkout_sessions;
CREATE POLICY "Treinadores leem suas proprias sessoes" ON public.checkout_sessions
    FOR SELECT
    USING (auth.uid() = trainer_id);


-- 2. Função de Reserva Atômica de Cota de IA (Prevenção de Race Conditions)
-- Retorna TRUE se a cota foi reservada com sucesso; FALSE se excedeu o limite.
CREATE OR REPLACE FUNCTION public.reserve_trainer_ai_usage(
    p_trainer_id UUID,
    p_period_start DATE,
    p_max_generations INTEGER
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current INTEGER;
BEGIN
    -- Se o plano é ilimitado (max < 0, ex: Pro/Elite/Studio), incrementa e permite
    IF p_max_generations < 0 THEN
        INSERT INTO public.trainer_ai_usage (trainer_id, period_start, generations_used)
        VALUES (p_trainer_id, p_period_start, 1)
        ON CONFLICT (trainer_id, period_start)
        DO UPDATE SET
            generations_used = public.trainer_ai_usage.generations_used + 1,
            updated_at = now();
        RETURN TRUE;
    END IF;

    -- Para planos com cota finita (ex: Starter com 10 gerações/mês):
    -- Bloqueia a linha para atualização atômica
    SELECT generations_used INTO v_current
    FROM public.trainer_ai_usage
    WHERE trainer_id = p_trainer_id AND period_start = p_period_start
    FOR UPDATE;

    IF v_current IS NULL THEN
        -- Primeira geração do período
        INSERT INTO public.trainer_ai_usage (trainer_id, period_start, generations_used)
        VALUES (p_trainer_id, p_period_start, 1);
        RETURN TRUE;
    ELSIF v_current < p_max_generations THEN
        -- Ainda possui franquia disponível
        UPDATE public.trainer_ai_usage
        SET generations_used = generations_used + 1,
            updated_at = now()
        WHERE trainer_id = p_trainer_id AND period_start = p_period_start;
        RETURN TRUE;
    ELSE
        -- Limite atingido: não reserva
        RETURN FALSE;
    END IF;
END;
$$;

-- 3. Função de Liberação de Cota em caso de falha de geração (Rollback de Cota)
CREATE OR REPLACE FUNCTION public.release_trainer_ai_usage(
    p_trainer_id UUID,
    p_period_start DATE
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.trainer_ai_usage
    SET generations_used = GREATEST(0, generations_used - 1),
        updated_at = now()
    WHERE trainer_id = p_trainer_id AND period_start = p_period_start;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_trainer_ai_usage(UUID, DATE, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_trainer_ai_usage(UUID, DATE, INTEGER) TO service_role;

REVOKE ALL ON FUNCTION public.release_trainer_ai_usage(UUID, DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_trainer_ai_usage(UUID, DATE) TO service_role;
