import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch, MagicMock
from app.main import app

@pytest.mark.asyncio
async def test_create_invite_validation():
    """Valida rejeição de criação com dados ausentes"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # Sem token de auth -> 401
        res = await client.post("/api/v1/invites/create", json={"channel": "email"})
        assert res.status_code == 401

@pytest.mark.asyncio
async def test_consume_invite_not_found():
    """Valida tentativa de consumir token inexistente gerando 404 e auditoria de falha"""
    mock_supabase = AsyncMock()
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

    with patch("app.services.supabase_service.supabase_service.get_client", return_value=mock_supabase):
        with patch("app.services.audit_service.log_audit_event", new_callable=AsyncMock) as mock_audit:
            async with AsyncClient(app=app, base_url="http://test") as client:
                res = await client.post("/api/v1/invites/consume", json={"token": "token_inexistente_123"})
                assert res.status_code == 404
                assert mock_audit.called
                call_args = mock_audit.call_args[1]
                assert call_args["event_type"] == "invite_failed"

