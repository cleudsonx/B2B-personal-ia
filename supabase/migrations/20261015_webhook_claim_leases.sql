-- Claims de webhook com lease/retry (Asaas e InfinitePay). Aditiva e idempotente.
-- Linhas legadas em processed_webhook_events passam a ser 'completed'.

ALTER TABLE public.processed_webhook_events
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed',
    ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS claim_token UUID,
    ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS lease_expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_error TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'processed_webhook_events_status_check'
          AND conrelid = 'public.processed_webhook_events'::regclass
    ) THEN
        ALTER TABLE public.processed_webhook_events
            ADD CONSTRAINT processed_webhook_events_status_check
            CHECK (status IN ('processing', 'completed', 'failed'));
    END IF;
END $$;

-- Backfill: eventos legados já tinham event_id gravado, logo são concluídos.
UPDATE public.processed_webhook_events
SET attempts = GREATEST(attempts, 1),
    claimed_at = COALESCE(claimed_at, processed_at),
    completed_at = processed_at
WHERE status = 'completed' AND completed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_processed_webhook_processing_lease
    ON public.processed_webhook_events(lease_expires_at)
    WHERE status = 'processing';

ALTER TABLE public.processed_webhook_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.processed_webhook_events FROM anon, authenticated;

-- ------------------------------------------------------------------------------
-- claim_webhook_event_v2: disposition = claimed | duplicate | busy | failed
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_webhook_event_v2(
    p_event_id TEXT,
    p_provider TEXT,
    p_event_type TEXT,
    p_payload JSONB,
    p_token UUID,
    p_lease_seconds INT DEFAULT 300,
    p_max_attempts INT DEFAULT 5
)
RETURNS TABLE(disposition TEXT, claim_token UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
    v_row public.processed_webhook_events%ROWTYPE;
    v_now TIMESTAMPTZ;
    v_max INT := LEAST(COALESCE(p_max_attempts, 5), 5);
    v_provider TEXT := lower(COALESCE(p_provider, ''));
BEGIN
    IF COALESCE(p_event_id, '') = '' OR p_token IS NULL
       OR COALESCE(p_lease_seconds, 0) <= 0 OR v_max < 1 THEN
        RAISE EXCEPTION 'claim_webhook_event_v2: argumentos invalidos';
    END IF;
    IF v_provider NOT IN ('asaas', 'infinitepay') THEN
        RAISE EXCEPTION 'claim_webhook_event_v2: provider nao suportado';
    END IF;

    FOR i IN 1..3 LOOP
        v_now := clock_timestamp();

        INSERT INTO public.processed_webhook_events AS e (
            event_id, provider, event_type, payload, processed_at,
            status, attempts, claim_token, claimed_at, lease_expires_at
        )
        VALUES (
            p_event_id, v_provider, p_event_type, COALESCE(p_payload, '{}'::jsonb), v_now,
            'processing', 1, p_token, v_now, v_now + make_interval(secs => p_lease_seconds)
        )
        ON CONFLICT (event_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT 'claimed'::TEXT, p_token;
            RETURN;
        END IF;

        SELECT * INTO v_row
        FROM public.processed_webhook_events
        WHERE event_id = p_event_id
        FOR UPDATE;

        IF NOT FOUND THEN
            CONTINUE; -- linha removida entre o INSERT e o SELECT; tenta de novo
        END IF;

        IF v_row.status = 'completed' THEN
            RETURN QUERY SELECT 'duplicate'::TEXT, NULL::UUID;
            RETURN;
        ELSIF v_row.status = 'failed' THEN
            RETURN QUERY SELECT 'failed'::TEXT, NULL::UUID;
            RETURN;
        ELSIF v_row.lease_expires_at IS NOT NULL AND v_row.lease_expires_at > v_now THEN
            RETURN QUERY SELECT 'busy'::TEXT, NULL::UUID;
            RETURN;
        END IF;

        -- processing com lease expirado (ou liberado): reclaim ou falha definitiva
        IF v_row.attempts >= v_max THEN
            UPDATE public.processed_webhook_events
            SET status = 'failed',
                claim_token = NULL,
                lease_expires_at = NULL,
                last_error = COALESCE(last_error, 'lease expirado: maximo de tentativas atingido')
            WHERE event_id = p_event_id;
            RETURN QUERY SELECT 'failed'::TEXT, NULL::UUID;
            RETURN;
        END IF;

        UPDATE public.processed_webhook_events
        SET attempts = attempts + 1,
            claim_token = p_token,
            claimed_at = v_now,
            lease_expires_at = v_now + make_interval(secs => p_lease_seconds)
        WHERE event_id = p_event_id;
        RETURN QUERY SELECT 'claimed'::TEXT, p_token;
        RETURN;
    END LOOP;

    RAISE EXCEPTION 'claim_webhook_event_v2: nao foi possivel reivindicar o evento';
END;
$$;

-- ------------------------------------------------------------------------------
-- release_webhook_event_v2: libera o lease para retry imediato (nunca deleta)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.release_webhook_event_v2(
    p_event_id TEXT,
    p_token UUID,
    p_error TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
BEGIN
    IF p_token IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE public.processed_webhook_events
    SET status = CASE WHEN attempts >= 5 THEN 'failed' ELSE 'processing' END,
        claim_token = NULL,
        lease_expires_at = CASE WHEN attempts >= 5 THEN NULL ELSE clock_timestamp() END,
        last_error = left(p_error, 2000)
    WHERE event_id = p_event_id
      AND status = 'processing'
      AND claim_token = p_token;

    RETURN FOUND;
END;
$$;

-- ------------------------------------------------------------------------------
-- complete_subscription_webhook_v2: mutação da assinatura + conclusão do evento
-- na mesma transação. Token/status inválido => exceção (rollback).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_subscription_webhook_v2(
    p_event_id TEXT,
    p_token UUID,
    p_action TEXT,
    p_trainer_id UUID DEFAULT NULL,
    p_plan_id TEXT DEFAULT NULL,
    p_billing_interval TEXT DEFAULT 'monthly',
    p_payment_method TEXT DEFAULT 'asaas'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
    v_row public.processed_webhook_events%ROWTYPE;
    v_now TIMESTAMPTZ := now();
    v_days INT;
BEGIN
    IF p_token IS NULL OR p_action IS NULL
       OR p_action NOT IN ('activate', 'past_due', 'canceled', 'none') THEN
        RAISE EXCEPTION 'complete_subscription_webhook_v2: argumentos invalidos';
    END IF;

    SELECT * INTO v_row
    FROM public.processed_webhook_events
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF NOT FOUND OR v_row.status <> 'processing' OR v_row.claim_token IS DISTINCT FROM p_token THEN
        RAISE EXCEPTION 'complete_subscription_webhook_v2: claim invalido para o evento';
    END IF;

    IF p_action = 'activate' THEN
        IF p_trainer_id IS NULL OR COALESCE(p_plan_id, '') = '' THEN
            RAISE EXCEPTION 'complete_subscription_webhook_v2: trainer_id e plan_id obrigatorios';
        END IF;
        IF p_billing_interval NOT IN ('monthly', 'yearly') THEN
            RAISE EXCEPTION 'complete_subscription_webhook_v2: billing_interval invalido';
        END IF;
        v_days := CASE WHEN p_billing_interval = 'yearly' THEN 365 ELSE 30 END;

        INSERT INTO public.subscriptions AS s (
            trainer_id, plan_id, status, billing_interval,
            current_period_start, current_period_end, payment_provider, updated_at
        )
        VALUES (
            p_trainer_id, p_plan_id,
            CASE WHEN p_plan_id = 'starter' THEN 'trialing' ELSE 'active' END,
            p_billing_interval, v_now, v_now + make_interval(days => v_days),
            COALESCE(NULLIF(p_payment_method, ''), 'asaas'), v_now
        )
        ON CONFLICT (trainer_id) DO UPDATE SET
            plan_id = EXCLUDED.plan_id,
            status = EXCLUDED.status,
            billing_interval = EXCLUDED.billing_interval,
            current_period_start = EXCLUDED.current_period_start,
            current_period_end = EXCLUDED.current_period_end,
            payment_provider = EXCLUDED.payment_provider,
            updated_at = EXCLUDED.updated_at;

    ELSIF p_action IN ('past_due', 'canceled') THEN
        IF p_trainer_id IS NULL THEN
            RAISE EXCEPTION 'complete_subscription_webhook_v2: trainer_id obrigatorio';
        END IF;

        -- Mesma regra do serviço: só transiciona assinaturas ativas (past_due também pode cancelar).
        UPDATE public.subscriptions
        SET status = p_action, updated_at = v_now
        WHERE trainer_id = p_trainer_id
          AND (status = 'active' OR (p_action = 'canceled' AND status = 'past_due'));
    END IF;

    UPDATE public.processed_webhook_events
    SET status = 'completed',
        claim_token = NULL,
        lease_expires_at = NULL,
        completed_at = v_now,
        last_error = NULL
    WHERE event_id = p_event_id;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_webhook_event_v2(TEXT, TEXT, TEXT, JSONB, UUID, INT, INT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.release_webhook_event_v2(TEXT, UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_subscription_webhook_v2(TEXT, UUID, TEXT, UUID, TEXT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.claim_webhook_event_v2(TEXT, TEXT, TEXT, JSONB, UUID, INT, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.release_webhook_event_v2(TEXT, UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_subscription_webhook_v2(TEXT, UUID, TEXT, UUID, TEXT, TEXT, TEXT) TO service_role;
