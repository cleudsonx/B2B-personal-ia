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

        # 7. Plano Elite Coach também libera Gemini em pergunta aberta
        async def fake_sub_elite(trainer_id: str):
            return SimpleNamespace(plan_id="elite", plan_name="Elite Coach")

        monkeypatch.setattr(supabase_service, "get_trainer_subscription", fake_sub_elite)
        await whatsapp_ai._answer(valid_instance, "5511999999999", "5511999999999", "Como fazer o supino?")
        assert len(sent_messages) == 7
        assert len(gemini_calls) == 2

        # 8. Mensagem de Abertura do App (Saudação padrão): Zero Custo
        await whatsapp_ai._answer(
            valid_instance,
            "5511999999999",
            "5511999999999",
            "Olá professor! Sou aluno no Mr. Coach e gostaria de tirar uma dúvida sobre meu treino.",
        )
        assert len(sent_messages) == 8
        assert "Sou o assistente automático" in sent_messages[-1][2]
        assert len(gemini_calls) == 2  # Não chamou Gemini, zero tokens!

        # 9. Guardrail de Segurança: Alerta de Dor Aguda
        await whatsapp_ai._answer(
            valid_instance,
            "5511999999999",
            "5511999999999",
            "Senti muita dor no ombro e acho que lesionei",
        )
        assert len(sent_messages) == 9
        assert "Relato de Desconforto Registrado" in sent_messages[-1][2] or "descanse a articulação" in sent_messages[-1][2]
        assert len(gemini_calls) == 2  # Bloqueio de segurança sem tokens

        # 10. Injeção de Anamnese Expandida no Prompt
        async def fake_anamnesis(client_id: str):
            return {
                "objective": "Definição e Força",
                "injuries_or_restrictions": "Condromalácia no joelho esquerdo",
                "training_level": "Avançado",
            }

        monkeypatch.setattr(supabase_service, "get_student_anamnesis", fake_anamnesis)
        await whatsapp_ai._answer(
            valid_instance,
            "5511999999999",
            "5511999999999",
            "Qual a cadência do supino inclinado?",
        )
        assert len(sent_messages) == 10
        assert len(gemini_calls) == 3
        last_prompt = gemini_calls[-1].get("contents", "")
        assert "Condromalácia no joelho esquerdo" in last_prompt
        assert "Definição e Força" in last_prompt

    asyncio.run(run_scenarios())


def test_simulate_whatsapp_endpoint(monkeypatch):
    from app.api.deps import get_current_trainer
    from app.services.supabase_service import supabase_service
    from types import SimpleNamespace

    app.dependency_overrides[get_current_trainer] = lambda: {"sub": "631e76b9-3cb0-454f-8fd9-1d450e5560d6"}

    async def fake_get_students(trainer_id: str):
        return [
            SimpleNamespace(
                model_dump=lambda: {
                    "id": "student-1",
                    "full_name": "Juliana Lima",
                    "trainer_id": trainer_id,
                }
            )
        ]

    async def fake_sub(trainer_id: str):
        return SimpleNamespace(plan_id="pro")

    async def fake_get_prescription(student_id: str):
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

    monkeypatch.setattr(supabase_service, "list_students", fake_get_students)
    monkeypatch.setattr(supabase_service, "get_trainer_subscription", fake_sub)
    monkeypatch.setattr(supabase_service, "get_active_prescription", fake_get_prescription)

    res = client.post("/api/v1/whatsapp/simulate", json={"question": "1"})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["cost_type"] == "free"
    assert "Juliana" in data["student_name"]

    app.dependency_overrides.clear()



def test_connect_resets_stale_instance_and_generates_fresh_code(monkeypatch):
    import httpx
    from app.api.deps import get_current_trainer
    from app.services.whatsapp_service import whatsapp_service

    app.dependency_overrides[get_current_trainer] = lambda: {"sub": "631e76b9-3cb0-454f-8fd9-1d450e5560d6"}

    call_history = []

    async def fake_get_state(instance):
        call_history.append(("get_state", instance))
        return {"instance": {"state": "connecting"}}

    create_count = 0

    async def fake_create_instance(instance, number):
        nonlocal create_count
        create_count += 1
        call_history.append(("create_instance", instance, number))
        if create_count == 1:
            # Simula a primeira tentativa encontrando instância existente (403/409)
            req = httpx.Request("POST", "http://test")
            resp = httpx.Response(409, request=req)
            raise httpx.HTTPStatusError("Instance already exists", request=req, response=resp)
        # Segunda tentativa (após delete): sucesso gerando código limpo
        return {"pairingCode": "NEW99999"}

    async def fake_delete_instance(instance):
        call_history.append(("delete_instance", instance))
        return {"status": "success"}

    async def fake_set_webhook(instance):
        call_history.append(("set_webhook", instance))
        return {"status": "success"}

    monkeypatch.setattr(whatsapp_service, "get_instance_state", fake_get_state)
    monkeypatch.setattr(whatsapp_service, "create_instance", fake_create_instance)
    monkeypatch.setattr(whatsapp_service, "delete_instance", fake_delete_instance)
    monkeypatch.setattr(whatsapp_service, "set_webhook", fake_set_webhook)

    res = client.post("/api/v1/whatsapp/connect", json={"number": "5511988887777"})
    assert res.status_code == 200
    data = res.json()
    assert data["pairingCode"] == "NEW99999"

    # Valida sequência: tentou criar -> 409 -> deletou sessão antiga -> recriou com o novo número
    actions = [c[0] for c in call_history]
    assert "delete_instance" in actions
    assert actions.count("create_instance") == 2
    assert ("create_instance", "trainer_631e76b93cb0454f8fd91d450e5560d6", "5511988887777") in call_history

    app.dependency_overrides.clear()


