import json
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.api.v1.endpoints import subscriptions as subs
from app.services.supabase_service import supabase_service


@pytest.fixture(autouse=True)
def reset_lease_state():
    supabase_service._mem_processed_events.clear()
    supabase_service._mem_subscriptions.clear()
    supabase_service._mem_checkout_sessions.clear()
    yield
    supabase_service._mem_processed_events.clear()
    supabase_service._mem_subscriptions.clear()
    supabase_service._mem_checkout_sessions.clear()


@pytest.fixture
def dummy_request():
    def _make(payload):
        request = SimpleNamespace(headers={"x-test":"value"})
        request.body = AsyncMock(return_value=json.dumps(payload).encode("utf-8"))
        return request

    return _make


@pytest.mark.asyncio
async def test_memory_lease_claim_busy_duplicate_and_complete():
    event_id = "evt-lease-001"
    payload = {"id": event_id, "event": "PAYMENT_RECEIVED"}

    first = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload=payload,
    )
    assert first["disposition"] == "claimed"
    assert first["event_id"] == event_id
    token = first["claim_token"]
    assert token

    second = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload=payload,
    )
    assert second["disposition"] == "busy"
    assert second["claim_token"] == token

    completion = await supabase_service.complete_subscription_webhook_v2(
        event_id=event_id,
        token=token,
        action="activate",
        trainer_id="631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        plan_id="pro",
        billing_interval="monthly",
        payment_method="asaas",
    )
    assert completion["disposition"] == "completed"

    duplicate = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload=payload,
    )
    assert duplicate["disposition"] == "duplicate"
    assert duplicate["claim_token"] == token


@pytest.mark.asyncio
async def test_release_with_wrong_token_does_not_modify_claim_and_correct_token_releases_retry():
    event_id = "evt-lease-002"
    payload = {"id": event_id, "event": "PAYMENT_RECEIVED"}

    claimed = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload=payload,
    )
    token = claimed["claim_token"]

    wrong_release = await supabase_service.release_webhook_event_v2(
        event_id=event_id,
        token="wrong-token",
        error="invalid_release_token",
    )
    assert wrong_release == {"released": False, "event_id": event_id, "claim_token": "wrong-token"}

    record = supabase_service._mem_processed_events[event_id]
    assert record["status"] == "processing"
    assert record["claim_token"] == token

    released = await supabase_service.release_webhook_event_v2(
        event_id=event_id,
        token=token,
        error="retryable_error",
    )
    assert released["released"] is True
    assert supabase_service._mem_processed_events[event_id]["status"] == "released"

    retry = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload=payload,
    )
    assert retry["disposition"] == "claimed"
    assert retry["claim_token"] != token
    assert supabase_service._mem_processed_events[event_id]["attempts"] == 2


@pytest.mark.asyncio
async def test_release_reclaim_until_max_attempts_then_failed():
    event_id = "evt-lease-003"
    supabase_service._mem_processed_events[event_id] = {
        "event_id": event_id,
        "provider": "asaas",
        "event_type": "PAYMENT_RECEIVED",
        "status": "released",
        "payload": {"id": event_id},
        "claim_token": "old-token",
        "attempts": 4,
        "claimed_at": "2024-01-01T00:00:00+00:00",
        "lease_seconds": 300,
        "max_attempts": 5,
    }

    retry = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload={"id": event_id},
        max_attempts=5,
    )
    assert retry["disposition"] == "claimed"
    assert retry["claim_token"] != "old-token"
    assert supabase_service._mem_processed_events[event_id]["attempts"] == 5

    supabase_service._mem_processed_events[event_id]["status"] = "released"
    exhausted = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload={"id": event_id},
        max_attempts=5,
    )
    assert exhausted["disposition"] == "failed"
    assert exhausted["event_id"] == event_id


