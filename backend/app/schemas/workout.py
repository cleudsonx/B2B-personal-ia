from typing import List, Optional
from pydantic import BaseModel, Field


class Exercise(BaseModel):
    order: int = Field(..., description="Ordem de execução dentro do treino")
    name: str = Field(..., description="Nome do exercício padronizado")
    target_muscle_group: str = Field(..., description="Grupo muscular principal (ex: Peitoral Maior)")
    sets: int = Field(..., ge=1, le=10, description="Número de séries de trabalho")
    reps: str = Field(..., description="Faixa de repetições prescrita (ex: '8-10', '10-12', '12-15')")
    rest_seconds: int = Field(..., ge=15, le=300, description="Intervalo de descanso em segundos")
    notes: str = Field(..., description="Instruções biomecânicas de postura, cadência e segurança")
    substitution_vector: str = Field(
        ...,
        description="Padrão de movimento / vetor para substituição rápida (ex: 'Empurrar horizontal livre')"
    )


class Split(BaseModel):
    split_identifier: str = Field(..., description="Letra ou identificador da divisão (ex: 'A', 'B', 'C')")
    split_name: str = Field(..., description="Descrição muscular do split (ex: 'Peito, Ombros e Tríceps')")
    estimated_duration_min: int = Field(..., ge=20, le=120, description="Duração estimada da sessão em minutos")
    exercises: List[Exercise] = Field(..., min_length=1, description="Lista ordenada de exercícios do split")


class WorkoutPlanResponse(BaseModel):
    workout_plan_title: str = Field(..., description="Título da periodização prescrita")
    notes_for_trainer: str = Field(..., description="Justificativa da distribuição de volume e escolhas biomecânicas")
    splits: List[Split] = Field(..., min_length=1, description="Divisões de treino semanais")


class PrescriptionSaveRequest(BaseModel):
    client_id: str = Field(..., description="ID do aluno que receberá a prescrição")
    trainer_id: Optional[str] = Field(None, description="ID do personal trainer responsável")
    plan: WorkoutPlanResponse = Field(..., description="Objeto estruturado da periodização e fichas")
    notes: Optional[str] = None


class PrescriptionSaveResponse(BaseModel):
    id: str
    client_id: str
    trainer_id: str
    workout_plan_title: str
    splits_count: int
    is_active: bool
    created_at: str
    status: str = "active"
    message: str


class StudentCreateRequest(BaseModel):
    full_name: str = Field(..., min_length=2, description="Nome completo do aluno")
    email: str = Field(..., description="E-mail válido do aluno para confirmação e acesso")
    phone: Optional[str] = Field(None, description="WhatsApp ou telefone")
    goal: str = Field("Hipertrofia Muscular", description="Objetivo principal do aluno")
    trainer_id: Optional[str] = Field(None, description="ID do personal trainer vinculado")


class StudentResponse(BaseModel):
    id: str
    full_name: str
    email: str
    phone: Optional[str] = None
    goal: str
    status: str = Field("Pendente Confirmação", description="'Ativo', 'Pendente Confirmação', 'Inativo'")
    trainer_id: str
    created_at: str
    has_active_prescription: bool = False
