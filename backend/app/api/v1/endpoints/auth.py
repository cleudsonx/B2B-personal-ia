import logging
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends, status, Security
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from app.services.supabase_service import supabase_service
from app.core.security import security_bearer, decode_supabase_jwt
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
            await whatsapp_service.send_text_with_fallback(
                number=formatted_phone,
                text=msg_text,
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


# ==============================================================================
# SMART ADAPTIVE 2FA (MULTI-CANAL, RESET TOTP & TRUSTED DEVICE)
# ==============================================================================
# Todos os endpoints abaixo exigem sessão autenticada (Bearer). O 2FA é a segunda
# etapa DEPOIS do login com senha; não existe caminho anônimo (evita enumeração
# de contas e força bruta de OTP).

from app.services import mfa_security as mfa
from app.services.mfa_security import has_recent_mfa


class RequestMfaCodeRequest(BaseModel):
    channel: str = Field("whatsapp", description="'whatsapp' ou 'email'")
    phone_or_email: Optional[str] = None  # legado/ignorado


class RequestMfaCodeResponse(BaseModel):
    success: bool
    channel: str
    masked_target: str
    message: str


class VerifyMfaCodeRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6)
    phone_or_email: Optional[str] = None  # legado/ignorado
    remember_device: bool = False
    device_name: Optional[str] = None


class VerifyMfaCodeResponse(BaseModel):
    success: bool
    message: str
    trusted_device_token: Optional[str] = None
    trusted_until: Optional[str] = None


class ResetMfaTotpRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6)
    channel: str = Field("whatsapp", description="'whatsapp' ou 'email'")
    phone_or_email: Optional[str] = None  # legado/ignorado
    password: Optional[str] = None


class TrustedLoginRequest(BaseModel):
    trusted_device_token: str = Field(..., min_length=20, max_length=200)


class BackupCodesResponse(BaseModel):
    success: bool
    backup_codes: List[str]
    message: str


class VerifyBackupCodeRequest(BaseModel):
    code: str
    phone_or_email: Optional[str] = None  # legado/ignorado
    remember_device: bool = False
    device_name: Optional[str] = None


class UpdateContactChannelRequest(BaseModel):
    new_phone: Optional[str] = None
    new_email: Optional[str] = None
    validation_code: str
    validation_channel: str = Field("email", description="Canal que recebeu o código de validação ('email' ou 'whatsapp')")


def _require_user_id(credentials: Optional[HTTPAuthorizationCredentials]) -> str:
    if not credentials or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Entre com sua senha antes de validar a segunda etapa.")
    try:
        payload = decode_supabase_jwt(credentials.credentials)
    except Exception:
        raise HTTPException(status_code=401, detail="Sessão inválida ou expirada. Entre novamente.")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Sessão inválida. Entre novamente.")
    return str(user_id)


async def _require_db():
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Erro de conexão com o banco de dados.")
    return client


async def _consume_otp(
    client,
    user_id: str,
    code: str,
    *,
    channel: Optional[str] = None,
    invalid_detail: str = "Código incorreto ou expirado. Verifique os 6 dígitos digitados.",
) -> None:
    """Valida o OTP mais recente do usuário com limite de tentativas e consumo atômico."""
    now_iso = datetime.now(timezone.utc).isoformat()
    query = (
        client.table("auth_recovery_otps")
        .select("id, otp_code, attempts")
        .eq("user_id", user_id)
        .eq("purpose", "mfa_challenge")
        .is_("used_at", "null")
        .gt("expires_at", now_iso)
    )
    if channel:
        query = query.eq("channel", channel)
    res = await query.order("created_at", desc=True).limit(1).execute()
    row = res.data[0] if (res and res.data) else None
    if not row:
        raise HTTPException(status_code=400, detail=invalid_detail)

    attempts = int(row.get("attempts") or 0)
    if attempts >= mfa.MAX_OTP_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Muitas tentativas incorretas. Solicite um novo código.")

    if not mfa.verify_secret(code.strip(), "mfa-otp", row.get("otp_code")):
        attempts += 1
        patch: Dict[str, Any] = {"attempts": attempts}
        if attempts >= mfa.MAX_OTP_ATTEMPTS:
            patch["used_at"] = now_iso
        await client.table("auth_recovery_otps").update(patch).eq("id", row["id"]).execute()
        remaining = mfa.MAX_OTP_ATTEMPTS - attempts
        if remaining <= 0:
            raise HTTPException(status_code=429, detail="Muitas tentativas incorretas. Solicite um novo código.")
        raise HTTPException(status_code=400, detail=f"Código incorreto. Restam {remaining} tentativa(s).")

    # Consumo atômico: só um request consegue marcar used_at (evita reuso concorrente)
    consumed = await (
        client.table("auth_recovery_otps")
        .update({"used_at": now_iso})
        .eq("id", row["id"])
        .is_("used_at", "null")
        .execute()
    )
    if not consumed or not consumed.data:
        raise HTTPException(status_code=400, detail=invalid_detail)


