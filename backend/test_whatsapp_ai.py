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
    assert response.status_code == 200
    assert response.json()["status"] == "accepted"


def test_zero_cost_menu_and_phase2_lock(monkeypatch):
    import asyncio
    from types import SimpleNamespace
    from app.api.v1.endpoints import whatsapp_ai
    from app.services.whatsapp_service import instance_name_for, whatsapp_service
    from app.services.supabase_service import supabase_service
    from app.services.gemini_service import gemini_service

    sent_messages = []
    gemini_calls = []
    valid_instance = instance_name_for("631e76b9-3cb0-454f-8fd9-1d450e5560d6")

    async def fake_find_student(digits: str, trainer_id: str):
        return {"id": "student-1", "full_name": "Carlos Silva", "trainer_id": trainer_id}

    async def fake_send_text(instance: str, number: str, text: str):
        sent_messages.append((instance, number, text))
        return {"status": "success"}

    async def fake_get_active_prescription(student_id: str):
        return SimpleNamespace(
            workout_plan_title="Hipertrofia A/B",
            splits=[
                SimpleNamespace(
                    split_identifier="A",
                    split_name="Superiores",
                    exercises=[SimpleNamespace(name="Supino Reto", sets=4, reps="10", rest_seconds=60)],
                )
            ],
        )

    async def fake_gamification(student_id: str):
        return {"current_streak": 5, "daily_goal_progress": 1.0}

    async def fake_gemini(*args, **kwargs):
        gemini_calls.append(kwargs)
        return SimpleNamespace(text="Mantenha os pés afastados na largura dos ombros!")

    monkeypatch.setattr(whatsapp_ai, "_find_student_by_phone", fake_find_student)
    monkeypatch.setattr(whatsapp_service, "send_text_message", fake_send_text)
    monkeypatch.setattr(supabase_service, "get_active_prescription", fake_get_active_prescription)
    monkeypatch.setattr(supabase_service, "get_gamification_data", fake_gamification)
    monkeypatch.setattr(gemini_service, "_generate_with_fallback_async", fake_gemini)

    async def run_scenarios():
        # 1. Saudação / Menu (zero tokens)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "Olá!")
        assert len(sent_messages) == 1
        assert "Olá, Carlos!" in sent_messages[-1][2]
        assert len(gemini_calls) == 0

        # 2. Opção 1 - Treino ativo (zero tokens)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "1")
        assert len(sent_messages) == 2
        assert "Hipertrofia A/B" in sent_messages[-1][2]
        assert "https://shaipados-labs.web.app" in sent_messages[-1][2]
        assert len(gemini_calls) == 0

        # 3. Opção 2 - Streak (zero tokens)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "streak")
        assert len(sent_messages) == 3
        assert "5 dia(s)" in sent_messages[-1][2]
        assert len(gemini_calls) == 0

        # 4. Opção 3 - Link do App (zero tokens)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "3")
        assert len(sent_messages) == 4
        assert "https://shaipados-labs.web.app" in sent_messages[-1][2]
        assert len(gemini_calls) == 0

        # 5. Trava Comercial: Plano Starter bloqueia Gemini em pergunta aberta
        async def fake_sub_starter(trainer_id: str):
            return SimpleNamespace(plan_id="starter")

        monkeypatch.setattr(supabase_service, "get_trainer_subscription", fake_sub_starter)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "Como faço o agachamento?")
        assert len(sent_messages) == 5
        assert "Recebi sua mensagem! Já encaminhei para o seu treinador responder pessoalmente." in sent_messages[-1][2]
        assert len(gemini_calls) == 0

        # 6. Plano Pro libera Gemini em pergunta aberta
        async def fake_sub_pro(trainer_id: str):
            return SimpleNamespace(plan_id="pro")

        monkeypatch.setattr(supabase_service, "get_trainer_subscription", fake_sub_pro)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "Como faço o agachamento?")
        assert len(sent_messages) == 6
        assert len(gemini_calls) == 1
        assert "largura dos ombros" in sent_messages[-1][2]

    asyncio.run(run_scenarios())


if __name__ == "__main__":
    test_webhook()

