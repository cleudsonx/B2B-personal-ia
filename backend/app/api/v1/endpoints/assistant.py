from typing import Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from app.schemas.assistant import AssistantChatRequest, AssistantChatResponse
from app.services.gemini_service import gemini_service
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/chat", response_model=AssistantChatResponse, summary="Conversar com o Assistente B2B Gemini")
async def chat_with_assistant(
    request: AssistantChatRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Endpoint para consultoria e assistência B2B a personais trainers.
    Processa dúvidas de retenção, comercial, biomecânica e montagem de treinos.
    Requer autenticação e respeita a cota mensal de IA do plano.
    """
    trainer_id = current_user.get("sub") or "current-trainer"

    # Verificar cota mensal de IA antes de chamar o Gemini
    sub = await supabase_service.get_trainer_subscription(trainer_id)
    if not sub.can_generate_ai:
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
        await supabase_service.increment_monthly_ai_generations(trainer_id)
        return AssistantChatResponse(
            text=reply,
            model=request.model or "gemini-2.5-flash"
        )
    except Exception as e:
        logger.error(f"Erro ao processar mensagem do assistente B2B: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro no processamento da IA: {str(e)}"
        )


@router.post("/generate", response_model=AssistantChatResponse, summary="Compatibilidade com gateway de geração")
async def generate_text(
    request: AssistantChatRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Alias para compatibilidade direta com rotas /api/generate."""
    return await chat_with_assistant(request, current_user)

