from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.anamnesis import AnamnesisInput
from app.schemas.workout import WorkoutPlanResponse
from app.services.gemini_service import GeminiService
from app.api.deps import get_gemini_service, get_current_user

router = APIRouter()


@router.post(
    "/generate-plan",
    response_model=WorkoutPlanResponse,
    status_code=status.HTTP_200_OK,
    summary="Gerar Periodização e Ficha Completa via IA",
    description="Gera uma divisão de treinos personalizada (A, B, C...) com volumes e restrições biomecânicas respeitadas."
)
async def generate_workout_plan(
    data: AnamnesisInput,
    gemini_svc: GeminiService = Depends(get_gemini_service),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> WorkoutPlanResponse:
    try:
        plan = await gemini_svc.generate_workout_plan(
            objective=data.objective,
            training_level=data.training_level,
            days_per_week=data.days_per_week,
            workout_location=data.workout_location,
            injuries_or_restrictions=data.injuries_or_restrictions or "Nenhuma restrição articular.",
            additional_notes=data.additional_notes
        )
        return plan
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao gerar treino com IA: {str(e)}"
        )