def test_fase7_biohub_note_and_proactive_radar(monkeypatch):
    import asyncio
    from app.api.deps import get_current_trainer
    from app.api.v1.endpoints import whatsapp_ai
    from app.services.supabase_service import supabase_service
    from app.services.whatsapp_service import whatsapp_service

    app.dependency_overrides[get_current_trainer] = lambda: {"sub": "631e76b9-3cb0-454f-8fd9-1d450e5560d6"}

    async def fake_biohub(client_id: str):
        return {
            "weight_kg": 78.5,
            "height_cm": 175,
            "bmi": 25.6,
            "bmi_category": "Sobrepeso",
            "body_fat_pct": 16.2,
            "muscle_mass_kg": 38.4,
            "objective": "Hipertrofia Limpa",
        }

    monkeypatch.setattr(supabase_service, "get_student_latest_biohub", fake_biohub)

    async def run_cmd_tests():
        student = {"id": "student-1", "full_name": "Carlos Silva", "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6"}
        res5 = await whatsapp_ai.process_whatsapp_question("631e76b9-3cb0-454f-8fd9-1d450e5560d6", student, "5")
        assert res5["cost_type"] == "free"
        assert res5["tokens_used"] == 0
        assert "78.5 kg" in res5["reply"]
        assert "25.6" in res5["reply"]

        res4 = await whatsapp_ai.process_whatsapp_question(
            "631e76b9-3cb0-454f-8fd9-1d450e5560d6",
            student,
            "recado: Hoje finalizei o treino A em 45min!",
        )
        assert res4["cost_type"] == "free"
        assert "Recado Registrado" in res4["reply"]

    asyncio.run(run_cmd_tests())

    async def fake_radar(trainer_id: str, min_inactive_days: int = 4):
        return {
            "inactive_students": [
                {
                    "id": "st-inactive-1",
                    "full_name": "Marina Costa",
                    "phone": "5511977776666",
                    "days_inactive": 6,
                    "streak_days": 0,
                    "last_contacted_at": None,
                    "recently_contacted_48h": False,
                }
            ],
            "weekly_digest": {
                "total_students": 12,
                "active_this_week": 11,
                "weekly_workouts_completed": 33,
                "retention_rate": 92,
                "inactive_count": 1,
                "pending_alerts_count": 0,
                "top_streaks": [{"id": "st-1", "full_name": "Carlos Silva", "streak_days": 14}],
                "trainer_phone": "5511999998888",
                "digest_message": "📊 *Resumo Executivo Semanal — Mr. Coach*",
            },
        }

    async def fake_mark_contacted(student_id: str):
        return True

    async def fake_send_text(instance: str, number: str, text: str):
        return {"status": "sent"}

    monkeypatch.setattr(supabase_service, "get_proactive_radar_and_weekly_digest", fake_radar)
    monkeypatch.setattr(supabase_service, "mark_student_contacted", fake_mark_contacted)
    monkeypatch.setattr(whatsapp_service, "send_text_message", fake_send_text)

    r_radar = client.get("/api/v1/whatsapp/proactive-radar")
    assert r_radar.status_code == 200
    assert r_radar.json()["weekly_digest"]["retention_rate"] == 92
    assert len(r_radar.json()["inactive_students"]) == 1

    r_checkin = client.post("/api/v1/whatsapp/proactive-checkin", json={"min_inactive_days": 4})
    assert r_checkin.status_code == 200
    assert r_checkin.json()["sent_count"] == 1

    r_digest = client.post("/api/v1/whatsapp/send-weekly-digest", json={})
    assert r_digest.status_code == 200
    assert r_digest.json()["sent_via_evolution"] is True

    app.dependency_overrides.clear()


if __name__ == "__main__":
    test_webhook()



