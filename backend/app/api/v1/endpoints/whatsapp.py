import logging
from typing import Any, Dict, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.deps import get_current_trainer
from app.services.whatsapp_service import instance_name_for, whatsapp_service
from app.services.supabase_service import supabase_service

logger = logging.getLogger(__name__)
router = APIRouter()


class ConnectRequest(BaseModel):
    number: Optional[str] = None  # DDI+DDD+número; habilita código de pareamento


class NotifyWorkoutRequest(BaseModel):
    student_name: str
    student_phone: str
    workout_title: str
    trainer_name: Optional[str] = "Seu Treinador"


class NotifyStreakRiskRequest(BaseModel):
    student_name: str
    student_phone: str
    current_streak: int
    trainer_name: Optional[str] = "Seu Treinador"


def _trainer_id(user: Dict[str, Any]) -> str:
    sub = user.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Usuário não autenticado.")
    return sub


@router.post("/connect")
async def connect_whatsapp(req: ConnectRequest, user: Dict[str, Any] = Depends(get_current_trainer)):
    """Conecta o WhatsApp do professor autenticado gerando código limpo e atualizado."""
    instance = instance_name_for(_trainer_id(user))
    number = whatsapp_service._format_phone(req.number or "") or None
    try:
        # 1. Se a instância já estiver aberta (conectada com sucesso), evita recriar
        try:
            state_data = await whatsapp_service.get_instance_state(instance)
            inst_dict = state_data.get("instance") or {}
            raw_state = (
                state_data.get("state")
                or inst_dict.get("state")
                or ""
            ).lower()
            if raw_state == "open" and inst_dict.get("disconnectionReasonCode") != 401:
                return {
                    "instance_name": instance,
                    "status": "already_connected",
                    "pairingCode": None,
                }
        except Exception:
            pass

        # 2. Tenta criar a instância com o número informado
        data = None
        try:
            data = await whatsapp_service.create_instance(instance, number)
        except httpx.HTTPStatusError as e:
            # 403/409: instância já existe no servidor. Se não está 'open', a sessão anterior
            # pode estar com pairingCode antigo/expirado em cache ou vinculada a outro número.
            # Limpamos a instância antiga para forçar a Evolution API a gerar um NOVO código para o número atual.
            if e.response.status_code in (403, 409):
                logger.info(f"[WhatsApp] Instância {instance} já existia. Reiniciando sessão para gerar código limpo...")
                await whatsapp_service.delete_instance(instance)
                try:
                    data = await whatsapp_service.create_instance(instance, number)
                except Exception as create_err:
                    logger.warning(f"[WhatsApp] Falha ao recriar após exclusão, usando connect_instance: {create_err}")
                    data = await whatsapp_service.connect_instance(instance, number)
            else:
                raise

        # 3. Garante registro do webhook na Evolution API mesmo em caso de reconexão
        try:
            await whatsapp_service.set_webhook(instance)
        except Exception:
            pass

        # 4. Extração resiliente de pairingCode e QR Code
        pairing_code = None
        qr_base64 = None
        if isinstance(data, dict):
            pairing_code = data.get("pairingCode") or data.get("code")
            qr_base64 = data.get("base64")
            qr_obj = data.get("qrcode")
            if isinstance(qr_obj, dict):
                pairing_code = pairing_code or qr_obj.get("pairingCode") or qr_obj.get("code")
                qr_base64 = qr_base64 or qr_obj.get("base64")

        return {
            "instance_name": instance,
            "pairingCode": pairing_code,
            "qr_code_base64": qr_base64,
        }
    except RuntimeError as e:
        logger.error(f"[WhatsApp] Configuração ausente: {e}")
        raise HTTPException(status_code=503, detail="Integração WhatsApp não configurada.")
    except Exception as e:
        logger.error(f"[WhatsApp] Falha ao conectar: {e}")
        raise HTTPException(status_code=502, detail="Não foi possível falar com o servidor de WhatsApp.")


