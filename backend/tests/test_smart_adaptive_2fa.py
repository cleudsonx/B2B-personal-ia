import re
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.api.v1.endpoints import auth as auth_ep
from app.api.v1.endpoints.auth import (
    RequestMfaCodeRequest,
    ResetMfaTotpRequest,
    TrustedLoginRequest,
    UpdateContactChannelRequest,
    VerifyBackupCodeRequest,
    VerifyMfaCodeRequest,
)
from app.services import mfa_security as mfa
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service

USER = "11111111-1111-1111-1111-111111111111"
CREDS = HTTPAuthorizationCredentials(scheme="Bearer", credentials="jwt")


# ---------------------------------------------------------------- fake supabase
class FakeResult:
    def __init__(self, data):
        self.data = data


class FakeQuery:
    def __init__(self, db, name):
        self.db, self.name = db, name
        self.filters, self._order, self._limit = [], None, None
        self._single, self._insert, self._update = False, None, None

    def select(self, *_a, **_k):
        return self

    def eq(self, k, v):
        self.filters.append(lambda r: r.get(k) == v)
        return self

    def is_(self, k, _v):
        self.filters.append(lambda r: r.get(k) is None)
        return self

    def gt(self, k, v):
        def f(r):
            a, b = mfa.parse_ts(r.get(k)), mfa.parse_ts(v)
            return a is not None and a > b
        self.filters.append(f)
        return self

    def order(self, k, desc=False):
        self._order = (k, desc)
        return self

    def limit(self, n):
        self._limit = n
        return self

    def maybe_single(self):
        self._single = True
        return self

    def insert(self, row):
        self._insert = row
        return self

    def update(self, patch):
        self._update = patch
        return self

    async def execute(self):
        rows = self.db.setdefault(self.name, [])
        if self._insert is not None:
            row = {
                "id": str(uuid.uuid4()),
                "used_at": None,
                "attempts": 0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat(),
                **self._insert,
            }
            rows.append(row)
            return FakeResult([row])
        matched = [r for r in rows if all(f(r) for f in self.filters)]
        if self._update is not None:
            for r in matched:
                r.update(self._update)
            return FakeResult(matched)
        if self._order:
            k, desc = self._order
            matched.sort(key=lambda r: str(r.get(k)), reverse=desc)
        if self._limit:
            matched = matched[: self._limit]
        if self._single:
            return FakeResult(matched[0] if matched else None)
        return FakeResult(matched)


def make_client(profile_extra=None):
    db = {
        "profiles": [{
            "id": USER,
            "full_name": "Prof Teste",
            "phone": "61999998888",
            "public_whatsapp": "61999998888",
            "mfa_trusted_devices": [],
            "mfa_backup_codes": [],
            "mfa_backup_failed_attempts": 0,
            "mfa_backup_locked_until": None,
            "mfa_verified_at": None,
            **(profile_extra or {}),
        }],
        "auth_recovery_otps": [],
    }
    client = MagicMock()
    client.db = db
    client.table.side_effect = lambda name: FakeQuery(db, name)
    client.auth.admin.get_user_by_id = AsyncMock(
        return_value=MagicMock(user=MagicMock(email="prof@example.com", phone="61999998888"))
    )
    client.auth.admin.update_user_by_id = AsyncMock(return_value=True)
    client.auth.admin.mfa.list_factors = AsyncMock(return_value=[MagicMock(id="factor-1")])
    client.auth.admin.mfa.delete_factor = AsyncMock(return_value=True)
    return client


@pytest.fixture
def env():
    client = make_client()
    sent = []

    async def fake_send(number, text, *args, **kwargs):
        sent.append(text)
        return {"status": "sent"}

    with patch.object(supabase_service, "get_client", new=AsyncMock(return_value=client)), \
         patch.object(whatsapp_service, "send_text_with_fallback", new=fake_send), \
         patch.object(auth_ep, "decode_supabase_jwt", return_value={"sub": USER}):
        yield client, sent


def last_code(sent):
    return re.search(r"\*(\d{6})\*", sent[-1]).group(1)


def age_otps(client, seconds=120):
    for r in client.db["auth_recovery_otps"]:
        r["created_at"] = (datetime.now(timezone.utc) - timedelta(seconds=seconds)).isoformat()


async def request_whatsapp(client, sent):
    res = await auth_ep.request_mfa_code(RequestMfaCodeRequest(channel="whatsapp"), credentials=CREDS)
    return res


# ---------------------------------------------------------------- request-code
@pytest.mark.asyncio
async def test_request_code_requires_authentication(env):
    with pytest.raises(HTTPException) as exc:
        await auth_ep.request_mfa_code(RequestMfaCodeRequest(channel="whatsapp"), credentials=None)
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_request_code_stores_only_hash_and_masks_target(env):
    client, sent = env
    res = await request_whatsapp(client, sent)
    code = last_code(sent)
    assert "9****-8888" in res.masked_target
    row = client.db["auth_recovery_otps"][0]
    assert row["otp_code"] != code
    assert len(row["otp_code"]) == 64
    assert row["purpose"] == "mfa_challenge"


