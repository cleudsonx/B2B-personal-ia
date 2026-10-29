import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.api.v1.endpoints import auth as auth_ep
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service
from app.services import mfa_security as mfa

client = TestClient(app)

@pytest.fixture
def mock_supabase():
    mock = MagicMock()
    mock_db = {
        "profiles": [
            {
                "id": "11111111-1111-1111-1111-111111111111",
                "full_name": "Cleudson Treinador",
                "role": "trainer",
                "phone": "(61) 98291-2174",
                "public_whatsapp": "61982912174",
                "email": "cleudson@mrcoach.app",
            }
        ],
        "auth_recovery_otps": [],
    }

    class FakeQuery:
        def __init__(self, table):
            self.table = table
            self._filters = []
            self._data = None

        def select(self, *args, **kwargs):
            return self

        def or_(self, *args, **kwargs):
            return self

        def ilike(self, *args, **kwargs):
            return self

        def eq(self, *args, **kwargs):
            return self

        def gt(self, *args, **kwargs):
            return self

        def is_(self, *args, **kwargs):
            return self

        def order(self, *args, **kwargs):
            return self

        def limit(self, *args, **kwargs):
            return self

        def insert(self, payload):
            self._data = payload
            mock_db[self.table].append(payload)
            return self

        def update(self, payload):
            return self

        async def execute(self):
            rows = mock_db.get(self.table, [])
            res = MagicMock()
            res.data = rows
            return res

    mock.table.side_effect = lambda name: FakeQuery(name)
    return mock

@pytest.mark.asyncio
async def test_passwordless_request_existing_user(mock_supabase):
    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=mock_supabase)), \
         patch.object(whatsapp_service, "send_text_with_fallback", new=AsyncMock(return_value={"status": "sent"})):
        
        response = client.post(
            "/api/v1/auth/otp/login-request",
            json={"phone": "61982912174", "role": "trainer", "full_name": "cleudson Hotmail"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "masked_phone" in data