@router.get("/status")
async def get_status(user: Dict[str, Any] = Depends(get_current_trainer)):
    """Estado da conexão do WhatsApp do professor autenticado."""
    instance = instance_name_for(_trainer_id(user))
    try:
        data = await whatsapp_service.get_instance_state(instance)
        return {"state": data.get("instance", {}).get("state", "UNKNOWN")}
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"state": "NOT_CREATED"}
        raise HTTPException(status_code=502, detail="Erro ao consultar o WhatsApp.")
    except Exception:
        raise HTTPException(status_code=502, detail="Erro ao consultar o WhatsApp.")


@router.delete("/disconnect")
async def disconnect_whatsapp(user: Dict[str, Any] = Depends(get_current_trainer)):
    """Desconecta e remove a instância do professor autenticado para permitir nova conexão limpa."""
    instance = instance_name_for(_trainer_id(user))
    try:
        res = await whatsapp_service.delete_instance(instance)
        return {"status": "disconnected", "instance": instance, "result": res}
    except Exception as e:
        logger.error(f"[WhatsApp] Erro ao desconectar instância: {e}")
        raise HTTPException(status_code=502, detail="Erro ao desconectar instância.")


@router.post("/notify-workout")
async def notify_workout(req: NotifyWorkoutRequest, user: Dict[str, Any] = Depends(get_current_trainer)):
    """Dispara notificação proativa de novo treino no WhatsApp do aluno (Fase 3 - Custo Zero de IA)."""
    trainer_id = _trainer_id(user)
    trainer_name = req.trainer_name or "Seu Treinador"
    result = await whatsapp_service.notify_new_workout(
        trainer_id=trainer_id,
        student_name=req.student_name,
        student_phone=req.student_phone,
        workout_title=req.workout_title,
        trainer_name=trainer_name,
    )
    return result


@router.post("/notify-streak-risk")
async def notify_streak_risk(req: NotifyStreakRiskRequest, user: Dict[str, Any] = Depends(get_current_trainer)):
    """Dispara notificação proativa de recuperação de ofensiva no WhatsApp do aluno (Fase 3 - Custo Zero de IA)."""
    trainer_id = _trainer_id(user)
    trainer_name = req.trainer_name or "Seu Treinador"
    result = await whatsapp_service.notify_streak_risk(
        trainer_id=trainer_id,
        student_name=req.student_name,
        student_phone=req.student_phone,
        current_streak=req.current_streak,
        trainer_name=trainer_name,
    )
    return result


class TestSendRequest(BaseModel):
    phone: Optional[str] = None


