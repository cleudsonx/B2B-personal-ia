import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Depends, Request, status
from app.api.deps import get_current_user
from app.core.config import settings
from app.schemas.subscription import (
    PlanResponse,
    PlanFeature,
    MySubscriptionResponse,
    CheckoutSessionRequest,
    CheckoutSessionResponse,
    PlanChangeSimulationRequest,
    PlanChangeSimulationResponse,
    PlanActivationRequest,
    CardPaymentRequest,
    CardPaymentResponse,
)
from app.services.payment_service import PaymentProviderService
from app.services.supabase_service import supabase_service

router = APIRouter()

# Armazenamento referencial vinculado ao serviço com fallback
ACTIVE_TRAINER_SUBSCRIPTIONS = supabase_service._mem_subscriptions

# Importa catálogo unificado de planos da fonte única da verdade
from app.core.plans import SAAS_PLANS, get_plan


async def _verify_payment_webhook(provider: str, payload: dict, request: Request) -> None:
    try:
        PaymentProviderService.verify_webhook(
            provider=provider,
            payload=payload,
            headers=dict(request.headers),
            raw_body=await request.body(),
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e


@router.get("/plans", response_model=List[PlanResponse])
async def list_subscription_plans():
    """Retorna os planos SaaS disponíveis para contratação."""
    return SAAS_PLANS


@router.get("/my-subscription", response_model=MySubscriptionResponse)
async def get_my_subscription(
    trainer_id: str = "current-trainer",
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Retorna o plano ativo e consumo de cotas do Personal Trainer autenticado.
    Busca no Supabase com contagem real de alunos ocupando vagas na assessoria.
    """
    auth_trainer_id = current_user.get("sub") or current_user.get("id")
    if settings.ENVIRONMENT.lower() == "production" and auth_trainer_id:
        effective_id = auth_trainer_id
    else:
        effective_id = trainer_id or auth_trainer_id or "current-trainer"
    return await supabase_service.get_trainer_subscription(effective_id)


@router.post("/activate-plan", response_model=MySubscriptionResponse)
async def activate_subscription_plan(
    req: PlanActivationRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Ativa ou troca o plano do Personal Trainer imediatamente, persistindo no Supabase.
    Atualiza cotas de alunos, limite de gerações IA e periodicidade.
    Em produção: permite ativação direta APENAS para o plano gratuito ('starter').
    Planos pagos (pro, elite, studio) requerem pagamento comprovado via Asaas/Gateway.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == req.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail=f"Plano '{req.plan_id}' não encontrado.")

    auth_trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    trainer_id = req.trainer_id or auth_trainer_id

    # Bloqueio em produção: planos pagos não podem ser ativados sem checkout comprovado
    if settings.ENVIRONMENT.lower() == "production":
        if req.plan_id != "starter":
            raise HTTPException(
                status_code=400,
                detail="Planos pagos só podem ser ativados através de pagamento confirmado (Pix ou Cartão)."
            )
        trainer_id = auth_trainer_id

    return await supabase_service.activate_subscription(
        trainer_id=trainer_id,
        plan_id=req.plan_id,
        billing_interval=req.billing_interval,
        payment_method=req.payment_method or "pix",
    )


@router.post("/calculate-change", response_model=PlanChangeSimulationResponse)
async def simulate_plan_change(request: PlanChangeSimulationRequest):
    """
    Simula e calcula as regras de negócio para Upgrade ou Downgrade de plano:
    - Pró-rata de saldo não utilizado
    - Bloqueio de downgrade caso a quantidade de alunos cadastrados exceda o novo limite
    - Efetivação imediata (upgrade) ou no fim do ciclo (downgrade)
    """
    valid_ids = {"starter", "pro", "elite", "studio"}
    if request.current_plan_id not in valid_ids or request.new_plan_id not in valid_ids:
        raise HTTPException(status_code=400, detail="Plano atual ou novo plano inválido.")

    result = PaymentProviderService.calculate_plan_change(
        current_plan_id=request.current_plan_id,
        new_plan_id=request.new_plan_id,
        billing_interval=request.billing_interval,
        days_used_in_cycle=request.days_used_in_cycle,
        total_days_in_cycle=request.total_days_in_cycle,
        active_students_count=request.active_students_count,
    )
    return PlanChangeSimulationResponse(**result)


@router.post("/checkout-session", response_model=CheckoutSessionResponse)
async def create_checkout_session(
    request: CheckoutSessionRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Gera uma sessão de checkout para assinatura do plano escolhido via Pix ou Cartão.
    Requer autenticação JWT. Em produção, o trainer_id é derivado do token autenticado.
    Suporta múltiplos gateways: Asaas, Mercado Pago, InfinitePay e Stripe.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == request.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail="Plano não encontrado.")

    # Derivar trainer_id das claims do token em produção — nunca do corpo da requisição
    auth_trainer_id = current_user.get("sub") or current_user.get("id")
    if settings.ENVIRONMENT.lower() == "production":
        if not auth_trainer_id or auth_trainer_id == "current-trainer":
            raise HTTPException(status_code=401, detail="Usuário não autenticado.")
        effective_trainer_id = auth_trainer_id
    else:
        effective_trainer_id = request.trainer_id or auth_trainer_id or "current-trainer"

    amount = (
        selected_plan.price_yearly_cents
        if request.billing_interval == "yearly"
        else selected_plan.price_monthly_cents
    )

    checkout_data = PaymentProviderService.create_checkout(
        provider=request.provider or "asaas",
        plan_id=selected_plan.id,
        plan_name=selected_plan.name,
        amount_cents=amount,
        billing_interval=request.billing_interval,
        payment_method=request.payment_method,
        trainer_name=request.trainer_name or "Personal Trainer",
        trainer_email=request.trainer_email or "treinador@demo.com",
        trainer_id=effective_trainer_id,
    )

    # Persiste a sessão de checkout no Supabase para sobreviver a restarts (PAY-003)
    try:
        await supabase_service.save_checkout_session(checkout_data)
    except Exception as e:
        if settings.ENVIRONMENT.lower() == "production":
            raise HTTPException(
                status_code=500,
                detail=f"Falha ao persistir sessão de checkout de forma durável no banco: {e}"
            )
        import logging as _log
        _log.getLogger(__name__).warning(f"Erro ao persistir sessão em ambiente de teste/dev: {e}")

    return CheckoutSessionResponse(
        session_id=checkout_data["session_id"],
        provider=checkout_data["provider"],
        plan_id=checkout_data["plan_id"],
        plan_name=checkout_data["plan_name"],
        amount_cents=checkout_data["amount_cents"],
        billing_interval=checkout_data["billing_interval"],
        payment_method=checkout_data["payment_method"],
        pix_qr_code_base64=checkout_data.get("pix_qr_code_base64"),
        pix_copy_paste=checkout_data.get("pix_copy_paste"),
        checkout_url=checkout_data.get("checkout_url"),
        status=checkout_data.get("status", "pending"),
        expires_at=checkout_data["expires_at"],
        notes=checkout_data.get("notes"),
    )


@router.post("/process-card", response_model=CardPaymentResponse, status_code=status.HTTP_410_GONE, deprecated=True)
async def process_card_checkout():
    """
    [DESATIVADO PERMANENTEMENTE / CONFORMIDADE PCI DSS SAQ A]
    Este endpoint foi desativado permanentemente para garantir que o backend
    nunca trafegue, processe ou armazene dados brutos de cartão de crédito (PAN/CVV).
    O fluxo oficial de cartão de crédito ocorre exclusivamente através da página
    hospedada segura do Asaas gerada em POST /checkout-session.
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Endpoint desativado em conformidade estrita com PCI DSS. Utilize o checkout oficial Asaas via POST /checkout-session."
    )


@router.post("/webhook/asaas")
async def webhook_asaas(payload: dict, request: Request):
    """Webhook oficial Asaas para confirmação de Pix recorrente e boleto/cartão.
    Persiste a ativação ou cancelamento da assinatura no Supabase via externalReference.
    Garante idempotência estrita via event_id único para evitar duplicidade de processamento.
    """
    await _verify_payment_webhook("asaas", payload, request)

    # Identificador de evento para garantia de idempotência
    event_id = payload.get("id")
    if not event_id:
        payment_obj = payload.get("payment") or {}
        p_id = payment_obj.get("id") or ""
        evt = payload.get("event") or "UNKNOWN"
        event_id = f"asaas_{evt}_{p_id}" if p_id else None

    # PAY-004: Reivindicação atômica do evento antes de qualquer processamento ou mutação
    if event_id:
        claimed = await supabase_service.claim_webhook_event(
            event_id=event_id,
            provider="asaas",
            event_type=payload.get("event", "UNKNOWN"),
            payload=payload,
        )
        if not claimed:
            import logging as _log
            _log.getLogger(__name__).info(f"[webhook/asaas] Evento duplicado ou sob concorrência ignorado com sucesso: {event_id}")
            return {
                "processed": True,
                "provider": "asaas",
                "idempotent": True,
                "event_id": event_id,
                "message": f"Evento {event_id} já processado anteriormente. Ignorando duplicata com segurança.",
            }

    result = PaymentProviderService.process_webhook("asaas", payload)

    # Recuperar metadados da sessão pelo externalReference presente no payload (Supabase primeiro, fallback memória)
    ext_ref = (
        (payload.get("payment") or {}).get("externalReference")
        or payload.get("externalReference")
    )
    order_meta = (
        (await supabase_service.get_checkout_session(ext_ref))
        or PaymentProviderService._PENDING_ORDERS.get(ext_ref or "", {})
    ) if ext_ref else {}

    subscription_status = result.get("subscription_status", "pending")
    trainer_id = order_meta.get("trainer_id") or result.get("trainer_id") or ""
    plan_id = order_meta.get("plan_id") or result.get("plan_id") or ""
    billing_interval = order_meta.get("billing_interval") or result.get("billing_interval") or "monthly"

    # Persistir no Supabase apenas se houver dados suficientes para identificar o treinador e plano
    action_persisted = False
    if trainer_id and trainer_id not in ("current-trainer", "") and plan_id:
        if subscription_status == "active":
            await supabase_service.activate_subscription(
                trainer_id=trainer_id,
                plan_id=plan_id,
                billing_interval=billing_interval,
                payment_method="pix",
            )
            action_persisted = True
        elif subscription_status in ("canceled", "past_due"):
            await supabase_service.update_subscription_status(
                trainer_id=trainer_id,
                new_status=subscription_status,
            )
            action_persisted = True
    else:
        import logging as _log
        _log.getLogger(__name__).warning(
            f"[webhook/asaas] Evento '{result.get('event')}' sem metadados suficientes "
            f"para persistir (trainer_id={trainer_id!r}, plan_id={plan_id!r}, ext_ref={ext_ref!r}). "
            "Liberando claim atômico para permitir retry legítimo do gateway."
        )
        if event_id:
            await supabase_service.release_webhook_claim(event_id)

    # PAY-004: Consolida o evento como concluído com sucesso
    if event_id and action_persisted:
        await supabase_service.record_processed_event(
            event_id=event_id,
            provider="asaas",
            event_type=payload.get("event", "UNKNOWN"),
            payload=payload,
        )

    return result


@router.post("/webhook/mercadopago")
async def webhook_mercadopago(payload: dict, request: Request):
    """Webhook oficial Mercado Pago para IPN / Notificações de pagamentos."""
    await _verify_payment_webhook("mercadopago", payload, request)
    return PaymentProviderService.process_webhook("mercadopago", payload)


@router.post("/webhook/infinitepay")
async def webhook_infinitepay(payload: dict, request: Request):
    """Webhook oficial InfinitePay para aprovações instantâneas de Pix e Smart Checkout.
    Garante idempotência estrita via nsu/slug único.
    """
    await _verify_payment_webhook("infinitepay", payload, request)

    order_nsu = payload.get("order_nsu") or payload.get("order_id") or payload.get("nsu") or payload.get("slug") or ""
    evt = payload.get("event") or payload.get("status") or "UNKNOWN"
    event_id = f"infinitepay_{evt}_{order_nsu}" if order_nsu else None

    if event_id:
        claimed = await supabase_service.claim_webhook_event(
            event_id=event_id,
            provider="infinitepay",
            event_type=str(evt),
            payload=payload,
        )
        if not claimed:
            return {
                "processed": True,
                "provider": "infinitepay",
                "idempotent": True,
                "event_id": event_id,
                "message": f"Evento {event_id} já processado anteriormente.",
            }

    result = PaymentProviderService.process_webhook("infinitepay", payload)
    if result.get("subscription_status") == "active":
        trainer_id = result.get("trainer_id") or "current-trainer"
        plan_id = result.get("plan_id") or "pro"
        billing_interval = result.get("billing_interval") or "monthly"
        await supabase_service.activate_subscription(
            trainer_id=trainer_id,
            plan_id=plan_id,
            billing_interval=billing_interval,
            payment_method="infinitepay"
        )

    if event_id:
        await supabase_service.record_processed_event(
            event_id=event_id,
            provider="infinitepay",
            event_type=str(evt),
            payload=payload,
        )

    return result


@router.get("/check-status/{order_nsu}")
async def check_payment_status(
    order_nsu: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Consulta o status da transação no Asaas, InfinitePay ou gateway associado.
    Requer autenticação JWT. Em produção, valida que o treinador autenticado é o
    proprietário da sessão antes de ativar qualquer assinatura.
    Recupera metadados duráveis do Supabase (PAY-003).
    """
    auth_trainer_id = current_user.get("sub") or current_user.get("id")

    is_paid = PaymentProviderService.check_payment(order_nsu)
    order_meta = (await supabase_service.get_checkout_session(order_nsu)) or PaymentProviderService._PENDING_ORDERS.get(order_nsu, {})

    if is_paid and order_meta:
        session_trainer_id = str(order_meta.get("trainer_id", ""))

        # Em produção: rejeitar se o trainer autenticado não é dono da sessão
        if settings.ENVIRONMENT.lower() == "production":
            if not auth_trainer_id or auth_trainer_id == "current-trainer":
                raise HTTPException(status_code=401, detail="Usuário não autenticado.")
            if session_trainer_id and session_trainer_id not in ("current-trainer", "") \
                    and session_trainer_id != auth_trainer_id:
                raise HTTPException(
                    status_code=403,
                    detail="Acesso negado: esta sessão de checkout pertence a outro treinador.",
                )
            # Usar sempre o trainer autenticado como fonte confiável
            effective_trainer_id = auth_trainer_id
        else:
            effective_trainer_id = session_trainer_id or auth_trainer_id or "current-trainer"

        plan_id = order_meta.get("plan_id", "pro")
        billing_interval = order_meta.get("billing_interval", "monthly")
        payment_method = order_meta.get("payment_method", "pix")

        # Não ativar com defaults genéricos — se plano/ciclo ausentes, falhar fechado
        if not order_meta.get("plan_id") or not order_meta.get("billing_interval"):
            raise HTTPException(
                status_code=422,
                detail="Metadados da sessão incompletos — não é possível ativar assinatura com segurança. Inicie um novo checkout.",
            )

        await supabase_service.activate_subscription(
            trainer_id=effective_trainer_id,
            plan_id=plan_id,
            billing_interval=billing_interval,
            payment_method=payment_method,
        )

    return {
        "order_nsu": order_nsu,
        "paid": is_paid,
        "plan_id": order_meta.get("plan_id"),
        "trainer_id": order_meta.get("trainer_id"),
    }


@router.post("/webhook/stripe")
async def webhook_stripe(payload: dict, request: Request):
    """Webhook oficial Stripe Billing para eventos de Checkout e Ciclo de Vida da Assinatura."""
    await _verify_payment_webhook("stripe", payload, request)
    return PaymentProviderService.process_webhook("stripe", payload)


@router.post("/webhook")
async def handle_payment_webhook(payload: dict, request: Request):
    """
    Webhook universal unificado para receber notificações automáticas do Asaas,
    Mercado Pago, InfinitePay ou Stripe.
    """
    provider = payload.get("provider", "universal")
    await _verify_payment_webhook(provider, payload, request)
    return PaymentProviderService.process_webhook(provider, payload)
