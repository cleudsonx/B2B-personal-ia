import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient

from app.main import app
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_trainer

client = TestClient(app)

TRAINER_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_1 = "00000000-0000-0000-0000-000000000002"
STUDENT_2 = "00000000-0000-0000-0000-000000000003"


@pytest.fixture(autouse=True)
def setup_prs_data():
    now = datetime.now(timezone.utc)
    ten_days_ago = (now - timedelta(days=10)).isoformat()
    two_days_ago = (now - timedelta(days=2)).isoformat()
    three_days_ago = (now - timedelta(days=3)).isoformat()

    supabase_service._mem_students[STUDENT_1] = {
        "id": STUDENT_1,
        "full_name": "Carlos Silva",
        "name": "Carlos Silva",
        "email": "carlos@shaipados.com",
        "phone": "5511999991111",
        "trainer_id": TRAINER_ID,
        "role": "client",
        "subscription_status": "active",
        "streak_days": 7,
        "last_checkin_date": two_days_ago,
        "created_at": ten_days_ago,
    }
    supabase_service._mem_students[STUDENT_2] = {
        "id": STUDENT_2,
        "full_name": "Ana Beatriz",
        "name": "Ana Beatriz",
        "email": "ana@shaipados.com",
        "phone": "5511999992222",
        "trainer_id": TRAINER_ID,
        "role": "client",
        "subscription_status": "active",
        "streak_days": 12,
        "last_checkin_date": three_days_ago,
        "created_at": ten_days_ago,
    }
    supabase_service._mem_students[TRAINER_ID] = {
        "id": TRAINER_ID,
        "full_name": "Treinador Roberto",
        "name": "Treinador Roberto",
        "email": "roberto@shaipados.com",
        "phone": "5511988880000",
        "role": "trainer",
        "subscription_status": "active",
    }

    # Limpa cargas anteriores em memória
    supabase_service._mem_exercise_loads = []

    app.dependency_overrides[get_current_trainer] = lambda: {
        "sub": TRAINER_ID,
        "role": "trainer",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }

    yield

    supabase_service._mem_students.pop(STUDENT_1, None)
    supabase_service._mem_students.pop(STUDENT_2, None)
    supabase_service._mem_students.pop(TRAINER_ID, None)
    supabase_service._mem_exercise_loads = []
    app.dependency_overrides.pop(get_current_trainer, None)


@pytest.mark.asyncio
async def test_weekly_digest_pr_calculation():
    now = datetime.now(timezone.utc)
    ten_days_ago = (now - timedelta(days=10)).isoformat()
    two_days_ago = (now - timedelta(days=2)).isoformat()

    # Carlos: Carga antiga 80kg no Supino Reto -> Carga nova 85kg (+5kg PR)
    await supabase_service.record_exercise_load(
        client_id=STUDENT_1,
        exercise_name="Supino Reto",
        load_kg=80.0,
        recorded_at=ten_days_ago,
    )
    await supabase_service.record_exercise_load(
        client_id=STUDENT_1,
        exercise_name="Supino Reto",
        load_kg=85.0,
        recorded_at=two_days_ago,
    )

    # Ana: Carga nova 110kg no Agachamento Livre
    await supabase_service.record_exercise_load(
        client_id=STUDENT_2,
        exercise_name="Agachamento Livre",
        load_kg=110.0,
        recorded_at=two_days_ago,
    )

    data = await supabase_service.get_proactive_radar_and_weekly_digest(TRAINER_ID)
    digest = data["weekly_digest"]

    assert digest["personal_records_count"] >= 2
    prs = digest["personal_records"]

    carlos_pr = next(p for p in prs if p["student_id"] == STUDENT_1 and p["exercise_name"] == "Supino Reto")
    assert carlos_pr["load_kg"] == 85.0
    assert carlos_pr["previous_max_kg"] == 80.0
    assert carlos_pr["increase_kg"] == 5.0

    ana_pr = next(p for p in prs if p["student_id"] == STUDENT_2 and p["exercise_name"] == "Agachamento Livre")
    assert ana_pr["load_kg"] == 110.0

    # Valida presença na mensagem de texto enviada pelo WhatsApp
    msg = digest["digest_message"]
    assert "Recordes de Carga (PRs da Semana)" in msg
    assert "Carlos Silva: Supino Reto (85.0 kg • +5.0 kg! 🔥)" in msg
    assert "Ana Beatriz: Agachamento Livre (110.0 kg ⚡)" in msg
    assert "Top Consistência (Streaks)" in msg


def test_send_weekly_digest_endpoint():
    response = client.post(
        "/api/v1/whatsapp/send-weekly-digest",
        json={"trainer_phone": "5511988880000"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("sent", "fallback_wa")
    assert "digest_message" in data
    assert "Resumo Executivo Semanal" in data["digest_message"]
