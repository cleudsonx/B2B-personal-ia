# backend/tests/test_wallet_splits_cockpit.py
# FASE 6: Testes do Cockpit Financeiro do Treinador (Extrato de Splits em Tempo Real e KPIs BCB 4.893)

import pytest
from datetime import datetime, timezone
from app.services.wallet_service import WalletService, PLATFORM_FEE_PERCENT
from app.schemas.wallet import WalletSplitsCockpitResponse, WalletSummaryResponse


@pytest.mark.asyncio
async def test_wallet_summary_kpis_calculation():
    """Valida o cálculo exato de splits 95/5 e KPIs no resumo da carteira."""
    trainer_id = "trainer-cockpit-test-01"
    
    # Limpa estado anterior em memória
    WalletService._mem_wallets[trainer_id] = {
        "balance_cents": 9500,
        "pending_balance_cents": 19000,
        "pix_key": "12345678900",
        "pix_key_type": "cpf",
        "bank_name": "Nubank",
        "asaas_wallet_id": "wlt_trainer_test_01",
    }
    WalletService._mem_invoices = [
        inv for inv in WalletService._mem_invoices if inv.get("trainer_id") != trainer_id
    ]

    now_iso = datetime.now(timezone.utc).isoformat()

    # Fatura 1: Liquidada (R$ 100,00 -> R$ 95,00 personal, R$ 5,00 plataforma)
    WalletService._mem_invoices.append({
        "id": "inv-settled-01",
        "trainer_id": trainer_id,
        "student_name": "Carlos Atleta",
        "title": "Consultoria Mensal Musculação",
        "amount_cents": 10000,
        "platform_fee_cents": 500,
        "net_amount_cents": 9500,
        "status": "paid",
        "split_status": "settled",
        "payment_method": "pix",
        "paid_at": now_iso,
        "due_date": "2026-11-10",
        "created_at": now_iso,
        "asaas_payment_id": "pay_test_pix_01",
        "asaas_wallet_id": "wlt_trainer_test_01",
        "jws_split_token": "eyJhbGciOiJSUzI1NiJ9.simulated.signature",
    })

    # Fatura 2: Pendente (R$ 200,00 -> R$ 190,00 personal, R$ 10,00 plataforma)
    WalletService._mem_invoices.append({
        "id": "inv-pending-02",
        "trainer_id": trainer_id,
        "student_name": "Mariana Fitness",
        "title": "Consultoria Trimestral Hipertrofia",
        "amount_cents": 20000,
        "platform_fee_cents": 1000,
        "net_amount_cents": 19000,
        "status": "pending",
        "split_status": "pending",
        "payment_method": "credit_card",
        "paid_at": None,
        "due_date": "2026-11-15",
        "created_at": now_iso,
        "asaas_payment_id": "pay_test_cc_02",
        "asaas_wallet_id": "wlt_trainer_test_01",
        "jws_split_token": "eyJhbGciOiJSUzI1NiJ9.simulated.signature2",
    })

    summary: WalletSummaryResponse = await WalletService.get_summary(trainer_id)

    # Asserções de conformidade de valores e splits
    assert summary.total_splits_count == 2
    assert summary.settled_splits_count == 1
    assert summary.pending_splits_count == 1

    assert summary.settled_gross_cents == 10000
    assert summary.settled_net_cents == 9500
    assert summary.settled_fee_cents == 500

    assert summary.pending_gross_cents == 20000
    assert summary.pending_net_cents == 19000

    assert summary.balance_cents == 9500
    assert summary.total_billed_month_cents == 9500
    assert summary.asaas_wallet_id == "wlt_trainer_test_01"
    assert summary.asaas_account_status == "active"


@pytest.mark.asyncio
async def test_wallet_splits_cockpit_full_payload():
    """Valida o payload unificado retornado para a tela do Cockpit do Treinador."""
    trainer_id = "trainer-cockpit-test-02"

    WalletService._mem_wallets[trainer_id] = {
        "balance_cents": 28500,
        "pix_key": "cleudson@shapelab.ia.br",
        "pix_key_type": "email",
        "asaas_wallet_id": "wlt_cleudson_pro",
    }
    WalletService._mem_invoices = [
        inv for inv in WalletService._mem_invoices if inv.get("trainer_id") != trainer_id
    ]

    now_iso = datetime.now(timezone.utc).isoformat()

    WalletService._mem_invoices.append({
        "id": "inv-split-03",
        "trainer_id": trainer_id,
        "student_name": "Juliana Santos",
        "title": "Acompanhamento Nutricional + Treino",
        "amount_cents": 30000,
        "platform_fee_cents": 1500,
        "net_amount_cents": 28500,
        "status": "paid",
        "split_status": "settled",
        "payment_method": "pix",
        "paid_at": now_iso,
        "due_date": "2026-11-20",
        "created_at": now_iso,
        "asaas_payment_id": "pay_asaas_987",
        "asaas_wallet_id": "wlt_cleudson_pro",
        "jws_split_token": "eyJhbGciOiJSUzI1NiJ9.test.sig",
    })

    cockpit: WalletSplitsCockpitResponse = await WalletService.get_splits_cockpit(trainer_id)

    assert cockpit.summary.balance_cents == 28500
    assert cockpit.summary.settled_net_cents == 28500
    assert cockpit.summary.settled_fee_cents == 1500
    assert cockpit.summary.asaas_wallet_id == "wlt_cleudson_pro"
    assert cockpit.summary.asaas_account_status == "active"

    assert len(cockpit.items) >= 1
    target_item = next(i for i in cockpit.items if i.id == "inv-split-03")
    assert target_item.student_name == "Juliana Santos"
    assert target_item.amount_cents == 30000
    assert target_item.net_amount_cents == 28500
    assert target_item.platform_fee_cents == 1500
    assert target_item.split_status == "settled"
    assert target_item.asaas_wallet_id == "wlt_cleudson_pro"
    assert target_item.jws_split_token is not None
