from typing import Optional
from pydantic import BaseModel, Field


class AdaptationInput(BaseModel):
    current_exercise: str = Field(..., description="Nome do exercício atual que precisa ser trocado")
    reason: str = Field(
        ...,
        description="Motivo da troca: 'Aparelho Ocupado / Fila' ou 'Desconforto ou Dor Articular'"
    )
    workout_location: str = Field(
        default="Academia completa",
        description="Ambiente atual com os recursos disponíveis"
    )
    injuries_or_restrictions: Optional[str] = Field(
        default="Nenhuma",
        description="Restrições articulares registradas do aluno"
    )


class AdaptationResponse(BaseModel):
    original_exercise: str = Field(..., description="Exercício original substituído")
    adapted_exercise: str = Field(..., description="Novo exercício biomecanicamente equivalente indicado")
    reason: str = Field(..., description="Motivo registrado para a substituição")
    sets: int = Field(..., ge=1, le=10, description="Séries recomendadas para a variação")
    reps: str = Field(..., description="Faixa de repetições ajustada")
    rest_seconds: int = Field(..., ge=15, le=300, description="Tempo de descanso em segundos")
    notes: str = Field(..., description="Orientações de posicionamento e execução da nova variação")
    biomechanical_rationale: str = Field(
        ...,
        description="Explicação sucinta de por que essa variação preserva o mesmo estímulo motor sem agravar dores"
    )
