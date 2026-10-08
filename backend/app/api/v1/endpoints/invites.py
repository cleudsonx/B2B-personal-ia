import secrets
import logging
import re
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.api.deps import get_current_user, get_current_trainer
from app.core.config import settings
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.audit_service import log_audit_event

logger = logging.getLogger(__name__)
router = APIRouter()


def _normalize_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone)
    return digits[2:] if digits.startswith("55") and len(digits) > 11 else digits

# ---------------------------------------------------------
# Schemas Pydantic
# ---------------------------------------------------------
class CreateInviteRequest(BaseModel):
    channel: str = Field(..., pattern="^(email|whatsapp)$", description="Canal de envio: 'email' ou 'whatsapp'")
    target_email: Optional[EmailStr] = None
    target_phone: Optional[str] = None

class CreateInviteResponse(BaseModel):
    token: str
    invite_url: str
    channel: str
    expires_at: str

class ValidateInviteResponse(BaseModel):
    is_valid: bool
    trainer_id: str
    trainer_name: str
    target_email: Optional[str] = None
    target_phone: Optional[str] = None
    channel: str

class ConsumeInviteRequest(BaseModel):
    token: str

class ConsumeInviteResponse(BaseModel):
    status: str
    trainer_id: str
    trainer_name: str
    target_email: Optional[str] = None
    target_phone: Optional[str] = None


# ---------------------------------------------------------
# Endpoints
# ---------------------------------------------------------

