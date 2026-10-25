import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.supabase_service import supabase_service
from app.schemas.student_pulse import StudentPulseEventCreate

client = TestClient(app)

TRAINER_UUID = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
STUDENT_UUID = "0b988373-cd16-404f-b02c-c5e1aac7ec3f"


def test_pulse_event_model():
    ev = StudentPulseEventCreate(
        student_id=STUDENT_UUID,
        student_name="Carlos Silva",
        trainer_id=TRAINER_UUID,
        event_type="pain_alert",
        severity="critical",
        title="Alerta de Dor no Ombro",
        description="Aluno relatou pinçamento no supino inclinado",
        metadata={"exercise": "Supino Inclinado", "pain_location": "Ombro direito"}
    )
    assert ev.student_name == "Carlos Silva"
    assert ev.event_type == "pain_alert"
    assert ev.severity == "critical"


@pytest.mark.asyncio
async def test_supabase_service_pulse_methods():
    ev_create = StudentPulseEventCreate(
        student_id=STUDENT_UUID,
        student_name="Mariana Souza",
        trainer_id=TRAINER_UUID,
        event_type="workout_completed",
        severity="success",
        title="Treino A Finalizado",
        description="Treino de 52 minutos com volume total de 4.200kg",
        metadata={"split": "A", "duration_min": 52}
    )
    created = await supabase_service.create_student_pulse_event(ev_create)
    assert created.id is not None
    assert created.student_name == "Mariana Souza"
    assert created.event_type == "workout_completed"
    assert not created.viewed_by_trainer

    # Listagem de eventos do treinador
    events = await supabase_service.list_trainer_pulse_events(TRAINER_UUID)
    assert any(e.id == created.id for e in events)

    # Sumário executivo
    summary = await supabase_service.get_trainer_pulse_summary(TRAINER_UUID)
    assert summary.total_events >= 1
    assert summary.workouts_completed_today >= 1

    # Marcação como visto
    ack_res = await supabase_service.mark_pulse_event_viewed(
        created.id,
        TRAINER_UUID,
        action_taken="whatsapp_contacted"
    )
    assert ack_res is True

    # Verifica se status atualizou
    updated_events = await supabase_service.list_trainer_pulse_events(TRAINER_UUID)
    target = next((e for e in updated_events if e.id == created.id), None)
    assert target is not None
    assert target.viewed_by_trainer is True
    assert target.action_taken == "whatsapp_contacted"
