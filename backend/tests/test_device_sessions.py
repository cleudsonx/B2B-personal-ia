import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

@pytest.fixture
def fake_trainer_user():
    return {
        "sub": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
        "id": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
        "email": "cleudsonx2021@gmail.com",
        "role": "trainer",
        "roles": ["trainer", "admin"],
        "profile": {
            "id": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
            "full_name": "Mr. Coach",
            "role": "trainer",
            "roles": ["trainer", "admin"],
            "is_admin": True,
            "is_vip": True,
            "current_plan": "Studio Scale",
            "phone": "61991497852",
        }
    }

def test_register_device_session_and_list(fake_trainer_user, monkeypatch):
    from app.api.deps import get_current_user
    app.dependency_overrides[get_current_user] = lambda: fake_trainer_user

    mock_db = MagicMock()
    mock_table = MagicMock()
    mock_db.table.return_value = mock_table

    # Mock select existing (new device)
    mock_select = MagicMock()
    mock_select.eq.return_value = mock_select
    mock_select.maybe_single.return_value = mock_select
    mock_select.execute = AsyncMock(return_value=MagicMock(data=None))

    # Mock upsert
    mock_table.upsert.return_value = MagicMock(execute=AsyncMock(return_value=MagicMock(data=[{"id": "session-123"}])))
    mock_table.select.return_value = mock_select

    with patch("app.services.supabase_service.supabase_service.get_client", AsyncMock(return_value=mock_db)):
        resp = client.post(
            "/api/v1/auth/device-session/register",
            json={
                "device_id": "device-iphone-15",
                "device_name": "iPhone 15 Pro",
                "platform": "iOS",
                "app_version": "1.12.19",
            }
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["ok"] is True
        assert data["device_id"] == "device-iphone-15"
        assert data["allowed_concurrent_devices"] == 10  # VIP / Admin

    app.dependency_overrides.clear()

