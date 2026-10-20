# backend/tests/test_asaas_student_webhook.py
# Testes do Ciclo Financeiro: Webhook Asaas para Consultorias de Alunos

import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.api.deps import get_current_trainer
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.services.whatsapp_service import whatsapp_service
from app.services.supabase_service import supabase_service

client = TestClient(app)

MOCK_TRAINER = {
    "id": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
    "sub": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
    "email": "cleudsonx@gmail.com",
    "full_name": "Cleudson Cavalcante",
    "role": "trainer",
    "professional_document": "CREF 012345-G/DF",
    "phone": "61999998888",
    "public_whatsapp": "61999998888",
}


@pytest.fixture(autouse=True)
def setup_teardown():
    app.dependency_overrides[get_current_trainer] = lambda: MOCK_TRAINER
    ConsultancyPlanService._mem_plans.clear()
    ConsultancyPlanService._mem_invoices.clear()
    yield
    app.dependency_overrides.clear()
    ConsultancyPlanService._mem_plans.clear()
    ConsultancyPlanService._mem_invoices.clear()


@pytest.mark.asyncio
async def test_asaas_webhook_student_payment_lifecycle(monkeypatch):
    """
    Ciclo financeiro completo:
    1. Criação do plano e checkout transparente via Pix (status pending)
    2. Recebimento de Webhook Asaas (PAYMENT_RECEIVED)
    3. Atualização de fatura para 'paid', crédito na carteira e link de boas-vindas
    4. Idempotência: reenvio do webhook não duplica crédito
    """
    # 1. Cria plano de consultoria
    plan_res = client.post(
        "/api/v1/trainers/consultancy-plans",
        json={
            "name": "Plano Musculação Pro",
            "price_cents": 20000,  # R$ 200,00
            "billing_period": "monthly",
            "features": ["Treino semanal", "Suporte WhatsApp"],
        },
    )
    assert plan_res.status_code == 201
    plan_id = plan_res.json()["id"]

    # Mock de contagem de vagas para garantir vaga livre
    async def mock_count_slots(*args, **kwargs):
        return 5

    monkeypatch.setattr(supabase_service, "count_trainer_occupied_slots", mock_count_slots)

    # 2. Executa checkout público
    checkout_res = client.post(
        "/api/v1/public/trainers/mrcoach/checkout",
        json={
            "plan_id": plan_id,
            "student_name": "Marcos Vinicius",
            "student_email": "marcos.vini@example.com",
            "student_phone": "61988887777",
            "student_cpf": "123.456.789-00",
            "payment_method": "PIX",
        },
    )
    assert checkout_res.status_code == 201
    checkout_data = checkout_res.json()
    invoice_id = checkout_data["invoice_id"]
    assert checkout_data["status"] == "pending"
    assert checkout_data["amount_cents"] == 20000
    assert checkout_data["net_amount_cents"] == 19000  # 95% do total

    # Mock de envio de WhatsApp para capturar mensagens disparadas
    sent_messages = []

    async def mock_send_wa(number, text, trainer_id=None):
        sent_messages.append({"number": number, "text": text, "trainer_id": trainer_id})
        return {"status": "sent"}

    monkeypatch.setattr(whatsapp_service, "send_text_with_fallback", mock_send_wa)

    # 3. Simula Webhook Asaas enviado para /api/v1/webhooks/asaas
    webhook_payload = {
        "event": "PAYMENT_RECEIVED",
        "payment": {
            "id": "pay_asaas_test_12345",
            "customer": "cus_123456",
            "value": 200.0,
            "netValue": 190.0,
            "billingType": "PIX",
            "status": "RECEIVED",
            "externalReference": invoice_id,
            "description": "Consultoria Plano Musculação Pro",
        },
    }

    wh_res = client.post("/api/v1/webhooks/asaas", json=webhook_payload)
    assert wh_res.status_code == 200
    wh_data = wh_res.json()
    assert wh_data["processed"] is True
    assert wh_data["type"] == "student_invoice"
    assert wh_data["result"]["status"] == "processed"
    assert wh_data["result"]["net_amount_cents"] == 19000

    # 4. Verifica se a fatura em memória foi atualizada para 'paid'
    inv = ConsultancyPlanService._mem_invoices[invoice_id]
    assert inv["status"] == "paid"
    assert inv["paid_at"] is not None

    # 5. Verifica se mensagens de WhatsApp foram disparadas (para aluno e treinador)
    assert len(sent_messages) >= 1
    student_msg = next((m for m in sent_messages if "61988887777" in m["number"]), None)
    assert student_msg is not None
    assert "confirmado com sucesso" in student_msg["text"]
    assert "shaipados-labs.web.app" in student_msg["text"]

    # 6. Teste de Idempotência: Envio duplicado
    sent_count_before = len(sent_messages)
    wh_res_dup = client.post("/api/v1/webhooks/asaas", json=webhook_payload)
    assert wh_res_dup.status_code == 200
    wh_dup_data = wh_res_dup.json()
    assert wh_dup_data["result"]["status"] == "already_paid"
    # Nenhuma mensagem extra disparada na duplicata
    assert len(sent_messages) == sent_count_before


