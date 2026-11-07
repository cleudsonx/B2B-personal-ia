import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from app.main import app
from app.services.supabase_service import supabase_service, DEFAULT_DEMO_TRAINER_ID
from app.schemas.student_pulse import (
    StudentPulseEventCreate,
    TrainerOperationalCockpitResponse,
    InactiveStudentCard,
    OperationalPainAlertItem,
)
from app.schemas.workout import BiomechanicalAlertCreate
from app.api.deps import get_current_trainer

client = TestClient(app)

TRAINER_UUID = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
STUDENT_UUID = "0b988373-cd16-404f-b02c-c5e1aac7ec3f"


def test_operational_cockpit_schemas():
    card = InactiveStudentCard(
        id=STUDENT_UUID,
        full_name="Lucas Pereira",
        phone="11988887777",
        days_inactive=5,
        streak_days=3,
        suggested_whatsapp_message="Fala Lucas! Como estão os treinos?",
        contact_whatsapp_url="https://wa.me/5511988887777?text=teste",
    )
    assert card.full_name == "Lucas Pereira"
    assert card.days_inactive == 5
    assert not card.recently_contacted_48h

    alert = OperationalPainAlertItem(
        id="alert-1",
        student_id=STUDENT_UUID,
        student_name="Lucas Pereira",
        original_exercise="Agachamento Livre",
        adapted_exercise="Leg Press 45",
        pain_location="Joelho direito",
        severity="Moderada",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    assert alert.original_exercise == "Agachamento Livre"
    assert alert.adapted_exercise == "Leg Press 45"

    resp = TrainerOperationalCockpitResponse(
        sessions_completed_24h=4,
        exercises_completed_24h=24,
        estimated_sets_24h=72,
        pending_pain_alerts_count=1,
        recent_pain_alerts=[alert],
        inactive_students_count=1,
        inactive_students=[card],
        total_students=10,
        active_students_this_week=9,
        retention_rate=90,
    )
    assert resp.estimated_sets_24h == 72
    assert resp.retention_rate == 90


@pytest.mark.asyncio
async def test_get_trainer_operational_cockpit_service():
    # 1. Registra evento de treino concluído nas últimas 24h
    ev_workout = StudentPulseEventCreate(
        student_id=STUDENT_UUID,
        student_name="Lucas Pereira",
        trainer_id=TRAINER_UUID,
        event_type="workout_completed",
        severity="success",
        title="Treino Superior Finalizado",
        description="Treino finalizado com sucesso",
        metadata={"completed_exercises": 8, "duration_min": 45},
    )
    await supabase_service.create_student_pulse_event(ev_workout)

    # 2. Registra alerta biomecânico pendente
    alert_create = BiomechanicalAlertCreate(
        student_id=STUDENT_UUID,
        student_name="Lucas Pereira",
        trainer_id=TRAINER_UUID,
        original_exercise="Supino Reto",
        adapted_exercise="Supino com Halteres",
        reason="Pinçamento no ombro anterior",
        pain_location="Ombro anterior",
        severity="Moderada",
    )
    await supabase_service.create_biomechanical_alert(alert_create)

    # 3. Adiciona aluno inativo (ausente há 6 dias)
    six_days_ago = (datetime.now(timezone.utc) - timedelta(days=6)).date().isoformat()
    supabase_service._mem_students[STUDENT_UUID] = {
        "id": STUDENT_UUID,
        "full_name": "Lucas Pereira",
        "email": "lucas@exemplo.com",
        "goal": "Hipertrofia",
        "status": "Ativo",
        "trainer_id": TRAINER_UUID,
        "phone": "11999998888",
        "subscription_status": "active",
        "streak_days": 2,
        "last_checkin_date": six_days_ago,
        "last_contacted_at": None,
        "created_at": (datetime.now(timezone.utc) - timedelta(days=30)).isoformat(),
    }

    try:
        cockpit = await supabase_service.get_trainer_operational_cockpit(TRAINER_UUID)

        assert cockpit.sessions_completed_24h >= 1
        assert cockpit.exercises_completed_24h >= 8
        assert cockpit.estimated_sets_24h == cockpit.exercises_completed_24h * 3
        assert cockpit.pending_pain_alerts_count >= 1
        assert len(cockpit.recent_pain_alerts) >= 1
        assert any(a.student_id == STUDENT_UUID for a in cockpit.recent_pain_alerts)

        # Verifica o radar de evasão
        assert cockpit.inactive_students_count >= 1
        inactive_item = next(s for s in cockpit.inactive_students if s.id == STUDENT_UUID)
        assert inactive_item.days_inactive >= 5
        assert "Lucas" in inactive_item.suggested_whatsapp_message
        assert inactive_item.contact_whatsapp_url is not None
        assert "wa.me" in inactive_item.contact_whatsapp_url
        assert not inactive_item.recently_contacted_48h

        # 4. Testa marcação de contato (trava anti-spam de 48h)
        contacted_res = await supabase_service.mark_student_contacted(STUDENT_UUID)
        assert contacted_res is True

        cockpit_after = await supabase_service.get_trainer_operational_cockpit(TRAINER_UUID)
        inactive_after = next(s for s in cockpit_after.inactive_students if s.id == STUDENT_UUID)
        assert inactive_after.recently_contacted_48h is True
    finally:
        supabase_service._mem_students.pop(STUDENT_UUID, None)



def test_operational_cockpit_fastapi_endpoints():
    app.dependency_overrides[get_current_trainer] = lambda: {
        "sub": TRAINER_UUID,
        "role": "trainer",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }

    try:
        # Acesso negado para treinador diferente
        denied_res = client.get(f"/api/v1/student-pulse/trainer/other-trainer-id/cockpit")
        assert denied_res.status_code == 403

        # Acesso permitido para o treinador autenticado
        ok_res = client.get(f"/api/v1/student-pulse/trainer/{TRAINER_UUID}/cockpit")
        assert ok_res.status_code == 200
        data = ok_res.json()

        assert "sessions_completed_24h" in data
        assert "exercises_completed_24h" in data
        assert "estimated_sets_24h" in data
        assert "pending_pain_alerts_count" in data
        assert "recent_pain_alerts" in data
        assert "inactive_students" in data
        assert "retention_rate" in data

        # Marcação de contato
        contact_res = client.post(f"/api/v1/student-pulse/students/{STUDENT_UUID}/contacted")
        assert contact_res.status_code == 200
        contact_data = contact_res.json()
        assert contact_data["success"] is True
        assert contact_data["student_id"] == STUDENT_UUID
    finally:
        app.dependency_overrides.pop(get_current_trainer, None)