@pytest.mark.asyncio
async def test_complete_with_invalid_claim_token_no_mutation_and_valid_token_completes():
    event_id = "evt-lease-004"
    claimed = await supabase_service.claim_webhook_event(
        event_id=event_id,
        provider="asaas",
        event_type="PAYMENT_RECEIVED",
        payload={"id": event_id},
    )
    token = claimed["claim_token"]

    invalid = await supabase_service.complete_subscription_webhook_v2(
        event_id=event_id,
        token="wrong-token",
        action="activate",
        trainer_id="631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        plan_id="pro",
        billing_interval="monthly",
        payment_method="asaas",
    )
    assert invalid["disposition"] == "failed"
    assert invalid["error"] == "invalid_claim_token"
    assert supabase_service._mem_processed_events[event_id]["status"] == "processing"
    assert event_id not in supabase_service._mem_subscriptions

    valid = await supabase_service.complete_subscription_webhook_v2(
        event_id=event_id,
        token=token,
        action="activate",
        trainer_id="631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        plan_id="pro",
        billing_interval="monthly",
        payment_method="asaas",
    )
    assert valid["disposition"] == "completed"
    record = supabase_service._mem_processed_events[event_id]
    assert record["status"] == "completed"
    assert record["action"] == "activate"
    assert supabase_service._mem_subscriptions["631e76b9-3cb0-454f-8fd9-1d450e5560d6"]["status"] == "active"


@pytest.mark.asyncio
async def test_complete_paid_checkout_session_v2_missing_session_and_invalid_claim_do_not_mutate_state():
    session_id = "sess-missing-activity-001"
    event_id = "evt-missing-activity-001"
    token = str(uuid.uuid4())

    missing_result = await supabase_service.complete_paid_checkout_session_v2(
        session_id=None,
        event_id=event_id,
        claim_token=token,
    )
    assert missing_result["disposition"] == "failed"
    assert missing_result["error"] == "missing_session_id"

    absent_result = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=token,
    )
    assert absent_result["disposition"] == "failed"
    assert absent_result["error"] == "session_not_found"
    assert event_id not in supabase_service._mem_processed_events
    assert session_id not in supabase_service._mem_checkout_sessions

    valid_session = {
        "session_id": session_id,
        "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        "plan_id": "pro",
        "status": "pending",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
    }
    supabase_service._mem_checkout_sessions[session_id] = valid_session
    supabase_service._mem_processed_events[event_id] = {
        "event_id": event_id,
        "status": "processing",
        "claim_token": token,
        "payload": {"id": event_id},
    }

    invalid_pair = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=None,
    )
    assert invalid_pair["disposition"] == "failed"
    assert invalid_pair["error"] == "invalid_event_claim_pair"
    assert supabase_service._mem_processed_events[event_id]["status"] == "processing"
    assert supabase_service._mem_checkout_sessions[session_id]["status"] == "pending"

    wrong_claim = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=str(uuid.uuid4()),
    )
    assert wrong_claim["disposition"] == "failed"
    assert wrong_claim["error"] == "invalid_claim_token"
    assert supabase_service._mem_processed_events[event_id]["status"] == "processing"
    assert supabase_service._mem_checkout_sessions[session_id]["status"] == "pending"
    assert supabase_service._mem_subscriptions == {}


@pytest.mark.asyncio
async def test_complete_paid_checkout_session_v2_pending_valid_claim_marks_paid_and_event_completed():
    session_id = "sess-complete-001"
    trainer_id = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
    event_id = "evt-complete-001"
    claim_token = str(uuid.uuid4())
    supabase_service._mem_checkout_sessions[session_id] = {
        "session_id": session_id,
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "status": "pending",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
        "paid": False,
    }
    supabase_service._mem_processed_events[event_id] = {
        "event_id": event_id,
        "status": "processing",
        "claim_token": claim_token,
        "payload": {"id": event_id},
    }

    result = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=claim_token,
        provider_payment_id="pay-001",
    )

    assert result["disposition"] == "completed"
    assert result["paid"] is True
    assert result["completed"] is True
    session = supabase_service._mem_checkout_sessions[session_id]
    assert session["status"] == "paid"
    assert session["paid"] is True
    assert session["provider_payment_id"] == "pay-001"
    assert supabase_service._mem_processed_events[event_id]["status"] == "completed"
    assert supabase_service._mem_processed_events[event_id]["claim_token"] is None
    assert supabase_service._mem_subscriptions[trainer_id]["status"] == "active"