@pytest.mark.asyncio
async def test_asaas_webhook_via_subscriptions_route_fallback(monkeypatch):
    """
    Se o webhook for configurado na URL /subscriptions/webhook/asaas,
    deve interceptar e processar a fatura do aluno sem erro de sessão ausente.
    """
    # 1. Cria plano e fatura
    plan_res = client.post(
        "/api/v1/trainers/consultancy-plans",
        json={"name": "Plano Express", "price_cents": 10000},
    )
    plan_id = plan_res.json()["id"]

    async def mock_count_slots(*args, **kwargs):
        return 2

    monkeypatch.setattr(supabase_service, "count_trainer_occupied_slots", mock_count_slots)

    checkout_res = client.post(
        "/api/v1/public/trainers/mrcoach/checkout",
        json={
            "plan_id": plan_id,
            "student_name": "Juliana Paes",
            "student_email": "juliana.paes@example.com",
            "student_phone": "61977778888",
            "payment_method": "PIX",
        },
    )
    assert checkout_res.status_code == 201
    invoice_id = checkout_res.json()["invoice_id"]

    # 2. Dispara webhook para rota de subscriptions
    webhook_payload = {
        "event": "PAYMENT_CONFIRMED",
        "payment": {
            "id": "pay_sub_fallback_999",
            "value": 100.0,
            "billingType": "PIX",
            "status": "CONFIRMED",
            "externalReference": invoice_id,
        },
    }

    wh_res = client.post("/api/v1/subscriptions/webhook/asaas", json=webhook_payload)
    assert wh_res.status_code == 200
    wh_data = wh_res.json()
    assert wh_data["processed"] is True
    assert wh_data["type"] == "student_invoice"
    assert wh_data["result"]["status"] == "processed"

    # Fatura atualizada para paid
    inv = ConsultancyPlanService._mem_invoices[invoice_id]
    assert inv["status"] == "paid"


@pytest.mark.asyncio
async def test_asaas_webhook_cancellation():
    """Evento PAYMENT_REFUNDED ou PAYMENT_DELETED atualiza fatura para canceled."""
    ConsultancyPlanService._mem_invoices["f7a1c9e2-3b4d-5e6f-7a8b-9c0d1e2f3a4b"] = {
        "id": "f7a1c9e2-3b4d-5e6f-7a8b-9c0d1e2f3a4b",
        "trainer_id": MOCK_TRAINER["id"],
        "status": "pending",
    }

    payload = {
        "event": "PAYMENT_REFUNDED",
        "payment": {
            "id": "pay_ref_111",
            "externalReference": "f7a1c9e2-3b4d-5e6f-7a8b-9c0d1e2f3a4b",
        },
    }

    res = client.post("/api/v1/webhooks/asaas", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["type"] == "student_invoice"
    assert data["status"] == "canceled"

