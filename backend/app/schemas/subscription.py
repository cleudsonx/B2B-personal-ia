from typing import List, Optional
from pydantic import BaseModel, Field


class PlanFeature(BaseModel):
    title: str
    included: bool = True
    highlight: bool = False


class PlanResponse(BaseModel):
    id: str = Field(..., description="Identificador único do plano (ex: 'starter', 'pro', 'studio')")
    name: str = Field(..., description="Nome comercial do plano")
    tagline: str = Field(..., description="Subtítulo persuasivo")
    price_monthly_cents: int = Field(..., description="Preço mensal em centavos (ex: 8900 = R$ 89,00)")
    price_yearly_cents: int = Field(..., description="Preço anual total em centavos")
    price_yearly_monthly_equivalent_cents: int = Field(..., description="Equivalente mensal no plano anual com 20% OFF")
    max_students: int = Field(..., description="Limite de alunos cadastrados simultâneos")
    max_ai_generations_per_month: int = Field(..., description="Limite de prescrições IA por mês (-1 para ilimitado)")
    is_popular: bool = False
    badge: Optional[str] = None
    features: List[PlanFeature]


class MySubscriptionResponse(BaseModel):
    plan_id: str
    plan_name: str
    status: str = Field(..., description="'active', 'trialing', 'past_due', 'canceled'")
    billing_interval: str = Field("monthly", description="'monthly' ou 'yearly'")
    current_students: int
    max_students: int
    ai_generations_used: int
    max_ai_generations: int
    trial_days_remaining: Optional[int] = None
    next_billing_date: Optional[str] = None
    payment_method: Optional[str] = "pix"
    can_create_student: bool = True
    can_generate_ai: bool = True


class CheckoutSessionRequest(BaseModel):
    plan_id: str = Field(..., description="ID do plano escolhido ('starter', 'pro', 'studio')")
    billing_interval: str = Field("monthly", description="'monthly' ou 'yearly'")
    payment_method: str = Field("pix", description="'pix' ou 'credit_card'")
    provider: Optional[str] = Field("asaas", description="Provedor de pagamento: 'asaas', 'mercadopago', 'infinitepay', 'stripe'")
    trainer_name: Optional[str] = "Personal Trainer"
    trainer_email: Optional[str] = "treinador@demo.com"
    trainer_id: Optional[str] = "current-trainer"


class CheckoutSessionResponse(BaseModel):
    session_id: str
    provider: Optional[str] = "asaas"
    plan_id: str
    plan_name: str
    amount_cents: int
    billing_interval: str
    payment_method: str
    pix_qr_code_base64: Optional[str] = None
    pix_copy_paste: Optional[str] = None
    checkout_url: Optional[str] = None
    status: str = "pending"
    expires_at: str
    notes: Optional[str] = None


class PlanChangeSimulationRequest(BaseModel):
    current_plan_id: str = Field(..., description="ID do plano atual ('starter', 'pro', 'studio')")
    new_plan_id: str = Field(..., description="ID do novo plano desejado")
    billing_interval: str = Field("monthly", description="'monthly' ou 'yearly'")
    days_used_in_cycle: int = Field(0, description="Dias decorridos no ciclo de faturamento atual", ge=0)
    total_days_in_cycle: int = Field(30, description="Duração total do ciclo (30 ou 365 dias)", gt=0)
    active_students_count: int = Field(0, description="Quantidade atual de alunos ativos do treinador", ge=0)


class PlanChangeSimulationResponse(BaseModel):
    change_type: str = Field(..., description="'upgrade', 'downgrade' ou 'same'")
    is_blocked: bool = Field(False, description="True se o downgrade for bloqueado por excesso de alunos ativos")
    block_reason: Optional[str] = Field(None, description="Motivo do bloqueio se is_blocked=True")
    current_plan_name: str
    new_plan_name: str
    current_plan_price_cents: int
    new_plan_price_cents: int
    unused_credit_cents: int = Field(0, description="Crédito residual pró-rata do plano anterior")
    net_charge_cents: int = Field(0, description="Valor líquido a pagar agora no caso de upgrade")
    effective_date: str = Field(..., description="Data em que a mudança entra em vigor ('Imediato' ou 'Fim do ciclo')")
    new_student_limit: int
    new_ai_limit: int
    summary_message: str


class PlanActivationRequest(BaseModel):
    plan_id: str = Field(..., description="ID do plano escolhido ('starter', 'pro', 'elite', 'studio')")
    billing_interval: str = Field("monthly", description="'monthly' ou 'yearly'")
    payment_method: Optional[str] = "pix"
    trainer_id: Optional[str] = "current-trainer"


class CardPaymentRequest(BaseModel):
    """
    [DESCONTINUADO / PCI DSS]
    Schema descontinuado. O backend não aceita nem processa dados brutos de cartão (PAN/CVV)
    em conformidade com o escopo PCI DSS SAQ A.
    """
    session_id: Optional[str] = Field(None, description="ID da sessão de checkout (opcional)")


class CardPaymentResponse(BaseModel):
    """
    Resposta padrão indicando desativação do processamento in-app de cartão.
    """
    success: bool = False
    session_id: Optional[str] = None
    status: str = "deprecated"
    message: str = (
        "Endpoint desativado em conformidade estrita com PCI DSS. "
        "Utilize o checkout oficial Asaas via POST /checkout-session."
    )
    plan_id: Optional[str] = None
    trainer_id: Optional[str] = None
    billing_interval: Optional[str] = "monthly"

