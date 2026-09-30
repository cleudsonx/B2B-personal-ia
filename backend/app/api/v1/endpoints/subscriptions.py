import uuid
from datetime import datetime, timedelta
from typing import List
from fastapi import APIRouter, HTTPException, Depends
from app.schemas.subscription import (
    PlanResponse,
    PlanFeature,
    MySubscriptionResponse,
    CheckoutSessionRequest,
    CheckoutSessionResponse,
    PlanChangeSimulationRequest,
    PlanChangeSimulationResponse,
    PlanActivationRequest,
)
from app.services.payment_service import PaymentProviderService

router = APIRouter()

# Armazenamento em memória das assinaturas ativas por treinador (para demo e sincronização em tempo real)
ACTIVE_TRAINER_SUBSCRIPTIONS = {}

# Tabela estática de planos conforme o Plano de Negócios B2B Personal IA
SAAS_PLANS: List[PlanResponse] = [
    PlanResponse(
        id="starter",
        name="Starter Trial",
        tagline="Degustação completa para começar sua consultoria com IA",
        price_monthly_cents=0,
        price_yearly_cents=0,
        price_yearly_monthly_equivalent_cents=0,
        max_students=3,
        max_ai_generations_per_month=10,
        is_popular=False,
        badge="GRATUITO",
        features=[
            PlanFeature(title="Até 3 alunos ativos simultâneos", included=True, highlight=False),
            PlanFeature(title="10 fichas geradas por IA com Gemini 3.5", included=True, highlight=False),
            PlanFeature(title="Adaptação de exercícios por dor ou aparelho ocupado", included=True, highlight=False),
            PlanFeature(title="Raio-X Anatômico e Split-View para o aluno", included=True, highlight=False),
            PlanFeature(title="Suporte comunitário", included=True, highlight=False),
            PlanFeature(title="Alunos ilimitados", included=False, highlight=False),
            PlanFeature(title="Alertas automáticos via WhatsApp", included=False, highlight=False),
        ],
    ),
    PlanResponse(
        id="pro",
        name="Personal Pro",
        tagline="O plano definitivo para o Personal Trainer autônomo de alta renda",
        price_monthly_cents=8900,  # R$ 89,00
        price_yearly_cents=85200,  # R$ 852,00 (R$ 71,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=7100,
        max_students=30,
        max_ai_generations_per_month=-1,  # Ilimitado
        is_popular=True,
        badge="MAIS POPULAR",
        features=[
            PlanFeature(title="Até 30 alunos ativos na consultoria", included=True, highlight=True),
            PlanFeature(title="Prescrições IA Ilimitadas (Gemini Flash)", included=True, highlight=True),
            PlanFeature(title="Anamnese clínica profunda com histórico de lesões", included=True, highlight=False),
            PlanFeature(title="Raio-X Muscular com EMG e Análise de Fases", included=True, highlight=True),
            PlanFeature(title="Timer de descanso interativo sincronizado", included=True, highlight=False),
            PlanFeature(title="Painel de alertas de adaptação em tempo real", included=True, highlight=True),
            PlanFeature(title="Suporte prioritário via WhatsApp", included=True, highlight=False),
            PlanFeature(title="Múltiplos personals colaboradores", included=False, highlight=False),
        ],
    ),
    PlanResponse(
        id="elite",
        name="Elite Coach",
        tagline="Consultoria esportiva de alta escala com canal WhatsApp automatizado",
        price_monthly_cents=14900,  # R$ 149,00
        price_yearly_cents=142800,  # R$ 1.428,00 (R$ 119,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=11900,
        max_students=60,
        max_ai_generations_per_month=-1,
        is_popular=False,
        badge="ALTA ESCALA",
        features=[
            PlanFeature(title="Até 60 alunos ativos na consultoria", included=True, highlight=True),
            PlanFeature(title="Prescrições IA Ilimitadas (Gemini Flash)", included=True, highlight=True),
            PlanFeature(title="Automação WhatsApp (Evolution/Z-API): Envio de treinos", included=True, highlight=True),
            PlanFeature(title="Alertas de dor e faltas recorrentes direto no WhatsApp", included=True, highlight=True),
            PlanFeature(title="Raio-X Muscular com EMG e Análise de Fases", included=True, highlight=False),
            PlanFeature(title="Relatórios de assiduidade e retenção de alunos", included=True, highlight=True),
            PlanFeature(title="Suporte prioritário via WhatsApp", included=True, highlight=False),
        ],
    ),
    PlanResponse(
        id="studio",
        name="Studio Scale",
        tagline="Para assessorias esportivas e estúdios que buscam escala máxima",
        price_monthly_cents=19900,  # R$ 199,00
        price_yearly_cents=190800,  # R$ 1.908,00 (R$ 159,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=15900,
        max_students=100,
        max_ai_generations_per_month=-1,
        is_popular=False,
        badge="ESCALA MÁXIMA",
        features=[
            PlanFeature(title="Até 100 alunos ativos na assessoria", included=True, highlight=True),
            PlanFeature(title="Prescrições e adaptações IA Ilimitadas", included=True, highlight=True),
            PlanFeature(title="Múltiplos personals e estagiários sob a mesma conta", included=True, highlight=True),
            PlanFeature(title="Alertas de dor e evasão em tempo real via WhatsApp", included=True, highlight=True),
            PlanFeature(title="Relatórios de assiduidade e retenção de alunos", included=True, highlight=True),
            PlanFeature(title="Personalização com a marca (White-Label parcial)", included=True, highlight=False),
            PlanFeature(title="Gerente de contas dedicado e suporte VIP", included=True, highlight=False),
        ],
    ),
]


