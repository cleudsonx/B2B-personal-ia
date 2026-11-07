from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from app.schemas.student_pulse import (
    StudentPulseEventCreate,
    StudentPulseEventResponse,
    StudentPulseAcknowledgeRequest,
    StudentPulseSummaryResponse,
    TrainerOperationalCockpitResponse,
)
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_user, get_current_trainer
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post(
    "/events",
    response_model=StudentPulseEventResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar Evento no Barramento do Aluno (Live Pulse)",
    description="Registra alertas de dor, substituições de aparelho ocupado, finalização de treino ou marcos de consistência.",
)
async def register_pulse_event(
    event: StudentPulseEventCreate,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> StudentPulseEventResponse:
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    user_id = current_user.get("sub")

    # Se for um aluno registrando evento, garante que o student_id seja o dele mesmo
    if "client" in roles and "trainer" not in roles:
        if event.student_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="O evento de treino deve pertencer ao aluno autenticado.",
            )
        if not event.trainer_id:
            event.trainer_id = profile.get("trainer_id")

    return await supabase_service.create_student_pulse_event(event)


@router.get(
    "/trainer/{trainer_id}",
    response_model=List[StudentPulseEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Listar Eventos de Alunos para o Feed do Treinador",
    description="Retorna o fluxo de atividades dos alunos (dores, treinos concluídos, dúvidas, trocas de aparelho).",
)
async def list_trainer_pulse_events(
    trainer_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    unread_only: bool = Query(default=False),
    event_type: Optional[str] = Query(default=None),
    current_user: Dict[str, Any] = Depends(get_current_trainer),
) -> List[StudentPulseEventResponse]:
    authenticated_id = current_user.get("sub")
    if trainer_id != authenticated_id and authenticated_id != "current-trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado aos eventos deste treinador.",
        )
    return await supabase_service.list_trainer_pulse_events(
        trainer_id=authenticated_id or trainer_id,
        limit=limit,
        unread_only=unread_only,
        event_type=event_type,
    )


@router.get(
    "/trainer/{trainer_id}/summary",
    response_model=StudentPulseSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Resumo do Live Student Pulse",
    description="Retorna contadores agregados (alertas de dor não lidos, treinos hoje, alunos em risco de evasão).",
)
async def get_trainer_pulse_summary(
    trainer_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
) -> StudentPulseSummaryResponse:
    authenticated_id = current_user.get("sub")
    if trainer_id != authenticated_id and authenticated_id != "current-trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado ao resumo deste treinador.",
        )
    return await supabase_service.get_trainer_pulse_summary(
        trainer_id=authenticated_id or trainer_id
    )


@router.patch(
    "/events/{event_id}/view",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Marcar Evento do Pulse como Visualizado / Tratado",
    description="Registra que o professor visualizou ou tomou uma ação sobre o alerta do aluno.",
)
async def mark_pulse_event_viewed(
    event_id: str,
    req: StudentPulseAcknowledgeRequest = StudentPulseAcknowledgeRequest(),
    current_user: Dict[str, Any] = Depends(get_current_trainer),
) -> Dict[str, Any]:
    trainer_id = current_user.get("sub") or "current-trainer"
    success = await supabase_service.mark_pulse_event_viewed(
        event_id=event_id,
        trainer_id=trainer_id,
        action_taken=req.action_taken,
    )
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Evento não encontrado ou já reconhecido.",
        )
    return {"id": event_id, "viewed_by_trainer": True, "action_taken": req.action_taken}


@router.get(
    "/trainer/{trainer_id}/cockpit",
    response_model=TrainerOperationalCockpitResponse,
    status_code=status.HTTP_200_OK,
    summary="Cockpit Operacional 24h & Radar Anti-Evasão do Treinador",
    description="Retorna métricas em tempo real das últimas 24h (séries concluídas, alertas articulares de dor) e lista de alunos ausentes com mensagem de reengajamento WhatsApp.",
)
async def get_trainer_operational_cockpit(
    trainer_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
) -> TrainerOperationalCockpitResponse:
    authenticated_id = current_user.get("sub")
    if trainer_id != authenticated_id and authenticated_id != "current-trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso negado ao cockpit deste treinador.",
        )
    return await supabase_service.get_trainer_operational_cockpit(
        trainer_id=authenticated_id or trainer_id
    )


@router.post(
    "/students/{student_id}/contacted",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Registrar Contato de Reengajamento com Aluno",
    description="Atualiza last_contacted_at do aluno para ativar a trava anti-spam de 48h.",
)
async def mark_student_contacted(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
) -> Dict[str, Any]:
    success = await supabase_service.mark_student_contacted(student_id)
    return {
        "success": True,
        "student_id": student_id,
        "contacted": success,
        "message": "Trava anti-spam de 48h ativada com sucesso.",
    }


