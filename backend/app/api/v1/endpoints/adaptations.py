from typing import Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.adaptation import AdaptationInput, AdaptationResponse
from app.services.gemini_service import GeminiService
from app.services.supabase_service import supabase_service
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
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> AdaptationResponse:
    trainer_id = current_user.get("sub") or "current-trainer"

    # Reserva atômica da cota mensal antes de chamar o Gemini (Prevenção de Race Conditions - AI-001)
    sub = await supabase_service.get_trainer_subscription(trainer_id)
    reserved = await supabase_service.reserve_monthly_ai_quota(trainer_id, sub.max_ai_generations)
    if not reserved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {sub.max_ai_generations} gerações de IA por mês atingido no plano '{sub.plan_name}'. "
                   "Faça upgrade para o plano Personal Pro para adaptações ilimitadas.",
        )

    try:
        adaptation = await gemini_svc.adapt_exercise(
            current_exercise=data.current_exercise,
            reason=data.reason,
            workout_location=data.workout_location,
            injuries_or_restrictions=data.injuries_or_restrictions or "Nenhuma"
        )
        return adaptation
    except ValueError as e:
        await supabase_service.release_monthly_ai_quota(trainer_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    except Exception as e:
        await supabase_service.release_monthly_ai_quota(trainer_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao adaptar exercício com IA: {str(e)}"
        )
