import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings

client = TestClient(app)

def test_webhook():
    settings.EVOLUTION_WEBHOOK_TOKEN = "test_token"
    response = client.post(
        "/api/v1/whatsapp/webhook",
        headers={"apikey": "test_token"},
        json={
            "event": "messages.upsert",
            "instance": "trainer_123",
            "data": {
                "key": {
                    "remoteJid": "5511999999999@s.whatsapp.net",
                    "fromMe": False
                },
                "message": {
                    "conversation": "Olá, como faço o leg press?"
                }
            }
        }
    )
    print("Status:", response.status_code)
    print("Response:", response.json())

if __name__ == "__main__":
    test_webhook()
