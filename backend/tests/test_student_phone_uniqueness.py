# backend/tests/test_student_phone_uniqueness.py
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.deps import get_current_trainer
from app.services.supabase_service import normalize_phone_digits, supabase_service

client = TestClient(app)

TRAINER_A = {
    "id": "11111111-1111-1111-1111-111111111111",
    "sub": "11111111-1111-1111-1111-111111111111",
    "email": "trainer.a@shaipados.com",
    "full_name": "Treinador Alpha",
    "role": "trainer",
}

TRAINER_B = {
    "id": "22222222-2222-2222-2222-222222222222",
    "sub": "22222222-2222-2222-2222-222222222222",
    "email": "trainer.b@shaipados.com",
    "full_name": "Treinadora Beta",
    "role": "trainer",
}


@pytest.fixture(autouse=True)
def reset_mem():
    """Reseta stores em memória e overrides antes de cada teste."""
    app.dependency_overrides.clear()
    supabase_service._mem_students.clear()
    supabase_service._mem_prescriptions.clear()
    supabase_service._mem_alerts.clear()
    yield
    app.dependency_overrides.clear()
    supabase_service._mem_students.clear()
    supabase_service._mem_prescriptions.clear()
    supabase_service._mem_alerts.clear()


def test_normalize_phone_digits():
    """Valida a normalização de números de telefone com DDI, DDD e pontuação."""
    assert normalize_phone_digits("+55 (11) 98888-7777") == "11988887777"
    assert normalize_phone_digits("5511988887777") == "11988887777"
    assert normalize_phone_digits("(11) 98888-7777") == "11988887777"
    assert normalize_phone_digits("11988887777") == "11988887777"
    assert normalize_phone_digits("98888-7777") == "988887777"
    assert normalize_phone_digits("") == ""
    assert normalize_phone_digits(None) == ""


def test_duplicate_phone_rejected_for_same_trainer():
    """Alunos com mesmo telefone no MESMO treinador devem ser bloqueados."""
    app.dependency_overrides[get_current_trainer] = lambda: TRAINER_A

    # 1. Cria primeiro aluno com telefone (11) 99999-1111
    r1 = client.post("/api/v1/workouts/students", json={
        "full_name": "Carlos Silva",
        "email": "carlos.silva@teste.com",
        "phone": "(11) 99999-1111",
        "goal": "Hipertrofia",
    })
    assert r1.status_code == 201

    # 2. Tenta criar segundo aluno com o MESMO telefone no mesmo treinador (com +55)
    r2 = client.post("/api/v1/workouts/students", json={
        "full_name": "Marcos Silva",
        "email": "marcos.silva@teste.com",
        "phone": "+55 11 99999-1111",
        "goal": "Emagrecimento",
    })
    assert r2.status_code == 400
    assert "Já existe um aluno" in r2.json()["detail"]
    assert "Carlos Silva" in r2.json()["detail"]


def test_same_phone_allowed_for_different_trainers():
    """O mesmo telefone DEVE ser permitido quando os treinadores forem DISTINTOS."""
    # Aluno se cadastra com o Treinador A (ex: Musculação)
    app.dependency_overrides[get_current_trainer] = lambda: TRAINER_A
    r1 = client.post("/api/v1/workouts/students", json={
        "full_name": "Mariana Lima",
        "email": "mariana.musculacao@teste.com",
        "phone": "(21) 98888-2222",
        "goal": "Hipertrofia",
    })
    assert r1.status_code == 201

    # A MESMA Mariana se cadastra com a Treinadora B (ex: Pilates / Reabilitação) com o mesmo WhatsApp
    app.dependency_overrides[get_current_trainer] = lambda: TRAINER_B
    r2 = client.post("/api/v1/workouts/students", json={
        "full_name": "Mariana Lima",
        "email": "mariana.pilates@teste.com",
        "phone": "+55 21 98888-2222",
        "goal": "Mobilidade e Postura",
    })
    assert r2.status_code == 201
    assert r2.json()["full_name"] == "Mariana Lima"


def test_update_student_phone_conflict_validation():
    """Ao atualizar telefone, não permitir conflito com outro aluno do mesmo treinador."""
    app.dependency_overrides[get_current_trainer] = lambda: TRAINER_A

    # Aluno 1
    r1 = client.post("/api/v1/workouts/students", json={
        "full_name": "Aluno Um",
        "email": "aluno1@teste.com",
        "phone": "11911111111",
        "goal": "Hipertrofia",
    })
    assert r1.status_code == 201
    sid1 = r1.json()["id"]

    # Aluno 2
    r2 = client.post("/api/v1/workouts/students", json={
        "full_name": "Aluno Dois",
        "email": "aluno2@teste.com",
        "phone": "11922222222",
        "goal": "Força",
    })
    assert r2.status_code == 201
    sid2 = r2.json()["id"]

    # 1. Aluno 1 atualiza o próprio telefone para o mesmo número -> Permitido
    up1 = client.put(f"/api/v1/workouts/students/{sid1}", json={
        "phone": "+55 11 91111-1111"
    })
    assert up1.status_code == 200

    # 2. Aluno 2 tenta mudar seu telefone para o número do Aluno 1 -> Bloqueado
    up2 = client.put(f"/api/v1/workouts/students/{sid2}", json={
        "phone": "(11) 91111-1111"
    })
    assert up2.status_code == 400
    assert "Já existe outro aluno" in up2.json()["detail"]


def test_invite_rejects_active_student_phone():
    """Enviar convite para telefone que já é aluno ativo do treinador deve ser rejeitado."""
    app.dependency_overrides[get_current_trainer] = lambda: TRAINER_A

    # Cadastra aluno ativo
    r1 = client.post("/api/v1/workouts/students", json={
        "full_name": "Juliana Mendes",
        "email": "juliana@teste.com",
        "phone": "11977778888",
        "goal": "Emagrecimento",
    })
    assert r1.status_code == 201

    # Tenta enviar convite via WhatsApp para o mesmo telefone
    inv = client.post("/api/v1/workouts/students/invite", json={
        "full_name": "Juliana Mendes",
        "email": "juliana.nova@teste.com",
        "phone": "(11) 97777-8888",
        "channel": "whatsapp",
        "objective": "Emagrecimento",
    })
    assert inv.status_code == 400
    assert "já possui este telefone" in inv.json()["detail"] or "já existe" in inv.json()["detail"].lower()