def _active_devices(raw: Any, now: datetime) -> List[Dict[str, Any]]:
    devices = raw if isinstance(raw, list) else []
    active = []
    for d in devices:
        if not isinstance(d, dict) or not d.get("token_hash"):
            continue
        exp = mfa.parse_ts(d.get("expires_at"))
        if exp and exp > now:
            active.append(d)
    return active


def _register_trusted_device(raw_devices: Any, name: Optional[str]) -> Dict[str, Any]:
    """Cria novo dispositivo confiável (guarda só o hash do token)."""
    now = datetime.now(timezone.utc)
    token = mfa.generate_trusted_token()
    until = now + timedelta(days=mfa.TRUSTED_DEVICE_DAYS)
    devices = _active_devices(raw_devices, now)
    devices.append({
        "token_hash": mfa.hash_secret(token, "mfa-trusted-device"),
        "name": (name or "Dispositivo Confiável")[:60],
        "created_at": now.isoformat(),
        "last_used_at": now.isoformat(),
        "expires_at": until.isoformat(),
    })
    devices = devices[-mfa.MAX_TRUSTED_DEVICES:]
    return {"devices": devices, "token": token, "until": until.isoformat()}


@router.post("/mfa/request-code", response_model=RequestMfaCodeResponse)
async def request_mfa_code(
    req: RequestMfaCodeRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer),
):
    """Envia código de 6 dígitos via WhatsApp ou E-mail (cooldown e limite por hora)."""
    user_id = _require_user_id(credentials)
    client = await _require_db()

    channel = req.channel.lower().strip()
    if channel not in ("whatsapp", "email"):
        raise HTTPException(status_code=400, detail="Canal inválido. Escolha 'whatsapp' ou 'email'.")

    # Rate limit persistente (por usuário)
    now = datetime.now(timezone.utc)
    hour_ago = (now - timedelta(hours=1)).isoformat()
    recent = await (
        client.table("auth_recovery_otps")
        .select("created_at")
        .eq("user_id", user_id)
        .eq("purpose", "mfa_challenge")
        .gt("created_at", hour_ago)
        .order("created_at", desc=True)
        .execute()
    )
    recent_rows = (recent.data if recent else None) or []
    if len(recent_rows) >= mfa.MAX_OTP_REQUESTS_PER_HOUR:
        raise HTTPException(status_code=429, detail="Limite de códigos por hora atingido. Tente novamente mais tarde.")
    if recent_rows:
        last = mfa.parse_ts(recent_rows[0].get("created_at"))
        if last:
            wait = mfa.OTP_RESEND_COOLDOWN_SECONDS - (now - last).total_seconds()
            if wait > 0:
                raise HTTPException(status_code=429, detail=f"Aguarde {int(wait) + 1}s para solicitar um novo código.")

    # Destinos cadastrados do próprio usuário
    full_name = "Treinador"
    user_email: Optional[str] = None
    user_phone: Optional[str] = None
    profile_res = await client.table("profiles").select("id, full_name, phone, public_whatsapp").eq("id", user_id).maybe_single().execute()
    if profile_res and profile_res.data:
        prof = profile_res.data
        full_name = prof.get("full_name") or full_name
        user_phone = prof.get("public_whatsapp") or prof.get("phone")
    try:
        admin_u = await client.auth.admin.get_user_by_id(user_id)
        if admin_u and getattr(admin_u, "user", None):
            user_email = admin_u.user.email
            if not user_phone:
                user_phone = getattr(admin_u.user, "phone", None)
    except Exception:
        pass

    if channel == "whatsapp":
        clean_target = re.sub(r"\D", "", user_phone or "")
        if len(clean_target) < 10:
            raise HTTPException(status_code=400, detail="Número de WhatsApp não cadastrado ou inválido. Use o e-mail.")
        identifier = clean_target
        if len(clean_target) == 11:
            masked_target = f"+55 ({clean_target[:2]}) {clean_target[2]}****-{clean_target[-4:]}"
        elif len(clean_target) >= 10:
            masked_target = f"+55 ({clean_target[:2]}) ****-{clean_target[-4:]}"
        else:
            masked_target = f"+55 {clean_target}"
    else:
        if not user_email or "@" not in user_email:
            raise HTTPException(status_code=400, detail="E-mail não cadastrado. Use o WhatsApp.")
        identifier = user_email.strip().lower()
        local, domain = identifier.split("@", 1)
        masked_target = f"{local[:2]}***@{domain}"

    otp_code = mfa.generate_otp()
    await client.table("auth_recovery_otps").insert({
        "identifier": identifier,
        "channel": channel,
        "otp_code": mfa.hash_secret(otp_code, "mfa-otp"),
        "user_id": user_id,
        "purpose": "mfa_challenge",
        "attempts": 0,
    }).execute()

    if channel == "whatsapp":
        formatted_phone = identifier if identifier.startswith("55") else f"55{identifier}"
        msg_text = (
            f"Olá, {full_name}! 👋\n\n"
            f"Seu código de segurança (2FA) do *Mr. Coach* é:\n\n"
            f"🔐 *{otp_code}*\n\n"
            f"Ele é válido por 10 minutos. Nunca compartilhe este código com ninguém."
        )
        try:
            wa_res = await whatsapp_service.send_text_with_fallback(
                number=formatted_phone,
                text=msg_text,
                trainer_id=user_id,
            )
            if isinstance(wa_res, dict) and wa_res.get("status") == "failed":
                raise RuntimeError(wa_res.get("reason") or "Falha no envio WhatsApp")
        except Exception as e:
            logger.error(f"[MFA] Falha ao enviar WhatsApp: {e}")
            if user_email and "@" in user_email:
                try:
                    await email_service.send_recovery_otp_email(
                        recipient_email=user_email,
                        user_name=full_name,
                        otp_code=otp_code,
                    )
                    logger.info("[MFA] Fallback automático para email %s enviado com sucesso", user_email)
                    local, domain = user_email.split("@", 1)
                    masked_target = f"{local[:2]}***@{domain}"
                    return RequestMfaCodeResponse(
                        success=True,
                        channel="email",
                        masked_target=masked_target,
                        message=f"Não foi possível enviar pelo WhatsApp, mas enviamos o código com segurança para seu E-mail ({masked_target}).",
                    )
                except Exception as mail_e:
                    logger.error(f"[MFA] Falha no fallback por email: {mail_e}")
            raise HTTPException(status_code=502, detail="Não foi possível enviar o código via WhatsApp. Tente por E-mail.")
    else:
        try:
            await email_service.send_recovery_otp_email(recipient_email=identifier, user_name=full_name, otp_code=otp_code)
        except Exception as e:
            logger.error(f"[MFA] Falha ao enviar E-mail: {e}")
            raise HTTPException(status_code=502, detail="Não foi possível enviar o código via E-mail. Tente por WhatsApp.")

    return RequestMfaCodeResponse(
        success=True,
        channel=channel,
        masked_target=masked_target,
        message=f"Código de segurança enviado via {channel.capitalize()} para {masked_target}.",
    )


