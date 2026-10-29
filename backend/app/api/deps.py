from typing import Dict, Any
from datetime import datetime, timezone, timedelta
from fastapi import Depends, HTTPException, status
from app.core.security import get_current_user_payload
from app.services.gemini_service import gemini_service, GeminiService
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.core.config import settings
from app.services.mfa_security import has_recent_mfa


_CANONICAL_OWNER_IDS = {
    "6f645308-f1b2-4d73-ac45-9890c27e20d4",
    "50c26610-8054-4b05-9274-7f414f91f52f",
    "92dfd58c-845f-473e-b846-a2b8fdd3e508",
}


def _is_synthetic_provisioned_email(email: str) -> bool:
    clean = (email or "").strip().lower()
    if not clean:
        return False
    return (
        clean.startswith("wa_")
        or clean.startswith("aluno_")
        or clean.endswith(".internal")
        or clean.endswith(".local")
    )


async def get_current_user(payload: Dict[str, Any] = Depends(get_current_user_payload)) -> Dict[str, Any]:
    user_id = payload.get("sub")
    if settings.ENVIRONMENT.lower() != "production" and user_id == "dev-user-0000-0000-000000000001":
        payload["aal"] = "aal2"
        payload["profile"] = {
            "role": "trainer",
            "roles": ["trainer", "client"],
            "trainer_id": "current-trainer",
        }
        return payload
    if not is_valid_uuid(user_id):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Identidade inválida.")

    client = await supabase_service.get_client()
    if client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Não foi possível validar a sessão.")
    result = await (
        client.table("profiles")
        .select("role, roles, trainer_id, session_revoked_at, subscription_status, mfa_verified_at, mfa_trusted_devices")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    profile = result.data if result else None
    if not profile:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Perfil autenticado não encontrado.")

    revoked_at = profile.get("session_revoked_at")
    issued_at = payload.get("iat")
    if revoked_at:
        try:
            revoked_time = datetime.fromisoformat(str(revoked_at).replace("Z", "+00:00"))
            token_time = datetime.fromtimestamp(float(issued_at), tz=timezone.utc)
        except (TypeError, ValueError, OSError):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sessão revogada.")
        if token_time <= revoked_time:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Sessão revogada. Entre novamente.")

    # Blindagem contra escalação acidental em contas sintéticas (WhatsApp OTP / Checkout rápido)
    jwt_email = str(payload.get("email") or "").strip().lower()
    if str(user_id).lower() not in _CANONICAL_OWNER_IDS and _is_synthetic_provisioned_email(jwt_email):
        raw_roles = [str(r).strip().lower() for r in (profile.get("roles") or [profile.get("role") or "client"]) if r]
        if "admin" in raw_roles or str(profile.get("role") or "").strip().lower() == "admin":
            cleaned_roles = [r for r in raw_roles if r != "admin"]
            clean_primary = "trainer" if "trainer" in cleaned_roles else "client"
            if not cleaned_roles:
                cleaned_roles = [clean_primary]
            profile["role"] = clean_primary
            profile["roles"] = cleaned_roles
            profile["is_admin"] = False
            try:
                await client.table("profiles").update({
                    "role": clean_primary,
                    "roles": cleaned_roles,
                    "is_admin": False,
                    "is_vip": False,
                }).eq("id", user_id).execute()
            except Exception:
                pass

    roles = profile.get("roles") or [profile.get("role")]
    payload["profile"] = profile
    return payload


async def get_current_trainer(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    if "trainer" not in roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso exclusivo para treinadores.")
    
    # 2FA aceita AAL2 nativo (TOTP) OU verificação multi-canal recente (janela curta de sessão).
    # A confiança de 30 dias é por dispositivo e renovada via /auth/mfa/trusted-login.
    is_aal2 = current_user.get("aal") == "aal2"
    has_valid_multichannel_mfa = has_recent_mfa(profile)

    if not is_aal2 and not has_valid_multichannel_mfa:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verificação em duas etapas obrigatória para treinadores.")
    return current_user


async def get_current_client(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    if "client" not in roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso exclusivo para alunos.")
    if str(profile.get("subscription_status") or "").lower() == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso suspenso pelo seu professor. Entre em contato com ele para regularizar.",
        )
    return current_user


def get_gemini_service() -> GeminiService:
    return gemini_service
