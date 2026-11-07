import pytest
import jwt
from datetime import datetime, timezone
from fastapi.testclient import TestClient

from app.main import app
from app.core.config import settings
from app.services.supabase_service import supabase_service

settings.ENVIRONMENT = "development"
client = TestClient(app)

TRAINER_ID = "dev-user-0000-0000-000000000001"
STUDENT_ID = "00000000-0000-0000-0000-000000000002"
TRAINER_TOKEN = jwt.encode(
    {"sub": TRAINER_ID, "role": "trainer", "email": "coach@shaipados.com"},
    settings.SUPABASE_JWT_SECRET or "dev-insecure-secret-key-for-testing-only-12345",
    algorithm="HS256",
)
AUTH_HEADERS = {"Authorization": f"Bearer {TRAINER_TOKEN}"}


@pytest.fixture(autouse=True)
def setup_biohub_state():
    supabase_service._mem_students[STUDENT_ID] = {
        "id": STUDENT_ID,
        "full_name": "Carlos Aluno Bio",
        "email": "carlos@shaipados.com",
        "trainer_id": TRAINER_ID,
        "goal": "Hipertrofia Muscular",
        "status": "Ativo",
        "created_at": "2026-11-07T00:00:00Z",
    }
    supabase_service._mem_student_biometrics[STUDENT_ID] = []
    supabase_service._mem_exercise_loads = []
    yield
    supabase_service._mem_students.pop(STUDENT_ID, None)


def test_get_student_readiness_default():
    response = client.get(
        f"/api/v1/biohub/students/{STUDENT_ID}/readiness",
        headers=AUTH_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert "score" in data
    assert 0 <= data["score"] <= 100
    assert "level" in data
    assert "headline" in data
    assert "recommendation" in data


def test_post_daily_biometrics_and_impact_on_readiness():
    # Envia log com sono deprimido e dor articular
    log_payload = {
        "sleep_hours": 4.5,
        "sleep_quality": 2,
        "perceived_stress": 4,
        "soreness_level": 4,
        "has_joint_pain": True,
        "notes": "Noite péssima e dor no joelho",
    }
    post_res = client.post(
        f"/api/v1/biohub/students/{STUDENT_ID}/daily-log",
        json=log_payload,
        headers=AUTH_HEADERS,
    )
    assert post_res.status_code == 200
    saved_log = post_res.json()
    assert saved_log["has_joint_pain"] is True

    # Consulta histórico
    hist_res = client.get(
        f"/api/v1/biohub/students/{STUDENT_ID}/biometrics",
        headers=AUTH_HEADERS,
    )
    assert hist_res.status_code == 200
    logs = hist_res.json()
    assert len(logs) >= 1
    assert logs[0]["sleep_hours"] == 4.5

    # Consulta score recalculado (deve refletir a queda de sono e dor articular)
    readiness_res = client.get(
        f"/api/v1/biohub/students/{STUDENT_ID}/readiness",
        headers=AUTH_HEADERS,
    )
    assert readiness_res.status_code == 200
    r_data = readiness_res.json()
    assert r_data["score"] < 60
    assert r_data["level"] in ("low", "critical")
    assert r_data["joint_factor"] == -15.0


def test_record_load_and_strength_evolution():
    # Registra carga no Supino Reto (100kg x 5 reps)
    load_payload = {
        "exercise_name": "Supino Reto com Barra",
        "load_kg": 100.0,
        "reps": 5,
        "recorded_at": datetime.now(timezone.utc).isoformat(),
    }
    rec_res = client.post(
        f"/api/v1/biohub/students/{STUDENT_ID}/record-load",
        json=load_payload,
        headers=AUTH_HEADERS,
    )
    assert rec_res.status_code == 200
    assert rec_res.json()["status"] == "success"

    # Registra nova carga no Supino com PR maior (110kg x 5 reps)
    client.post(
        f"/api/v1/biohub/students/{STUDENT_ID}/record-load",
        json={
            "exercise_name": "Supino Reto com Barra",
            "load_kg": 110.0,
            "reps": 5,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        },
        headers=AUTH_HEADERS,
    )

    # Consulta evolução de força
    evol_res = client.get(
        f"/api/v1/biohub/students/{STUDENT_ID}/strength-evolution",
        headers=AUTH_HEADERS,
    )
    assert evol_res.status_code == 200
    evol_data = evol_res.json()
    assert evol_data["prs_count"] >= 1
    assert evol_data["total_volume_7d_kg"] > 0
    assert "supino" in evol_data["key_lifts"]
    supino_pr = evol_data["key_lifts"]["supino"]
    assert supino_pr["weight_kg"] == 110.0
    assert supino_pr["estimated_1rm"] > 110.0


def test_muscle_recovery_after_recording_exercise():
    # Registra exercício de peito
    client.post(
        f"/api/v1/biohub/students/{STUDENT_ID}/record-load",
        json={
            "exercise_name": "Supino Inclinado com Halteres",
            "load_kg": 32.0,
            "reps": 10,
            "recorded_at": datetime.now(timezone.utc).isoformat(),
        },
        headers=AUTH_HEADERS,
    )

    recov_res = client.get(
        f"/api/v1/biohub/students/{STUDENT_ID}/muscle-recovery",
        headers=AUTH_HEADERS,
    )
    assert recov_res.status_code == 200
    recov_data = recov_res.json()
    assert "muscles" in recov_data
    assert len(recov_data["muscles"]) == 6

    # O grupo peitoral deve estar em processo de recuperação/fadiga recente
    chest_item = next(m for m in recov_data["muscles"] if m["muscle_group"] == "chest")
    assert chest_item["recovery_percentage"] < 50
    assert chest_item["status"] in ("fatigued", "recovering")
    assert chest_item["hours_until_recovered"] > 0


def test_trainer_fatigue_radar():
    radar_res = client.get(
        f"/api/v1/biohub/trainers/{TRAINER_ID}/fatigue-radar",
        headers=AUTH_HEADERS,
    )
    assert radar_res.status_code == 200
    radar_data = radar_res.json()
    assert "total_students" in radar_data
    assert "high_readiness_count" in radar_data
    assert "students_summary" in radar_data
