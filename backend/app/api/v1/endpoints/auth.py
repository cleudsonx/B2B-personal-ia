import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field
from app.services.supabase_service import supabase_service
import re

logger = logging.getLogger(__name__)
router = APIRouter()



class DirectRegisterRequest(BaseModel):
    email: str
    password: str = Field(..., min_length=6)
    full_name: str
    role: str = Field("trainer", description="'trainer' ou 'client'")
    phone: Optional[str] = None
    trainer_id: Optional[str] = None
    invite_token: Optional[str] = None
    professional_document_type: Optional[str] = None
    professional_document: Optional[str] = None
    photo_url: Optional[str] = None


class DirectRegisterResponse(BaseModel):
    success: bool
    user_id: str
    email: str
    role: str
    message: str


@router.post("/register-direct", response_model=DirectRegisterResponse)
async def register_user_direct(req: DirectRegisterRequest):
    """
    Cadastra o usuário diretamente via Admin API do Supabase com email pré-confirmado,
    bypassing falhas de SMTP/rate-limit de e-mail de confirmação do Supabase.
    """
    try:
        role = req.role.strip().lower()
        if role not in ("trainer", "client"):
            raise ValueError("Papel inválido. São aceitos apenas 'trainer' ou 'client'.")
        if role == "client":
            if not req.invite_token:
                raise ValueError("É necessário um convite válido para cadastrar uma conta de aluno.")
            client = await supabase_service.get_client()
            if not client:
                raise HTTPException(status_code=503, detail="Serviço de convites indisponível.")
            invite_res = await client.table("invite_tokens").select(
                "target_email, target_phone, channel, used_at, expires_at"
            ).eq("token", req.invite_token.strip()).maybe_single().execute()
            invite = invite_res.data if invite_res else None
            if not invite or invite.get("used_at"):
                raise ValueError("Convite não encontrado, expirado ou já utilizado.")
            expires_at = invite.get("expires_at")
            if expires_at and datetime.fromisoformat(expires_at.replace("Z", "+00:00")) <= datetime.now(timezone.utc):
                raise ValueError("Convite não encontrado, expirado ou já utilizado.")
            if invite.get("channel") == "email":
                if (req.email or "").strip().lower() != (invite.get("target_email") or "").strip().lower():
                    raise ValueError("Este convite foi destinado a outro e-mail.")
            elif invite.get("channel") == "whatsapp":
                invited_phone = re.sub(r"\D", "", invite.get("target_phone") or "")
                registered_phone = re.sub(r"\D", "", req.phone or "")
                if invited_phone.startswith("55") and len(invited_phone) > 11:
                    invited_phone = invited_phone[2:]
                if registered_phone.startswith("55") and len(registered_phone) > 11:
                    registered_phone = registered_phone[2:]
                if not registered_phone or invited_phone != registered_phone:
                    raise ValueError("Este convite foi destinado a outro telefone.")
            else:
                raise ValueError("Canal de convite inválido.")

        res = await supabase_service.admin_create_user(
            email=str(req.email),
            password=req.password,
            full_name=req.full_name,
            role=role,
            phone=req.phone,
            trainer_id=req.trainer_id if role != "client" else None,
            invite_token=req.invite_token,
            professional_document_type=req.professional_document_type,
            professional_document=req.professional_document,
            photo_url=req.photo_url,
        )
        return DirectRegisterResponse(**res)
    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro interno ao criar conta: {str(e)}")


from app.api.deps import get_current_user
from fastapi import Depends
from typing import Dict, Any

@router.get("/me")
async def get_my_profile(current_user: Dict[str, Any] = Depends(get_current_user)):
    """
    Retorna o perfil do usuário atual, incluindo o nome e a foto do seu professor vinculado (se for aluno).
    """
    user_id = current_user.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Usuário não autenticado.")
        
    profile = await supabase_service.get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Perfil não encontrado.")
        
    return profile


