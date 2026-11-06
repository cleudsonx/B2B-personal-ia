# app/schemas/wallet.py
# FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Cobranças de Alunos)

from typing import Optional, List
from datetime import date, datetime
from pydantic import BaseModel, Field


class WalletSummaryResponse(BaseModel):
    balance_cents: int = Field(default=0, description="Saldo disponível para saque em centavos")
    pending_balance_cents: int = Field(default=0, description="Saldo a receber de faturas pendentes")
    total_billed_month_cents: int = Field(default=0, description="Total faturado no mês corrente")
    pix_key: Optional[str] = Field(default=None, description="Chave Pix cadastrada para repasse")
    pix_key_type: Optional[str] = Field(default="cpf", description="Tipo de chave Pix")
    bank_name: Optional[str] = Field(default=None, description="Instituição bancária do treinador")
    asaas_account_id: Optional[str] = Field(default=None, description="ID da subconta no Asaas")
    asaas_wallet_id: Optional[str] = Field(default=None, description="Wallet ID da subconta Asaas para split direto")
    asaas_account_status: Optional[str] = Field(default="unlinked", description="Status da conta no Asaas (active, pending, unlinked)")
    # Métricas analíticas do Cockpit de Splits (Resolução BCB nº 4.893 & Asaas 95/5)
    total_splits_count: int = Field(default=0, description="Total de transações de split geradas")
    settled_splits_count: int = Field(default=0, description="Transações de split liquidadas com sucesso")
    pending_splits_count: int = Field(default=0, description="Transações de split aguardando compensação")
    settled_gross_cents: int = Field(default=0, description="Total bruto liquidado de planos (100%) em centavos")
    settled_net_cents: int = Field(default=0, description="Total líquido liquidado do treinador (95%) em centavos")
    settled_fee_cents: int = Field(default=0, description="Total de taxa operacional retida pelo SaaS (5%) em centavos")
    pending_gross_cents: int = Field(default=0, description="Total bruto aguardando pagamento em centavos")
    pending_net_cents: int = Field(default=0, description="Total líquido pendente do treinador (95%) em centavos")


class SetPixKeyRequest(BaseModel):
    pix_key: str = Field(..., min_length=3, description="Chave Pix (CPF, CNPJ, E-mail, Celular ou Chave Aleatória)")
    pix_key_type: str = Field(default="cpf", description="Tipo da chave: cpf, cnpj, email, phone, random")
    bank_name: Optional[str] = Field(default=None, description="Nome do banco ou instituição")


class CreateInvoiceRequest(BaseModel):
    student_id: Optional[str] = Field(default=None, description="ID do aluno no sistema (se já cadastrado)")
    student_name: str = Field(..., min_length=2, description="Nome completo do aluno")
    student_phone: Optional[str] = Field(default=None, description="WhatsApp do aluno para envio da cobrança")
    student_email: Optional[str] = Field(default=None, description="E-mail do aluno")
    title: str = Field(..., min_length=3, description="Descrição da consultoria (ex: Mensalidade de Treino)")
    description: Optional[str] = Field(default=None, description="Detalhes adicionais do plano")
    amount_cents: int = Field(..., gt=0, description="Valor cobrado em centavos (ex: 15000 para R$ 150,00)")
    due_date: Optional[str] = Field(default=None, description="Data de vencimento (YYYY-MM-DD)")
    send_whatsapp: bool = Field(default=True, description="Se deve disparar notificação automática no WhatsApp")


class StudentInvoiceResponse(BaseModel):
    id: str
    trainer_id: str
    student_id: Optional[str] = None
    student_name: str
    student_phone: Optional[str] = None
    student_email: Optional[str] = None
    title: str
    description: Optional[str] = None
    amount_cents: int
    platform_fee_cents: int
    net_amount_cents: int
    status: str
    due_date: str
    paid_at: Optional[str] = None
    payment_method: str = "pix"
    payment_link: Optional[str] = None
    pix_copy_paste: Optional[str] = None
    asaas_payment_id: Optional[str] = None
    asaas_wallet_id: Optional[str] = None
    jws_split_token: Optional[str] = None
    split_status: Optional[str] = "pending"
    created_at: str


class WithdrawalRequest(BaseModel):
    amount_cents: int = Field(..., gt=0, description="Valor do saque em centavos")


class WithdrawalResponse(BaseModel):
    id: str
    trainer_id: str
    amount_cents: int
    pix_key: str
    status: str
    created_at: str
    message: str


class WalletSplitsCockpitResponse(BaseModel):
    summary: WalletSummaryResponse
    items: List[StudentInvoiceResponse]


