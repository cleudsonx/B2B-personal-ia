import pytest
from app.services.payment_service import PaymentProviderService
from app.api.v1.endpoints.subscriptions import SAAS_PLANS


def test_saas_plans_structure():
    assert len(SAAS_PLANS) == 3
    plan_ids = [p.id for p in SAAS_PLANS]
    assert "starter" in plan_ids
    assert "pro" in plan_ids
    assert "studio" in plan_ids

    # Pro plan assertions
    pro = next(p for p in SAAS_PLANS if p.id == "pro")
    assert pro.price_monthly_cents == 8900
    assert pro.max_students == 30
    assert pro.max_ai_generations_per_month == -1


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