@router.post("/revoke-sessions")
async def revoke_all_sessions(current_user: Dict[str, Any] = Depends(get_current_user)):
    user_id = current_user.get("sub")
    client = await supabase_service.get_client()
    if not user_id or client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Não foi possível revogar as sessões.")
    result = await (
        client.table("profiles")
        .update({"session_revoked_at": datetime.now(timezone.utc).isoformat()})
        .eq("id", user_id)
        .execute()
    )
    if not result or not result.data:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Falha ao revogar as sessões da conta.")
    return {"success": True, "revoked_at": result.data[0].get("session_revoked_at")}


# ==============================================================================
# RECUPERAÇÃO DE ACESSO VIA WHATSAPP / OTP
# ==============================================================================

class RequestOtpRecovery(BaseModel):
    phone_or_email: str
    channel: str = Field("whatsapp", description="'whatsapp' ou 'email'")

class VerifyOtpResetPassword(BaseModel):
    phone_or_email: str
    otp_code: str
    new_password: str = Field(..., min_length=6)

import random
import re
from datetime import datetime, timezone
from app.services.whatsapp_service import whatsapp_service
from app.services.email_service import email_service
from app.services.audit_service import log_audit_event

@router.post("/recovery/request-otp")
async def request_recovery_otp(req: RequestOtpRecovery):
    """
    Solicita código OTP de 6 dígitos via WhatsApp ou E-mail para professor ou aluno.
    """
    identifier = req.phone_or_email.strip()
    clean_phone = re.sub(r"\D", "", identifier)

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Erro de conexão com o banco de dados.")

    user_row = None
    user_email = None
    user_id = None

    # 1. Se o identificador for e-mail, busca no auth.users via admin API
    if "@" in identifier:
        try:
            users = await client.auth.admin.list_users()
            user_target = next((u for u in users if u.email and u.email.lower() == identifier.lower()), None)
            if user_target:
                user_id = user_target.id
                user_email = user_target.email
                res = await client.table("profiles").select("id, full_name, phone, role").eq("id", user_id).maybe_single().execute()
                if res and res.data:
                    user_row = res.data
                else:
                    meta = user_target.user_metadata or {}
                    user_row = {
                        "id": user_id,
                        "full_name": meta.get("full_name") or "Usuário",
                        "phone": getattr(user_target, "phone", None),
                        "role": "client",
                    }
        except Exception as e:
            logger.error(f"[Recovery] Erro ao buscar usuário por email no auth.admin: {e}")

    # 2. Se não encontrou e temos um telefone com DDD (>= 10 dígitos)
    if not user_row and clean_phone and len(clean_phone) >= 10:
        try:
            res = await client.table("profiles").select("id, full_name, phone, role").ilike("phone", f"%{clean_phone[-9:]}%").maybe_single().execute()
            if res and res.data:
                user_row = res.data
                user_id = user_row["id"]
                try:
                    admin_user = await client.auth.admin.get_user_by_id(user_id)
                    if admin_user and hasattr(admin_user, "user") and admin_user.user:
                        user_email = admin_user.user.email
                except Exception:
                    pass
        except Exception as e:
            logger.error(f"[Recovery] Erro ao buscar usuário por telefone no profiles: {e}")

    # Se não encontrou usuário, responde genericamente para evitar enumeração
    if not user_row or not user_id:
        return {"success": True, "message": "Se os dados constarem no sistema, o código de recuperação será enviado."}

    full_name = user_row.get("full_name") or "Usuário"
    phone_target = user_row.get("phone") or (clean_phone if len(clean_phone) >= 10 else None)

    # 3. Gera OTP numérico de 6 dígitos
    otp_code = f"{random.randint(100000, 999999)}"

    # 4. Salva na tabela auth_recovery_otps com identificadores normalizados
    identifiers_to_save = {identifier.strip().lower() if "@" in identifier else identifier.strip()}
    if clean_phone and len(clean_phone) >= 10:
        identifiers_to_save.add(clean_phone)
        identifiers_to_save.add(f"55{clean_phone}" if not clean_phone.startswith("55") else clean_phone)
    if user_email:
        identifiers_to_save.add(user_email.strip().lower())

    for ident in identifiers_to_save:
        try:
            await client.table("auth_recovery_otps").insert({
                "identifier": ident,
                "channel": req.channel,
                "otp_code": otp_code,
                "user_id": user_id,
            }).execute()
        except Exception as e:
            logger.warning(f"[Recovery] Falha ao registrar OTP para {ident}: {e}")

    # 5. Envia via WhatsApp (Evolution API)
    if req.channel == "whatsapp" and phone_target:
        formatted_phone = phone_target if phone_target.startswith("55") else f"55{phone_target}"
        msg_text = (
            f"Olá, {full_name}! 👋\n\n"
            f"Seu código de segurança para redefinir o acesso ao *Mr. Coach* é:\n\n"
            f"🔑 *{otp_code}*\n\n"
            f"Ele é válido por 10 minutos. Se você não solicitou, ignore esta mensagem."
        )
        try:
            await whatsapp_service.send_text_message(
                instance_name="system_recovery",
                number=formatted_phone,
                text=msg_text
            )
        except Exception as e:
            logger.warning(f"[Recovery] Erro ao enviar mensagem WhatsApp: {e}")
            if user_email:
                try:
                    await email_service.send_recovery_otp_email(
                        recipient_email=user_email,
                        user_name=full_name,
                        otp_code=otp_code,
                    )
                    logger.info(f"[Recovery] Fallback do OTP enviado com sucesso por e-mail para {user_email}")
                except Exception as mail_err:
                    logger.warning(f"[Recovery] Falha no fallback por e-mail: {mail_err}")

    # 6. Envia via E-mail (Resend API)
    if req.channel == "email" and (user_email or ("@" in identifier)):
        target_email = user_email or identifier
        try:
            await email_service.send_recovery_otp_email(
                recipient_email=target_email,
                user_name=full_name,
                otp_code=otp_code,
            )
        except Exception as e:
            logger.warning(f"[Recovery] Erro ao enviar OTP por e-mail: {e}")


    return {
        "success": True,
        "message": f"Código de segurança enviado via {req.channel} com sucesso!"
    }


