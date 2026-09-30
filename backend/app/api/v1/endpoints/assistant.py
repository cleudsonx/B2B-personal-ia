from fastapi import APIRouter, HTTPException, status
from app.schemas.assistant import AssistantChatRequest, AssistantChatResponse
from app.services.gemini_service import gemini_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/chat", response_model=AssistantChatResponse, summary="Conversar com o Assistente B2B Gemini")
async def chat_with_assistant(request: AssistantChatRequest):
    """
    Endpoint para consultoria e assistência B2B a personais trainers.
    Processa dúvidas de retenção, comercial, biomecânica e montagem de treinos.
    """
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
        logger.error(f"Erro ao processar mensagem do assistente B2B: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro no processamento da IA: {str(e)}"
        )


@router.post("/generate", response_model=AssistantChatResponse, summary="Compatibilidade com gateway de geração")
async def generate_text(request: AssistantChatRequest):
    """Alias para compatibilidade direta com rotas /api/generate."""
    return await chat_with_assistant(request)
