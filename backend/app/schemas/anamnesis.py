from typing import Optional
from pydantic import BaseModel, Field


class AnamnesisInput(BaseModel):
    objective: str = Field(
        ...,
        description="Objetivo principal do aluno (ex: 'Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento')"
    )
    training_level: str = Field(
        ...,
        description="Nível de experiência do praticante (ex: 'Iniciante', 'Intermediário', 'Avançado')"
    )
    days_per_week: int = Field(
        ...,
        ge=1,
        le=7,
        description="Frequência semanal de treinos disponíveis (1 a 7 dias)"
    )
    workout_location: str = Field(
        ...,
        description="Local e infraestrutura onde o treino será realizado (ex: 'Academia completa', 'Condomínio', 'Em casa')"
    )
    injuries_or_restrictions: Optional[str] = Field(
        default="Nenhuma restrição articular ou dor relatada.",
        description="Histórico de lesões, cirurgias ou dores com contraindicações específicas"
    )
    additional_notes: Optional[str] = Field(
        default=None,
        description="Observações adicionais ou preferências prescritas pelo treinador"
    )