@router.post("/mfa/verify-code", response_model=VerifyMfaCodeResponse)
async def verify_mfa_code(
    req: VerifyMfaCodeRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer),
):
    """Valida o OTP, abre a janela de sessão (`mfa_verified_at`) e opcionalmente registra o dispositivo."""
    user_id = _require_user_id(credentials)
    client = await _require_db()

    await _consume_otp(client, user_id, req.code)

    now_iso = datetime.now(timezone.utc).isoformat()
    update_data: Dict[str, Any] = {"mfa_verified_at": now_iso}
    trusted_token = None
    trusted_until = None

    if req.remember_device:
        prof_res = await client.table("profiles").select("mfa_trusted_devices").eq("id", user_id).maybe_single().execute()
        raw = prof_res.data.get("mfa_trusted_devices") if (prof_res and prof_res.data) else []
        reg = _register_trusted_device(raw, req.device_name)
        update_data["mfa_trusted_devices"] = reg["devices"]
        trusted_token, trusted_until = reg["token"], reg["until"]

    await client.table("profiles").update(update_data).eq("id", user_id).execute()

    return VerifyMfaCodeResponse(
        success=True,
        message="Identidade confirmada com sucesso! Acesso liberado.",
        trusted_device_token=trusted_token,
        trusted_until=trusted_until,
    )


@router.post("/mfa/trusted-login")
async def trusted_device_login(
    req: TrustedLoginRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer),
):
    """Renova a janela de sessão se o dispositivo apresentar um token confiável válido (validado no servidor)."""
    user_id = _require_user_id(credentials)
    client = await _require_db()

    prof_res = await client.table("profiles").select("mfa_trusted_devices").eq("id", user_id).maybe_single().execute()
    raw = prof_res.data.get("mfa_trusted_devices") if (prof_res and prof_res.data) else []
    now = datetime.now(timezone.utc)
    devices = _active_devices(raw, now)

    matched = None
    for d in devices:
        if mfa.verify_secret(req.trusted_device_token, "mfa-trusted-device", d.get("token_hash")):
            matched = d
            break
    if not matched:
        raise HTTPException(status_code=403, detail="Dispositivo não reconhecido ou expirado. Confirme o código novamente.")

    matched["last_used_at"] = now.isoformat()
    await client.table("profiles").update({
        "mfa_verified_at": now.isoformat(),
        "mfa_trusted_devices": devices,
    }).eq("id", user_id).execute()

    return {"success": True, "trusted_until": matched.get("expires_at")}


