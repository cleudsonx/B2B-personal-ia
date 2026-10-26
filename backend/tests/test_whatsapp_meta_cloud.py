import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from app.main import app
from app.services.whatsapp_service import whatsapp_service
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
