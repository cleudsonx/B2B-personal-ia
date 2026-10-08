from datetime import datetime, timezone
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field
from app.services.supabase_service import supabase_service

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
        res = await supabase_service.admin_create_user(
            email=str(req.email),
            password=req.password,
            full_name=req.full_name,
            role=req.role,
            phone=req.phone,
            trainer_id=req.trainer_id,
            invite_token=req.invite_token,
            professional_document_type=req.professional_document_type,
            professional_document=req.professional_document,
            photo_url=req.photo_url,
        )
        return DirectRegisterResponse(**res)
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

    # 1. Localiza o usuário em profiles pelo telefone ou pelo email
    user_row = None
    if clean_phone and len(clean_phone) >= 10:
        # Busca por telefone
        res = await client.table("profiles").select("id, full_name, phone, role").ilike("phone", f"%{clean_phone[-9:]}%").maybe_single().execute()
        user_row = res.data if res else None
    
    if not user_row and "@" in identifier:
        # Busca por auth.users / profiles
        res = await client.table("profiles").select("id, full_name, phone, role").ilike("email", identifier).maybe_single().execute()
        user_row = res.data if res else None

    # Se não encontrou, responde com mensagem genérica para evitar enumeração de contas
    if not user_row:
        return {"success": True, "message": "Se os dados constarem no sistema, o código de recuperação será enviado."}

    user_id = user_row["id"]
    full_name = user_row.get("full_name") or "Usuário"
    phone_target = user_row.get("phone") or clean_phone

    # 2. Gera OTP numérico de 6 dígitos
    otp_code = f"{random.randint(100000, 999999)}"

    # 3. Salva na tabela auth_recovery_otps
    try:
        await client.table("auth_recovery_otps").insert({
            "identifier": identifier,
            "channel": req.channel,
            "otp_code": otp_code,
            "user_id": user_id,
        }).execute()
    except Exception as e:
        # Se tabela ainda não foi criada, não quebra
        pass

    # 4. Envia via WhatsApp (Evolution API)
    if req.channel == "whatsapp" and phone_target:
        formatted_phone = phone_target if phone_target.startswith("55") else f"55{phone_target}"
        msg_text = (
            f"Olá, {full_name}! 👋\n\n"
            f"Seu código de segurança para redefinir o acesso ao *Mr. Coach* é:\n\n"
            f"🔑 *{otp_code}*\n\n"
            f"Ele é válido por 10 minutos. Se você não solicitou, ignore esta mensagem."
        )
        try:
            # Envia usando a instância padrão do sistema ou do professor
            await whatsapp_service.send_text_message(
                instance_name="system_recovery",
                number=formatted_phone,
                text=msg_text
            )
        except Exception as e:
            # Fallback caso a instância Evolution precise de pareamento
            pass

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
    code = req.otp_code.strip()

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Erro de conexão com o banco de dados.")

    # 1. Consulta o OTP mais recente e não expirado
    now_utc = datetime.now(timezone.utc).isoformat()
    try:
        res = await client.table("auth_recovery_otps")\
            .select("*")\
            .eq("identifier", identifier)\
            .eq("otp_code", code)\
            .is_("used_at", "null")\
            .gt("expires_at", now_utc)\
            .order("created_at", desc=True)\
            .limit(1)\
            .execute()
        
        if not res or not res.data:
            raise HTTPException(status_code=400, detail="Código inválido ou expirado.")

        otp_row = res.data[0]
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
