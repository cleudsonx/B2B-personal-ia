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


@pytest.mark.asyncio
async def test_student_creation_fails_when_supabase_is_unavailable_in_production(monkeypatch):
    from app.core.config import settings
    from app.schemas.workout import StudentCreateRequest
    from app.services.supabase_service import SupabaseService

    service = SupabaseService()
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")

    async def no_supabase_client():
        return None

    monkeypatch.setattr(service, "get_client", no_supabase_client)

    with pytest.raises(RuntimeError, match="não foi persistido"):
        await service.create_student(
            "trainer-id",
            StudentCreateRequest(full_name="Aluno Teste", email="aluno@example.com"),
        )


@pytest.mark.asyncio
async def test_student_list_does_not_use_memory_when_production_database_is_empty(monkeypatch):
    from app.core.config import settings
    from app.services.supabase_service import SupabaseService

    class EmptyQuery:
        def select(self, *_args):
            return self

        def eq(self, *_args):
            return self

        def order(self, *_args, **_kwargs):
            return self

        async def execute(self):
            return type("Result", (), {"data": []})()

    class EmptyDatabase:
        def table(self, _table_name):
            return EmptyQuery()

    service = SupabaseService()
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    service._mem_students["stale-student"] = {
        "id": "stale-student",
        "full_name": "Aluno Antigo",
        "email": "antigo@example.com",
        "goal": "Hipertrofia",
        "trainer_id": "trainer-id",
        "created_at": "2026-01-01T00:00:00+00:00",
    }

    async def fake_get_client():
        return EmptyDatabase()

    monkeypatch.setattr(service, "get_client", fake_get_client)

    assert await service.list_students("631e76b9-3cb0-454f-8fd9-1d450e5560d6") == []


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


def test_student_update_archive_and_delete():
    # 1. Cria aluno
    create_res = client.post("/api/v1/workouts/students", json={
        "full_name": "Marcos Oliveira",
        "email": "marcos.oliveira@teste.com",
        "goal": "Condicionamento Geral"
    })
    assert create_res.status_code == 201
    st_id = create_res.json()["id"]

    # 2. Atualiza dados (editar aluno)
    update_res = client.put(f"/api/v1/workouts/students/{st_id}", json={
        "goal": "Hipertrofia Glúteos",
        "injuries_or_restrictions": "Condromalácia patelar",
        "phone": "(11) 91111-2222"
    })
    assert update_res.status_code == 200
    assert update_res.json()["goal"] == "Hipertrofia Glúteos"
    assert update_res.json()["injuries_or_restrictions"] == "Condromalácia patelar"

    # 3. Arquivar aluno
    archive_res = client.patch(f"/api/v1/workouts/students/{st_id}/status", json={
        "status": "Arquivado"
    })
    assert archive_res.status_code == 200
    assert archive_res.json()["status"] == "Arquivado"

    # 4. Excluir aluno
    del_res = client.delete(f"/api/v1/workouts/students/{st_id}")
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"


def test_biomechanical_alert_flow():
    # 1. Aluno registra alerta de dor articular no salão
    alert_res = client.post("/api/v1/workouts/adaptations/alert", json={
        "student_id": "st-1",
        "student_name": "Rodrigo Silveira",
        "trainer_id": "current-trainer",
        "original_exercise": "Supino Reto com Barra",
        "adapted_exercise": "Supino Máquina",
        "reason": "Desconforto ou Dor Articular",
        "pain_location": "Ombro Anterior",
        "severity": "Moderada"
    })
    assert alert_res.status_code == 201
    alert_data = alert_res.json()
    alert_id = alert_data["id"]
    assert alert_data["acknowledged"] is False

    # 2. Treinador lista alertas
    list_res = client.get("/api/v1/workouts/trainer/current-trainer/alerts")
    assert list_res.status_code == 200
    alerts = list_res.json()
    assert any(a["id"] == alert_id for a in alerts)

    # 3. Treinador marca como ciente
    ack_res = client.patch(f"/api/v1/workouts/alerts/{alert_id}/acknowledge")
    assert ack_res.status_code == 200
    assert ack_res.json()["acknowledged"] is True


