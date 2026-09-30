import pytest
from app.services.payment_service import PaymentProviderService
from app.api.v1.endpoints.subscriptions import SAAS_PLANS


def test_saas_plans_structure():
    assert len(SAAS_PLANS) == 4
    plan_ids = [p.id for p in SAAS_PLANS]
    assert "starter" in plan_ids
    assert "pro" in plan_ids
    assert "elite" in plan_ids
    assert "studio" in plan_ids

    # Pro plan assertions
    pro = next(p for p in SAAS_PLANS if p.id == "pro")
    assert pro.price_monthly_cents == 8900
    assert pro.max_students == 30
    assert pro.max_ai_generations_per_month == -1

    # Elite plan assertions
    elite = next(p for p in SAAS_PLANS if p.id == "elite")
    assert elite.price_monthly_cents == 14900
    assert elite.max_students == 60
    assert elite.max_ai_generations_per_month == -1


def test_payment_service_multi_provider_checkout():
    # Asaas
    res_asaas = PaymentProviderService.create_checkout(
        provider="asaas",
        plan_id="pro",
        plan_name="Personal Pro",
        amount_cents=8900,
        billing_interval="monthly",
        payment_method="pix",
        trainer_name="Carlos Personal",
        trainer_email="carlos@academia.com"
    )
    assert res_asaas["provider"] == "asaas"
    assert res_asaas["status"] == "pending"
    assert res_asaas["pix_copy_paste"] is not None

    # InfinitePay
    res_inf = PaymentProviderService.create_checkout(
        provider="infinitepay",
        plan_id="pro",
        plan_name="Personal Pro",
        amount_cents=8900,
        billing_interval="monthly",
        payment_method="pix",
        trainer_name="Carlos Personal",
        trainer_email="carlos@academia.com"
    )
    assert res_inf["provider"] == "infinitepay"
    assert "infinitepay.io" in res_inf["checkout_url"]

    # Stripe
    res_stripe = PaymentProviderService.create_checkout(
        provider="stripe",
        plan_id="studio",
        plan_name="Studio Scale",
        amount_cents=19900,
        billing_interval="monthly",
        payment_method="credit_card",
        trainer_name="Carlos Personal",
        trainer_email="carlos@academia.com"
    )
    assert res_stripe["provider"] == "stripe"
    assert "stripe.com" in res_stripe["checkout_url"]


def test_payment_service_webhooks():
    # Asaas webhook
    wh_asaas = PaymentProviderService.process_webhook("asaas", {"event": "PAYMENT_RECEIVED", "trainer_id": "tr-1"})
    assert wh_asaas["subscription_status"] == "active"

    # InfinitePay webhook
    wh_inf = PaymentProviderService.process_webhook("infinitepay", {"event": "transaction.approved", "trainer_id": "tr-2"})
    assert wh_inf["subscription_status"] == "active"

    # Stripe webhook
    wh_stripe = PaymentProviderService.process_webhook("stripe", {"type": "checkout.session.completed", "trainer_id": "tr-3"})
    assert wh_stripe["subscription_status"] == "active"


def test_plan_upgrade_calculation_and_proration():
    # Upgrade Starter (grátis) -> Pro (R$ 89,00)
    res = PaymentProviderService.calculate_plan_change(
        current_plan_id="starter",
        new_plan_id="pro",
        billing_interval="monthly",
        days_used_in_cycle=10,
        total_days_in_cycle=30,
        active_students_count=2,
    )
    assert res["change_type"] == "upgrade"
    assert res["is_blocked"] is False
    assert res["unused_credit_cents"] == 0
    assert res["net_charge_cents"] == 8900
    assert res["new_student_limit"] == 30

    # Upgrade Pro (R$ 89,00) -> Studio (R$ 199,00) no meio do ciclo (15 dias restantes de 30)
    res_studio = PaymentProviderService.calculate_plan_change(
        current_plan_id="pro",
        new_plan_id="studio",
        billing_interval="monthly",
        days_used_in_cycle=15,
        total_days_in_cycle=30,
        active_students_count=15,
    )
    assert res_studio["change_type"] == "upgrade"
    assert res_studio["is_blocked"] is False
    # Crédito de 15 dias de Pro (8900 / 30 * 15 = 4450)
    assert res_studio["unused_credit_cents"] == 4450
    # Valor líquido a pagar = 19900 - 4450 = 15450
    assert res_studio["net_charge_cents"] == 15450
    assert res_studio["new_student_limit"] == 100


