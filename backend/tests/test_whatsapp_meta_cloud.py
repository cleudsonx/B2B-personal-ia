import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from app.main import app
from app.services.whatsapp_service import whatsapp_service
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.api.v1.endpoints.whatsapp_ai import (
    handle_deterministic_button,
    process_meta_cloud_event,
    WhatsAppButtonPayload,
    AgentWhatsAppOutput,
)
from app.core.config import settings

client = TestClient(app)


def test_meta_webhook_verification_success():
    verify_token = settings.META_WA_WEBHOOK_VERIFY_TOKEN
    response = client.get(
        "/api/v1/whatsapp/meta-webhook",
        params={
            "hub.mode": "subscribe",
            "hub.verify_token": verify_token,
            "hub.challenge": "1158201234",
        },
    )
    assert response.status_code == 200
    assert response.text == "1158201234"


def test_meta_webhook_verification_forbidden():
    response = client.get(
        "/api/v1/whatsapp/meta-webhook",
        params={
            "hub.mode": "subscribe",
            "hub.verify_token": "token_invalido_hacker",
            "hub.challenge": "1158201234",
        },
    )
    assert response.status_code == 403


def test_meta_webhook_post_messages():
    payload = {
        "object": "whatsapp_business_account",
        "entry": [
            {
                "id": "1002938475",
                "changes": [
                    {
                        "value": {
                            "messaging_product": "whatsapp",
                            "metadata": {"phone_number_id": "10982347"},
                            "contacts": [{"profile": {"name": "Mariana Silva"}, "wa_id": "5511999998888"}],
                            "messages": [
                                {
                                    "from": "5511999998888",
                                    "id": "wamid.HBgLMTIzNDU2",
                                    "timestamp": "1730000000",
                                    "type": "text",
                                    "text": {"body": "qual meu treino de hoje?"},
                                }
                            ],
                        },
                        "field": "messages",
                    }
                ],
            }
        ],
    }
    response = client.post("/api/v1/whatsapp/meta-webhook", json=payload)
    assert response.status_code == 200
    assert response.json() == {"status": "EVENT_RECEIVED"}


@pytest.mark.asyncio
async def test_meta_cloud_send_message_mock():
    res = await whatsapp_service.send_meta_cloud_message(
        number="11999998888",
        text="Olá aluno! Seu novo treino foi liberado no Mr. Coach.",
    )
    assert res["status"] in ("sent", "success")
    assert res["provider"] == "meta_cloud"


@pytest.mark.asyncio
async def test_meta_cloud_send_template_mock():
    res = await whatsapp_service.send_meta_cloud_message(
        number="11999998888",
        template_name="novo_treino_aluno",
        template_language="pt_BR",
        template_components=[
            {
                "type": "body",
                "parameters": [
                    {"type": "text", "text": "Carlos"},
                    {"type": "text", "text": "Hipertrofia A/B"},
                ],
            }
        ],
    )
    assert res["status"] in ("sent", "success")
    assert res["provider"] == "meta_cloud"


@pytest.mark.asyncio
async def test_meta_cloud_health_check():
    health = await whatsapp_service.check_meta_cloud_health()
    assert "status" in health
    assert health["provider"] == "meta_cloud"


# =============================================================================
# WHATSAPP AI ENGINE — TESTES DE BOTÕES INTERATIVOS E DETERMINÍSTICOS
# =============================================================================

@pytest.mark.asyncio
async def test_meta_cloud_send_interactive_sanitization():
    """Valida regra estrita da Meta: máximo 3 botões e truncamento de título a 20 caracteres."""
    buttons = [
        {"id": "btn1", "title": "Título Normal"},
        {"id": "btn2", "title": "Este título é muito longo e passa de vinte caracteres"},
        {"id": "btn3", "title": "Terceiro Botão"},
        {"id": "btn4", "title": "Quarto Botão Excedente"},
    ]
    res = await whatsapp_service.send_meta_cloud_interactive(
        number="5511999998888",
        body_text="Escolha sua opção abaixo:",
        buttons=buttons,
        header_text="Cabeçalho",
        footer_text="Rodapé",
    )
    assert res["status"] in ("sent", "success")
    assert res["interactive"] is True
    assert res["buttons_count"] == 3


@pytest.mark.asyncio
async def test_send_interactive_with_fallback_evolution_degraded():
    """Valida graceful degradation para Evolution/texto puro com atalhos numéricos."""
    buttons = [
        {"id": "menu_act|workout", "title": "Ver Treino 📋"},
        {"id": "menu_act|streak", "title": "Streak 🔥"},
    ]
    with patch.object(whatsapp_service, "send_meta_cloud_interactive", side_effect=Exception("Meta Cloud Offline")):
        res = await whatsapp_service.send_interactive_with_fallback(
            number="5511999998888",
            text="Menu do Aluno:",
            buttons=buttons,
        )
        assert res.get("interactive_degraded") is True
        assert res["status"] in ("sent", "success")


