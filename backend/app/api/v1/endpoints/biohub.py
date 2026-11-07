import logging
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.schemas.biohub import (
    DailyBiometricLog,
    ReadinessScore,
    MuscleRecoveryReport,
    StrengthEvolutionReport,
)
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()


class RecordLoadRequest(BaseModel):
    exercise_name: str = Field(..., min_length=2, description="Nome do exercício executado")
    load_kg: float = Field(..., ge=0, description="Carga utilizada em quilogramas")
    reps: int = Field(default=1, ge=1, le=100, description="Repetições válidas concluídas")
    recorded_at: Optional[str] = Field(None, description="Data/hora ISO da execução")


@router.get(
    "/students/{student_id}/readiness",
    response_model=ReadinessScore,
    summary="Score de Prontidão Neuromuscular do Aluno",
    description="Retorna a pontuação de 0 a 100, nível de prontidão e diretriz técnica para o treino de hoje."
)
async def get_student_readiness(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> ReadinessScore:
    try:
        return await supabase_service.get_student_readiness(student_id)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao obter prontidão do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao calcular prontidão: {str(e)}",
        )


@router.post(
    "/students/{student_id}/daily-log",
    response_model=DailyBiometricLog,
    summary="Registrar Biometria Diária do Aluno",
    description="Registra sono, dor, estresse e notas do aluno para calibrar o score de prontidão."
)
async def save_student_daily_log(
    student_id: str,
    log: DailyBiometricLog,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> DailyBiometricLog:
    try:
        return await supabase_service.save_student_biometrics(student_id, log)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao salvar log diário do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao registrar log diário: {str(e)}",
        )


@router.get(
    "/students/{student_id}/biometrics",
    response_model=List[DailyBiometricLog],
    summary="Histórico Recente de Biometria Diária",
    description="Retorna os últimos logs diários registrados pelo aluno."
)
async def get_student_biometrics(
    student_id: str,
    limit: int = 7,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> List[DailyBiometricLog]:
    try:
        return await supabase_service.get_student_biometrics(student_id, limit=limit)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao obter biometria do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao recuperar histórico biométrico: {str(e)}",
        )


@router.get(
    "/students/{student_id}/muscle-recovery",
    response_model=MuscleRecoveryReport,
    summary="Mapa de Recuperação Muscular do Aluno",
    description="Retorna a cinética de recuperação estimada para os 6 grupamentos anatômicos."
)
async def get_student_muscle_recovery(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> MuscleRecoveryReport:
    try:
        return await supabase_service.get_student_muscle_recovery(student_id)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao obter recuperação muscular do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao calcular recuperação muscular: {str(e)}",
        )


@router.get(
    "/students/{student_id}/strength-evolution",
    response_model=StrengthEvolutionReport,
    summary="Evolução de Cargas e Recordes Pessoais (1RM)",
    description="Retorna os PRs estimados (Brzycki/Epley), volume acumulado e evolução percentual."
)
async def get_student_strength_evolution(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> StrengthEvolutionReport:
    try:
        return await supabase_service.get_student_strength_evolution(student_id)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao obter evolução de força do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao calcular evolução de carga: {str(e)}",
        )


@router.post(
    "/students/{student_id}/record-load",
    summary="Registrar Carga de Exercício (Sobrecarga Progressiva)",
    description="Registra carga e repetições executadas para recalcular PRs e recuperação de grupamentos."
)
async def record_exercise_load(
    student_id: str,
    payload: RecordLoadRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    try:
        entry = await supabase_service.record_exercise_load(
            client_id=student_id,
            exercise_name=payload.exercise_name,
            load_kg=payload.load_kg,
            reps=payload.reps,
            recorded_at=payload.recorded_at,
        )
        return {
            "status": "success",
            "message": "Carga registrada com sucesso",
            "entry": entry,
        }
    except Exception as e:
        logger.error(f"[BioHub] Erro ao registrar carga do aluno {student_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao registrar carga: {str(e)}",
        )


@router.get(
    "/trainers/{trainer_id}/fatigue-radar",
    summary="Radar de Fadiga e Alertas de Deload do Personal",
    description="Visão consolidada para o personal de quais alunos precisam de deload ou estão em risco."
)
async def get_trainer_fatigue_radar(
    trainer_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    try:
        return await supabase_service.get_trainer_fatigue_radar(trainer_id)
    except Exception as e:
        logger.error(f"[BioHub] Erro ao obter radar de fadiga do personal {trainer_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao gerar radar de fadiga: {str(e)}",
        )
