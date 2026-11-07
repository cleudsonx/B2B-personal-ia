# backend/tests/test_wallet.py
# Testes da FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Cobrança de Alunos)

import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock
from app.main import app
from app.api.deps import get_current_trainer
from app.services.wallet_service import WalletService

client = TestClient(app)

MOCK_TRAINER = {
    "id": "11111111-2222-3333-4444-555555555555",
    "sub": "11111111-2222-3333-4444-555555555555",
    "email": "personal.pro@shaipados.com",
    "full_name": "Personal Pro",
    "role": "trainer",
}


@pytest.fixture(autouse=True)
def override_auth_and_clean_wallet():
    app.dependency_overrides[get_current_trainer] = lambda: MOCK_TRAINER
    # Limpa estado em memória
    WalletService._mem_wallets.clear()
    WalletService._mem_invoices.clear()
    WalletService._mem_withdrawals.clear()
    yield
    app.dependency_overrides.pop(get_current_trainer, None)


def test_wallet_initial_summary():
    """Valida consulta de resumo inicial da carteira com saldo zero."""
    res = client.get("/api/v1/wallet/summary")
    assert res.status_code == 200
    data = res.json()
    assert data["balance_cents"] == 0
    assert data["pending_balance_cents"] == 0
    assert data["total_billed_month_cents"] == 0


def test_update_pix_key():
    """Valida cadastro de chave Pix para repasse."""
    res = client.put(
        "/api/v1/wallet/pix-key",
        json={
            "pix_key": "123.456.789-00",
            "pix_key_type": "cpf",
            "bank_name": "Nubank",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["pix_key"] == "123.456.789-00"
    assert data["pix_key_type"] == "cpf"
    assert data["bank_name"] == "Nubank"


@patch("app.services.whatsapp_service.whatsapp_service.send_text_with_fallback", new_callable=AsyncMock)
def test_create_student_invoice_and_split(mock_whatsapp):
    """Valida emissão de fatura para aluno com cálculo de split (5% plataforma / 95% personal)."""
    mock_whatsapp.return_value = True

    res = client.post(
        "/api/v1/wallet/invoices",
        json={
            "student_name": "Carlos Aluno",
            "student_phone": "5511999998888",
            "title": "Consultoria Mensal de Musculação",
            "amount_cents": 20000,  # R$ 200,00
            "send_whatsapp": True,
        },
    )
    assert res.status_code == 201
    data = res.json()
    assert data["amount_cents"] == 20000
    assert data["platform_fee_cents"] == 1000  # 5% de R$ 200 = R$ 10
    assert data["net_amount_cents"] == 19000   # 95% = R$ 190
    assert data["status"] == "pending"
    assert "https://shaipados-labs.web.app/pay/" in data["payment_link"]
    assert "00020126" in data["pix_copy_paste"]

    # Verifica saldo pendente no resumo da carteira
    summary = client.get("/api/v1/wallet/summary").json()
    assert summary["pending_balance_cents"] == 19000
    assert summary["balance_cents"] == 0


def test_mark_invoice_paid_and_credit_balance():
    """Valida pagamento de fatura e crédito de saldo na carteira."""
    # 1. Cria fatura de R$ 100
    create_res = client.post(
        "/api/v1/wallet/invoices",
        json={
            "student_name": "Mariana Silva",
            "title": "Acompanhamento Semanal",
            "amount_cents": 10000,
            "send_whatsapp": False,
        },
    )
    inv_id = create_res.json()["id"]

    # 2. Marca como paga
    pay_res = client.post(f"/api/v1/wallet/invoices/{inv_id}/mark-paid")
    assert pay_res.status_code == 200
    assert pay_res.json()["status"] == "paid"
    assert pay_res.json()["paid_at"] is not None

    # 3. Resumo da carteira deve refletir R$ 95 disponíveis (após taxa de 5%)
    summary = client.get("/api/v1/wallet/summary").json()
    assert summary["balance_cents"] == 9500
    assert summary["pending_balance_cents"] == 0
    assert summary["total_billed_month_cents"] == 9500


def test_withdrawal_flow():
    """Valida fluxo de saque Pix: bloqueio por saldo insuficiente e sucesso com saldo disponível."""
    # Cadastra chave Pix
    client.put(
        "/api/v1/wallet/pix-key",
        json={"pix_key": "treinador@gmail.com", "pix_key_type": "email"},
    )

    # Tentativa com saldo zero -> 400
    fail_res = client.post("/api/v1/wallet/withdraw", json={"amount_cents": 5000})
    assert fail_res.status_code == 400
    assert "insuficiente" in fail_res.json()["detail"].lower()

    # Cria e paga fatura de R$ 300 (líquido R$ 285 = 28500 cents)
    c_res = client.post(
        "/api/v1/wallet/invoices",
        json={"student_name": "Aluno Premium", "title": "Plano Trimestral", "amount_cents": 30000, "send_whatsapp": False},
    )
    client.post(f"/api/v1/wallet/invoices/{c_res.json()['id']}/mark-paid")

    # Solicita saque de R$ 200 (20000 cents)
    withdraw_res = client.post("/api/v1/wallet/withdraw", json={"amount_cents": 20000})
    assert withdraw_res.status_code == 200
    assert withdraw_res.json()["status"] == "completed"
    assert withdraw_res.json()["amount_cents"] == 20000

    # Saldo remanescente deve ser R$ 85 (8500 cents)
    summary = client.get("/api/v1/wallet/summary").json()
    assert summary["balance_cents"] == 8500

