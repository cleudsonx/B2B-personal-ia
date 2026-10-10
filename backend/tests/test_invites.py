import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch, MagicMock
from app.main import app
from app.api.v1.endpoints.invites import _normalize_phone


def test_invite_phone_normalization_accepts_brazil_country_code():
    assert _normalize_phone("+55 (11) 99999-8888") == "11999998888"
    assert _normalize_phone("11 99999-8888") == "11999998888"


@pytest.mark.asyncio
async def test_create_invite_uses_configured_frontend_url(monkeypatch):
    from app.api.v1.endpoints import invites as invite_endpoints

    monkeypatch.setattr(
        invite_endpoints.settings,
        "APP_FRONTEND_URL",
        "https://frontend.example/",
    )
    with patch(
        "app.api.v1.endpoints.invites.supabase_service.create_student_invite",
        new_callable=AsyncMock,
        return_value={"id": "invite-id", "token": "generated-token", "expires_at": "2026-10-09T00:00:00Z"},
    ) as create_invite:
        with patch(
            "app.api.v1.endpoints.invites.log_audit_event",
            new_callable=AsyncMock,
        ):
            response = await invite_endpoints.create_invite(
                invite_endpoints.CreateInviteRequest(
                    channel="email",
                    target_email="student@example.com",
                ),
                {"id": "trainer-test-id"},
            )

    assert response.invite_url == (
        "https://frontend.example/#/invite/generated-token"
    )
    assert create_invite.await_args.kwargs["channel"] == "email"


