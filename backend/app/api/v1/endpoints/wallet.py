# app/api/v1/endpoints/wallet.py
# FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Cobrança de Alunos)

import logging
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from app.api.deps import get_current_trainer
from app.schemas.wallet import (
    WalletSummaryResponse,
    SetPixKeyRequest,
    CreateInvoiceRequest,
    StudentInvoiceResponse,
    WithdrawalRequest,
    WithdrawalResponse,
    WalletSplitsCockpitResponse,
)
from app.services.wallet_service import wallet_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/summary", response_model=WalletSummaryResponse)
async def get_wallet_summary(
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """Retorna saldo disponível, pendente, faturado no mês e dados Pix do Personal Trainer."""
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    return await wallet_service.get_summary(trainer_id)


@router.get("/splits", response_model=WalletSplitsCockpitResponse)
async def get_splits_cockpit(
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Retorna visão unificada do Cockpit Financeiro do Treinador:
    - KPIs analíticos de Split 95/5 (total bruto, líquido 95%, taxa retida 5%, saldo pendente vs liberado).
    - Status de conformidade bancária Asaas e Resolução BCB nº 4.893 (JWS).
    - Extrato cronológico detalhado de faturas e splits.
    """
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    return await wallet_service.get_splits_cockpit(trainer_id)


@router.put("/pix-key", response_model=WalletSummaryResponse)
async def update_pix_key(
    req: SetPixKeyRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """Cadastra ou atualiza a chave Pix do treinador para recebimento de saques."""
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    return await wallet_service.update_pix_key(trainer_id, req)


@router.get("/invoices", response_model=List[StudentInvoiceResponse])
async def list_student_invoices(
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """Lista todas as faturas e cobranças geradas para os alunos."""
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    return await wallet_service.list_invoices(trainer_id)


@router.post("/invoices", response_model=StudentInvoiceResponse, status_code=status.HTTP_201_CREATED)
async def create_student_invoice(
    req: CreateInvoiceRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Gera uma cobrança com Pix copia-e-cola e link de pagamento para um aluno.
    Dispara notificação automática no WhatsApp do aluno se configurado.
    """
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    trainer_name = current_user.get("full_name") or current_user.get("user_metadata", {}).get("full_name") or "Personal"
    return await wallet_service.create_invoice(trainer_id, trainer_name, req)


@router.post("/invoices/{invoice_id}/mark-paid", response_model=StudentInvoiceResponse)
async def mark_invoice_as_paid(
    invoice_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Marca manualmente uma fatura como PAGA (ex: recebimento em dinheiro ou confirmação externa).
    Transfere o valor líquido para o saldo disponível na carteira do treinador.
    """
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    try:
        return await wallet_service.mark_paid(trainer_id, invoice_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/withdraw", response_model=WithdrawalResponse)
async def request_wallet_withdrawal(
    req: WithdrawalRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """Solicita saque do saldo disponível da carteira para a chave Pix cadastrada."""
    trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    try:
        return await wallet_service.request_withdrawal(trainer_id, req.amount_cents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