def test_plan_downgrade_validation():
    # Downgrade permitido: Pro -> Starter com apenas 2 alunos ativos (limite Starter é 3)
    res_allowed = PaymentProviderService.calculate_plan_change(
        current_plan_id="pro",
        new_plan_id="starter",
        billing_interval="monthly",
        days_used_in_cycle=15,
        total_days_in_cycle=30,
        active_students_count=2,
    )
    assert res_allowed["change_type"] == "downgrade"
    assert res_allowed["is_blocked"] is False
    assert res_allowed["net_charge_cents"] == 0
    assert "fim do ciclo" in res_allowed["effective_date"].lower()

    # Downgrade bloqueado por integridade: Pro -> Starter com 12 alunos ativos (limite Starter é 3)
    res_blocked = PaymentProviderService.calculate_plan_change(
        current_plan_id="pro",
        new_plan_id="starter",
        billing_interval="monthly",
        days_used_in_cycle=10,
        total_days_in_cycle=30,
        active_students_count=12,
    )
    assert res_blocked["change_type"] == "downgrade"
    assert res_blocked["is_blocked"] is True
    assert "Desative ou arquive pelo menos 9" in res_blocked["block_reason"]
    assert res_blocked["net_charge_cents"] == 0


def test_activate_plan_endpoint():
    from fastapi.testclient import TestClient
    from app.main import app

    client = TestClient(app)

    # 1. Ativa plano Elite Coach
    res = client.post("/api/v1/subscriptions/activate-plan", json={
        "plan_id": "elite",
        "billing_interval": "yearly",
        "payment_method": "pix",
        "trainer_id": "trainer-test-123"
    })
    assert res.status_code == 200
    data = res.json()
    assert data["plan_id"] == "elite"
    assert data["plan_name"] == "Elite Coach"
    assert data["max_students"] == 60
    assert data["billing_interval"] == "yearly"

    # 2. Consulta my-subscription para o mesmo trainer_id
    res_get = client.get("/api/v1/subscriptions/my-subscription?trainer_id=trainer-test-123")
    assert res_get.status_code == 200
    data_get = res_get.json()
    assert data_get["plan_id"] == "elite"
    assert data_get["plan_name"] == "Elite Coach"
    assert data_get["max_students"] == 60

    # 3. Consulta my-subscription sem query param (fallback current-trainer) deve refletir o plano ativado
    res_fallback = client.get("/api/v1/subscriptions/my-subscription")
    assert res_fallback.status_code == 200
    data_fb = res_fallback.json()
    assert data_fb["plan_id"] == "elite"
    assert data_fb["plan_name"] == "Elite Coach"
    assert data_fb["max_students"] == 60

    # 4. Ativação do plano Studio Scale para outro ID
    res_studio = client.post("/api/v1/subscriptions/activate-plan", json={
        "plan_id": "studio",
        "billing_interval": "monthly",
        "payment_method": "credit_card",
        "trainer_id": "trainer-studio-999"
    })
    assert res_studio.status_code == 200
    assert res_studio.json()["plan_id"] == "studio"
    assert res_studio.json()["max_students"] == 100

    # 5. Consulta sem parâmetro agora reflete Studio Scale
    res_studio_fb = client.get("/api/v1/subscriptions/my-subscription")
    assert res_studio_fb.status_code == 200
    assert res_studio_fb.json()["plan_id"] == "studio"
    assert res_studio_fb.json()["max_students"] == 100


def test_plans_catalog_unified_source_of_truth():
    from app.core.plans import SAAS_PLANS, PLANS_INFO, PLANS_CATALOG

    assert len(PLANS_CATALOG) == 4
    assert len(SAAS_PLANS) == 4

    plans_by_id = {p.id: p for p in SAAS_PLANS}

    for pid in ("starter", "pro", "elite", "studio"):
        assert pid in PLANS_INFO
        assert pid in PLANS_CATALOG
        assert pid in plans_by_id

        p_obj = plans_by_id[pid]
        p_dict = PLANS_CATALOG[pid]

        assert p_obj.max_students == p_dict["max_students"]
        assert p_obj.price_monthly_cents == p_dict["monthly_cents"]
        assert p_obj.price_yearly_cents == p_dict["yearly_cents"]

    # Valida regras de IA (Starter limitado a 10; Pro/Elite/Studio ilimitados)
    assert plans_by_id["starter"].max_ai_generations_per_month == 10
    assert plans_by_id["pro"].max_ai_generations_per_month == -1
    assert plans_by_id["elite"].max_ai_generations_per_month == -1
    assert plans_by_id["studio"].max_ai_generations_per_month == -1