@router.post("/mfa/reset-totp")
async def reset_mfa_totp(
    req: ResetMfaTotpRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer),
):
    """Desvincula o autenticador perdido após validar OTP (WhatsApp/E-mail). Revoga dispositivos confiáveis."""
    user_id = _require_user_id(credentials)
    client = await _require_db()

    await _consume_otp(client, user_id, req.code, channel=req.channel.lower().strip(),
                       invalid_detail="Código de segurança incorreto ou expirado.")

    deleted_count = 0
    try:
        if hasattr(client.auth, "admin") and hasattr(client.auth.admin, "mfa"):
            factors = await client.auth.admin.mfa.list_factors({"user_id": user_id})
            for factor in factors:
                factor_id = getattr(factor, "id", None) or (factor.get("id") if isinstance(factor, dict) else None)
                if factor_id:
                    try:
                        await client.auth.admin.mfa.delete_factor({"id": factor_id, "user_id": user_id})
                        deleted_count += 1
                    except Exception as del_err:
                        logger.warning(f"[MFA Reset] Erro ao deletar fator {factor_id}: {del_err}")
    except Exception as e:
        logger.warning(f"[MFA Reset] Aviso ao listar/deletar fatores via Admin API: {e}")

    await client.table("profiles").update({
        "mfa_verified_at": datetime.now(timezone.utc).isoformat(),
        "mfa_trusted_devices": [],
    }).eq("id", user_id).execute()

    return {
        "success": True,
        "deleted_factors": deleted_count,
        "message": "Autenticador anterior desvinculado com sucesso! Dispositivos confiáveis foram revogados.",
    }


@router.post("/mfa/backup-codes/generate", response_model=BackupCodesResponse)
async def generate_backup_codes(current_user: Dict[str, Any] = Depends(get_current_user)):
    """Gera 8 códigos de reserva. Exige 2FA recente (step-up) e guarda apenas hashes."""
    user_id = current_user.get("sub")
    profile = current_user.get("profile") or {}
    if current_user.get("aal") != "aal2" and not has_recent_mfa(profile):
        raise HTTPException(status_code=403, detail="Confirme sua identidade (2FA) antes de gerar códigos de reserva.")
    client = await supabase_service.get_client()
    if not user_id or not client:
        raise HTTPException(status_code=500, detail="Não foi possível gerar códigos de emergência.")

    plain = [mfa.generate_backup_code() for _ in range(mfa.BACKUP_CODE_COUNT)]
    hashes = [mfa.hash_secret(c, "mfa-backup") for c in plain]
    await client.table("profiles").update({
        "mfa_backup_codes": hashes,
        "mfa_backup_failed_attempts": 0,
        "mfa_backup_locked_until": None,
    }).eq("id", user_id).execute()

    return BackupCodesResponse(
        success=True,
        backup_codes=[mfa.format_backup_code(c) for c in plain],
        message="8 códigos de emergência gerados. Guarde-os em local seguro: eles não serão exibidos novamente.",
    )


