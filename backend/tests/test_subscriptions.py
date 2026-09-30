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

