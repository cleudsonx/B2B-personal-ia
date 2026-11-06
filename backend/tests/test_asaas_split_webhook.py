# backend/tests/test_asaas_split_webhook.py
"""
Testes de Conciliação de Split no Webhook Asaas & Resolução BCB 4.893 (Bloco 4)
Verifica:
- Recepção do webhook PAYMENT_RECEIVED com conciliação do comando JWS
- Confirmação idempotente sem duplicidade de repasse
- Evento de estorno (PAYMENT_REFUNDED) com reversão de split e auditoria
- Integridade inquebrável da trilha de auditoria BCB 4.893
"""

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.core.config import settings
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.core.financial_security import FinancialAuditTrail, JwsSplitCommandService
from app.schemas.consultancy_plan import ConsultancyPlanCreate, PublicCheckoutRequest

client = TestClient(app)


@pytest.mark.asyncio
async def test_asaas_webhook_split_conciliation_and_audit():
    """Valida conciliação de split Asaas via Webhook com JWS e auditoria BCB 4.893."""
    settings.ENVIRONMENT = "development"
    FinancialAuditTrail._chain.clear()
    FinancialAuditTrail._last_hash = "0" * 64
    ConsultancyPlanService._mem_plans.clear()
    ConsultancyPlanService._mem_invoices.clear()

    trainer_id = "6f645308-f1b2-4d73-ac45-9890c27e20d4"

    with patch.object(supabase_service, "get_client", new_callable=AsyncMock) as mock_sb:
        mock_sb.return_value = None

        # 1. Cria plano e executa checkout na vitrine
        plan = await ConsultancyPlanService.create_plan(
            trainer_id=trainer_id,
            req=ConsultancyPlanCreate(
                name="Plano Semestral Pro",
                price_cents=30000,  # R$ 300,00
                billing_period="monthly",
                features=["Treino Semestral", "Análise de Cargas"],
            ),
        )

        checkout_resp = await ConsultancyPlanService.process_public_checkout(
            username="mrcoach",
            req=PublicCheckoutRequest(
                plan_id=plan.id,
                student_name="Lucas Gabriel",
                student_email="lucas.gabriel@example.com",
                student_phone="61998887766",
                student_cpf="98765432100",
                payment_method="PIX",
            ),
        )
        invoice_id = checkout_resp.invoice_id
        wallet_id = checkout_resp.trainer_wallet_id

        # Mock de envio WhatsApp
        with patch.object(whatsapp_service, "send_text_with_fallback", new_callable=AsyncMock) as mock_wa:
            mock_wa.return_value = {"status": "sent"}

            # 2. Simula recebimento de Webhook Asaas PAYMENT_RECEIVED
            webhook_body = {
                "event": "PAYMENT_RECEIVED",
                "payment": {
                    "id": "pay_asaas_split_test_99",
                    "customer": "cus_123456",
                    "value": 300.0,
                    "netValue": 285.0,
                    "billingType": "PIX",
                    "status": "RECEIVED",
                    "externalReference": invoice_id,
                    "split": [
                        {
                            "walletId": wallet_id,
                            "percentualValue": 95.0,
                            "status": "DONE",
                        }
                    ],
                },
            }

            res = client.post("/api/v1/webhooks/asaas", json=webhook_body)
            assert res.status_code == 200
            data = res.json()
            assert data["processed"] is True
            assert data["type"] == "student_invoice"
            assert data["result"]["status"] == "processed"
            assert data["result"]["net_amount_cents"] == 28500  # 95% de 30000

            # 3. Idempotência estrita: reenvio do mesmo webhook não duplica crédito
            res_repeat = client.post("/api/v1/webhooks/asaas", json=webhook_body)
            assert res_repeat.status_code == 200
            data_repeat = res_repeat.json()
            assert data_repeat["result"]["status"] == "already_paid"

            # 4. Simula evento de estorno PAYMENT_REFUNDED
            refund_webhook_body = {
                "event": "PAYMENT_REFUNDED",
                "payment": {
                    "id": "pay_asaas_split_test_99",
                    "externalReference": invoice_id,
                },
            }
            res_refund = client.post("/api/v1/webhooks/asaas", json=refund_webhook_body)
            assert res_refund.status_code == 200
            refund_data = res_refund.json()
            assert refund_data["status"] == "canceled"
            assert refund_data["result"]["reversed_cents"] == 28500

            # 5. Verifica integridade total da Trilha de Auditoria BCB 4.893
            is_valid, msg = FinancialAuditTrail.verify_chain_integrity()
            assert is_valid is True
            assert "registros auditados" in msg

            # Verifica eventos encadeados na trilha
            entries = FinancialAuditTrail.get_entries(invoice_id=invoice_id)
            event_types = [e.event_type for e in entries]
            assert "SPLIT_COMMAND_CREATED" in event_types
            assert "SPLIT_SETTLED" in event_types
            assert "SPLIT_REFUNDED" in event_types