@pytest.mark.asyncio
async def test_ai_generation_limit_enforcement_on_starter_plan():
    from fastapi.testclient import TestClient
    from app.main import app
    from app.api.deps import get_current_user
    from app.services.supabase_service import supabase_service

    test_trainer_id = "trainer-starter-limit-test"

    # 1. Ativa o plano starter para o treinador
    sub = await supabase_service.activate_subscription(
        trainer_id=test_trainer_id,
        plan_id="starter",
        billing_interval="monthly",
        payment_method="pix"
    )
    assert sub.plan_id == "starter"
    assert sub.max_ai_generations == 10
    assert sub.can_generate_ai is True
    assert sub.ai_generations_used == 0

    # 2. Incrementa 10 gerações de IA consumidas
    for _ in range(10):
        supabase_service.increment_ai_generations(test_trainer_id)

    # 3. Consulta assinatura e valida bloqueio can_generate_ai = False
    sub_after = await supabase_service.get_trainer_subscription(test_trainer_id)
    assert sub_after.ai_generations_used >= 10
    assert sub_after.can_generate_ai is False

    # 4. Tenta invocar o endpoint /generate-plan com esse treinador
    client = TestClient(app)
    app.dependency_overrides[get_current_user] = lambda: {"sub": test_trainer_id, "role": "trainer"}
    try:
        res = client.post("/api/v1/workouts/generate-plan", json={
            "objective": "Hipertrofia",
            "training_level": "Iniciante",
            "days_per_week": 3,
            "workout_location": "Academia completa",
            "injuries_or_restrictions": "Nenhuma",
            "split_type": "Full Body",
        })
        assert res.status_code == 403
        assert "Limite de 10 gerações de IA por mês atingido" in res.json()["detail"]
        assert "upgrade para o plano Personal Pro" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_infinitepay_real_checkout_and_webhook_activation():
    from fastapi.testclient import TestClient
    from app.main import app
    from app.services.payment_service import PaymentProviderService

    client = TestClient(app)
    trainer_test_id = "trainer-infinitepay-flow-1"

    # 1. Cria sessão de checkout oficial da InfinitePay
    checkout_res = client.post("/api/v1/subscriptions/checkout-session", json={
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "infinitepay",
        "trainer_name": "Carlos Personal",
        "trainer_email": "carlos@sheipados.com",
        "trainer_id": trainer_test_id
    })
    assert checkout_res.status_code == 200
    data = checkout_res.json()
    session_id = data["session_id"]
    assert data["provider"] == "infinitepay"
    assert data["amount_cents"] == 8900
    assert "sheipados" in data["checkout_url"]
    assert "infinitepay.io" in data["checkout_url"]

    # 2. Simula disparo do webhook da InfinitePay com aprovação
    webhook_res = client.post("/api/v1/subscriptions/webhook/infinitepay", json={
        "order_nsu": session_id,
        "status": "approved",
        "success": True,
        "amount": 89.00,
        "handle": "sheipados"
    })
    assert webhook_res.status_code == 200
    wh_data = webhook_res.json()
    assert wh_data["processed"] is True
    assert wh_data["subscription_status"] == "active"
    assert wh_data["trainer_id"] == trainer_test_id
    assert wh_data["plan_id"] == "pro"

    # 3. Valida que a assinatura do personal foi ativada com sucesso
    sub_res = client.get(f"/api/v1/subscriptions/my-subscription?trainer_id={trainer_test_id}")
    assert sub_res.status_code == 200
    sub_data = sub_res.json()
    assert sub_data["plan_id"] == "pro"
    assert sub_data["plan_name"] == "Personal Pro"
    assert sub_data["status"] == "active"
    assert sub_data["max_students"] == 30




