import uuid
from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, HTTPException, Depends, Request
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
async def get_my_subscription(trainer_id: str = "current-trainer"):
    """
    Retorna o plano ativo e consumo de cotas do Personal Trainer autenticado.
    Busca no Supabase com contagem real de alunos ocupando vagas na assessoria.
    """
    return await supabase_service.get_trainer_subscription(trainer_id)


@router.post("/activate-plan", response_model=MySubscriptionResponse)
async def activate_subscription_plan(req: PlanActivationRequest):
    """
    Ativa ou troca o plano do Personal Trainer imediatamente, persistindo no Supabase.
    Atualiza cotas de alunos, limite de gerações IA e periodicidade.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == req.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail=f"Plano '{req.plan_id}' não encontrado.")

    trainer_id = req.trainer_id or "current-trainer"
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
async def create_checkout_session(request: CheckoutSessionRequest):
    """
    Gera uma sessão de checkout para assinatura do plano escolhido via Pix ou Cartão.
    Suporta múltiplos gateways: Asaas, Mercado Pago, InfinitePay e Stripe.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == request.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail="Plano não encontrado.")

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
        trainer_id=request.trainer_id or "current-trainer"
    )

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
        notes=checkout_data.get("notes")
    )


@router.post("/process-card", response_model=CardPaymentResponse)
async def process_card_checkout(request: CardPaymentRequest):
    """
    Processa pagamento transparente com cartão de crédito in-app via Asaas.
    Ativa a assinatura instantaneamente no Supabase após a confirmação.
    """
    result = PaymentProviderService.process_card_payment(
        session_id=request.session_id,
        card_holder_name=request.card_holder_name,
        card_number=request.card_number,
        expiry_month=request.expiry_month,
        expiry_year=request.expiry_year,
        ccv=request.ccv,
        installments=request.installments or 1,
    )
    if result.get("success"):
        order_meta = PaymentProviderService._PENDING_ORDERS.get(request.session_id, {})
        trainer_id = request.trainer_id or order_meta.get("trainer_id", "current-trainer")
        plan_id = order_meta.get("plan_id", "pro")
        billing_interval = order_meta.get("billing_interval", "monthly")
        await supabase_service.activate_subscription(
            trainer_id=trainer_id,
            plan_id=plan_id,
            billing_interval=billing_interval,
            payment_method="credit_card",
        )
    return CardPaymentResponse(**result)


@router.post("/webhook/asaas")
async def webhook_asaas(payload: dict, request: Request):
    """Webhook oficial Asaas para confirmação de Pix recorrente e boleto/cartão."""
    await _verify_payment_webhook("asaas", payload, request)
    return PaymentProviderService.process_webhook("asaas", payload)


@router.post("/webhook/mercadopago")
async def webhook_mercadopago(payload: dict, request: Request):
    """Webhook oficial Mercado Pago para IPN / Notificações de pagamentos."""
    await _verify_payment_webhook("mercadopago", payload, request)
    return PaymentProviderService.process_webhook("mercadopago", payload)


@router.post("/webhook/infinitepay")
async def webhook_infinitepay(payload: dict, request: Request):
    """Webhook oficial InfinitePay para aprovações instantâneas de Pix e Smart Checkout."""
    await _verify_payment_webhook("infinitepay", payload, request)
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
    return result


@router.get("/check-status/{order_nsu}")
async def check_payment_status(order_nsu: str):
    """Consulta o status da transação no Asaas, InfinitePay ou gateway associado."""
    is_paid = PaymentProviderService.check_payment(order_nsu)
    order_meta = PaymentProviderService._PENDING_ORDERS.get(order_nsu, {})
    if is_paid and order_meta:
        trainer_id = order_meta.get("trainer_id", "current-trainer")
        plan_id = order_meta.get("plan_id", "pro")
        billing_interval = order_meta.get("billing_interval", "monthly")
        payment_method = order_meta.get("payment_method", "pix")
        await supabase_service.activate_subscription(
            trainer_id=trainer_id,
            plan_id=plan_id,
            billing_interval=billing_interval,
            payment_method=payment_method
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