@router.post("/create", response_model=CreateInviteResponse, summary="Gerar Convite Único Intransferível")
async def create_invite(
    body: CreateInviteRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Treinador autenticado gera um convite único atrelado ao e-mail ou WhatsApp do aluno.
    Gera token criptográfico seguro de 32 bytes e registra em audit_log.
    """
    trainer_id = current_user.get("id") or current_user.get("sub")
    if not trainer_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuário não autenticado.")

    if body.channel == "email" and not body.target_email:
        raise HTTPException(status_code=400, detail="E-mail de destino é obrigatório para canal 'email'.")
    if body.channel == "whatsapp" and not body.target_phone:
        raise HTTPException(status_code=400, detail="Telefone de destino é obrigatório para canal 'whatsapp'.")

    # Gera token seguro de alta entropia
    token = secrets.token_urlsafe(32)

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Falha na conexão com banco de dados.")

    # Insere token na tabela invite_tokens
    insert_data = {
        "token": token,
        "trainer_id": trainer_id,
        "channel": body.channel,
        "target_email": str(body.target_email) if body.target_email else None,
        "target_phone": body.target_phone,
    }

    try:
        res = await client.table("invite_tokens").insert(insert_data).execute()
        created_row = res.data[0] if res.data else None
        expires_at_str = created_row.get("expires_at") if created_row else ""
    except Exception as e:
        logger.error(f"[Invites] Erro ao salvar invite_token: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Erro ao gerar token de convite.")

    # Grava na auditoria imutável
    await log_audit_event(
        event_type="invite_created",
        token=token,
        trainer_id=trainer_id,
        channel=body.channel,
        target_email=str(body.target_email) if body.target_email else None,
        target_phone=body.target_phone,
        details={"origin": "trainer_dashboard"}
    )

    # Constrói o link de convite usando o domínio web configurado.
    invite_url = f"{settings.APP_FRONTEND_URL.rstrip('/')}/#/invite/{token}"

    return CreateInviteResponse(
        token=token,
        invite_url=invite_url,
        channel=body.channel,
        expires_at=str(expires_at_str),
    )


@router.get("/validate/{token}", response_model=ValidateInviteResponse, summary="Validar Convite sem Consumir")
async def validate_invite(token: str):
    token = token.strip()
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Falha na conexão com banco de dados.")

    res = await client.table("invite_tokens").select("*").eq("token", token).maybe_single().execute()
    if not res or not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Convite não encontrado ou inválido.")

    invite_data = res.data
    if invite_data.get("used_at"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite já foi utilizado.")

    expires_at_val = invite_data.get("expires_at")
    if expires_at_val:
        expires_dt = datetime.fromisoformat(expires_at_val.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > expires_dt:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite expirou.")

    trainer_id = invite_data.get("trainer_id")
    trainer_res = await client.table("profiles").select("id, full_name").eq("id", trainer_id).maybe_single().execute()
    trainer_name = "Seu Personal Trainer"
    if trainer_res and trainer_res.data:
        trainer_name = trainer_res.data.get("full_name") or trainer_name

    return ValidateInviteResponse(
        is_valid=True,
        trainer_id=str(trainer_id),
        trainer_name=trainer_name,
        target_email=invite_data.get("target_email"),
        target_phone=invite_data.get("target_phone"),
        channel=invite_data.get("channel") or "email",
    )

@router.post("/consume", response_model=ConsumeInviteResponse, summary="Consumir Convite e Vincular Aluno")
async def consume_invite(
    body: ConsumeInviteRequest,
    request: Request,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Aluno consome o convite após criar a conta e estar autenticado.
    Verifica se o token é válido, marca como usado e vincula o trainer_id ao perfil do aluno.
    """
    student_id = current_user.get("id") or current_user.get("sub")
    if not student_id:
        raise HTTPException(status_code=401, detail="Usuário não autenticado.")

    token = body.token.strip()
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Falha na conexão com banco de dados.")

    res = await client.table("invite_tokens").select("*").eq("token", token).maybe_single().execute()
    if not res or not res.data:
        await log_audit_event(
            event_type="invite_failed",
            token=token,
            trainer_id="00000000-0000-0000-0000-000000000000",
            channel="email",
            ip_address=client_ip,
            user_agent=user_agent,
            details={"reason": "token_not_found"},
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Convite não encontrado ou inválido.")

    invite_data = res.data
    trainer_id = invite_data.get("trainer_id")
    channel = invite_data.get("channel") or "email"
    target_email = invite_data.get("target_email")
    target_phone = invite_data.get("target_phone")

    if invite_data.get("used_at"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite já foi utilizado.")

    expires_at_val = invite_data.get("expires_at")
    if expires_at_val:
        expires_dt = datetime.fromisoformat(expires_at_val.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > expires_dt:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite expirou.")

    # Verifica se o e-mail/telefone do aluno bate com o do convite (opcional/fortemente recomendado)
    student_email = current_user.get("email")
    user_metadata = current_user.get("user_metadata") or {}
    student_phone = current_user.get("phone") or user_metadata.get("phone")
    if not student_phone:
        profile_res = await client.table("profiles").select("phone").eq("id", student_id).maybe_single().execute()
        student_phone = profile_res.data.get("phone") if profile_res and profile_res.data else None

    # Regra: se o convite foi direcionado, o alvo deve coincidir
    if channel == "email" and target_email:
        if not student_email or target_email.strip().lower() != student_email.strip().lower():
            raise HTTPException(status_code=403, detail="Este convite foi destinado a outro e-mail.")
    
    if channel == "whatsapp" and target_phone:
        invited_phone = _normalize_phone(target_phone)
        registered_phone = _normalize_phone(student_phone or "")
        if not registered_phone or invited_phone != registered_phone:
            raise HTTPException(status_code=403, detail="Este convite foi destinado a outro telefone.")

    profile_res = await client.table("profiles").select("role, roles").eq("id", student_id).maybe_single().execute()
    if not profile_res or not profile_res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Perfil do usuário não encontrado.")
    profile = profile_res.data
    roles = profile.get("roles") or [profile.get("role")]
    updated_roles = list(dict.fromkeys([*roles, "client"]))

    await client.table("profiles").update({
        "trainer_id": trainer_id,
        "roles": updated_roles,
    }).eq("id", student_id).execute()

    # Marca o token como consumido
    now_utc = datetime.now(timezone.utc).isoformat()
    await client.table("invite_tokens").update({"used_at": now_utc}).eq("token", token).execute()

    # Busca nome do treinador
    trainer_res = await client.table("profiles").select("full_name").eq("id", trainer_id).maybe_single().execute()
    trainer_name = "Seu Personal Trainer"
    if trainer_res and trainer_res.data:
        trainer_name = trainer_res.data.get("full_name") or trainer_name

    await log_audit_event(
        event_type="invite_consumed",
        token=token,
        trainer_id=trainer_id,
        channel=channel,
        target_email=target_email,
        target_phone=target_phone,
        ip_address=client_ip,
        user_agent=user_agent,
        details={"status": "success", "trainer_name": trainer_name, "student_id": student_id}
    )

    return ConsumeInviteResponse(
        status="consumed",
        trainer_id=str(trainer_id),
        trainer_name=trainer_name,
        target_email=target_email,
        target_phone=target_phone,
    )