@pytest.mark.asyncio
async def test_complete_paid_checkout_session_v2_is_idempotent_for_paid_session_without_resetting_subscription_periods():
    session_id = "sess-paid-idempotent-001"
    trainer_id = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
    event_id = "evt-paid-idempotent-001"
    claim_token = str(uuid.uuid4())
    initial_start = "2025-01-01T00:00:00+00:00"
    initial_end = "2025-02-01T00:00:00+00:00"
    initial_updated = "2025-01-15T00:00:00+00:00"
    supabase_service._mem_subscriptions[trainer_id] = {
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "status": "active",
        "billing_interval": "monthly",
        "current_period_start": initial_start,
        "current_period_end": initial_end,
        "updated_at": initial_updated,
    }
    supabase_service._mem_checkout_sessions[session_id] = {
        "session_id": session_id,
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "status": "paid",
        "paid": True,
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
    }
    supabase_service._mem_processed_events[event_id] = {
        "event_id": event_id,
        "status": "processing",
        "claim_token": claim_token,
    }

    result = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=claim_token,
        provider_payment_id="pay-002",
    )

    assert result["disposition"] == "completed"
    subscription = supabase_service._mem_subscriptions[trainer_id]
    assert subscription["current_period_start"] == initial_start
    assert subscription["current_period_end"] == initial_end
    assert subscription["updated_at"] == initial_updated
    assert supabase_service._mem_processed_events[event_id]["status"] == "completed"


@pytest.mark.asyncio
@pytest.mark.parametrize("failed_status", ["failed", "canceled", "expired"])
async def test_complete_paid_checkout_session_v2_rejects_failed_terminal_statuses_without_activating(failed_status):
    session_id = f"sess-{failed_status}-001"
    trainer_id = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
    event_id = f"evt-{failed_status}-001"
    claim_token = str(uuid.uuid4())
    supabase_service._mem_checkout_sessions[session_id] = {
        "session_id": session_id,
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "status": failed_status,
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
        "paid": False,
    }
    supabase_service._mem_processed_events[event_id] = {
        "event_id": event_id,
        "status": "processing",
        "claim_token": claim_token,
    }
    supabase_service._mem_subscriptions[trainer_id] = {
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "status": "active",
        "billing_interval": "monthly",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }

    result = await supabase_service.complete_paid_checkout_session_v2(
        session_id=session_id,
        event_id=event_id,
        claim_token=claim_token,
    )

    assert result["disposition"] == "failed"
    assert result["error"] == "checkout_session_status_not_activable"
    assert supabase_service._mem_processed_events[event_id]["status"] == "processing"
    assert supabase_service._mem_checkout_sessions[session_id]["status"] == failed_status
    assert supabase_service._mem_subscriptions[trainer_id]["status"] == "active"


@pytest.mark.asyncio
async def test_webhook_asaas_rejects_missing_event_id_before_claim(monkeypatch, dummy_request):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)

    claim_mock = AsyncMock()
    monkeypatch.setattr(subs.supabase_service, "claim_webhook_event", claim_mock)

    payload = {"event": "PAYMENT_RECEIVED", "payment": {"status": "RECEIVED"}}
    request = dummy_request(payload)

    with pytest.raises(subs.HTTPException) as exc:
        await subs.webhook_asaas(payload, request)

    assert exc.value.status_code == 400
    claim_mock.assert_not_called()


