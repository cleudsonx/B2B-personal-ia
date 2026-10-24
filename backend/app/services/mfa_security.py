"""Primitivas de segurança do 2FA adaptativo (OTP, códigos de reserva e dispositivos confiáveis)."""
import hashlib
import hmac
import re
import secrets
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, Optional

from app.core.config import settings

# --- Políticas ---------------------------------------------------------------
MAX_OTP_ATTEMPTS = 5
OTP_RESEND_COOLDOWN_SECONDS = 45
MAX_OTP_REQUESTS_PER_HOUR = 6
MFA_SESSION_HOURS = 12            # validade de mfa_verified_at (sessão curta)
TRUSTED_DEVICE_DAYS = 30
MAX_TRUSTED_DEVICES = 10
BACKUP_CODE_COUNT = 8
BACKUP_CODE_LENGTH = 10
MAX_BACKUP_FAILURES = 5
BACKUP_LOCK_MINUTES = 15

# Alfabeto sem caracteres ambíguos (0/O, 1/I)
_BACKUP_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _pepper() -> bytes:
    value = settings.SUPABASE_JWT_SECRET or settings.SUPABASE_SECRET_KEY or "dev-only-pepper"
    return value.encode("utf-8")


def hash_secret(value: str, purpose: str) -> str:
    """HMAC-SHA256 com pepper do servidor e separação por propósito."""
    msg = f"{purpose}:{value}".encode("utf-8")
    return hmac.new(_pepper(), msg, hashlib.sha256).hexdigest()


def verify_secret(value: str, purpose: str, stored_hash: Optional[str]) -> bool:
    if not stored_hash:
        return False
    return hmac.compare_digest(hash_secret(value, purpose), str(stored_hash))


def generate_otp() -> str:
    return f"{secrets.randbelow(900000) + 100000}"


def generate_trusted_token() -> str:
    return secrets.token_urlsafe(32)


def normalize_backup_code(raw: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", raw or "").upper()


def generate_backup_code() -> str:
    """Retorna o código normalizado (10 caracteres, sem hífen)."""
    return "".join(secrets.choice(_BACKUP_ALPHABET) for _ in range(BACKUP_CODE_LENGTH))


def format_backup_code(code: str) -> str:
    half = BACKUP_CODE_LENGTH // 2
    return f"{code[:half]}-{code[half:]}"


def parse_ts(value: Any) -> Optional[datetime]:
    if not value:
        return None
    try:
        dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def has_recent_mfa(profile: Dict[str, Any]) -> bool:
    """True se o profile tem verificação multi-canal dentro da janela de sessão."""
    verified_at = parse_ts((profile or {}).get("mfa_verified_at"))
    if not verified_at:
        return False
    return datetime.now(timezone.utc) - verified_at < timedelta(hours=MFA_SESSION_HOURS)

