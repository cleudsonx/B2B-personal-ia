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
    """Conecta o WhatsApp do professor autenticado (instância dele, nunca de outro)."""
    instance = instance_name_for(_trainer_id(user))
    number = whatsapp_service._format_phone(req.number or "") or None
    try:
        try:
            data = await whatsapp_service.create_instance(instance, number)
        except httpx.HTTPStatusError as e:
            # 403/409: instância já existe -> apenas gera novo código
            if e.response.status_code in (403, 409):
                data = await whatsapp_service.connect_instance(instance, number)
            else:
                raise
        # Garante registro do webhook na Evolution API mesmo em caso de reconexão
        try:
            await whatsapp_service.set_webhook(instance)
        except Exception:
            pass

        qr = data.get("qrcode") if isinstance(data.get("qrcode"), dict) else data
        return {
            "instance_name": instance,
            "pairingCode": qr.get("pairingCode"),
            "qr_code_base64": qr.get("base64"),
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
        raw_state = (
            state_data.get("state")
            or state_data.get("instance", {}).get("state")
            or ""
        ).lower()
        if raw_state != "open":
            raise HTTPException(
                status_code=400,
                detail=f"Seu WhatsApp não está com a conexão ativa no momento (Status: {raw_state or 'desconectado'}). "
                       f"Aguarde o status ficar Online ou gere um novo código de pareamento."
            )
    except HTTPException:
        raise
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
    except Exception as e:
        logger.error(f"[WhatsApp] Erro ao disparar mensagem de teste: %s", e)
        err_msg = str(e)
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