@router.post("/mfa/backup-codes/verify")
async def verify_backup_code(
    req: VerifyBackupCodeRequest,
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer),
):
    """Valida código de reserva de uso único, com bloqueio temporário após falhas."""
    user_id = _require_user_id(credentials)
    client = await _require_db()
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()

    prof_res = await client.table("profiles").select(
        "mfa_backup_codes, mfa_trusted_devices, mfa_backup_failed_attempts, mfa_backup_locked_until"
    ).eq("id", user_id).maybe_single().execute()
    if not prof_res or not prof_res.data:
        raise HTTPException(status_code=404, detail="Perfil não encontrado.")
    prof = prof_res.data

    locked_until = mfa.parse_ts(prof.get("mfa_backup_locked_until"))
    if locked_until and locked_until > now:
        raise HTTPException(status_code=429, detail="Muitas tentativas. Tente novamente em alguns minutos ou use WhatsApp/E-mail.")

    stored: List[str] = list(prof.get("mfa_backup_codes") or [])
    code = mfa.normalize_backup_code(req.code)
    candidate = mfa.hash_secret(code, "mfa-backup") if len(code) == mfa.BACKUP_CODE_LENGTH else None
    matched = None
    if candidate:
        for h in stored:
            if mfa.verify_secret(code, "mfa-backup", h):
                matched = h
                break

    if not matched:
        failures = int(prof.get("mfa_backup_failed_attempts") or 0) + 1
        patch: Dict[str, Any] = {"mfa_backup_failed_attempts": failures}
        if failures >= mfa.MAX_BACKUP_FAILURES:
            patch["mfa_backup_failed_attempts"] = 0
            patch["mfa_backup_locked_until"] = (now + timedelta(minutes=mfa.BACKUP_LOCK_MINUTES)).isoformat()
        await client.table("profiles").update(patch).eq("id", user_id).execute()
        raise HTTPException(status_code=400, detail="Código de reserva inválido ou já utilizado.")

    stored.remove(matched)
    update_data: Dict[str, Any] = {
        "mfa_backup_codes": stored,
        "mfa_verified_at": now_iso,
        "mfa_backup_failed_attempts": 0,
        "mfa_backup_locked_until": None,
    }
    trusted_token = None
    trusted_until = None
    if req.remember_device:
        reg = _register_trusted_device(prof.get("mfa_trusted_devices"), req.device_name or "Dispositivo Confiável (Reserva)")
        update_data["mfa_trusted_devices"] = reg["devices"]
        trusted_token, trusted_until = reg["token"], reg["until"]

    await client.table("profiles").update(update_data).eq("id", user_id).execute()

    return {
        "success": True,
        "remaining_codes": len(stored),
        "trusted_device_token": trusted_token,
        "trusted_until": trusted_until,
        "message": f"Código de emergência aceito! Restam {len(stored)} códigos de reserva.",
    }


