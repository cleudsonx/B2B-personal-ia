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
