import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch

from app.main import app
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service
from app.api.v1.endpoints.whatsapp_ai import (
    parse_workout_feedback,
    process_whatsapp_question,
    handle_deterministic_button,
)
from app.api.deps import get_current_user

client = TestClient(app)

TRAINER_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_ID = "00000000-0000-0000-0000-000000000002"


@pytest.fixture(autouse=True)
def setup_test_data():
    supabase_service._mem_students[STUDENT_ID] = {
        "id": STUDENT_ID,
        "full_name": "Marcos Aluno",
        "name": "Marcos Aluno",
        "email": "marcos@shaipados.com",
        "phone": "5511999998888",
        "trainer_id": TRAINER_ID,
        "role": "client",
        "subscription_status": "active",
        "streak_days": 5,
        "goal": "Hipertrofia",
    }
    supabase_service._mem_students[TRAINER_ID] = {
        "id": TRAINER_ID,
        "full_name": "Professor Treinador",
        "name": "Professor Treinador",
        "email": "coach@shaipados.com",
        "phone": "5511988887777",
        "role": "trainer",
        "subscription_status": "active",
        "goal": "Gestão",
    }
    app.dependency_overrides[get_current_user] = lambda: {
        "sub": TRAINER_ID,
        "role": "trainer",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    yield
    # Cleanup
    supabase_service._mem_students.pop(STUDENT_ID, None)
    supabase_service._mem_students.pop(TRAINER_ID, None)
    app.dependency_overrides.pop(get_current_user, None)


def test_parse_workout_feedback_rpe_patterns():
    # Teste 1: RPE com prefixo explícito
    f1 = parse_workout_feedback("treino muito bom, RPE 8")
    assert f1["rpe"] == 8
    assert f1["is_pain"] is False

    # Teste 2: PSE
    f2 = parse_workout_feedback("intensidade PSE: 9")
    assert f2["rpe"] == 9
    assert f2["is_pain"] is False

    # Teste 3: 8/10
    f3 = parse_workout_feedback("treino hoje foi 8/10")
    assert f3["rpe"] == 8

    # Teste 4: Número isolado
    f4 = parse_workout_feedback("7")
    assert f4["rpe"] == 7

    # Teste 5: Negação de dor
    f5 = parse_workout_feedback("RPE 8, concluído sem dores e tudo bem")
    assert f5["rpe"] == 8
    assert f5["is_pain"] is False


def test_parse_workout_feedback_joint_pain_patterns():
    # Teste 1: Dor no joelho com RPE
    f1 = parse_workout_feedback("treino puxado, rpe 8, mas senti uma pontada no joelho")
    assert f1["rpe"] == 8
    assert f1["is_pain"] is True
    assert f1["pain_location"] == "Joelho"
    assert f1["pain_severity"] == "Moderada"

    # Teste 2: Dor no ombro aguda
    f2 = parse_workout_feedback("muita dor no ombro esquerdo durante o supino")
    assert f2["rpe"] is None
    assert f2["is_pain"] is True
    assert f2["pain_location"] == "Ombro"
    assert f2["pain_severity"] == "Alta"

    # Teste 3: Lombar
    f3 = parse_workout_feedback("senti fisgada forte na lombar")
    assert f3["is_pain"] is True
    assert f3["pain_location"] == "Lombar"

    # Teste 4: Cotovelo
    f4 = parse_workout_feedback("meu cotovelo ficou estalando no tríceps")
    assert f4["is_pain"] is True
    assert f4["pain_location"] == "Cotovelo"


@pytest.mark.asyncio
async def test_process_whatsapp_question_post_workout_checkin():
    student = supabase_service._mem_students[STUDENT_ID]
    question = "treino hoje foi foda, rpe 8, mas senti uma pontada no joelho"

    res = await process_whatsapp_question(
        trainer_id=TRAINER_ID,
        student=student,
        question=question,
    )

    assert "RPE 8/10" in res["reply"]
    assert "Joelho" in res["reply"]
    assert res["cost_type"] == "free"
    assert res["tokens_used"] == 0
    assert res["is_alert"] is True
    assert res["rpe"] == 8
    assert res["pain_location"] == "Joelho"

    # Verifica se gerou evento no Student Pulse
    pulse_events = [ev for ev in supabase_service._mem_pulse_events.values() if ev.get("student_id") == STUDENT_ID]
    rpe_events = [ev for ev in pulse_events if ev.get("event_type") == "rpe_feedback"]
    assert len(rpe_events) >= 1
    assert rpe_events[-1]["metadata"]["rpe"] == 8

    # Verifica se gerou alerta biomecânico
    alerts = await supabase_service.list_trainer_alerts(TRAINER_ID)
    matching_alerts = [a for a in alerts if a.student_id == STUDENT_ID and a.pain_location == "Joelho"]
    assert len(matching_alerts) >= 1


@pytest.mark.asyncio
async def test_deterministic_rpe_button():
    res = await handle_deterministic_button(
        digits="5511999998888",
        button_id=f"rpe_log|workout_999|9",
        trainer_id=TRAINER_ID,
    )
    assert "RPE 9" in res["reply"]
    assert res["cost_type"] == "free"
    assert res["rpe"] == "9"


def test_post_workout_checkin_endpoint():
    response = client.post(
        "/api/v1/whatsapp/checkin/post-workout",
        json={
            "student_id": STUDENT_ID,
            "workout_title": "Treino A - Peito e Tríceps",
            "workout_session_id": "session_uuid_101",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["student_id"] == STUDENT_ID
    assert data["workout_title"] == "Treino A - Peito e Tríceps"
    assert data["status"] in ("sent", "fallback_wa", "skipped")


@pytest.mark.asyncio
async def test_cockpit_integration_after_pain_report():
    # Cria alerta via WhatsApp
    student = supabase_service._mem_students[STUDENT_ID]
    await process_whatsapp_question(
        trainer_id=TRAINER_ID,
        student=student,
        question="rpe 7 mas senti dor no cotovelo ao fazer supino",
    )

    # Consulta Cockpit 24h
    cockpit = await supabase_service.get_trainer_operational_cockpit(TRAINER_ID)
    assert cockpit.pending_pain_alerts_count >= 1
    pain_locations = [a.pain_location for a in cockpit.recent_pain_alerts]
    assert any("Cotovelo" in str(loc) for loc in pain_locations)
