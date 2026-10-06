import secrets
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.api.deps import get_current_user
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.audit_service import log_audit_event

logger = logging.getLogger(__name__)
router = APIRouter()

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
    current_user: Dict[str, Any] = Depends(get_current_user),
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

    # Constrói o link de convite (deeplink / landing page)
    # Por padrão aponta para o domínio web ou deeplink do app
    invite_url = f"https://mrcoach.app/invite/{token}"

    return CreateInviteResponse(
        token=token,
        invite_url=invite_url,
        channel=body.channel,
        expires_at=str(expires_at_str),
    )


@router.post("/consume", response_model=ConsumeInviteResponse, summary="Validar e Consumir Convite de Aluno")
async def consume_invite(
    body: ConsumeInviteRequest,
    request: Request,
):
    """
    Aluno abre o convite no app ou web.
    Valida token, verifica expiração e se já foi consumido.
    Marca como used_at e audita o consumo.
    """
    token = body.token.strip()
    client_ip = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Falha na conexão com banco de dados.")

    # 1. Busca token no banco
    res = await client.table("invite_tokens").select("*").eq("token", token).maybe_single().execute()
    if not res or not res.data:
        # Registra falha de auditoria
        await log_audit_event(
            event_type="invite_failed",
            token=token,
            trainer_id="00000000-0000-0000-0000-000000000000",
            channel="email",
            ip_address=client_ip,
            user_agent=user_agent,
            details={"reason": "token_not_found"}
        )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Convite não encontrado ou inválido.")

    invite_data = res.data
    trainer_id = invite_data.get("trainer_id")
    channel = invite_data.get("channel") or "email"
    target_email = invite_data.get("target_email")
    target_phone = invite_data.get("target_phone")

    # 2. Verifica se já foi usado
    if invite_data.get("used_at"):
        await log_audit_event(
            event_type="invite_failed",
            token=token,
            trainer_id=trainer_id,
            channel=channel,
            target_email=target_email,
            target_phone=target_phone,
            ip_address=client_ip,
            user_agent=user_agent,
            details={"reason": "already_used", "used_at": invite_data.get("used_at")}
        )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite já foi utilizado.")

    # 3. Verifica expiração
    expires_at_val = invite_data.get("expires_at")
    if expires_at_val:
        expires_dt = datetime.fromisoformat(expires_at_val.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > expires_dt:
            await log_audit_event(
                event_type="invite_failed",
                token=token,
                trainer_id=trainer_id,
                channel=channel,
                target_email=target_email,
                target_phone=target_phone,
                ip_address=client_ip,
                user_agent=user_agent,
                details={"reason": "expired", "expires_at": expires_at_val}
            )
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Este convite expirou.")

    # 4. Busca dados públicos do treinador para acolhimento
    trainer_res = await client.table("profiles").select("id, full_name").eq("id", trainer_id).maybe_single().execute()
    trainer_name = "Seu Personal Trainer"
    if trainer_res and trainer_res.data:
        trainer_name = trainer_res.data.get("full_name") or trainer_name

    # 5. Marca o token como consumido
    now_utc = datetime.now(timezone.utc).isoformat()
    await client.table("invite_tokens").update({"used_at": now_utc}).eq("token", token).execute()

    # 6. Grava auditoria de sucesso
    await log_audit_event(
        event_type="invite_consumed",
        token=token,
        trainer_id=trainer_id,
        channel=channel,
        target_email=target_email,
        target_phone=target_phone,
        ip_address=client_ip,
        user_agent=user_agent,
        details={"status": "success", "trainer_name": trainer_name}
    )

    return ConsumeInviteResponse(
        status="consumed",
        trainer_id=str(trainer_id),
        trainer_name=trainer_name,
        target_email=target_email,
        target_phone=target_phone,
    )

