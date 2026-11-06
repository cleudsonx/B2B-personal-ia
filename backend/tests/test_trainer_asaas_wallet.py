# backend/tests/test_trainer_asaas_wallet.py
"""
Testes unitários para Mapeamento de Subcontas Asaas & Carteira do Personal (Bloco 2)
Verifica:
- Provisionamento e resolução de subconta / walletId no Asaas
- Fallback determinístico de wallet para ambiente de testes e sandbox
- Enriquecimento dos schemas de Carteira com asaas_wallet_id e asaas_account_status
"""

import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from app.services.payment_service import PaymentProviderService
from app.services.wallet_service import WalletService
from app.services.supabase_service import supabase_service
from app.schemas.wallet import WalletSummaryResponse, SetPixKeyRequest


@pytest.mark.asyncio
async def test_get_or_create_trainer_asaas_wallet_fallback():
    """Garante resolução de wallet determinística para o personal trainer com mock do Supabase."""
    trainer_id = "6f645308-f1b2-4d73-ac45-9890c27e20d4"
    trainer_name = "Cleudson Cavalcante"
    trainer_email = "cleudsonx@gmail.com"

    with patch.object(supabase_service, "get_client", new_callable=AsyncMock) as mock_sb:
        mock_sb.return_value = None

        wallet = await PaymentProviderService.get_or_create_trainer_asaas_wallet(
            trainer_id=trainer_id,
            trainer_name=trainer_name,
            trainer_email=trainer_email,
            cpf_cnpj="12345678900",
            phone="61999998888",
        )

        assert wallet is not None
        assert "asaas_wallet_id" in wallet
        assert wallet["asaas_wallet_id"].startswith("wal_")
        assert wallet["status"] in ("active", "active_sandbox")


def test_asaas_get_or_create_subaccount_mock():
    """Valida chamada e parsing de criação de subconta Asaas via API."""
    mock_client = MagicMock()
    # Simula resposta de conta existente por CPF
    mock_res = MagicMock()
    mock_res.status_code = 200
    mock_res.json.return_value = {
        "object": "list",
        "data": [
            {
                "id": "acc_asaas_test_123",
                "walletId": "wal_asaas_test_456",
                "name": "Personal Teste",
            }
        ]
    }
    mock_client.get.return_value = mock_res

    sub_info = PaymentProviderService._asaas_get_or_create_subaccount(
        client=mock_client,
        base_url="https://sandbox.asaas.com/api/v3",
        headers={"access_token": "mock_token"},
        name="Personal Teste",
        email="personal@teste.com",
        cpf_cnpj="12345678900",
        phone="61999998888",
    )

    assert sub_info["account_id"] == "acc_asaas_test_123"
    assert sub_info["wallet_id"] == "wal_asaas_test_456"


@pytest.mark.asyncio
async def test_wallet_service_get_summary_includes_asaas_fields():
    """Garante que o resumo da carteira do personal inclui campos Asaas."""
    trainer_id = "trainer_test_summary_123"

    with patch.object(supabase_service, "get_client", new_callable=AsyncMock) as mock_sb:
        mock_sb.return_value = None

        WalletService._mem_wallets[trainer_id] = {
            "balance_cents": 50000,
            "pending_balance_cents": 20000,
            "pix_key": "12345678900",
            "pix_key_type": "cpf",
            "bank_name": "Nubank",
            "asaas_account_id": "acc_test_999",
            "asaas_wallet_id": "wal_test_999",
            "asaas_account_status": "active",
        }

        summary = await WalletService.get_summary(trainer_id)
        assert isinstance(summary, WalletSummaryResponse)
        assert summary.balance_cents == 50000
        assert summary.asaas_wallet_id == "wal_test_999"
        assert summary.asaas_account_id == "acc_test_999"
        assert summary.asaas_account_status == "active"
