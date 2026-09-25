from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.adaptation import AdaptationInput, AdaptationResponse
from app.services.gemini_service import GeminiService
from app.api.deps import get_gemini_service, get_current_user

router = APIRouter()


@router.post(
    "/adapt-exercise",
    response_model=AdaptationResponse,
    status_code=status.HTTP_200_OK,
    summary="Substituir Exercício em Tempo Real (No Salão de Treino)",
    description="Substitui instantaneamente um aparelho ocupado ou varia o movimento em caso de desconforto/dor com o mesmo padrão biomecânico."
)
async def adapt_exercise(
    data: AdaptationInput,
    gemini_svc: GeminiService = Depends(get_gemini_service),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> AdaptationResponse:
    try:
        adaptation = await gemini_svc.adapt_exercise(
            current_exercise=data.current_exercise,
            reason=data.reason,
            workout_location=data.workout_location,
            injuries_or_restrictions=data.injuries_or_restrictions or "Nenhuma"
        )
        return adaptation
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao adaptar exercício com IA: {str(e)}"
        )
