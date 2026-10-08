from typing import Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from app.schemas.assistant import AssistantChatRequest, AssistantChatResponse
from app.services.gemini_service import gemini_service
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_trainer
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/chat", response_model=AssistantChatResponse, summary="Conversar com o Assistente B2B Gemini")
async def chat_with_assistant(
    request: AssistantChatRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Endpoint para consultoria e assistência B2B a personais trainers.
    Processa dúvidas de retenção, comercial, biomecânica e montagem de treinos.
    Requer autenticação e respeita a cota mensal de IA do plano.
    """
    trainer_id = current_user.get("sub") or "current-trainer"

    # Reserva atômica da cota mensal antes de chamar o Gemini (Prevenção de Race Conditions - AI-001)
    sub = await supabase_service.get_trainer_subscription(trainer_id)
    reserved = await supabase_service.reserve_monthly_ai_quota(trainer_id, sub.max_ai_generations)
    if not reserved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {sub.max_ai_generations} gerações de IA por mês atingido no plano '{sub.plan_name}'. "
                   "Faça upgrade para o plano Personal Pro para consultas ilimitadas com o assistente.",
        )

    try:
        reply = await gemini_service.ask_assistant(
            prompt=request.prompt,
            system_instruction=request.systemInstruction,
            temperature=request.temperature or 0.7,
            model_name=request.model
        )
        return AssistantChatResponse(
            text=reply,
            model=request.model or "gemini-2.5-flash"
        )
    except Exception as e:
        await supabase_service.release_monthly_ai_quota(trainer_id)
        logger.error(f"Erro ao processar mensagem do assistente B2B: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro no processamento da IA: {str(e)}"
        )


@router.post("/generate", response_model=AssistantChatResponse, summary="Compatibilidade com gateway de geração")
async def generate_text(
    request: AssistantChatRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """Alias para compatibilidade direta com rotas /api/generate."""
    return await chat_with_assistant(request, current_user)

