from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


class StudentPulseEventCreate(BaseModel):
    student_id: str
    student_name: str
    trainer_id: Optional[str] = None
    event_type: str = Field(
        ...,
        description="Tipo de evento: pain_alert, exercise_adapted, workout_completed, ai_doubt, inactivity_risk, streak_milestone"
    )
    severity: str = Field(
        default="info",
        description="Nível de severidade: critical, warning, info, success"
    )
    title: str = Field(..., description="Título conciso do evento para o feed do professor")
    description: str = Field(..., description="Detalhes adicionais ou contextualização")
    metadata: Optional[Dict[str, Any]] = Field(
        default_factory=dict,
        description="Metadados adicionais (exercício, split, duração, etc.)"
    )


class StudentPulseEventResponse(BaseModel):
    id: str
    student_id: str
    student_name: str
    trainer_id: str
    event_type: str
    severity: str
    title: str
    description: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    viewed_by_trainer: bool = False
    action_taken: Optional[str] = None
    created_at: str


class StudentPulseAcknowledgeRequest(BaseModel):
    action_taken: Optional[str] = Field(
        default=None,
        description="Ação tomada pelo professor (ex: whatsapp_contacted, plan_reviewed, dismissed)"
    )


class StudentPulseSummaryResponse(BaseModel):
    total_events: int
    unread_events: int
    pain_alerts_count: int
    workouts_completed_today: int
    high_risk_inactivity_count: int
    recent_events: List[StudentPulseEventResponse]


class InactiveStudentCard(BaseModel):
    id: str
    full_name: str
    phone: str = ""
    days_inactive: int
    streak_days: int = 0
    last_contacted_at: Optional[str] = None
    recently_contacted_48h: bool = False
    suggested_whatsapp_message: str = ""
    contact_whatsapp_url: Optional[str] = None


class OperationalPainAlertItem(BaseModel):
    id: str
    student_id: str
    student_name: str
    original_exercise: str
    adapted_exercise: str
    pain_location: Optional[str] = None
    severity: str = "Moderada"
    created_at: str


class TrainerOperationalCockpitResponse(BaseModel):
    sessions_completed_24h: int
    exercises_completed_24h: int
    estimated_sets_24h: int
    pending_pain_alerts_count: int
    recent_pain_alerts: List[OperationalPainAlertItem] = Field(default_factory=list)
    inactive_students_count: int
    inactive_students: List[InactiveStudentCard] = Field(default_factory=list)
    total_students: int
    active_students_this_week: int
    retention_rate: int


