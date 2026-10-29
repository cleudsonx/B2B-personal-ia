import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi.testclient import TestClient

from app.main import app
from app.api.v1.endpoints import auth as auth_ep
from app.api.v1.endpoints.subscriptions import _is_profile_admin
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service

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
                "email": "treinador@exemplo.com",
            }
        ],
        "auth_recovery_otps": [],
    }

    class FakeQuery:
        def __init__(self, table):
            self.table = table
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
    mock._db = mock_db
    return mock


@pytest.mark.asyncio
async def test_passwordless_request_existing_user(mock_supabase):
    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=mock_supabase)), \
         patch.object(whatsapp_service, "send_text_with_fallback", new=AsyncMock(return_value={"status": "sent"})):

        response = client.post(
            "/api/v1/auth/otp/login-request",
            json={"phone": "61982912174", "role": "trainer", "full_name": "Cleudson Hotmail"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["is_new_user"] is False
        assert "masked_phone" in data


@pytest.mark.asyncio
async def test_passwordless_blocks_name_hijack_and_admin_role_injection(mock_supabase):
    """
    Garante que um novo usuário informando o mesmo nome de um perfil existente
    NÃO sequestre a conta existente (Account Takeover), use domínio sintético isolado
    (@wa.mrcoach.internal) e JAMAIS receba role 'admin' mesmo enviando role='admin'.
    """
    created_calls = []

    async def fake_admin_create_user(**kwargs):
        created_calls.append(kwargs)
        return {
            "success": True,
            "user_id": "22222222-2222-2222-2222-222222222222",
            "email": kwargs["email"],
            "role": kwargs["role"],
        }

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=mock_supabase)), \
         patch.object(supabase_service, "admin_create_user", side_effect=fake_admin_create_user), \
         patch.object(whatsapp_service, "send_text_with_fallback", new=AsyncMock(return_value={"status": "sent"})):

        response = client.post(
            "/api/v1/auth/otp/login-request",
            json={
                "phone": "11977776666",
                "role": "admin",  # Tentativa maliciosa de injeção de role admin
                "full_name": "Cleudson Treinador",  # Tentativa de colisão por nome
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["is_new_user"] is True
        assert len(created_calls) == 1
        assert created_calls[0]["email"] == "wa_5511977776666@wa.mrcoach.internal"
        assert created_calls[0]["role"] == "client"  # 'admin' rejeitado -> fallback seguro


def test_is_profile_admin_blocks_whatsapp_synthetic_and_substring_spoofing():
    """
    Garante que contas WhatsApp (wa_*@mrcoach.app / @wa.mrcoach.internal), alunos
    de checkout rápido e ataques de substring em nome/email/username NUNCA recebam SuperAdmin.
    """
    # Caso exato reportado em produção (Cleudson Hotmail via WhatsApp)
    wa_polluted_profile = {
        "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        "email": "wa_5561982912174@mrcoach.app",
        "full_name": "Cleudson Hotmail",
        "role": "trainer",
        "roles": ["trainer", "admin"],
        "is_admin": True,
    }
    assert _is_profile_admin(wa_polluted_profile) is False

    # Substring spoofing em e-mail comum, nome e username
    assert _is_profile_admin({
        "id": "bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee",
        "email": "cleudson.impostor@gmail.com",
        "full_name": "Prof. Cleudson Cavalcante",
        "username": "mrcoach",
        "role": "trainer",
    }) is False

    assert _is_profile_admin({
        "id": "cccccccc-bbbb-cccc-dddd-eeeeeeeeeeee",
        "email": "outro@mrcoach.app",
        "role": "trainer",
    }) is False

    # Contas canônicas reais continuam funcionando normalmente
    assert _is_profile_admin({
        "id": "92dfd58c-845f-473e-b846-a2b8fdd3e508",
        "email": "cleudsonx@hotmail.com",
        "role": "trainer",
    }) is True


@pytest.mark.asyncio
async def test_admin_create_user_rejects_admin_role():
    with pytest.raises(ValueError, match="Somente 'trainer' ou 'client'"):
        await supabase_service.admin_create_user(
            email="attacker@example.com",
            password="Password123!",
            full_name="Attacker",
            role="admin",
        )
