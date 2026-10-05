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
    injuries_or_restrictions: Optional[str] = Field(None, description="Histórico ou restrições articulares/lesões")
    trainer_id: Optional[str] = Field(None, description="ID do personal trainer vinculado")


class StudentUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    goal: Optional[str] = None
    injuries_or_restrictions: Optional[str] = None
    status: Optional[str] = None


class StudentStatusUpdateRequest(BaseModel):
    status: str = Field(..., description="'Ativo', 'Pendente Confirmação', 'Arquivado'")


class StudentResponse(BaseModel):
    id: str
    full_name: str
    email: str
    phone: Optional[str] = None
    goal: str
    status: str = Field("Pendente Confirmação", description="'Ativo', 'Pendente Confirmação', 'Arquivado'")
    trainer_id: str
    created_at: str
    has_active_prescription: bool = False
    last_session: Optional[str] = None
    active_split: Optional[str] = None
    injuries_or_restrictions: Optional[str] = None
    trainer_name: Optional[str] = None
    trainer_photo_url: Optional[str] = None
    temp_password: Optional[str] = None


class BiomechanicalAlertCreate(BaseModel):
    student_id: str
    student_name: str
    trainer_id: Optional[str] = None
    original_exercise: str
    adapted_exercise: str
    reason: str
    pain_location: Optional[str] = None
    severity: str = "Moderada"
    workout_id: Optional[str] = None
    details: Optional[dict] = None


class BiomechanicalAlertResponse(BaseModel):
    id: str
    student_id: str
    student_name: str
    trainer_id: str
    original_exercise: str
    adapted_exercise: str
    reason: str
    pain_location: Optional[str] = None
    severity: str = "Moderada"
    status: str = "active"
    acknowledged: bool = False
    created_at: str
    message: str


class StudentInviteRequest(BaseModel):
    email: str
    full_name: str
    phone: Optional[str] = None
    objective: Optional[str] = "Hipertrofia Muscular"
    injuries_or_restrictions: Optional[str] = None
    send_email: bool = True
    send_whatsapp: bool = True
    trainer_id: Optional[str] = None
    trainer_name: Optional[str] = None


class StudentInviteResponse(BaseModel):
    id: str
    email: str
    full_name: str
    status: str = "Pendente Confirmação"
    invitation_link: str
    whatsapp_url: str
    email_status: str
    whatsapp_status: str
    message: str
    temp_password: Optional[str] = None


class GamificationResponse(BaseModel):
    current_streak: int = Field(default=0, description="Dias seguidos de treino concluídos")
    daily_goal_progress: float = Field(default=0.0, description="Porcentagem de conclusão do treino de hoje (0.0 a 1.0)")

