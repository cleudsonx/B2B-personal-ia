-- Conclusão atômica de checkout pago: sessão + assinatura + evento de webhook na mesma transação.
-- Forward-only e aditiva; não altera tabelas nem policies existentes.

CREATE OR REPLACE FUNCTION public.complete_paid_checkout_session_v2(
    p_session_id TEXT,
    p_event_id TEXT DEFAULT NULL,
    p_claim_token UUID DEFAULT NULL,
    p_provider_payment_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
#variable_conflict use_column
DECLARE
    v_session public.checkout_sessions%ROWTYPE;
    v_event public.processed_webhook_events%ROWTYPE;
    v_has_event BOOLEAN := COALESCE(p_event_id, '') <> '';
    v_now TIMESTAMPTZ := now();
    v_days INT;
BEGIN
    IF COALESCE(p_session_id, '') = '' THEN
        RAISE EXCEPTION 'complete_paid_checkout_session_v2: session_id obrigatorio';
    END IF;

    IF v_has_event <> (p_claim_token IS NOT NULL) THEN
        RAISE EXCEPTION 'complete_paid_checkout_session_v2: event_id e claim_token devem ser informados juntos';
    END IF;

    -- Serializa polling/webhook/chamadas repetidas na mesma sessão.
    SELECT * INTO v_session
    FROM public.checkout_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'complete_paid_checkout_session_v2: checkout_session nao encontrada';
    END IF;

    -- Ordem de locks fixa (sessão -> evento); claim inválido derruba a transação inteira.
    IF v_has_event THEN
        SELECT * INTO v_event
        FROM public.processed_webhook_events
        WHERE event_id = p_event_id
        FOR UPDATE;

        IF NOT FOUND OR v_event.status <> 'processing'
           OR v_event.claim_token IS DISTINCT FROM p_claim_token THEN
            RAISE EXCEPTION 'complete_paid_checkout_session_v2: claim invalido para o evento';
        END IF;
    END IF;

    -- Só 'pending' ativa; failed/canceled/expired etc. abortam a transação (rollback do claim).
    IF COALESCE(v_session.status, '') NOT IN ('pending', 'paid', 'completed', 'active') THEN
        RAISE EXCEPTION 'complete_paid_checkout_session_v2: checkout_session com status % nao pode ser ativada', v_session.status;
    END IF;

    IF v_session.status = 'pending' THEN
        IF v_session.billing_interval NOT IN ('monthly', 'yearly') THEN
            RAISE EXCEPTION 'complete_paid_checkout_session_v2: billing_interval invalido na sessao';
        END IF;
        v_days := CASE WHEN v_session.billing_interval = 'yearly' THEN 365 ELSE 30 END;

        INSERT INTO public.subscriptions AS s (
            trainer_id, plan_id, status, billing_interval,
            current_period_start, current_period_end, payment_provider, updated_at
        )
        VALUES (
            v_session.trainer_id, v_session.plan_id,
            CASE WHEN v_session.plan_id = 'starter' THEN 'trialing' ELSE 'active' END,
            v_session.billing_interval, v_now, v_now + make_interval(days => v_days),
            COALESCE(NULLIF(v_session.payment_method, ''), 'asaas'), v_now
        )
        ON CONFLICT (trainer_id) DO UPDATE SET
            plan_id = EXCLUDED.plan_id,
            status = EXCLUDED.status,
            billing_interval = EXCLUDED.billing_interval,
            current_period_start = EXCLUDED.current_period_start,
            current_period_end = EXCLUDED.current_period_end,
            payment_provider = EXCLUDED.payment_provider,
            updated_at = EXCLUDED.updated_at;

        UPDATE public.checkout_sessions
        SET status = 'paid',
            updated_at = v_now,
            provider_payment_id = COALESCE(p_provider_payment_id, provider_payment_id)
        WHERE session_id = p_session_id;
    ELSIF p_provider_payment_id IS NOT NULL THEN
        -- Já paga: não toca assinatura/período; só registra o id do pagamento se informado.
        UPDATE public.checkout_sessions
        SET provider_payment_id = p_provider_payment_id,
            updated_at = v_now
        WHERE session_id = p_session_id;
    END IF;

    IF v_has_event THEN
        UPDATE public.processed_webhook_events
        SET status = 'completed',
            claim_token = NULL,
            lease_expires_at = NULL,
            completed_at = v_now,
            last_error = NULL
        WHERE event_id = p_event_id;
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_paid_checkout_session_v2(TEXT, TEXT, UUID, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_paid_checkout_session_v2(TEXT, TEXT, UUID, TEXT) TO service_role;
