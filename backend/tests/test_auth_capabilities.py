import asyncio
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException


def test_trainer_dependency_requires_aal2():
    from app.api.deps import get_current_trainer

    with pytest.raises(HTTPException) as error:
        asyncio.run(get_current_trainer({
            "sub": "trainer-id",
            "aal": "aal1",
            "profile": {"role": "trainer", "roles": ["trainer"]},
        }))

    assert error.value.status_code == 403


def test_client_capability_does_not_grant_trainer_access():
    from app.api.deps import get_current_trainer

    with pytest.raises(HTTPException) as error:
        asyncio.run(get_current_trainer({
            "sub": "client-id",
            "aal": "aal2",
            "profile": {"role": "client", "roles": ["client"]},
        }))

    assert error.value.status_code == 403


def test_dual_role_trainer_requires_aal2_for_trainer_context():
    from app.api.deps import get_current_trainer

    with pytest.raises(HTTPException) as error:
        asyncio.run(get_current_trainer({
            "sub": "dual-role-id",
            "aal": "aal1",
            "profile": {"role": "trainer", "roles": ["trainer", "client"]},
        }))

    assert error.value.status_code == 403


def test_trainer_only_profile_cannot_enter_client_context():
    from app.api.deps import get_current_client

    with pytest.raises(HTTPException) as error:
        asyncio.run(get_current_client({
            "sub": "trainer-id",
            "aal": "aal2",
            "profile": {"role": "trainer", "roles": ["trainer"]},
        }))

    assert error.value.status_code == 403


def test_dual_role_profile_can_enter_client_context_at_aal1():
    from app.api.deps import get_current_client

    user = {
        "sub": "dual-role-id",
        "aal": "aal1",
        "profile": {"role": "trainer", "roles": ["trainer", "client"]},
    }
    assert asyncio.run(get_current_client(user)) is user


def test_get_current_user_rejects_sessions_issued_before_revocation():
    from app.api.deps import get_current_user
    from app.services.supabase_service import supabase_service

    query = MagicMock()
    query.select.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(return_value=SimpleNamespace(data={
        "role": "client",
        "roles": ["client"],
        "session_revoked_at": datetime.now(timezone.utc).isoformat(),
    }))
    client = MagicMock()
    client.table.return_value = query
    token_payload = {
        "sub": "123e4567-e89b-12d3-a456-426614174000",
        "iat": 1,
    }

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=client)):
        with pytest.raises(HTTPException) as error:
            asyncio.run(get_current_user(token_payload))

    assert error.value.status_code == 401


def test_dual_role_profile_accepts_trainer_context_after_aal2():
    from app.api.deps import get_current_trainer

    user = {
        "sub": "dual-role-id",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer", "client"]},
    }
    assert asyncio.run(get_current_trainer(user)) is user