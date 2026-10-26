import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch

from app.main import app
from app.api.deps import get_current_user
from app.schemas.notification import (
    NotificationRouteRequest,
    NotificationCategory,
    NotificationChannel,
)
from app.services.notification_router_service import NotificationRouterService

client = TestClient(app)

MOCK_USER = {
    "sub": "user-uuid-1234",
    "role": "authenticated",
    "aal": "aal2",
    "profile": {"role": "trainer", "roles": ["trainer"]},
}


@pytest.fixture(autouse=True)
def override_user():
    app.dependency_overrides[get_current_user] = lambda: MOCK_USER
    yield
    app.dependency_overrides.pop(get_current_user, None)


def test_habit_reminder_routes_to_push_free():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-1",
        category=NotificationCategory.HABIT_REMINDER,
        title="Beba Água!",
        body="Já se hidratou hoje? Faltam 800ml para bater a meta.",
    )
    decision = svc.evaluate_routing(req)

    assert decision.primary_channel == NotificationChannel.PUSH_APP
    assert decision.channels_to_dispatch == [NotificationChannel.PUSH_APP]
    assert decision.estimated_cost_brl == 0.0
    assert decision.requires_template is False
    assert decision.suppressed_by_cooldown is False


def test_in_app_support_routes_to_in_app():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-2",
        category=NotificationCategory.IN_APP_SUPPORT,
        title="Dúvida Supino",
        body="Qual o ângulo ideal do banco no supino inclinado?",
    )
    decision = svc.evaluate_routing(req)

    assert decision.primary_channel == NotificationChannel.IN_APP
    assert decision.estimated_cost_brl == 0.0
    assert decision.requires_template is False


def test_workout_released_within_24h_is_free():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-3",
        category=NotificationCategory.WORKOUT_RELEASED,
        title="Ficha Nova Pronta!",
        body="Seu treinador liberou o Split B de Hipertrofia.",
        last_interaction_hours_ago=2.5,
    )
    decision = svc.evaluate_routing(req)

    assert decision.primary_channel == NotificationChannel.HYBRID_DUAL
    assert NotificationChannel.PUSH_APP in decision.channels_to_dispatch
    assert NotificationChannel.WHATSAPP in decision.channels_to_dispatch
    assert decision.estimated_cost_brl == 0.0
    assert decision.requires_template is False
    assert decision.template_name is None


def test_workout_released_outside_24h_uses_template():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-3",
        category=NotificationCategory.WORKOUT_RELEASED,
        title="Ficha Nova Pronta!",
        body="Seu treinador liberou o Split B de Hipertrofia.",
        last_interaction_hours_ago=48.0,
    )
    decision = svc.evaluate_routing(req)

    assert decision.primary_channel == NotificationChannel.HYBRID_DUAL
    assert decision.estimated_cost_brl == 0.04
    assert decision.requires_template is True
    assert decision.template_name == "mrcoach_workout_ready"


def test_billing_renewal_routes_to_whatsapp():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-4",
        category=NotificationCategory.BILLING_RENEWAL,
        title="Renovação do Plano",
        body="Sua assinatura vence em 3 dias. Clique para renovar.",
        phone="5511999998888",
    )
    decision = svc.evaluate_routing(req)

    assert decision.primary_channel == NotificationChannel.WHATSAPP
    assert decision.channels_to_dispatch == [NotificationChannel.WHATSAPP]
    assert decision.estimated_cost_brl == 0.04
    assert decision.requires_template is True
    assert decision.template_name == "mrcoach_billing_due"


def test_retention_alert_suppressed_by_cooldown():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-5",
        category=NotificationCategory.RETENTION_ALERT,
        title="Sentimos sua falta!",
        body="Faz 5 dias que você não treina. Vamos voltar?",
        phone="5511999997777",
        last_notification_sent_hours_ago=10.0,  # menos de 48h
    )
    decision = svc.evaluate_routing(req)

    assert decision.suppressed_by_cooldown is True
    assert decision.channels_to_dispatch == []
    assert "Trava anti-spam de 48h ativa" in decision.cooldown_reason


def test_retention_alert_allowed_after_cooldown():
    svc = NotificationRouterService()
    req = NotificationRouteRequest(
        recipient_id="student-5",
        category=NotificationCategory.RETENTION_ALERT,
        title="Sentimos sua falta!",
        body="Faz 5 dias que você não treina. Vamos voltar?",
        phone="5511999997777",
        last_notification_sent_hours_ago=52.0,  # mais de 48h
    )
    decision = svc.evaluate_routing(req)

    assert decision.suppressed_by_cooldown is False
    assert decision.channels_to_dispatch == [NotificationChannel.WHATSAPP]
    assert decision.estimated_cost_brl == 0.04
    assert decision.template_name == "mrcoach_student_checkin"


def test_api_matrix_rules():
    res = client.get("/api/v1/notifications/matrix-rules")
    assert res.status_code == 200
    data = res.json()
    assert len(data) == 5
    categories = [r["category"] for r in data]
    assert "habit_reminder" in categories
    assert "workout_released" in categories
    assert "retention_alert" in categories


def test_api_route_decision():
    payload = {
        "recipient_id": "std-123",
        "category": "habit_reminder",
        "title": "Água",
        "body": "Hora de beber água!",
    }
    res = client.post("/api/v1/notifications/route-decision", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["primary_channel"] == "push_app"
    assert data["estimated_cost_brl"] == 0.0
    assert data["suppressed_by_cooldown"] is False


@pytest.mark.asyncio
async def test_api_dispatch_habit():
    payload = {
        "recipient_id": "std-123",
        "category": "habit_reminder",
        "title": "Ofensiva mantida!",
        "body": "Você completou 5 dias seguidos de treino.",
    }
    res = client.post("/api/v1/notifications/dispatch", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert "push_app" in data["dispatched_channels"]
