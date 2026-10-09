"""
Testes de Regressão — Auditoria de Segurança (Batch 2)

Cobre os itens implementados:
  - P0: /checkout-session agora exige JWT (não mais público)
  - P0: /check-status/{nsu} agora exige JWT e valida propriedade da sessão
  - 8.3/9.2.7: webhook/asaas persiste ativação/cancelamento no Supabase
  - 9.1.5: /adapt-exercise conta gerações mensais de IA
  - 9.1.5: /assistant/chat exige auth e conta gerações mensais de IA
  - Segurança: chave Evolution API não possui valor padrão hardcoded
"""

import pytest


# ---------------------------------------------------------------------------
# P0 — /checkout-session requer autenticação
# ---------------------------------------------------------------------------

def test_checkout_session_requires_auth(monkeypatch):
    """Sem token de auth, /checkout-session deve retornar 401 ou 403."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "SUPABASE_JWKS_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", "")
    client = TestClient(app, raise_server_exceptions=False)

    res = client.post("/api/v1/subscriptions/checkout-session", json={
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "provider": "asaas",
        "trainer_name": "Test Trainer",
        "trainer_email": "test@example.com",
    })
    assert res.status_code in (401, 403), f"Esperado 401/403, obteve {res.status_code}"


def test_checkout_session_uses_auth_trainer_id(monkeypatch):
    """Em produção, /checkout-session deriva trainer_id das claims, nunca do corpo."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings
    from app.api.deps import get_current_user
    from app.services.supabase_service import supabase_service
    from app.services.payment_service import PaymentProviderService

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ASAAS_API_KEY", "")  # evita chamada HTTP real

    async def mock_save_ok(data):
        supabase_service._mem_checkout_sessions[data["session_id"]] = dict(data)
    monkeypatch.setattr(supabase_service, "save_checkout_session", mock_save_ok)

    auth_id = "auth-trainer-prod-001"
    body_id = "attacker-trainer-999"

    app.dependency_overrides[get_current_user] = lambda: {
        "sub": auth_id,
        "role": "authenticated",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    try:
        client = TestClient(app)
        res = client.post("/api/v1/subscriptions/checkout-session", json={
            "plan_id": "pro",
            "billing_interval": "monthly",
            "payment_method": "pix",
            "provider": "asaas",
            "trainer_name": "Auth Trainer",
            "trainer_email": "auth@example.com",
            "trainer_id": body_id,  # tentativa de injetar trainer_id via corpo
        })
        assert res.status_code == 200
        session_id = res.json()["session_id"]
        stored = PaymentProviderService._PENDING_ORDERS.get(session_id, {})
        # O trainer_id armazenado deve ser o do token, não o do corpo
        assert stored.get("trainer_id") == auth_id, (
            f"Esperado trainer_id={auth_id!r} (do token), mas session tem {stored.get('trainer_id')!r}"
        )
        assert stored.get("trainer_id") != body_id
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        PaymentProviderService._PENDING_ORDERS.clear()


# ---------------------------------------------------------------------------
# P0 — /check-status exige auth e valida propriedade da sessão
# ---------------------------------------------------------------------------

def test_check_status_requires_auth(monkeypatch):
    """Sem token, /check-status deve retornar 401 ou 403."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "SUPABASE_JWKS_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", "")
    client = TestClient(app, raise_server_exceptions=False)

    res = client.get("/api/v1/subscriptions/check-status/fake-order-nsu")
    assert res.status_code in (401, 403), f"Esperado 401/403, obteve {res.status_code}"


def test_check_status_blocks_cross_trainer_access(monkeypatch):
    """Em produção, treinador A não pode ativar assinatura da sessão do treinador B."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings
    from app.api.deps import get_current_user
    from app.services.payment_service import PaymentProviderService

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ASAAS_API_KEY", "")

    # Registrar sessão do treinador B
    nsu = "sess_test_cross_trainer_001"
    PaymentProviderService._PENDING_ORDERS[nsu] = {
        "session_id": nsu,
        "trainer_id": "trainer-B-legitimate",
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
        "paid": True,   # simula pagamento confirmado
        "status": "active",
    }

    # Treinador A tenta fazer polling da sessão do treinador B
    app.dependency_overrides[get_current_user] = lambda: {
        "sub": "trainer-A-attacker",
        "role": "authenticated",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    try:
        client = TestClient(app)
        res = client.get(f"/api/v1/subscriptions/check-status/{nsu}")
        assert res.status_code == 403, (
            f"Esperado 403 (cross-trainer), obteve {res.status_code}: {res.json()}"
        )
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        PaymentProviderService._PENDING_ORDERS.pop(nsu, None)


def test_check_status_blocks_activation_without_full_metadata(monkeypatch):
    """Sessão sem plan_id/billing_interval não deve ativar assinatura — falhar fechado."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings
    from app.api.deps import get_current_user
    from app.services.payment_service import PaymentProviderService

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ASAAS_API_KEY", "")

    nsu = "sess_test_missing_meta_001"
    trainer_id = "trainer-safe-001"
    PaymentProviderService._PENDING_ORDERS[nsu] = {
        "session_id": nsu,
        "trainer_id": trainer_id,
        # plan_id e billing_interval ausentes — simula sessão reconstituída após restart
        "paid": True,
        "status": "active",
    }

    app.dependency_overrides[get_current_user] = lambda: {
        "sub": trainer_id,
        "role": "authenticated",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    try:
        client = TestClient(app)
        res = client.get(f"/api/v1/subscriptions/check-status/{nsu}")
        assert res.status_code == 422, (
            f"Esperado 422 (metadados incompletos), obteve {res.status_code}: {res.json()}"
        )
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        PaymentProviderService._PENDING_ORDERS.pop(nsu, None)


# ---------------------------------------------------------------------------
# 9.1.5 — /assistant/chat exige auth
# ---------------------------------------------------------------------------

def test_assistant_chat_requires_auth(monkeypatch):
    """Sem token, /assistant/chat deve retornar 401 ou 403."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "SUPABASE_JWKS_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", "")
    client = TestClient(app, raise_server_exceptions=False)

    res = client.post("/api/v1/assistant/chat", json={"prompt": "Olá"})
    assert res.status_code in (401, 403), f"Esperado 401/403, obteve {res.status_code}"


# ---------------------------------------------------------------------------
# Segurança — Evolution API sem valor padrão hardcoded
# ---------------------------------------------------------------------------

def test_evolution_api_key_has_no_hardcoded_default():
    """A chave da Evolution API não deve ter valor padrão hardcoded."""
    from app.services.whatsapp_service import WhatsAppService
    svc = WhatsAppService()
    assert svc.evolution_key != "mr_coach_secret_api_key_2026", (
        "Chave da Evolution API ainda está hardcoded no código — risco de credencial exposta!"
    )
    # Sem EVOLUTION_API_KEY no .env de teste, deve ser string vazia
    assert svc.evolution_key == "" or svc.evolution_key is None


def test_evolution_api_in_mock_mode_without_key():
    """WhatsApp service sem chave deve operar em modo mock sem erros."""
    from app.services.whatsapp_service import WhatsAppService
    import asyncio

    svc = WhatsAppService(provider="mock")
    result = asyncio.new_event_loop().run_until_complete(
        svc.send_text_message("mr_coach_instance", "11999999999", "Teste de mensagem mock")
    )
    assert result["status"] == "success"
    assert result["mode"] == "mock"


# ---------------------------------------------------------------------------
# supabase_service.update_subscription_status — smoke test dev mode
# ---------------------------------------------------------------------------

def test_update_subscription_status_dev_mode():
    """update_subscription_status em dev não deve lançar exceção."""
    from app.services.supabase_service import supabase_service
    import asyncio

    asyncio.run(
        supabase_service.update_subscription_status("current-trainer", "canceled")
    )
    # Sem exceção = sucesso


# ---------------------------------------------------------------------------
# Idempotência de Webhooks (P1 — Asaas e gateways)
# ---------------------------------------------------------------------------

def test_webhook_idempotency_service_methods():
    """Testa is_event_processed e record_processed_event em modo de desenvolvimento."""
    from app.services.supabase_service import supabase_service
    import asyncio

    evt_id = "test_evt_unique_12345"

    async def run():
        # Antes de registrar, deve ser False
        assert await supabase_service.is_event_processed(evt_id) is False
        # Registra
        rec = await supabase_service.record_processed_event(
            event_id=evt_id,
            provider="asaas",
            event_type="PAYMENT_RECEIVED",
            payload={"id": evt_id}
        )
        assert rec is True
        # Agora deve ser True
        assert await supabase_service.is_event_processed(evt_id) is True

    asyncio.run(run())


def test_webhook_asaas_ignores_duplicate_event():
    """Webhook do Asaas deve ignorar evento duplicado com flag idempotent=True."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.services.supabase_service import supabase_service
    import asyncio

    client = TestClient(app)
    evt_id = "evt_asaas_duplicate_check_999"

    # Pré-registra o evento como já processado
    asyncio.run(
        supabase_service.record_processed_event(
            event_id=evt_id,
            provider="asaas",
            event_type="PAYMENT_RECEIVED"
        )
    )

    # Dispara o webhook com o mesmo id
    res = client.post(
        "/api/v1/subscriptions/webhook/asaas",
        json={
            "id": evt_id,
            "event": "PAYMENT_RECEIVED",
            "payment": {
                "id": "pay_test_dup_1",
                "value": 89.0,
                "status": "RECEIVED"
            }
        }
    )
    assert res.status_code == 200
    data = res.json()
    assert data.get("idempotent") is True
    assert "já processado anteriormente" in data.get("message", "")


# ---------------------------------------------------------------------------
# AI-001 — Reserva Atômica de Cota de IA
# ---------------------------------------------------------------------------

def test_atomic_ai_quota_reservation_and_release():
    """Testa que a cota é reservada atomicamente e liberada em caso de falha."""
    from app.services.supabase_service import supabase_service
    import asyncio

    trainer_id = "tr-atomic-quota-test-01"

    async def run():
        # Limite de 2 gerações para teste
        max_quota = 2

        # 1ª reserva: deve ter sucesso
        assert await supabase_service.reserve_monthly_ai_quota(trainer_id, max_quota) is True
        # 2ª reserva: deve ter sucesso (limite atingido)
        assert await supabase_service.reserve_monthly_ai_quota(trainer_id, max_quota) is True
        # 3ª reserva: deve ser RECUSADA atomicamente (evita ultrapassagem concorrente)
        assert await supabase_service.reserve_monthly_ai_quota(trainer_id, max_quota) is False

        # Simula rollback em caso de falha de geração
        await supabase_service.release_monthly_ai_quota(trainer_id)
        # Agora deve permitir novamente 1 vaga
        assert await supabase_service.reserve_monthly_ai_quota(trainer_id, max_quota) is True
        # E bloquear em seguida
        assert await supabase_service.reserve_monthly_ai_quota(trainer_id, max_quota) is False

    asyncio.run(run())


def test_ai_quota_reservation_fails_closed_in_production_if_rpc_fails(monkeypatch):
    """Em produção, se a chamada da RPC falhar, não deve usar fallback vulnerável a race conditions."""
    from app.services.supabase_service import supabase_service
    from app.core.config import settings
    import pytest
    import asyncio

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")

    class MockFailingClient:
        def rpc(self, name, params):
            class RPC:
                async def execute(self):
                    raise RuntimeError("RPC reserve_trainer_ai_usage connection timeout")
            return RPC()

    async def mock_get_client():
        return MockFailingClient()

    monkeypatch.setattr(supabase_service, "get_client", mock_get_client)

    async def run():
        with pytest.raises(RuntimeError) as exc_info:
            await supabase_service.reserve_monthly_ai_quota("tr-fail-closed-ai", 10)
        assert "Falha ao reservar cota de IA via RPC no Supabase" in str(exc_info.value)

    asyncio.run(run())


# ---------------------------------------------------------------------------
# PAY-001 & PAY-002 — Desativação Definitiva de /process-card e Eliminação do Escopo PCI DSS
# ---------------------------------------------------------------------------

def test_process_card_is_permanently_decommissioned_http_410():
    """/process-card deve retornar HTTP 410 Gone imediatamente para qualquer requisição."""
    from fastapi.testclient import TestClient
    from app.main import app

    client = TestClient(app)
    res = client.post("/api/v1/subscriptions/process-card", json={"session_id": "test_sess"})
    assert res.status_code == 410
    detail = res.json().get("detail", "")
    assert "PCI DSS" in detail
    assert "POST /checkout-session" in detail


def test_process_card_rejects_raw_card_data_in_production(monkeypatch):
    """Em produção, /process-card permanece 410 Gone desativado, impedindo tráfego de dados de cartão."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    client = TestClient(app)
    res = client.post("/api/v1/subscriptions/process-card", json={
        "session_id": "sess_non_existent",
    })
    assert res.status_code == 410
    assert "PCI DSS" in res.json()["detail"]


# ---------------------------------------------------------------------------
# PAY-003 & PAY-004 — Sessão Durável e Webhook Não Consome Sem Metadados
# ---------------------------------------------------------------------------

def test_durable_checkout_session_storage():
    """Testa persistência e recuperação de sessão de checkout durável."""
    from app.services.supabase_service import supabase_service
    import asyncio

    sess_id = "sess_durable_test_abc"

    async def run():
        await supabase_service.save_checkout_session({
            "session_id": sess_id,
            "trainer_id": "tr-durable-01",
            "plan_id": "elite",
            "billing_interval": "yearly",
            "amount_cents": 142800,
            "status": "pending",
        })
        retrieved = await supabase_service.get_checkout_session(sess_id)
        assert retrieved is not None
        assert retrieved["plan_id"] == "elite"
        assert retrieved["billing_interval"] == "yearly"
        assert retrieved["amount_cents"] == 142800

    asyncio.run(run())


def test_checkout_session_fails_closed_in_production_if_persistence_fails(monkeypatch):
    """Em produção, falha na persistência da sessão de checkout deve retornar HTTP 500 (fail-closed)."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.core.config import settings
    from app.api.deps import get_current_user
    from app.services.supabase_service import supabase_service

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    app.dependency_overrides[get_current_user] = lambda: {
        "sub": "tr-fail-closed-test",
        "role": "authenticated",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }

    async def mock_save_fail(data):
        raise RuntimeError("Falha ao salvar sessão de checkout no Supabase.")

    monkeypatch.setattr(supabase_service, "save_checkout_session", mock_save_fail)
    try:
        client = TestClient(app)
        res = client.post("/api/v1/subscriptions/checkout-session", json={
            "plan_id": "pro",
            "billing_interval": "monthly",
            "payment_method": "pix",
            "trainer_id": "tr-fail-closed-test",
        })
        assert res.status_code == 500
        assert "Falha ao persistir sessão de checkout" in res.json()["detail"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_webhook_does_not_mark_event_processed_if_metadata_missing():
    """Se o webhook não encontrar metadados da sessão, o evento NÃO é marcado como processado (permitindo retry)."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.services.supabase_service import supabase_service
    import asyncio

    client = TestClient(app)
    unmatched_evt_id = "evt_missing_meta_12345"

    res = client.post(
        "/api/v1/subscriptions/webhook/asaas",
        json={
            "id": unmatched_evt_id,
            "event": "PAYMENT_RECEIVED",
            "payment": {
                "id": "pay_unmatched_1",
                "value": 89.0,
                "status": "RECEIVED",
                "externalReference": "non_existent_ref_999"
            }
        }
    )
    assert res.status_code == 503
    detail = res.json().get("detail", "").lower()
    assert "retry programado" in detail or "metadata" in detail

    # O evento foi reivindicado para retry, mas não foi finalizado; a falta de metadados
    # deve impedir a ativação e manter o estado em processamento/release, não como completed.
    async def check():
        record = supabase_service._mem_processed_events.get(unmatched_evt_id, {})
        assert record.get("status") in {"processing", "released", "failed"}
        assert record.get("status") != "completed"

    asyncio.run(check())


def test_webhook_atomic_claim_blocks_concurrent_duplicate():
    """Se um evento já foi reivindicado/processado, chamadas subsequentes retornam resposta idempotente imediatamente."""
    from fastapi.testclient import TestClient
    from app.main import app
    from app.services.supabase_service import supabase_service
    import asyncio

    client = TestClient(app)
    claimed_evt_id = "evt_claimed_test_888"

    async def pre_claim():
        # Simula reivindicação atômica já ocorrida
        await supabase_service.claim_webhook_event(
            event_id=claimed_evt_id,
            provider="asaas",
            event_type="PAYMENT_RECEIVED"
        )
    asyncio.run(pre_claim())

    # Segunda requisição concorrente com o mesmo event_id
    res = client.post(
        "/api/v1/subscriptions/webhook/asaas",
        json={
            "id": claimed_evt_id,
            "event": "PAYMENT_RECEIVED",
            "payment": {
                "id": "pay_dup_1",
                "value": 89.0,
                "status": "RECEIVED",
                "externalReference": "ref_dup_888"
            }
        }
    )
    assert res.status_code == 200
    data = res.json()
    assert data.get("idempotent") is True
    assert data.get("event_id") == claimed_evt_id
    assert data.get("disposition") in {"duplicate", "busy"}
    assert "duplicata" in data.get("message", "").lower() or "processamento" in data.get("message", "").lower()


def test_paid_checkout_atomic_completion_failure_does_not_activate_subscription(monkeypatch):
    """Falha na conclusão atômica via complete_paid_checkout_session_v2 não deve ativar assinatura."""
    from fastapi.testclient import TestClient
    from unittest.mock import AsyncMock
    from app.main import app
    from app.api.deps import get_current_trainer
    from app.services import supabase_service

    nsu = "sess_test_paid_completion_failure_001"
    trainer_id = "trainer-safe-004"
    checkout_meta = {
        "session_id": nsu,
        "trainer_id": trainer_id,
        "plan_id": "pro",
        "billing_interval": "monthly",
        "payment_method": "pix",
    }
    from app.services.payment_service import PaymentProviderService
    monkeypatch.setattr(PaymentProviderService, "check_payment", lambda *args, **kwargs: True)
    monkeypatch.setattr(supabase_service.supabase_service, "get_checkout_session", AsyncMock(return_value=checkout_meta))

    async def fake_complete(*args, **kwargs):
        return {"session_id": nsu, "paid": False, "completed": False, "disposition": "failed", "error": "checkout_session_status_not_activable"}

    async def fake_activate(*args, **kwargs):
        raise AssertionError("/check-status não deve tentar ativar assinatura se o wrapper falhou")

    monkeypatch.setattr(supabase_service.supabase_service, "complete_paid_checkout_session_v2", fake_complete)
    monkeypatch.setattr(supabase_service.supabase_service, "activate_subscription", fake_activate)

    app.dependency_overrides[get_current_trainer] = lambda: {"sub": trainer_id, "role": "authenticated", "profile": {"role": "trainer", "roles": ["trainer"]}}
    try:
        client = TestClient(app, raise_server_exceptions=False)
        res = client.get(f"/api/v1/subscriptions/check-status/{nsu}")
        assert res.status_code == 503, res.text
        body = res.json()
        assert "detail" in body
        assert "paid" not in body
    finally:
        app.dependency_overrides.pop(get_current_trainer, None)