@router.post("/contact/update-channel")
async def update_contact_channel(
    req: UpdateContactChannelRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Troca de contato com validação cruzada obrigatória:
    - Alterar telefone/WhatsApp exige código recebido no E-mail atual.
    - Alterar e-mail exige código recebido no WhatsApp atual.
    """
    user_id = current_user.get("sub")
    profile = current_user.get("profile") or {}
    if current_user.get("aal") != "aal2" and not has_recent_mfa(profile):
        raise HTTPException(status_code=403, detail="Confirme sua identidade (2FA) antes de alterar seus contatos.")
    client = await supabase_service.get_client()
    if not user_id or not client:
        raise HTTPException(status_code=500, detail="Serviço indisponível.")

    channel = req.validation_channel.lower().strip()
    if not req.new_phone and not req.new_email:
        raise HTTPException(status_code=400, detail="Informe 'new_phone' ou 'new_email' para atualização.")
    if req.new_phone and req.new_email:
        raise HTTPException(status_code=400, detail="Altere um contato por vez.")
    if req.new_phone and channel != "email":
        raise HTTPException(status_code=400, detail="Para alterar o telefone, valide com o código enviado ao seu e-mail atual.")
    if req.new_email and channel != "whatsapp":
        raise HTTPException(status_code=400, detail="Para alterar o e-mail, valide com o código enviado ao seu WhatsApp atual.")

    now_utc = datetime.now(timezone.utc).isoformat()

    if req.new_phone:
        clean_p = re.sub(r"\D", "", req.new_phone.strip())
        if len(clean_p) < 10:
            raise HTTPException(status_code=400, detail="Telefone informado inválido. Informe DDD + número.")
    else:
        new_em = req.new_email.strip().lower()
        if "@" not in new_em or len(new_em) < 5:
            raise HTTPException(status_code=400, detail="E-mail informado inválido.")

    await _consume_otp(client, user_id, req.validation_code, channel=channel,
                       invalid_detail="Código de validação cruzada inválido ou expirado.")

    if req.new_phone:
        await client.table("profiles").update({
            "phone": clean_p,
            "public_whatsapp": clean_p,
            "updated_at": now_utc,
        }).eq("id", user_id).execute()
        try:
            await client.auth.admin.update_user_by_id(user_id, {"phone": clean_p})
        except Exception:
            pass
        return {"success": True, "message": "Telefone e WhatsApp atualizados com sucesso via validação cruzada!"}

    try:
        await client.auth.admin.update_user_by_id(user_id, {"email": new_em, "email_confirm": True})
    except Exception as e:
        logger.error(f"[Channel Update] Erro ao atualizar e-mail: {e}")
        raise HTTPException(status_code=400, detail="Não foi possível alterar o e-mail.")
    return {"success": True, "message": "E-mail atualizado com sucesso via validação cruzada!"}


# ---------------------------------------------------------------------------
# Passwordless Auth SaaS via WhatsApp (Login Instantâneo sem Senha)
# ---------------------------------------------------------------------------

class PasswordlessLoginRequest(BaseModel):
    phone: str = Field(..., description="Telefone com DDD (ex: 61999998888)")
    role: Optional[str] = Field("client", description="'client' ou 'trainer'")
    full_name: Optional[str] = None


class PasswordlessLoginResponse(BaseModel):
    success: bool
    message: str
    masked_phone: str
    is_new_user: bool


class PasswordlessVerifyRequest(BaseModel):
    phone: str = Field(..., description="Telefone com DDD")
    code: str = Field(..., min_length=6, max_length=6, description="Código de 6 dígitos")
    role: Optional[str] = "client"
    full_name: Optional[str] = None


class PasswordlessVerifyResponse(BaseModel):
    success: bool
    message: str
    email: str
    auth_token: str
    user_id: str
    role: str
    full_name: str
    is_new_user: bool


@router.post("/otp/login-request", response_model=PasswordlessLoginResponse)
async def request_passwordless_login(req: PasswordlessLoginRequest):
    """
    Inicia o fluxo Passwordless SaaS via WhatsApp:
    Gera OTP de 6 dígitos e despacha via WhatsApp (Robô Central ou Instância ativa).
    Não exige senha prévia.
    """
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=503, detail="Serviço de autenticação temporariamente indisponível.")

    raw_phone = re.sub(r"\D", "", req.phone or "")
    if len(raw_phone) < 10:
        raise HTTPException(status_code=400, detail="Número de WhatsApp inválido. Informe DDD + 9 dígitos.")

    clean_phone = raw_phone if raw_phone.startswith("55") else f"55{raw_phone}"
    short_phone = clean_phone[2:] if clean_phone.startswith("55") else clean_phone

    # Rate limiting: máximo 5 tentativas por hora por telefone
    now = datetime.now(timezone.utc)
    hour_ago = (now - timedelta(hours=1)).isoformat()
    recent = await (
        client.table("auth_recovery_otps")
        .select("created_at")
        .eq("identifier", clean_phone)
        .eq("purpose", "passwordless_login")
        .gt("created_at", hour_ago)
        .order("created_at", desc=True)
        .execute()
    )
    recent_rows = (recent.data if recent else None) or []
    if len(recent_rows) >= 5:
        raise HTTPException(status_code=429, detail="Limite de solicitações atingido para este número. Tente em 1 hora.")
    if recent_rows:
        last = mfa.parse_ts(recent_rows[0].get("created_at"))
        if last:
            wait = 45 - (now - last).total_seconds()
            if wait > 0:
                raise HTTPException(status_code=429, detail=f"Aguarde {int(wait) + 1}s para solicitar um novo código.")

    # Busca perfil existente pelo telefone (compara últimos 8 dígitos para ignorar pontuação e formato com/sem 9)
    profile = None
    last8_phone = clean_phone[-8:]
    try:
        p_res = (
            await client.table("profiles")
            .select("id, full_name, role, phone, public_whatsapp, email")
            .or_(f"phone.ilike.%{last8_phone}%,public_whatsapp.ilike.%{last8_phone}%")
            .limit(1)
            .execute()
        )
        if p_res and p_res.data:
            profile = p_res.data[0]
    except Exception as e:
        logger.warning(f"[Passwordless] Erro ao buscar profile por telefone: {e}")

    # Fallback 2: busca por e-mail ou nome se informado
    if not profile and req.full_name:
        cand = req.full_name.strip()
        if "@" in cand:
            try:
                e_res = (
                    await client.table("profiles")
                    .select("id, full_name, role, phone, public_whatsapp, email")
                    .ilike("email", cand)
                    .limit(1)
                    .execute()
                )
                if e_res and e_res.data:
                    profile = e_res.data[0]
            except Exception:
                pass
        elif len(cand) >= 3:
            try:
                n_res = (
                    await client.table("profiles")
                    .select("id, full_name, role, phone, public_whatsapp, email")
                    .ilike("full_name", f"%{cand}%")
                    .limit(1)
                    .execute()
                )
                if n_res and n_res.data:
                    profile = n_res.data[0]
            except Exception:
                pass

    synthetic_email = f"wa_{clean_phone}@mrcoach.app"
    is_new = profile is None

    if profile:
        user_id = profile["id"]
        user_name = profile.get("full_name") or req.full_name or "Atleta"
        # Vincula o WhatsApp ao perfil se ainda não estiver configurado
        try:
            if not profile.get("phone") or not profile.get("public_whatsapp"):
                await client.table("profiles").update({
                    "phone": clean_phone,
                    "public_whatsapp": clean_phone,
                }).eq("id", user_id).execute()
        except Exception:
            pass
    else:
        # Garante que o usuário existe no Supabase Auth para ter user_id válido para o OTP
        temp_pw = f"MrCoach_Wa_{uuid.uuid4().hex[:12]}_{now.strftime('%M%S')}"
        role = "trainer" if (req.role or "").strip().lower() == "trainer" else "client"
        full_name = req.full_name.strip() if req.full_name and req.full_name.strip() else ("Professor" if role == "trainer" else "Aluno")
        user_name = full_name
        try:
            created = await supabase_service.admin_create_user(
                email=synthetic_email,
                password=temp_pw,
                full_name=full_name,
                role=role,
                phone=clean_phone,
            )
            user_id = created.get("user_id")
        except Exception as e_create:
            logger.info(f"[Passwordless] Usuário com email sintético já existe ou erro: {e_create}")
            try:
                p_exist = (
                    await client.table("profiles")
                    .select("id, full_name, role")
                    .eq("email", synthetic_email)
                    .limit(1)
                    .execute()
                )
                if p_exist and p_exist.data:
                    user_id = p_exist.data[0]["id"]
                    user_name = p_exist.data[0].get("full_name") or full_name
            except Exception:
                user_id = None

    # Gera OTP
    otp_code = mfa.generate_otp()
    expires_at = (now + timedelta(minutes=10)).isoformat()
    logger.info(f"[Passwordless OTP] Código gerado para {clean_phone}: {otp_code}")

    insert_payload = {
        "identifier": clean_phone,
        "channel": "whatsapp",
        "otp_code": mfa.hash_secret(otp_code, "mfa-otp"),
        "purpose": "passwordless_login",
        "attempts": 0,
        "expires_at": expires_at,
    }
    if user_id:
        insert_payload["user_id"] = user_id

    try:
        await client.table("auth_recovery_otps").insert(insert_payload).execute()
    except Exception as e_insert:
        logger.error(f"[Passwordless] Falha ao persistir OTP no Supabase: {e_insert}")
        raise HTTPException(
            status_code=500,
            detail="Falha ao registrar código de segurança. Tente novamente em instantes.",
        )

    # Dispara mensagem via WhatsApp
    msg_text = (
        f"Olá, {user_name}! 👋\n\n"
        f"Seu código de acesso ao *Mr. Coach* é:\n\n"
        f"🔐 *{otp_code}*\n\n"
        f"Ele é válido por 10 minutos. Nunca compartilhe este código com ninguém."
    )
    try:
        wa_res = await whatsapp_service.send_text_with_fallback(
            number=clean_phone,
            text=msg_text,
            trainer_id=None,
        )
        if isinstance(wa_res, dict) and wa_res.get("status") == "failed":
            logger.warning(f"[Passwordless] WhatsApp gateway reportou: {wa_res.get('reason')}")
    except Exception as e:
        logger.error(f"[Passwordless] Erro ao disparar WhatsApp: {e}")
        raise HTTPException(
            status_code=500,
            detail="Não foi possível enviar a mensagem no WhatsApp. Verifique se o número está correto.",
        )

    # Máscara do telefone (ex: +55 (61) 9****-7852)
    ddi_ddd = clean_phone[:4]
    last4 = clean_phone[-4:]
    masked = f"+{ddi_ddd[:2]} ({ddi_ddd[2:]}) 9****-{last4}"

    return PasswordlessLoginResponse(
        success=True,
        message="Código de acesso enviado com sucesso via WhatsApp!",
        masked_phone=masked,
        is_new_user=is_new,
    )


@router.post("/otp/login-verify", response_model=PasswordlessVerifyResponse)
async def verify_passwordless_login(req: PasswordlessVerifyRequest):
    """
    Valida o OTP do WhatsApp e autentica o usuário sem senha:
    - Se existente: gera sessão / credencial segura de uso único para login transparente.
    - Se novo: cria a conta no Supabase Auth e profile instantaneamente.
    """
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=503, detail="Serviço de autenticação temporariamente indisponível.")

    raw_phone = re.sub(r"\D", "", req.phone or "")
    clean_phone = raw_phone if raw_phone.startswith("55") else f"55{raw_phone}"
    short_phone = clean_phone[2:] if clean_phone.startswith("55") else clean_phone

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()

    # Busca o OTP mais recente
    res = await (
        client.table("auth_recovery_otps")
        .select("id, otp_code, attempts, user_id")
        .eq("identifier", clean_phone)
        .eq("purpose", "passwordless_login")
        .is_("used_at", "null")
        .gt("expires_at", now_iso)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    row = res.data[0] if (res and res.data) else None
    if not row:
        raise HTTPException(status_code=400, detail="Código expirado ou não encontrado. Solicite um novo código.")

    attempts = int(row.get("attempts") or 0)
    if attempts >= 5:
        raise HTTPException(status_code=429, detail="Muitas tentativas incorretas. Solicite um novo código.")

    if not mfa.verify_secret(req.code.strip(), "mfa-otp", row.get("otp_code")):
        attempts += 1
        patch = {"attempts": attempts}
        if attempts >= 5:
            patch["used_at"] = now_iso
        await client.table("auth_recovery_otps").update(patch).eq("id", row["id"]).execute()
        remaining = 5 - attempts
        if remaining <= 0:
            raise HTTPException(status_code=429, detail="Muitas tentativas incorretas. Solicite um novo código.")
        raise HTTPException(status_code=400, detail=f"Código incorreto. Restam {remaining} tentativa(s).")

    # Consome OTP
    await client.table("auth_recovery_otps").update({"used_at": now_iso}).eq("id", row["id"]).execute()

    # Busca perfil
    profile = None
    last8_phone = clean_phone[-8:]
    try:
        p_res = (
            await client.table("profiles")
            .select("id, full_name, role, phone, public_whatsapp, email")
            .or_(f"phone.ilike.%{last8_phone}%,public_whatsapp.ilike.%{last8_phone}%")
            .limit(1)
            .execute()
        )
        if p_res and p_res.data:
            profile = p_res.data[0]
    except Exception as e:
        logger.warning(f"[Passwordless] Erro ao buscar profile existente por telefone: {e}")

    if not profile and req.full_name:
        cand = req.full_name.strip()
        if "@" in cand:
            try:
                e_res = (
                    await client.table("profiles")
                    .select("id, full_name, role, phone, public_whatsapp, email")
                    .ilike("email", cand)
                    .limit(1)
                    .execute()
                )
                if e_res and e_res.data:
                    profile = e_res.data[0]
            except Exception:
                pass
        elif len(cand) >= 3:
            try:
                n_res = (
                    await client.table("profiles")
                    .select("id, full_name, role, phone, public_whatsapp, email")
                    .ilike("full_name", f"%{cand}%")
                    .limit(1)
                    .execute()
                )
                if n_res and n_res.data:
                    profile = n_res.data[0]
            except Exception:
                pass

    if not profile:
        # Tenta buscar pelo email sintético
        synthetic_email = f"wa_{clean_phone}@mrcoach.app"
        try:
            p_exist = (
                await client.table("profiles")
                .select("id, full_name, role, phone, public_whatsapp, email")
                .eq("email", synthetic_email)
                .limit(1)
                .execute()
            )
            if p_exist and p_exist.data:
                profile = p_exist.data[0]
        except Exception:
            pass

    # Gera credencial temporária de alta segurança para login
    temp_pw = f"MrCoach_Wa_{uuid.uuid4().hex[:12]}_{now.strftime('%M%S')}"

    if profile:
        user_id = profile["id"]
        full_name = profile.get("full_name") or "Usuário"
        role = profile.get("role") or "client"

        # Obtém e-mail do usuário no Supabase Auth
        user_email = None
        try:
            admin_u = await client.auth.admin.get_user_by_id(user_id)
            if admin_u and getattr(admin_u, "user", None):
                user_email = admin_u.user.email
        except Exception as e:
            logger.warning(f"[Passwordless] Falha ao recuperar e-mail: {e}")

        if not user_email:
            user_email = f"wa_{clean_phone}@mrcoach.app"
            try:
                await client.auth.admin.update_user_by_id(user_id, {"email": user_email, "email_confirm": True})
            except Exception:
                pass

        # Atualiza a senha no Supabase Auth para a credencial temporária
        await supabase_service.admin_update_user_password(user_id, temp_pw)

        return PasswordlessVerifyResponse(
            success=True,
            message="Autenticado com sucesso via WhatsApp!",
            email=user_email,
            auth_token=temp_pw,
            user_id=user_id,
            role=role,
            full_name=full_name,
            is_new_user=False,
        )
    else:
        # Usuário novo: cria direto via Supabase Admin API
        user_email = f"wa_{clean_phone}@mrcoach.app"
        role = "trainer" if (req.role or "").strip().lower() == "trainer" else "client"
        full_name = req.full_name.strip() if req.full_name and req.full_name.strip() else ("Professor" if role == "trainer" else "Aluno")

        created = await supabase_service.admin_create_user(
            email=user_email,
            password=temp_pw,
            full_name=full_name,
            role=role,
            phone=clean_phone,
        )
        new_uid = created["user_id"]

        return PasswordlessVerifyResponse(
            success=True,
            message="Conta criada e autenticada com sucesso via WhatsApp!",
            email=user_email,
            auth_token=temp_pw,
            user_id=new_uid,
            role=role,
            full_name=full_name,
            is_new_user=True,
        )