@pytest.mark.asyncio
@pytest.mark.parametrize("disposition", ["duplicate", "busy"])
async def test_webhook_asaas_duplicate_or_busy_omits_claim_token(monkeypatch, dummy_request, disposition):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)

    async def fake_process(*args, **kwargs):
        raise AssertionError("process_webhook should not run for duplicate/busy")

    monkeypatch.setattr(subs.PaymentProviderService, "process_webhook", staticmethod(fake_process))
    monkeypatch.setattr(
        subs.supabase_service,
        "claim_webhook_event",
        AsyncMock(return_value={"disposition": disposition, "claim_token": "hidden-token", "event_id": "evt-dup-001"}),
    )

    payload = {"id": "evt-dup-001", "event": "PAYMENT_RECEIVED", "payment": {"id": "pay-dup"}}
    request = dummy_request(payload)

    result = await subs.webhook_asaas(payload, request)

    assert result["processed"] is True
    assert result["idempotent"] is True
    assert result["disposition"] == disposition
    assert "claim_token" not in result


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("provider", "payload", "event_id", "handler"),
    [
        (
            "asaas",
            {"id": "evt-invalid-uuid-asaas", "event": "PAYMENT_RECEIVED", "payment": {"id": "pay-invalid-uuid"}},
            "evt-invalid-uuid-asaas",
            "asaas",
        ),
        (
            "infinitepay",
            {"event": "transaction.approved", "order_nsu": "txn-invalid-uuid", "status": "approved"},
            "infinitepay_transaction.approved_txn-invalid-uuid",
            "infinitepay",
        ),
    ],
)
async def test_webhook_invalid_uuid_releases_lease_and_returns_retryable(monkeypatch, dummy_request, provider, payload, event_id, handler):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)
    claim_token = "lease-token-invalid-uuid"
    monkeypatch.setattr(
        subs.supabase_service,
        "claim_webhook_event",
        AsyncMock(return_value={"disposition": "claimed", "claim_token": claim_token, "event_id": event_id}),
    )

    release_mock = AsyncMock(return_value={"released": True})
    monkeypatch.setattr(subs.supabase_service, "release_webhook_event_v2", release_mock)
    monkeypatch.setattr(
        subs.PaymentProviderService,
        "process_webhook",
        staticmethod(lambda provider, payload: {"subscription_status": "active", "trainer_id": "not-a-uuid", "plan_id": "pro", "billing_interval": "monthly"}),
    )

    request = dummy_request(payload)

    with pytest.raises(subs.HTTPException) as exc:
        if handler == "asaas":
            await subs.webhook_asaas(payload, request)
        else:
            await subs.webhook_infinitepay(payload, request)

    assert exc.value.status_code == 503
    release_mock.assert_awaited_once_with(event_id=event_id, token=claim_token, error="invalid_trainer_id_uuid")


@pytest.mark.asyncio
async def test_webhook_asaas_missing_metadata_releases_and_returns_retryable(monkeypatch, dummy_request):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)
    monkeypatch.setattr(
        subs.supabase_service,
        "claim_webhook_event",
        AsyncMock(return_value={"disposition": "claimed", "claim_token": "lease-token-1", "event_id": "evt-metadata"}),
    )

    release_mock = AsyncMock(return_value={"released": True})
    monkeypatch.setattr(subs.supabase_service, "release_webhook_event_v2", release_mock)

    monkeypatch.setattr(
        subs.PaymentProviderService,
        "process_webhook",
        staticmethod(lambda provider, payload: {"subscription_status": "active", "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6", "plan_id": ""}),
    )

    payload = {"id": "evt-metadata", "event": "PAYMENT_RECEIVED", "payment": {"id": "pay-missing"}}
    request = dummy_request(payload)

    with pytest.raises(subs.HTTPException) as exc:
        await subs.webhook_asaas(payload, request)

    assert exc.value.status_code == 503
    release_mock.assert_awaited_once_with(event_id="evt-metadata", token="lease-token-1", error="missing_plan_id")


