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
    split_type: Optional[str] = Field(
        default="Automático (IA Sugere)",
        description="Estrutura de divisão (ex: 'Automático (IA Sugere)', 'Full Body', 'Upper / Lower', 'Push / Pull / Legs', 'Agonista / Antagonista', 'Divisão ABC Tradicional', 'Divisão ABCD', 'Divisão ABCDE', 'Especialização de Ponto Fraco', 'Reabilitação / Articular')"
    )
    target_focus: Optional[str] = Field(
        default=None,
        description="Foco muscular prioritário ou especialização de ponto fraco (ex: 'Glúteos', 'Deltoides', 'Dorsais', 'Peitoral Superior')"
    )
    injuries_or_restrictions: Optional[str] = Field(
        default="Nenhuma restrição articular ou dor relatada.",
        description="Histórico de lesões, cirurgias ou dores com contraindicações específicas"
    )
    additional_notes: Optional[str] = Field(
        default=None,
        description="Observações adicionais ou preferências prescritas pelo treinador"
    )
    biological_sex: Optional[str] = Field(
        default=None,
        description="Sexo biológico para ajuste metabólico e biomecânico ('Masculino', 'Feminino')"
    )
    session_duration: Optional[str] = Field(
        default=None,
        description="Tempo disponível por sessão (ex: '45 a 60 min', '60 minutos')"
    )
    available_equipment: Optional[list[str]] = Field(
        default=None,
        description="Lista de equipamentos disponíveis no local (ex: ['Halteres', 'Polia', 'Smith'])"
    )
    exercises_to_avoid: Optional[str] = Field(
        default=None,
        description="Exercícios que o aluno prefere evitar ou não gosta de executar"
    )
    cardio_preference: Optional[str] = Field(
        default=None,
        description="Preferência para treino aeróbio / cardio ('Pós-musculação', 'Em turno separado', 'Apenas musculação')"
    )
    training_style: Optional[str] = Field(
        default=None,
        description="Estilo de treino preferido ('Cargas Mais Altas / Força', 'Mais Reps & Pump', 'Equilibrado')"
    )
    sleep_hours: Optional[str] = Field(
        default=None,
        description="Média de sono diário ('Menos de 6h', '7 a 8 horas', etc.)"
    )
    stress_level: Optional[str] = Field(
        default=None,
        description="Nível de estresse e fadiga ('Baixo', 'Moderado', 'Elevado')"
    )
    preferred_days: Optional[list[str]] = Field(
        default=None,
        description="Dias da semana preferidos para treinar (ex: ['Seg', 'Ter', 'Qui', 'Sex'])"
    )
