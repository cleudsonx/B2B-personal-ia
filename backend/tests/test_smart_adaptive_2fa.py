import asyncio
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi import HTTPException
from app.api.v1.endpoints.auth import (
    request_mfa_code,
    verify_mfa_code,
    reset_mfa_totp,
    generate_backup_codes,
    verify_backup_code,
    update_contact_channel,
    RequestMfaCodeRequest,
    VerifyMfaCodeRequest,
    ResetMfaTotpRequest,
    VerifyBackupCodeRequest,
    UpdateContactChannelRequest,
)


@pytest.mark.asyncio
async def test_request_mfa_code_whatsapp():
    client_mock = MagicMock()
    # Mock profiles table query
    profile_query = MagicMock()
    profile_query.select.return_value = profile_query
    profile_query.eq.return_value = profile_query
    profile_query.ilike.return_value = profile_query
    profile_query.maybe_single.return_value = profile_query
    profile_query.execute = AsyncMock(return_value=MagicMock(data={
        "id": "user-123",
        "full_name": "Cleudson Cavalcante",
        "phone": "61999998888",
        "public_whatsapp": "61999998888",
    }))

    client_mock.auth.admin.get_user_by_id = AsyncMock(return_value=MagicMock(user=MagicMock(email="cleudson@example.com", phone="61999998888")))

    # Mock insert into auth_recovery_otps
    otps_table = MagicMock()
    otps_table.insert.return_value = otps_table
    otps_table.execute = AsyncMock(return_value=MagicMock())

    def table_router(name):
        if name == "profiles":
            return profile_query
        return otps_table

    client_mock.table.side_effect = table_router

    from app.services.supabase_service import supabase_service
    from app.services.whatsapp_service import whatsapp_service

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=client_mock)), \
         patch.object(whatsapp_service, "send_text_with_fallback", new=AsyncMock(return_value=True)):
        req = RequestMfaCodeRequest(channel="whatsapp", phone_or_email="61999998888")
        res = await request_mfa_code(req=req, credentials=None)
        assert res.success is True
        assert res.channel == "whatsapp"
        assert "9****-8888" in res.masked_target


@pytest.mark.asyncio
async def test_verify_mfa_code_and_remember_device():
    client_mock = MagicMock()
    now_utc = datetime.now(timezone.utc).isoformat()
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()

    otp_row = {
        "id": "otp-1",
        "otp_code": "123456",
        "user_id": "user-123",
        "expires_at": expires_at,
        "used_at": None,
    }

    otps_query = MagicMock()
    otps_query.select.return_value = otps_query
    otps_query.eq.return_value = otps_query
    otps_query.is_.return_value = otps_query
    otps_query.gt.return_value = otps_query
    otps_query.in_.return_value = otps_query
    otps_query.order.return_value = otps_query
    otps_query.limit.return_value = otps_query
    otps_query.execute = AsyncMock(return_value=MagicMock(data=[otp_row]))
    otps_query.update.return_value = otps_query

    profiles_query = MagicMock()
    profiles_query.select.return_value = profiles_query
    profiles_query.eq.return_value = profiles_query
    profiles_query.maybe_single.return_value = profiles_query
    profiles_query.execute = AsyncMock(return_value=MagicMock(data={"mfa_trusted_devices": []}))
    profiles_query.update.return_value = profiles_query

    def table_router(name):
        if name == "auth_recovery_otps":
            return otps_query
        return profiles_query

    client_mock.table.side_effect = table_router

    from app.services.supabase_service import supabase_service

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=client_mock)):
        req = VerifyMfaCodeRequest(code="123456", phone_or_email="61999998888", remember_device=True)
        res = await verify_mfa_code(req=req, credentials=None)
        assert res.success is True
        assert res.trusted_device_token is not None
        assert res.trusted_until is not None


@pytest.mark.asyncio
async def test_reset_mfa_totp():
    client_mock = MagicMock()
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()

    otp_row = {
        "id": "otp-1",
        "otp_code": "123456",
        "user_id": "user-123",
        "expires_at": expires_at,
        "used_at": None,
    }

    otps_query = MagicMock()
    otps_query.select.return_value = otps_query
    otps_query.eq.return_value = otps_query
    otps_query.is_.return_value = otps_query
    otps_query.gt.return_value = otps_query
    otps_query.in_.return_value = otps_query
    otps_query.order.return_value = otps_query
    otps_query.limit.return_value = otps_query
    otps_query.execute = AsyncMock(return_value=MagicMock(data=[otp_row]))
    otps_query.update.return_value = otps_query

    profiles_query = MagicMock()
    profiles_query.update.return_value = profiles_query
    profiles_query.eq.return_value = profiles_query
    profiles_query.execute = AsyncMock(return_value=MagicMock())

    def table_router(name):
        if name == "auth_recovery_otps":
            return otps_query
        return profiles_query

    client_mock.table.side_effect = table_router

    # Mock admin mfa factors
    factor_mock = MagicMock(id="factor-totp-1")
    client_mock.auth.admin.mfa.list_factors = AsyncMock(return_value=[factor_mock])
    client_mock.auth.admin.mfa.delete_factor = AsyncMock(return_value=True)

    from app.services.supabase_service import supabase_service

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=client_mock)):
        req = ResetMfaTotpRequest(code="123456", channel="whatsapp", phone_or_email="61999998888")
        res = await reset_mfa_totp(req=req, credentials=None)
        assert res["success"] is True
        assert res["deleted_factors"] == 1
        client_mock.auth.admin.mfa.delete_factor.assert_called_once_with({"id": "factor-totp-1", "user_id": "user-123"})