@router.post("/recovery/verify-otp")
async def verify_otp_and_reset_password(req: VerifyOtpResetPassword):
    """
    Valida o código OTP e redefine a senha do usuário com a Admin API.
    """
    identifier = req.phone_or_email.strip()
    clean_phone = re.sub(r"\D", "", identifier)
    code = req.otp_code.strip()

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Erro de conexão com o banco de dados.")

    # 1. Consulta o OTP mais recente e não expirado
    now_utc = datetime.now(timezone.utc).isoformat()
    
    candidates = [identifier, identifier.lower()]
    if clean_phone:
        candidates.append(clean_phone)
        if not clean_phone.startswith("55"):
            candidates.append(f"55{clean_phone}")
    candidates = list(set(candidates))

    try:
        otp_row = None
        for cand in candidates:
            res = await client.table("auth_recovery_otps")\
                .select("*")\
                .eq("identifier", cand)\
                .eq("otp_code", code)\
                .is_("used_at", "null")\
                .gt("expires_at", now_utc)\
                .order("created_at", desc=True)\
                .limit(1)\
                .execute()
            if res and res.data:
                otp_row = res.data[0]
                break
        
        if not otp_row:
            raise HTTPException(status_code=400, detail="Código inválido ou expirado. Verifique os 6 dígitos informados.")

        user_id = otp_row["user_id"]

        # 2. Marca OTP como utilizado
        await client.table("auth_recovery_otps").update({"used_at": now_utc}).eq("id", otp_row["id"]).execute()

        # 3. Redefine a senha do usuário
        await supabase_service.admin_update_user_password(user_id, req.new_password)

        return {"success": True, "message": "Senha redefinida com sucesso! Você já pode entrar com sua nova senha."}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao processar redefinição: {str(e)}")

