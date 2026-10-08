from typing import Dict, Any
from datetime import datetime, timezone
from fastapi import Depends, HTTPException, status
from app.core.security import get_current_user_payload
from app.services.gemini_service import gemini_service, GeminiService
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.core.config import settings


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
        .select("role, roles, trainer_id, session_revoked_at")
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

    roles = profile.get("roles") or [profile.get("role")]
    payload["profile"] = profile
    return payload


async def get_current_trainer(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    if "trainer" not in roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso exclusivo para treinadores.")
    if current_user.get("aal") != "aal2":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verificação em duas etapas obrigatória para treinadores.")
    return current_user


async def get_current_client(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    if "client" not in roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso exclusivo para alunos.")
    return current_user


def get_gemini_service() -> GeminiService:
    return gemini_service