@pytest.mark.asyncio
async def test_webhook_asaas_complete_failure_returns_retryable_and_releases(monkeypatch, dummy_request):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)
    monkeypatch.setattr(
        subs.supabase_service,
        "claim_webhook_event",
        AsyncMock(return_value={"disposition": "claimed", "claim_token": "lease-token-2", "event_id": "evt-complete-fail"}),
    )
    release_mock = AsyncMock(return_value={"released": True})
    monkeypatch.setattr(subs.supabase_service, "release_webhook_event_v2", release_mock)

    session_id = "sess-complete-fail-001"
    supabase_service._mem_checkout_sessions[session_id] = {
        "session_id": session_id,
        "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
        "status": "pending",
    }
    completion_mock = AsyncMock(return_value={
        "session_id": session_id,
        "event_id": "evt-complete-fail",
        "paid": False,
        "completed": False,
        "disposition": "failed",
        "error": "complete_paid_checkout_failed",
    })
    monkeypatch.setattr(subs.supabase_service, "complete_paid_checkout_session_v2", completion_mock)
    monkeypatch.setattr(
        subs.PaymentProviderService,
        "process_webhook",
        staticmethod(lambda provider, payload: {"subscription_status": "active", "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6", "plan_id": "pro"}),
    )

    payload = {
        "id": "evt-complete-fail",
        "event": "PAYMENT_RECEIVED",
        "payment": {"id": "pay-fail", "externalReference": session_id},
    }
    request = dummy_request(payload)

    with pytest.raises(subs.HTTPException) as exc:
        await subs.webhook_asaas(payload, request)

    assert exc.value.status_code == 503
    completion_mock.assert_awaited_once_with(
        session_id=session_id,
        event_id="evt-complete-fail",
        claim_token="lease-token-2",
        provider_payment_id="pay-fail",
    )
    release_mock.assert_awaited_once_with(event_id="evt-complete-fail", token="lease-token-2", error="complete_paid_checkout_failed")


@pytest.mark.asyncio
async def test_webhook_asaas_success_calls_complete_and_returns_provider_payload(monkeypatch, dummy_request):
    async def fake_verify(*args, **kwargs):
        return None

    monkeypatch.setattr(subs, "_verify_payment_webhook", fake_verify)
    monkeypatch.setattr(
        subs.supabase_service,
        "claim_webhook_event",
        AsyncMock(return_value={"disposition": "claimed", "claim_token": "lease-token-3", "event_id": "evt-success"}),
    )

    session_id = "sess-webhook-success-001"
    supabase_service._mem_checkout_sessions[session_id] = {
        "session_id": session_id,
        "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
        "status": "pending",
    }
    completion_mock = AsyncMock(return_value={
        "session_id": session_id,
        "event_id": "evt-success",
        "paid": True,
        "completed": True,
        "disposition": "completed",
    })
    monkeypatch.setattr(subs.supabase_service, "complete_paid_checkout_session_v2", completion_mock)

    provider_payload = {
        "processed": True,
        "provider": "asaas",
        "subscription_status": "active",
        "trainer_id": "631e76b9-3cb0-454f-8fd9-1d450e5560d6",
        "plan_id": "pro",
        "billing_interval": "monthly",
    }
    monkeypatch.setattr(
        subs.PaymentProviderService,
        "process_webhook",
        staticmethod(lambda provider, payload: provider_payload),
    )

    payload = {
        "id": "evt-success",
        "event": "PAYMENT_RECEIVED",
        "payment": {"id": "pay-success", "externalReference": session_id},
    }
    request = dummy_request(payload)

    result = await subs.webhook_asaas(payload, request)

    assert result == provider_payload
    completion_mock.assert_awaited_once_with(
        session_id=session_id,
        event_id="evt-success",
        claim_token="lease-token-3",
        provider_payment_id="pay-success",
    )