@router.post("/test-send")
async def test_send_whatsapp(req: TestSendRequest = TestSendRequest(), user: Dict[str, Any] = Depends(get_current_trainer)):
    """Dispara uma mensagem de teste real para o WhatsApp do treinador ou número indicado."""
    trainer_id = _trainer_id(user)
    instance = instance_name_for(trainer_id)

    # 1. Verifica se a instância está aberta no WhatsApp antes de disparar
    try:
        state_data = await whatsapp_service.get_instance_state(instance)
        inst_dict = state_data.get("instance") or {}
        raw_state = (
            state_data.get("state")
            or inst_dict.get("state")
            or ""
        ).lower()
        if inst_dict.get("disconnectionReasonCode") == 401 or raw_state != "open":
            raise HTTPException(
                status_code=400,
                detail=f"Sua sessão do WhatsApp está desconectada (Status: {raw_state or 'desconectado'}). "
                       f"Por favor, clique em 'Desconectar Sessão' e gere um novo código de pareamento para reconectar."
            )
    except HTTPException:
        raise
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=400,
                detail="Nenhuma conexão do WhatsApp encontrada. Digite seu número e gere um código de pareamento para começar."
            )
        logger.warning("[WhatsApp] Não foi possível verificar estado prévio da instância: %s", e)
    except Exception as e:
        logger.warning("[WhatsApp] Não foi possível verificar estado prévio da instância: %s", e)

    # 2. Prioriza o celular pessoal do professor cadastrado no perfil
    target_phone = req.phone
    if not target_phone:
        client = await supabase_service.get_client()
        if client:
            try:
                prof = await client.table("profiles").select("phone, public_whatsapp, full_name").eq("id", trainer_id).maybe_single().execute()
                if prof and prof.data:
                    # Prioriza phone (celular pessoal) antes de public_whatsapp (que pode ser o bot)
                    target_phone = prof.data.get("phone") or prof.data.get("public_whatsapp")
            except Exception:
                pass

    if not target_phone:
        raise HTTPException(status_code=400, detail="Nenhum número de telefone cadastrado no seu perfil para envio do teste.")

    clean_phone = whatsapp_service._format_phone(target_phone)
    test_msg = (
        "🧪 *Teste de Operação do Mr. Coach*\n\n"
        "Olá, Professor! Seu robô de WhatsApp está 100% ativo e operacional.\n"
        "Seus alunos já podem consultar fichas e tirar dúvidas automáticas com custo zero! 💪🚀"
    )

    try:
        res = await whatsapp_service.send_text_message(instance, clean_phone, test_msg)
        await supabase_service.log_whatsapp_interaction(
            trainer_id=trainer_id,
            student_id=None,
            student_name="Teste do Treinador",
            student_phone=clean_phone,
            channel="whatsapp_test",
            message_in="[Disparo Manual de Teste]",
            message_out=test_msg,
            cost_type="free",
        )
        return {"status": "success", "phone": clean_phone, "response": res}
    except httpx.HTTPStatusError as e:
        logger.error(f"[WhatsApp] Erro HTTP ao disparar mensagem de teste: %s", e)
        detail_msg = ""
        try:
            err_json = e.response.json()
            if isinstance(err_json, dict):
                resp_field = err_json.get("response")
                if isinstance(resp_field, dict):
                    msg = resp_field.get("message")
                    detail_msg = ", ".join(msg) if isinstance(msg, list) else str(msg or "")
                elif isinstance(resp_field, list):
                    detail_msg = ", ".join(str(m) for m in resp_field)
                if not detail_msg:
                    detail_msg = err_json.get("message") or err_json.get("error") or ""
        except Exception:
            detail_msg = e.response.text if hasattr(e, "response") else str(e)

        if not detail_msg or not detail_msg.strip():
            detail_msg = f"Servidor do WhatsApp retornou código {e.response.status_code}" if hasattr(e, "response") else str(e)

        if any(w in detail_msg.lower() for w in ["connection", "closed", "not connected", "disconnected"]):
            detail_msg = "Sessão do WhatsApp desconectada ou reiniciando no servidor. Por favor, clique em 'Desconectar' e reconecte seu número."

        raise HTTPException(status_code=502, detail=f"Falha ao enviar mensagem de teste via Evolution API: {detail_msg}")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="O servidor do WhatsApp demorou para responder (Timeout). Verifique se seu aparelho está conectado à internet.")
    except Exception as e:
        logger.error(f"[WhatsApp] Erro ao disparar mensagem de teste: %s", e)
        err_msg = str(e) or "Erro interno de comunicação"
        if "timeout" in err_msg.lower():
            err_msg = "O servidor do WhatsApp demorou para responder. Verifique se o seu celular está conectado à internet."
        raise HTTPException(status_code=502, detail=f"Falha ao enviar mensagem de teste via Evolution API: {err_msg}")


@router.get("/logs")
async def get_whatsapp_logs(limit: int = 20, user: Dict[str, Any] = Depends(get_current_trainer)):
    """Retorna os registros recentes de atendimentos do robô para dar total transparência ao professor."""
    trainer_id = _trainer_id(user)
    logs = await supabase_service.get_whatsapp_logs(trainer_id, limit=limit)
    return {"logs": logs}


@router.get("/telemetry")
async def get_whatsapp_telemetry(user: Dict[str, Any] = Depends(get_current_trainer)):
    """Retorna métricas de impacto comercial do robô (interações, alunos atendidos, tempo economizado)."""
    trainer_id = _trainer_id(user)
    data = await supabase_service.get_whatsapp_telemetry(trainer_id)
    return data



