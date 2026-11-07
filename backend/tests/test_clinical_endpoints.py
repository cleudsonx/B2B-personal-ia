import pytest
import jwt
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from app.services.supabase_service import supabase_service
from app.schemas.clinical import JointRegion, JointSeverity, JointRestriction, StudentClinicalProfile

client = TestClient(app)

TRAINER_ID = "dev-user-0000-0000-000000000001"
STUDENT_ID = "00000000-0000-0000-0000-000000000002"
TRAINER_TOKEN = jwt.encode(
    {"sub": TRAINER_ID, "role": "trainer", "email": "coach@shaipados.com"},
    settings.SUPABASE_JWT_SECRET or "dev-insecure-secret-key-for-testing-only-12345",
    algorithm="HS256"
)
AUTH_HEADERS = {"Authorization": f"Bearer {TRAINER_TOKEN}"}

SAMPLE_PLAN = {
    "workout_plan_title": "Treino Hipertrofia Teste",
    "notes_for_trainer": "Foco membros inferiores",
    "splits": [
        {
            "split_identifier": "A",
            "split_name": "Pernas Completo",
            "estimated_duration_min": 60,
            "exercises": [
                {
                    "order": 1,
                    "name": "Agachamento Livre com Barra nas Costas",
                    "target_muscle_group": "Quadríceps",
                    "sets": 4,
                    "reps": "8-10",
                    "rest_seconds": 90,
                    "notes": "Pesado",
                    "substitution_vector": "Dominante de joelho",
                },
                {
                    "order": 2,
                    "name": "Cadeira Extensora em Amplitude Total",
                    "target_muscle_group": "Quadríceps",
                    "sets": 3,
                    "reps": "12",
                    "rest_seconds": 60,
                    "notes": "Extensão máxima",
                    "substitution_vector": "Extensão isolada de joelho",
                },
            ],
        }
    ],
}


@pytest.fixture(autouse=True)
def setup_student():
    supabase_service._mem_students[STUDENT_ID] = {
        "id": STUDENT_ID,
        "full_name": "Carlos Aluno",
        "email": "carlos@shaipados.com",
        "trainer_id": TRAINER_ID,
        "goal": "Hipertrofia Muscular",
        "created_at": "2026-11-07T00:00:00Z",
        "injuries_or_restrictions": "Desconforto no ombro direito e condromalácia no joelho",
        "status": "Ativo",
    }
    yield
    supabase_service._mem_students.pop(STUDENT_ID, None)
    supabase_service._mem_clinical_profiles.pop(STUDENT_ID, None)


def test_get_clinical_catalog():
    res = client.get("/api/v1/clinical/catalog")
    assert res.status_code == 200
    data = res.json()
    assert "joints" in data
    joints = [j["joint"] for j in data["joints"]]
    assert "shoulder" in joints
    assert "knee" in joints
    assert "lumbar_spine" in joints


def test_safety_check_endpoint_with_direct_restrictions():
    payload = {
        "restrictions": [
            {
                "joint": "lumbar_spine",
                "severity": "severe",
                "conditions": ["Hérnia Discal"],
                "avoid_vectors": ["Compressão axial pesada"],
            }
        ],
        "workout_plan": SAMPLE_PLAN,
        "auto_apply_substitutes": True,
    }
    res = client.post("/api/v1/clinical/safety-check", json=payload, headers=AUTH_HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert data["is_safe"] is False
    assert data["overall_risk"] == "critical_danger"
    assert data["contraindications_count"] >= 1

    dangers = [d["exercise_name"] for d in data["dangerous_exercises"]]
    assert any("Agachamento Livre" in name for name in dangers)

    # Verifica se gerou o plano adaptado
    adapted = data["adapted_plan"]
    assert adapted is not None
    adapted_ex1 = adapted["splits"][0]["exercises"][0]
    assert "Agachamento Búlgaro" in adapted_ex1["name"] or "Leg Press" in adapted_ex1["name"]


def test_get_and_put_student_clinical_profile():
    # 1. GET Perfil retrocompatível (deve inferir ombro e joelho do texto em _mem_students)
    get_res = client.get(f"/api/v1/clinical/students/{STUDENT_ID}/profile", headers=AUTH_HEADERS)
    assert get_res.status_code == 200
    profile = get_res.json()
    assert profile["student_id"] == STUDENT_ID
    assert len(profile["restrictions"]) >= 1

    # 2. PUT Atualização estruturada da matriz articular
    new_profile = {
        "student_id": STUDENT_ID,
        "restrictions": [
            {
                "joint": "knee",
                "severity": "severe",
                "conditions": ["Condromalácia Grau 3"],
                "avoid_vectors": ["Extensão terminal em cadeia aberta"],
                "notes": "Evitar cadeira extensora pesada",
            }
        ],
        "general_clinical_notes": "Acompanhamento fisioterápico em andamento",
        "risk_level": "high",
    }
    put_res = client.put(f"/api/v1/clinical/students/{STUDENT_ID}/profile", json=new_profile, headers=AUTH_HEADERS)
    assert put_res.status_code == 200
    updated = put_res.json()
    assert updated["risk_level"] == "high"
    assert len(updated["restrictions"]) == 1
    assert updated["restrictions"][0]["joint"] == "knee"

    # 3. Valida que o resumo textual no student foi atualizado
    mem_st = supabase_service._mem_students[STUDENT_ID]
    assert "Knee" in mem_st["injuries_or_restrictions"]

    # 4. Safety Check usando student_id (deve detectar a cadeira extensora automaticamente)
    check_res = client.post(
        "/api/v1/clinical/safety-check",
        json={"student_id": STUDENT_ID, "workout_plan": SAMPLE_PLAN, "auto_apply_substitutes": True},
        headers=AUTH_HEADERS,
    )
    assert check_res.status_code == 200
    check_data = check_res.json()
    assert check_data["is_safe"] is False
    dangerous_names = [d["exercise_name"] for d in check_data["dangerous_exercises"]]
    assert any("Extensora" in name for name in dangerous_names)
