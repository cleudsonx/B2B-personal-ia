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
    mock_supabase = MagicMock()
    mock_supabase.table.return_value.insert.return_value.execute = AsyncMock(
        return_value=MagicMock(data=[{"expires_at": "2026-10-09T00:00:00Z"}])
    )

    with patch(
        "app.services.supabase_service.supabase_service.get_client",
        new_callable=AsyncMock,
        return_value=mock_supabase,
    ):
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
        f"https://frontend.example/#/invite/{response.token}"
    )


@pytest.mark.asyncio
async def test_create_invite_validation():
    """Valida rejeição de criação com dados ausentes"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # O modo development injeta um usuário local; a validação rejeita o destino ausente.
        res = await client.post("/api/v1/invites/create", json={"channel": "email"})
        assert res.status_code == 400

@pytest.mark.asyncio
async def test_consume_invite_not_found():
    """Valida tentativa de consumir token inexistente gerando 404 e auditoria de falha"""
    mock_supabase = MagicMock()
    # Mock do retorno do Supabase simulando token não encontrado
    mock_table = MagicMock()
    mock_select = MagicMock()
    mock_eq = MagicMock()
    mock_maybe_single = MagicMock()
    mock_execute = AsyncMock(return_value=MagicMock(data=None))

    mock_supabase.table.return_value = mock_table
    mock_table.select.return_value = mock_select
    mock_select.eq.return_value = mock_eq
    mock_eq.maybe_single.return_value = mock_maybe_single
    mock_maybe_single.execute = mock_execute

    with patch(
        "app.services.supabase_service.supabase_service.get_client",
        new_callable=AsyncMock,
        return_value=mock_supabase,
    ):
        with patch("app.api.v1.endpoints.invites.log_audit_event", new_callable=AsyncMock) as mock_audit:
            async with AsyncClient(app=app, base_url="http://test") as client:
                res = await client.post("/api/v1/invites/consume", json={"token": "token_inexistente_123"})
                assert res.status_code == 404
                assert mock_audit.called
                call_args = mock_audit.call_args[1]
                assert call_args["event_type"] == "invite_failed"

