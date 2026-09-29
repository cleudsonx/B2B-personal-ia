import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

SAMPLE_PLAN = {
    "workout_plan_title": "Periodização Hipertrofia A/B",
    "notes_for_trainer": "Foco em peito e deltoides com restrição de ombro direito.",
    "splits": [
        {
            "split_identifier": "A",
            "split_name": "Peito e Tríceps",
            "estimated_duration_min": 50,
            "exercises": [
                {
                    "order": 1,
                    "name": "Supino Reto com Halteres",
                    "target_muscle_group": "Peitoral Maior",
                    "sets": 4,
                    "reps": "8-10",
                    "rest_seconds": 90,
                    "notes": "Escápulas retraídas.",
                    "substitution_vector": "Empurrar horizontal com halteres"
                }
            ]
        }
    ]
}


def test_student_creation_and_validation():
    # Email inválido
    bad_res = client.post("/api/v1/workouts/students", json={
        "full_name": "Aluno Teste",
        "email": "email_invalido_sem_arroba",
        "goal": "Emagrecimento"
    })
    assert bad_res.status_code == 400

    # Email válido
    good_res = client.post("/api/v1/workouts/students", json={
        "full_name": "João da Silva",
        "email": "joao.silva@exemplo.com",
        "phone": "(11) 97777-6666",
        "goal": "Hipertrofia Muscular"
    })
    assert good_res.status_code == 201
    data = good_res.json()
    assert data["full_name"] == "João da Silva"
    assert data["status"] == "Pendente Confirmação"
    assert data["has_active_prescription"] is False


def test_prescription_persistence_flow():
    # 1. Salva prescrição para o aluno st-1
    save_res = client.post("/api/v1/workouts/save-prescription", json={
        "client_id": "st-1",
        "trainer_id": "trainer-demo",
        "plan": SAMPLE_PLAN
    })
    assert save_res.status_code == 201
    saved_data = save_res.json()
    assert saved_data["is_active"] is True
    assert saved_data["splits_count"] == 1

    # 2. Aluno busca ficha ativa
    active_res = client.get("/api/v1/workouts/client/st-1/active")
    assert active_res.status_code == 200
    active_plan = active_res.json()
    assert active_plan["workout_plan_title"] == "Periodização Hipertrofia A/B"
    assert len(active_plan["splits"]) == 1