@pytest.mark.asyncio
async def test_request_code_cooldown_and_hourly_limit(env):
    client, sent = env
    await request_whatsapp(client, sent)
    with pytest.raises(HTTPException) as exc:
        await request_whatsapp(client, sent)
    assert exc.value.status_code == 429

    for _ in range(mfa.MAX_OTP_REQUESTS_PER_HOUR):
        client.db["auth_recovery_otps"].append({
            "id": str(uuid.uuid4()), "user_id": USER, "purpose": "mfa_challenge",
            "created_at": (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat(),
        })
    age_otps(client, seconds=3000)
    with pytest.raises(HTTPException) as exc:
        await request_whatsapp(client, sent)
    assert exc.value.status_code == 429
    assert "hora" in exc.value.detail


# ---------------------------------------------------------------- verify-code
@pytest.mark.asyncio
async def test_verify_code_success_registers_hashed_trusted_device(env):
    client, sent = env
    await request_whatsapp(client, sent)
    res = await auth_ep.verify_mfa_code(
        VerifyMfaCodeRequest(code=last_code(sent), remember_device=True), credentials=CREDS
    )
    assert res.success and res.trusted_device_token
    profile = client.db["profiles"][0]
    assert profile["mfa_verified_at"]
    device = profile["mfa_trusted_devices"][0]
    assert "token" not in device
    assert device["token_hash"] != res.trusted_device_token


@pytest.mark.asyncio
async def test_verify_code_without_remember_does_not_register_device(env):
    client, sent = env
    await request_whatsapp(client, sent)
    res = await auth_ep.verify_mfa_code(VerifyMfaCodeRequest(code=last_code(sent)), credentials=CREDS)
    assert res.trusted_device_token is None
    assert client.db["profiles"][0]["mfa_trusted_devices"] == []


@pytest.mark.asyncio
async def test_otp_is_single_use(env):
    client, sent = env
    await request_whatsapp(client, sent)
    code = last_code(sent)
    await auth_ep.verify_mfa_code(VerifyMfaCodeRequest(code=code), credentials=CREDS)
    with pytest.raises(HTTPException) as exc:
        await auth_ep.verify_mfa_code(VerifyMfaCodeRequest(code=code), credentials=CREDS)
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_otp_locks_after_max_wrong_attempts(env):
    client, sent = env
    await request_whatsapp(client, sent)
    good = last_code(sent)
    wrong = "000000" if good != "000000" else "111111"
    for i in range(mfa.MAX_OTP_ATTEMPTS):
        with pytest.raises(HTTPException) as exc:
            await auth_ep.verify_mfa_code(VerifyMfaCodeRequest(code=wrong), credentials=CREDS)
        assert exc.value.status_code in (400, 429)
    # Depois do bloqueio, nem o código correto funciona
    with pytest.raises(HTTPException):
        await auth_ep.verify_mfa_code(VerifyMfaCodeRequest(code=good), credentials=CREDS)
    assert client.db["profiles"][0]["mfa_verified_at"] is None


# ---------------------------------------------------------------- trusted-login
@pytest.mark.asyncio
async def test_trusted_login_validates_token_on_server(env):
    client, sent = env
    await request_whatsapp(client, sent)
    res = await auth_ep.verify_mfa_code(
        VerifyMfaCodeRequest(code=last_code(sent), remember_device=True), credentials=CREDS
    )
    client.db["profiles"][0]["mfa_verified_at"] = None  # sessão nova

    ok = await auth_ep.trusted_device_login(
        TrustedLoginRequest(trusted_device_token=res.trusted_device_token), credentials=CREDS
    )
    assert ok["success"] and client.db["profiles"][0]["mfa_verified_at"]

    client.db["profiles"][0]["mfa_verified_at"] = None
    with pytest.raises(HTTPException) as exc:
        await auth_ep.trusted_device_login(
            TrustedLoginRequest(trusted_device_token="x" * 43), credentials=CREDS
        )
    assert exc.value.status_code == 403
    assert client.db["profiles"][0]["mfa_verified_at"] is None


@pytest.mark.asyncio
async def test_trusted_login_rejects_expired_device(env):
    client, sent = env
    await request_whatsapp(client, sent)
    res = await auth_ep.verify_mfa_code(
        VerifyMfaCodeRequest(code=last_code(sent), remember_device=True), credentials=CREDS
    )
    client.db["profiles"][0]["mfa_trusted_devices"][0]["expires_at"] = (
        datetime.now(timezone.utc) - timedelta(days=1)
    ).isoformat()
    with pytest.raises(HTTPException) as exc:
        await auth_ep.trusted_device_login(
            TrustedLoginRequest(trusted_device_token=res.trusted_device_token), credentials=CREDS
        )
    assert exc.value.status_code == 403


# ---------------------------------------------------------------- reset TOTP
@pytest.mark.asyncio
async def test_reset_totp_deletes_factors_and_revokes_devices(env):
    client, sent = env
    client.db["profiles"][0]["mfa_trusted_devices"] = [{"token_hash": "h", "expires_at": "2099-01-01T00:00:00+00:00"}]
    await request_whatsapp(client, sent)
    res = await auth_ep.reset_mfa_totp(
        ResetMfaTotpRequest(code=last_code(sent), channel="whatsapp"), credentials=CREDS
    )
    assert res["success"] and res["deleted_factors"] == 1
    client.auth.admin.mfa.delete_factor.assert_called_once_with({"id": "factor-1", "user_id": USER})
    assert client.db["profiles"][0]["mfa_trusted_devices"] == []


# ---------------------------------------------------------------- backup codes
def user_ctx(client, verified=True, aal=None):
    profile = dict(client.db["profiles"][0])
    if verified:
        profile["mfa_verified_at"] = datetime.now(timezone.utc).isoformat()
    ctx = {"sub": USER, "profile": profile}
    if aal:
        ctx["aal"] = aal
    return ctx


@pytest.mark.asyncio
async def test_backup_generate_requires_recent_mfa(env):
    client, _ = env
    with pytest.raises(HTTPException) as exc:
        await auth_ep.generate_backup_codes(current_user=user_ctx(client, verified=False))
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_backup_codes_hashed_single_use_and_enterable(env):
    client, _ = env
    res = await auth_ep.generate_backup_codes(current_user=user_ctx(client))
    assert len(res.backup_codes) == mfa.BACKUP_CODE_COUNT
    stored = client.db["profiles"][0]["mfa_backup_codes"]
    assert all(len(h) == 64 for h in stored)
    shown = res.backup_codes[0]
    assert re.fullmatch(r"[A-Z2-9]{5}-[A-Z2-9]{5}", shown)

    # Aceita minúsculas, com ou sem hífen/espaços
    out = await auth_ep.verify_backup_code(
        VerifyBackupCodeRequest(code=shown.lower().replace("-", " ")), credentials=CREDS
    )
    assert out["success"] and out["remaining_codes"] == mfa.BACKUP_CODE_COUNT - 1
    with pytest.raises(HTTPException):
        await auth_ep.verify_backup_code(VerifyBackupCodeRequest(code=shown), credentials=CREDS)


@pytest.mark.asyncio
async def test_backup_code_lockout_after_failures(env):
    client, _ = env
    res = await auth_ep.generate_backup_codes(current_user=user_ctx(client))
    for _ in range(mfa.MAX_BACKUP_FAILURES):
        with pytest.raises(HTTPException) as exc:
            await auth_ep.verify_backup_code(VerifyBackupCodeRequest(code="AAAAA-BBBBB"), credentials=CREDS)
        assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        await auth_ep.verify_backup_code(VerifyBackupCodeRequest(code=res.backup_codes[0]), credentials=CREDS)
    assert exc.value.status_code == 429


# ---------------------------------------------------------------- contatos
@pytest.mark.asyncio
async def test_update_contact_enforces_cross_channel(env):
    client, _ = env
    ctx = user_ctx(client)
    with pytest.raises(HTTPException) as exc:
        await auth_ep.update_contact_channel(
            UpdateContactChannelRequest(new_phone="61988887777", validation_code="123456", validation_channel="whatsapp"),
            current_user=ctx,
        )
    assert exc.value.status_code == 400
    with pytest.raises(HTTPException) as exc:
        await auth_ep.update_contact_channel(
            UpdateContactChannelRequest(new_email="novo@example.com", validation_code="123456", validation_channel="email"),
            current_user=ctx,
        )
    assert exc.value.status_code == 400


@pytest.mark.asyncio
async def test_update_contact_requires_recent_mfa(env):
    client, _ = env
    with pytest.raises(HTTPException) as exc:
        await auth_ep.update_contact_channel(
            UpdateContactChannelRequest(new_phone="61988887777", validation_code="123456", validation_channel="email"),
            current_user=user_ctx(client, verified=False),
        )
    assert exc.value.status_code == 403


@pytest.mark.asyncio
async def test_update_contact_phone_with_email_code(env):
    client, _ = env
    client.db["auth_recovery_otps"].append({
        "id": "o1", "user_id": USER, "purpose": "mfa_challenge", "channel": "email", "attempts": 0,
        "otp_code": mfa.hash_secret("654321", "mfa-otp"), "used_at": None,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
    })
    out = await auth_ep.update_contact_channel(
        UpdateContactChannelRequest(new_phone="(61) 98888-7777", validation_code="654321", validation_channel="email"),
        current_user=user_ctx(client),
    )
    assert out["success"]
    assert client.db["profiles"][0]["phone"] == "61988887777"


# ---------------------------------------------------------------- janela de sessão
def test_has_recent_mfa_window():
    now = datetime.now(timezone.utc)
    assert mfa.has_recent_mfa({"mfa_verified_at": now.isoformat()})
    old = now - timedelta(hours=mfa.MFA_SESSION_HOURS + 1)
    assert not mfa.has_recent_mfa({"mfa_verified_at": old.isoformat()})
    assert not mfa.has_recent_mfa({"mfa_verified_at": None})
    assert not mfa.has_recent_mfa({})