def test_student_invitation_flow(monkeypatch):
    from app.services.email_service import email_service
    async def mock_send(*args, **kwargs):
        return {"status": "sent", "provider": "mock"}
    monkeypatch.setattr(email_service, "send_student_invitation_email", mock_send)

    # Treinador convida novo aluno com envio de e-mail e URL de WhatsApp
    invite_res = client.post("/api/v1/workouts/students/invite", json={
        "email": "novo.aluno@example.com",
        "full_name": "Gabriel Vasconcelos",
        "phone": "11988887777",
        "objective": "Hipertrofia Muscular",
        "injuries_or_restrictions": "Desconforto leve no manguito rotador",
        "send_email": True,
        "send_whatsapp": True,
    })
    assert invite_res.status_code == 201
    data = invite_res.json()
    assert data["status"] == "Pendente Confirmação"
    assert "onboarding" in data["invitation_link"]
    assert "wa.me/5511988887777" in data["whatsapp_url"]
    assert data["email_status"] in ("sent", "success")
    assert data["whatsapp_status"] in ("sent", "success", "ready_url")


def test_generate_workout_plan_multi_split():
    # 1. Full Body Split
    res_full_body = client.post("/api/v1/workouts/generate-plan", json={
        "objective": "Hipertrofia Muscular",
        "training_level": "Intermediário",
        "days_per_week": 3,
        "workout_location": "Academia completa",
        "split_type": "Full Body (1 a 3 dias - Corpo Inteiro)",
        "target_focus": "Glúteos & Posterior de Coxa",
        "injuries_or_restrictions": "Nenhuma dor relatada"
    })
    assert res_full_body.status_code == 200
    plan_fb = res_full_body.json()
    assert "splits" in plan_fb
    assert len(plan_fb["splits"]) >= 1

    # 2. Push Pull Legs Split
    res_ppl = client.post("/api/v1/workouts/generate-plan", json={
        "objective": "Hipertrofia Muscular",
        "training_level": "Avançado",
        "days_per_week": 5,
        "workout_location": "Academia completa",
        "split_type": "Push / Pull / Legs (PPL - 3 a 6 dias)",
        "target_focus": "Deltoides & Ombros 3D",
        "injuries_or_restrictions": "Leve estalido no ombro direito"
    })
    assert res_ppl.status_code == 200
    plan_ppl = res_ppl.json()
    assert len(plan_ppl["splits"]) >= 2


def test_assistant_chat_specialist_knowledge():
    # Testa consulta ao assistente com tópico de biomecânica/EMG
    res = client.post("/api/v1/assistant/chat", json={
        "prompt": "O que significa deltoide lateral 88% EMG e qual a diferença de torque entre halter e polia?",
        "model": "gemini-2.5-flash"
    })
    assert res.status_code == 200
    data = res.json()
    assert "text" in data
    assert len(data["text"]) > 50
    # Verifica que termos biomecânicos chave estão presentes
    assert "torque" in data["text"].lower() or "polia" in data["text"].lower() or "emg" in data["text"].lower()