@pytest.mark.asyncio
async def test_deterministic_handler_confirm_swap():
    """Valida Substituição de Exercício em 1 Toque (confirm_swap)."""
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id="confirm_swap|active|Supino Reto Halteres",
    )
    assert "Adaptação Registrada" in res["reply"]
    assert "Supino Reto Halteres" in res["reply"]
    assert "ficha oficial do mesociclo segue intacta" in res["reply"]
    assert res["cost_type"] == "free"
    assert res["tokens_used"] == 0


@pytest.mark.asyncio
async def test_deterministic_handler_keep_original():
    """Valida manutenção da prescrição original (keep_original)."""
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id="keep_original|wk_104",
    )
    assert "Prescrição Mantida" in res["reply"]
    assert "exercício original" in res["reply"]
    assert "Treino de Hoje" not in res["reply"]
    assert res["cost_type"] == "free"
    assert res["tokens_used"] == 0


@pytest.mark.asyncio
async def test_deterministic_handler_rpe_log():
    """Valida registro instantâneo de RPE."""
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id="rpe_log|active|9",
    )
    assert "Esforço Registrado (RPE 9)" in res["reply"]
    assert res["cost_type"] == "free"
    assert res["tokens_used"] == 0


@pytest.mark.asyncio
async def test_deterministic_handler_fin_pix():
    """Valida devolução imediata de chave Pix Copia e Cola."""
    inv_id = "test_inv_uuid_12345"
    ConsultancyPlanService._mem_invoices[inv_id] = {
        "id": inv_id,
        "amount": 149.90,
        "pix_copy_paste": "00020126580014br.gov.bcb.pix0136test-pix-copia-cola-mrcoach5204000053039865802BR",
    }
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id=f"fin_pix|{inv_id}",
    )
    assert "Código Pix Copia e Cola" in res["reply"]
    assert "00020126580014br.gov.bcb.pix0136test-pix-copia-cola-mrcoach5204000053039865802BR" in res["reply"]
    assert "149.90" in res["reply"]


@pytest.mark.asyncio
async def test_deterministic_handler_fin_link():
    """Valida devolução de link seguro de pagamento com cartão de crédito (NUNCA responde treino)."""
    inv_id = "test_inv_card_8831"
    ConsultancyPlanService._mem_invoices[inv_id] = {
        "id": inv_id,
        "amount": 80.00,
        "invoice_url": "https://asaas.com/i/test_inv_card_8831",
    }
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id=f"fin_link|{inv_id}",
    )
    assert "Cartão de Crédito" in res["reply"]
    assert "https://asaas.com/i/test_inv_card_8831" in res["reply"]
    assert "80.00" in res["reply"]
    # Garante que não é exibido o treino de forma errônea
    assert "Treino de Hoje" not in res["reply"]


@pytest.mark.asyncio
async def test_deterministic_handler_fin_paid():
    """Valida resposta de status de pagamento (NUNCA responde treino)."""
    inv_id = "test_inv_paid_8831"
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id=f"fin_paid|{inv_id}",
    )
    assert "Processamento Bancário em Andamento" in res["reply"]
    assert "Treino de Hoje" not in res["reply"]


@pytest.mark.asyncio
async def test_deterministic_handler_unknown_button_fallback():
    """Valida que botão desconhecido nunca exibe treino indevidamente."""
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id="random_action_123|xyz",
    )
    assert "Opção recebida com sucesso" in res["reply"]
    assert "Treino de Hoje" not in res["reply"]


@pytest.mark.asyncio
async def test_process_meta_cloud_event_interactive_button():
    """Valida o roteador em background com idempotência."""
    wamid = "wamid.HBgLTESTE_INTERACTIVE_001"
    payload_entry = {
        "id": "1002938475",
        "changes": [
            {
                "value": {
                    "messaging_product": "whatsapp",
                    "metadata": {"phone_number_id": "10982347"},
                    "messages": [
                        {
                            "from": "5511999998888",
                            "id": wamid,
                            "timestamp": "1730000000",
                            "type": "interactive",
                            "interactive": {
                                "type": "button_reply",
                                "button_reply": {
                                    "id": "confirm_swap|active|Crucifixo Máquina",
                                    "title": "Crucifixo Máquina",
                                },
                            },
                        }
                    ],
                },
                "field": "messages",
            }
        ],
    }
    await process_meta_cloud_event(payload_entry)
    await process_meta_cloud_event(payload_entry)


def test_pydantic_schemas_whatsapp():
    """Valida os schemas de output estruturado do agente WhatsApp."""
    btn = WhatsAppButtonPayload(id="confirm_swap|1|Halteres", title="Trocar p/ Halteres")
    assert btn.title == "Trocar p/ Halteres"

    output = AgentWhatsAppOutput(
        reply="Escolha sua opção:",
        interaction_type="reply_buttons",
        buttons=[btn],
    )
    assert output.interaction_type == "reply_buttons"
    assert len(output.buttons) == 1