@pytest.mark.asyncio
async def test_create_invite_validation():
    """Valida rejeição de criação com dados ausentes"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # O modo development injeta um usuário local; a validação rejeita o destino ausente.
        res = await client.post("/api/v1/invites/create", json={"channel": "email"})
        assert res.status_code == 400

@pytest.mark.asyncio
async def test_consume_invite_uses_atomic_rpc_and_returns_trainer():
    from starlette.requests import Request
    from app.api.v1.endpoints import invites as invite_endpoints

    result = {"status": "consumed", "trainer_id": "trainer-id", "trainer_name": "Coach", "channel": "whatsapp"}
    mock_supabase = MagicMock()
    mock_supabase.rpc.return_value.execute = AsyncMock(return_value=MagicMock(data=result))
    with patch(
        "app.services.supabase_service.supabase_service.get_client",
        new_callable=AsyncMock,
        return_value=mock_supabase,
    ):
        with patch("app.api.v1.endpoints.invites.log_audit_event", new_callable=AsyncMock):
            request = Request({"type": "http", "headers": [], "client": ("127.0.0.1", 1234)})
            response = await invite_endpoints.consume_invite(
                invite_endpoints.ConsumeInviteRequest(token="invite-token"),
                request,
                {"id": "student-id"},
            )

    assert response.trainer_id == "trainer-id"
    assert response.trainer_name == "Coach"
    mock_supabase.rpc.assert_called_once_with("consume_student_invite", {
        "p_token": "invite-token",
        "p_student_id": "student-id",
    })


@pytest.mark.asyncio
async def test_consume_invite_maps_wrong_recipient_to_forbidden():
    from fastapi import HTTPException
    from starlette.requests import Request
    from app.api.v1.endpoints import invites as invite_endpoints

    mock_supabase = MagicMock()
    mock_supabase.rpc.return_value.execute = AsyncMock(
        side_effect=Exception("Este convite foi destinado a outro e-mail.")
    )
    with patch(
        "app.services.supabase_service.supabase_service.get_client",
        new_callable=AsyncMock,
        return_value=mock_supabase,
    ), patch("app.api.v1.endpoints.invites.log_audit_event", new_callable=AsyncMock):
        request = Request({"type": "http", "headers": [], "client": ("127.0.0.1", 1234)})
        with pytest.raises(HTTPException) as error:
            await invite_endpoints.consume_invite(
                invite_endpoints.ConsumeInviteRequest(token="invite-token"),
                request,
                {"id": "student-id"},
            )

    assert error.value.status_code == 403


@pytest.mark.asyncio
async def test_direct_client_registration_requires_invite(monkeypatch):
    from fastapi import HTTPException
    from app.api.v1.endpoints import auth as auth_endpoints

    create_user = AsyncMock()
    monkeypatch.setattr(auth_endpoints.supabase_service, "admin_create_user", create_user)
    with pytest.raises(HTTPException) as error:
        await auth_endpoints.register_user_direct(auth_endpoints.DirectRegisterRequest(
            email="student@example.com",
            password="password123",
            full_name="Student",
            role="client",
            trainer_id="attacker-trainer",
        ))

    assert error.value.status_code == 400
    create_user.assert_not_awaited()


@pytest.mark.asyncio
async def test_direct_registration_rejects_unknown_role_before_supabase(monkeypatch):
    from fastapi import HTTPException
    from app.api.v1.endpoints import auth as auth_endpoints

    get_client = AsyncMock()
    create_user = AsyncMock()
    monkeypatch.setattr(auth_endpoints.supabase_service, "get_client", get_client)
    monkeypatch.setattr(auth_endpoints.supabase_service, "admin_create_user", create_user)

    with pytest.raises(HTTPException) as error:
        await auth_endpoints.register_user_direct(auth_endpoints.DirectRegisterRequest(
            email="user@example.com",
            password="password123",
            full_name="User",
            role=" admin ",
        ))

    assert error.value.status_code == 400
    assert "Papel inválido" in error.value.detail
    get_client.assert_not_awaited()
    create_user.assert_not_awaited()


@pytest.mark.asyncio
async def test_direct_trainer_registration_passes_trainer_id(monkeypatch):
    from app.api.v1.endpoints import auth as auth_endpoints

    create_user = AsyncMock(return_value={
        "success": True,
        "user_id": "trainer-id",
        "email": "trainer@example.com",
        "role": "trainer",
        "message": "created",
    })
    monkeypatch.setattr(auth_endpoints.supabase_service, "admin_create_user", create_user)

    await auth_endpoints.register_user_direct(auth_endpoints.DirectRegisterRequest(
        email="trainer@example.com",
        password="password123",
        full_name="Trainer",
        role="trainer",
        trainer_id="linked-trainer-id",
    ))

    create_user.assert_awaited_once()
    assert create_user.await_args.kwargs["role"] == "trainer"
    assert create_user.await_args.kwargs["trainer_id"] == "linked-trainer-id"


@pytest.mark.asyncio
async def test_direct_client_registration_ignores_submitted_trainer_id(monkeypatch):
    from app.api.v1.endpoints import auth as auth_endpoints

    query = MagicMock()
    query.execute = AsyncMock(return_value=MagicMock(data={
        "target_email": "student@example.com",
        "target_phone": None,
        "channel": "email",
        "used_at": None,
        "expires_at": "2099-01-01T00:00:00+00:00",
    }))
    mock_client = MagicMock()
    mock_client.table.return_value.select.return_value.eq.return_value.maybe_single.return_value = query
    monkeypatch.setattr(auth_endpoints.supabase_service, "get_client", AsyncMock(return_value=mock_client))
    create_user = AsyncMock(return_value={
        "success": True,
        "user_id": "student-id",
        "email": "student@example.com",
        "role": "client",
        "message": "created",
    })
    monkeypatch.setattr(auth_endpoints.supabase_service, "admin_create_user", create_user)

    await auth_endpoints.register_user_direct(auth_endpoints.DirectRegisterRequest(
        email="student@example.com",
        password="password123",
        full_name="Student",
        role="client",
        trainer_id="attacker-trainer",
        invite_token="valid-token",
    ))

    assert create_user.await_args.kwargs["trainer_id"] is None

