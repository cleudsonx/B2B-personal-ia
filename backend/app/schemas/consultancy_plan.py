# backend/app/schemas/consultancy_plan.py
from datetime import datetime
from typing import List, Optional, Literal
from pydantic import BaseModel, Field


BillingPeriod = Literal["monthly", "quarterly", "semiannual", "annual", "one_time"]


class ConsultancyPlanCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=100, description="Nome do plano ou consultoria")
    description: Optional[str] = Field(None, max_length=500, description="Descrição detalhada dos benefícios")
    price_cents: int = Field(..., ge=1000, description="Preço em centavos (mínimo R$ 10,00 = 1000)")
    billing_period: BillingPeriod = Field("monthly", description="Periodicidade de cobrança")
    features: List[str] = Field(default_factory=list, description="Lista de diferenciais / itens inclusos")
    is_active: bool = Field(True, description="Se o plano está visível para contratação na vitrine")
    sort_order: int = Field(0, description="Ordem de exibição na vitrine")


class ConsultancyPlanUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price_cents: Optional[int] = Field(None, ge=1000)
    billing_period: Optional[BillingPeriod] = None
    features: Optional[List[str]] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


class ConsultancyPlanResponse(BaseModel):
    id: str
    trainer_id: str
    name: str
    description: Optional[str] = None
    price_cents: int
    billing_period: str
    features: List[str] = Field(default_factory=list)
    is_active: bool
    sort_order: int
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class PublicCreditCardInfo(BaseModel):
    holder_name: str = Field(..., min_length=3)
    number: str = Field(..., min_length=13, max_length=19)
    expiry_month: str = Field(..., min_length=1, max_length=2)
    expiry_year: str = Field(..., min_length=2, max_length=4)
    ccv: str = Field(..., min_length=3, max_length=4)
    holder_cpf: str = Field(..., min_length=11)
    postal_code: Optional[str] = "70000-000"
    address_number: Optional[str] = "1"


class PublicCheckoutRequest(BaseModel):
    plan_id: str = Field(..., description="ID do plano escolhido")
    student_name: str = Field(..., min_length=3, description="Nome completo do aluno")
    student_email: str = Field(..., description="E-mail para acesso ao app")
    student_phone: str = Field(..., min_length=10, description="WhatsApp do aluno com DDD")
    student_cpf: Optional[str] = Field(None, description="CPF do aluno para emissão de nota/Pix")
    payment_method: Literal["PIX", "CREDIT_CARD"] = Field("PIX", description="Método de pagamento")
    credit_card: Optional[PublicCreditCardInfo] = Field(None, description="Dados do cartão caso payment_method seja CREDIT_CARD")


class PublicCheckoutResponse(BaseModel):
    invoice_id: str
    status: str
    payment_method: str
    amount_cents: int
    net_amount_cents: int
    platform_fee_cents: int
    pix_copy_paste: Optional[str] = None
    pix_qr_code_base64: Optional[str] = None
    checkout_url: Optional[str] = None
    expires_at: Optional[str] = None
    message: str
    trainer_name: str
    plan_name: str