def test_student_quota_enforcement_and_unarchive_blockage():
    """
    Testa a regra negocial estrita de limites de alunos por plano SaaS:
    - Plano Starter (limite 3 alunos)
    - Cadastra 3 alunos (cota cheia)
    - Tenta cadastrar o 4º -> Bloqueado (403)
    - Arquiva os 3 alunos (vagas liberadas)
    - Cadastra 3 novos alunos (cota cheia novamente com 3)
    - Tenta reativar um dos alunos arquivados -> Bloqueado com 403 Forbidden
    - Arquiva 1 dos novos -> Reativação do arquivado agora é permitida (200)
    - Upgrade de plano para Personal Pro (limite 30) -> Permite expansão
    """
    from app.api.v1.endpoints.subscriptions import ACTIVE_TRAINER_SUBSCRIPTIONS
    from app.schemas.subscription import MySubscriptionResponse
    from app.api.v1.endpoints.workouts import _STUDENTS_STORE
    from datetime import datetime, timezone

    trainer_id = "trainer-starter-quota-test"

    # 1. Configura assinatura Starter (3 alunos)
    ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id] = MySubscriptionResponse(
        plan_id="starter",
        plan_name="Starter Trial",
        status="active",
        billing_interval="monthly",
        current_students=0,
        max_students=3,
        ai_generations_used=0,
        max_ai_generations=10,
        can_create_student=True,
        can_generate_ai=True,
    )

    # 2. Cadastra 3 alunos iniciais
    batch1_ids = []
    for i in range(1, 4):
        res = client.post("/api/v1/workouts/students", json={
            "full_name": f"Aluno Inicial {i}",
            "email": f"aluno.inicial.{i}@teste.com",
            "goal": "Hipertrofia",
            "trainer_id": trainer_id,
        })
        assert res.status_code == 201, res.text
        batch1_ids.append(res.json()["id"])

    # 3. Tentativa de cadastrar 4º aluno deve falhar (cota de 3 atingida)
    overflow_res = client.post("/api/v1/workouts/students", json={
        "full_name": "Aluno Excedente",
        "email": "aluno.excedente@teste.com",
        "goal": "Emagrecimento",
        "trainer_id": trainer_id,
    })
    assert overflow_res.status_code == 403
    assert "Limite de 3 alunos ativos atingido" in overflow_res.json()["detail"]

    # 4. Professor arquiva os 3 alunos iniciais
    for sid in batch1_ids:
        arch_res = client.patch(f"/api/v1/workouts/students/{sid}/status", json={"status": "Arquivado"})
        assert arch_res.status_code == 200
        assert arch_res.json()["status"] == "Arquivado"

    # 5. Com os 3 arquivados, cadastra 3 novos alunos
    batch2_ids = []
    for i in range(1, 4):
        res = client.post("/api/v1/workouts/students", json={
            "full_name": f"Aluno Novo {i}",
            "email": f"aluno.novo.{i}@teste.com",
            "goal": "Definição",
            "trainer_id": trainer_id,
        })
        assert res.status_code == 201, res.text
        batch2_ids.append(res.json()["id"])

    # 6. Tenta reativar um dos alunos antigos via PATCH /status -> DEVE SER BLOQUEADO (403)!
    unarchive_res = client.patch(
        f"/api/v1/workouts/students/{batch1_ids[0]}/status",
        json={"status": "Ativo"}
    )
    assert unarchive_res.status_code == 403
    assert "Não é possível reativar o aluno" in unarchive_res.json()["detail"]
    assert "3 alunos ativos" in unarchive_res.json()["detail"]

    # 7. Tenta reativar também via PUT /students/{id} -> DEVE SER BLOQUEADO (403)!
    put_unarchive_res = client.put(
        f"/api/v1/workouts/students/{batch1_ids[1]}",
        json={"status": "Ativo", "goal": "Reabilitação"}
    )
    assert put_unarchive_res.status_code == 403
    assert "Não é possível reativar o aluno" in put_unarchive_res.json()["detail"]

    # 8. Arquiva um aluno do segundo lote (liberando 1 vaga ativa)
    free_slot_res = client.patch(
        f"/api/v1/workouts/students/{batch2_ids[0]}/status",
        json={"status": "Arquivado"}
    )
    assert free_slot_res.status_code == 200

    # 9. Agora a reativação do aluno antigo tem vaga e deve ser aceita com sucesso (200)
    reactivate_ok = client.patch(
        f"/api/v1/workouts/students/{batch1_ids[0]}/status",
        json={"status": "Ativo"}
    )
    assert reactivate_ok.status_code == 200
    assert reactivate_ok.json()["status"] == "Ativo"

    # 10. Upgrade de plano para Personal Pro (30 alunos)
    ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id] = MySubscriptionResponse(
        plan_id="pro",
        plan_name="Personal Pro",
        status="active",
        billing_interval="monthly",
        current_students=3,
        max_students=30,
        ai_generations_used=0,
        max_ai_generations=-1,
        can_create_student=True,
        can_generate_ai=True,
    )

    # 11. Agora reativa os demais arquivados sem impedimento
    reactivate_pro = client.patch(
        f"/api/v1/workouts/students/{batch1_ids[1]}/status",
        json={"status": "Ativo"}
    )
    assert reactivate_pro.status_code == 200
    assert reactivate_pro.json()["status"] == "Ativo"



