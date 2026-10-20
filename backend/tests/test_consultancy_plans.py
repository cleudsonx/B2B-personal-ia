# backend/tests/test_consultancy_plans.py
# FASE 6: Testes do Passo 1 (Backend & Banco) - Planos de Consultoria e Checkout Público

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.api.deps import get_current_trainer
from app.services.consultancy_plan_service import ConsultancyPlanService

client = TestClient(app)

MOCK_TRAINER = {
    "id": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
    "sub": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
    "email": "cleudsonx@gmail.com",
    "full_name": "Cleudson Cavalcante",
    "role": "trainer",
}


@pytest.fixture(autouse=True)
def override_auth_and_clean():
    app.dependency_overrides[get_current_trainer] = lambda: MOCK_TRAINER
    ConsultancyPlanService._mem_plans.clear()
    yield
    app.dependency_overrides.clear()
    ConsultancyPlanService._mem_plans.clear()


def test_create_and_list_consultancy_plans():
    """Treinador pode cadastrar e listar seus planos de consultoria."""
    # 1. Cria plano
    payload = {
        "name": "Consultoria VIP Presencial",
        "description": "Treino individualizado com acompanhamento semanal",
        "price_cents": 25000,  # R$ 250,00
        "billing_period": "monthly",
        "features": ["Treino semanal", "Suporte VIP", "App liberado"],
        "is_active": True,
        "sort_order": 1,
    }
    r = client.post("/api/v1/trainers/consultancy-plans", json=payload)
    assert r.status_code == 201
    data = r.json()
    assert data["name"] == "Consultoria VIP Presencial"
    assert data["price_cents"] == 25000
    assert data["billing_period"] == "monthly"
    plan_id = data["id"]

    # 2. Lista planos
    r_list = client.get("/api/v1/trainers/consultancy-plans")
    assert r_list.status_code == 200
    plans = r_list.json()
    assert len(plans) >= 1
    assert any(p["id"] == plan_id for p in plans)


def test_update_consultancy_plan():
    """Treinador pode alterar preço, nome e status do plano."""
    # Cria
    r = client.post("/api/v1/trainers/consultancy-plans", json={
        "name": "Plano Teste",
        "price_cents": 12000,
        "billing_period": "monthly",
    })
    assert r.status_code == 201
    plan_id = r.json()["id"]

    # Atualiza preço
    r_up = client.put(f"/api/v1/trainers/consultancy-plans/{plan_id}", json={
        "price_cents": 16000,
        "name": "Plano Teste Atualizado",
    })
    assert r_up.status_code == 200
    assert r_up.json()["price_cents"] == 16000
    assert r_up.json()["name"] == "Plano Teste Atualizado"


def test_delete_consultancy_plan():
    """Treinador pode excluir um plano de consultoria."""
    r = client.post("/api/v1/trainers/consultancy-plans", json={
        "name": "Plano Descartável",
        "price_cents": 10000,
        "billing_period": "one_time",
    })
    plan_id = r.json()["id"]

    r_del = client.delete(f"/api/v1/trainers/consultancy-plans/{plan_id}")
    assert r_del.status_code == 200
    assert r_del.json()["ok"] is True


def test_public_list_trainer_plans():
    """Vitrine pública retorna os planos ativos de um treinador pelo username."""
    # Cria plano ativo
    client.post("/api/v1/trainers/consultancy-plans", json={
        "name": "Plano Vitrine Ativo",
        "price_cents": 15000,
        "billing_period": "monthly",
        "is_active": True,
    })

    # Consulta pública
    r = client.get("/api/v1/public/trainers/mrcoach/plans")
    assert r.status_code == 200
    plans = r.json()
    assert isinstance(plans, list)
    assert len(plans) >= 1


def test_public_checkout_pix_generation():
    """Aluno pode realizar checkout na vitrine do treinador gerando Pix com QR Code."""
    # 1. Cria plano para checkout
    r_plan = client.post("/api/v1/trainers/consultancy-plans", json={
        "name": "Consultoria Mensal Checkout",
        "price_cents": 18000,  # R$ 180,00
        "billing_period": "monthly",
        "is_active": True,
    })
    plan_id = r_plan.json()["id"]

    # 2. Checkout público
    checkout_payload = {
        "plan_id": plan_id,
        "student_name": "Marcos Andrade",
        "student_email": "marcos.andrade@teste.com",
        "student_phone": "(11) 97777-6666",
        "student_cpf": "123.456.789-00",
        "payment_method": "PIX",
    }
    r_check = client.post("/api/v1/public/trainers/mrcoach/checkout", json=checkout_payload)
    assert r_check.status_code == 201
    res = r_check.json()
    assert res["status"] == "pending"
    assert res["payment_method"] == "PIX"
    assert res["amount_cents"] == 18000
    # Taxa de 5% (R$ 9,00)
    assert res["platform_fee_cents"] == 900
    # Saldo líquido do personal de 95% (R$ 171,00)
    assert res["net_amount_cents"] == 17100
    assert res["pix_copy_paste"] is not None
    assert len(res["pix_copy_paste"]) > 20



def test_public_checkout_credit_card():
    """Aluno pode realizar checkout pagando diretamente com Cartão de Crédito."""
    r_plan = client.post("/api/v1/trainers/consultancy-plans", json={
        "name": "Consultoria Trimestral Card",
        "price_cents": 39000,  # R$ 390,00
        "billing_period": "quarterly",
        "is_active": True,
    })
    plan_id = r_plan.json()["id"]

    checkout_payload = {
        "plan_id": plan_id,
        "student_name": "Fernanda Lima",
        "student_email": "fernanda.lima@teste.com",
        "student_phone": "(11) 98888-4444",
        "payment_method": "CREDIT_CARD",
        "credit_card": {
            "holder_name": "Fernanda Lima",
            "number": "4111111111111111",
            "expiry_month": "12",
            "expiry_year": "2029",
            "ccv": "123",
            "holder_cpf": "12345678901",
        }
    }
    r_check = client.post("/api/v1/public/trainers/mrcoach/checkout", json=checkout_payload)
    assert r_check.status_code == 201
    res = r_check.json()
    assert res["status"] == "paid"
    assert res["payment_method"] == "CREDIT_CARD"
    assert res["amount_cents"] == 39000
    assert res["net_amount_cents"] == 37050  # 95%
    assert res["platform_fee_cents"] == 1950  # 5%
