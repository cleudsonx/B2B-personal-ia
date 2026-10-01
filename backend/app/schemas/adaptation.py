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
    reason: str = Field(default="Adaptação no salão de musculação", description="Motivo registrado para a substituição")
    sets: int = Field(default=3, ge=1, le=10, description="Séries recomendadas para a variação")
    reps: str = Field(default="10-12", description="Faixa de repetições ajustada")
    rest_seconds: int = Field(default=60, ge=15, le=300, description="Tempo de descanso em segundos")
    notes: str = Field(default="Manter controle postural e cadência controlada.", description="Orientações de posicionamento e execução da nova variação")
    biomechanical_rationale: str = Field(
        default="Vetor biomecânico equivalente preservando o mesmo grupo muscular alvo.",
        description="Explicação sucinta de por que essa variação preserva o mesmo estímulo motor sem agravar dores"
    )
