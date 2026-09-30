from pydantic import BaseModel, Field
from typing import Optional


class AssistantChatRequest(BaseModel):
    prompt: str = Field(..., description="Pergunta ou instrução para o assistente B2B")
    systemInstruction: Optional[str] = Field(
        default=None,
        description="Instruções de sistema/personalidade para o assistente"
    )
    temperature: Optional[float] = Field(default=0.7, ge=0.0, le=1.0)
    model: Optional[str] = Field(default="gemini-2.5-flash", description="Modelo Gemini a ser utilizado")


class AssistantChatResponse(BaseModel):
    text: str = Field(..., description="Texto gerado pelo assistente")
    model: str = Field(default="gemini-2.5-flash", description="Modelo utilizado")