@router.get("/plans", response_model=List[PlanResponse])
async def list_subscription_plans():
    """Retorna os planos SaaS disponíveis para contratação."""
    return SAAS_PLANS


@router.get("/my-subscription", response_model=MySubscriptionResponse)
async def get_my_subscription(trainer_id: str = "current-trainer"):
    """
    Retorna o plano ativo e consumo de cotas do Personal Trainer autenticado.
    Se o treinador já ativou um plano, retorna a assinatura ativa correspondente.
    """
    if trainer_id in ACTIVE_TRAINER_SUBSCRIPTIONS:
        return ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id]

    # Default: Personal Pro ativo
    default_sub = MySubscriptionResponse(
        plan_id="pro",
        plan_name="Personal Pro",
        status="active",
        billing_interval="monthly",
        current_students=4,
        max_students=30,
        ai_generations_used=12,
        max_ai_generations=-1,
        trial_days_remaining=None,
        next_billing_date=(datetime.now() + timedelta(days=24)).strftime("%d/%m/%Y"),
        payment_method="pix",
        can_create_student=True,
        can_generate_ai=True,
    )
    ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id] = default_sub
    return default_sub


@router.post("/activate-plan", response_model=MySubscriptionResponse)
async def activate_subscription_plan(req: PlanActivationRequest):
    """
    Ativa ou troca o plano do Personal Trainer imediatamente.
    Atualiza cotas de alunos, limite de gerações IA e periodicidade.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == req.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail=f"Plano '{req.plan_id}' não encontrado.")

    is_trial = selected_plan.id == "starter"
    status_str = "trialing" if is_trial else "active"
    trial_days = 14 if is_trial else None
    days_to_add = 365 if req.billing_interval == "yearly" else 30
    next_date = (datetime.now() + timedelta(days=days_to_add)).strftime("%d/%m/%Y")

    trainer_id = req.trainer_id or "current-trainer"
    current_students = 4
    if trainer_id in ACTIVE_TRAINER_SUBSCRIPTIONS:
        current_students = ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id].current_students

    updated_sub = MySubscriptionResponse(
        plan_id=selected_plan.id,
        plan_name=selected_plan.name,
        status=status_str,
        billing_interval=req.billing_interval,
        current_students=current_students,
        max_students=selected_plan.max_students,
        ai_generations_used=12 if not is_trial else 3,
        max_ai_generations=selected_plan.max_ai_generations_per_month,
        trial_days_remaining=trial_days,
        next_billing_date=next_date,
        payment_method=req.payment_method or "pix",
        can_create_student=current_students < selected_plan.max_students,
        can_generate_ai=True,
    )

    ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id] = updated_sub
    return updated_sub


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
        trainer_email=request.trainer_email or "treinador@demo.com"
    )

    return CheckoutSessionResponse(
        session_id=checkout_data["session_id"],
        provider=checkout_data["provider"],
        plan_id=checkout_data["plan_id"],
        plan_name=checkout_data["plan_name"],
        amount_cents=checkout_data["amount_cents"],
        billing_interval=checkout_data["billing_interval"],
        payment_method=checkout_data["payment_method"],
        pix_copy_paste=checkout_data.get("pix_copy_paste"),
        checkout_url=checkout_data.get("checkout_url"),
        status=checkout_data.get("status", "pending"),
        expires_at=checkout_data["expires_at"],
        notes=checkout_data.get("notes")
    )


@router.post("/webhook/asaas")
async def webhook_asaas(payload: dict):
    """Webhook oficial Asaas para confirmação de Pix recorrente e boleto/cartão."""
    return PaymentProviderService.process_webhook("asaas", payload)


@router.post("/webhook/mercadopago")
async def webhook_mercadopago(payload: dict):
    """Webhook oficial Mercado Pago para IPN / Notificações de pagamentos."""
    return PaymentProviderService.process_webhook("mercadopago", payload)


@router.post("/webhook/infinitepay")
async def webhook_infinitepay(payload: dict):
    """Webhook oficial InfinitePay para aprovações instantâneas de Pix e Smart Checkout."""
    return PaymentProviderService.process_webhook("infinitepay", payload)


@router.post("/webhook/stripe")
async def webhook_stripe(payload: dict):
    """Webhook oficial Stripe Billing para eventos de Checkout e Ciclo de Vida da Assinatura."""
    return PaymentProviderService.process_webhook("stripe", payload)


@router.post("/webhook")
async def handle_payment_webhook(payload: dict):
    """
    Webhook universal unificado para receber notificações automáticas do Asaas,
    Mercado Pago, InfinitePay ou Stripe.
    """
    provider = payload.get("provider", "universal")
    return PaymentProviderService.process_webhook(provider, payload)
