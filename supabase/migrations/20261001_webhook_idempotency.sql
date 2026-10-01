-- ==============================================================================
-- MIGRAÇÃO B2B PERSONAL IA: IDEMPOTÊNCIA DE WEBHOOKS DE PAGAMENTO
-- ==============================================================================
-- Garante que o mesmo evento de webhook (Asaas, InfinitePay, Mercado Pago, Stripe)
-- seja processado exatamente uma vez, evitando ativações ou cobranças duplicadas.

CREATE TABLE IF NOT EXISTS public.processed_webhook_events (
    event_id VARCHAR(255) PRIMARY KEY,
    provider VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices de consulta rápida e auditoria
CREATE INDEX IF NOT EXISTS idx_processed_webhook_provider_type 
    ON public.processed_webhook_events(provider, event_type);
CREATE INDEX IF NOT EXISTS idx_processed_webhook_processed_at 
    ON public.processed_webhook_events(processed_at DESC);

-- Habilitação de RLS (Row Level Security)
ALTER TABLE public.processed_webhook_events ENABLE ROW LEVEL SECURITY;

-- Política de segurança:
-- Apenas service_role (backend da API) pode inserir e consultar eventos de webhook
DROP POLICY IF EXISTS "Service role gerencia eventos de webhook" ON public.processed_webhook_events;
CREATE POLICY "Service role gerencia eventos de webhook" ON public.processed_webhook_events
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
