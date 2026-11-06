# backend/tests/test_public_checkout_split.py
"""
Testes unitários para Injeção de Split nas Cobranças da Vitrine Pública & Assinatura JWS (Bloco 3)
Verifica:
- Resolução e injeção do walletId no checkout público
- Assinatura digital do comando de split via JWS (RFC 7515 / BCB 4.893)
- Registro e encadeamento do evento na trilha de auditoria criptográfica
- Confirmação de liquidação com split_status='settled'
"""

import pytest
from unittest.mock import AsyncMock, patch
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.services.supabase_service import supabase_service
from app.core.financial_security import JwsSplitCommandService, FinancialAuditTrail
from app.schemas.consultancy_plan import ConsultancyPlanCreate, PublicCheckoutRequest


@pytest.mark.asyncio
async def test_public_checkout_with_jws_split_injection():
    """Garante assinatura JWS e split de 95%/5% no checkout da vitrine pública."""
    from app.core.config import settings
    settings.ENVIRONMENT = "development"

    FinancialAuditTrail._chain.clear()
    FinancialAuditTrail._last_hash = "0" * 64
    ConsultancyPlanService._mem_plans.clear()
    ConsultancyPlanService._mem_invoices.clear()

    trainer_id = "6f645308-f1b2-4d73-ac45-9890c27e20d4"

    with patch.object(supabase_service, "get_client", new_callable=AsyncMock) as mock_sb:
        mock_sb.return_value = None

        # 1. Cria um plano de teste (R$ 200,00)
        plan = await ConsultancyPlanService.create_plan(
            trainer_id=trainer_id,
            req=ConsultancyPlanCreate(
                name="Consultoria Elite",
                price_cents=20000,
                billing_period="monthly",
                features=["Treino VIP", "Biomecânica"],
            ),
        )

        # 2. Executa checkout público simulado
        checkout_req = PublicCheckoutRequest(
            plan_id=plan.id,
            student_name="Thiago Atleta",
            student_email="thiago.atleta@example.com",
            student_phone="61999998888",
            student_cpf="12345678900",
            payment_method="PIX",
        )

        resp = await ConsultancyPlanService.process_public_checkout(
            username="mrcoach",
            req=checkout_req,
        )

        # 3. Validações do Split e JWS
        assert resp.invoice_id is not None
        assert resp.amount_cents == 20000
        assert resp.platform_fee_cents == 1000  # 5%
        assert resp.net_amount_cents == 19000  # 95%
        assert resp.trainer_wallet_id is not None
        assert resp.jws_split_token is not None

        # 4. Decodifica e verifica a assinatura matemática do JWS (BCB 4.893)
        verified_payload = JwsSplitCommandService.verify_split_command(resp.jws_split_token)
        assert verified_payload["invoice_id"] == resp.invoice_id
        assert verified_payload["gross_amount_cents"] == 20000
        assert verified_payload["platform_fee_cents"] == 1000
        assert verified_payload["trainer_net_cents"] == 19000
        assert verified_payload["trainer_wallet_id"] == resp.trainer_wallet_id
        assert verified_payload["compliance_standard"] == "BCB_4893_CYBERSECURITY_V1"

        # 5. Verifica evento gravado na trilha de auditoria
        audit_entries = FinancialAuditTrail.get_entries(invoice_id=resp.invoice_id)
        assert len(audit_entries) >= 1
        assert audit_entries[0].event_type == "SPLIT_COMMAND_CREATED"
        assert audit_entries[0].gross_amount_cents == 20000

        # 6. Simula confirmação de liquidação e valida evento SPLIT_SETTLED
        conf = await ConsultancyPlanService.process_student_payment_confirmation(
            invoice_id=resp.invoice_id,
            payment_method="pix",
            provider_payment_id="pay_test_settled_123",
        )

        updated_entries = FinancialAuditTrail.get_entries(invoice_id=resp.invoice_id)
        settled_entries = [e for e in updated_entries if e.event_type == "SPLIT_SETTLED"]
        assert len(settled_entries) == 1
        assert settled_entries[0].trainer_net_cents == 19000

        # 7. Verifica integridade inquebrável da cadeia hash-chain
        is_chain_valid, chain_msg = FinancialAuditTrail.verify_chain_integrity()
        assert is_chain_valid is True
        assert "registros auditados" in chain_msg
