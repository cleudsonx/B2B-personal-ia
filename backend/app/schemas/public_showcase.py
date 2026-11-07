from pydantic import BaseModel, Field
from typing import List, Optional


class LeadScreeningRequest(BaseModel):
    lead_name: str = Field(..., min_length=2, max_length=120, description="Nome do interessado")
    lead_phone: str = Field(..., min_length=8, max_length=25, description="WhatsApp ou telefone de contato")
    goal: str = Field(..., description="Objetivo principal (ex: Hipertrofia, Emagrecimento, Reabilitação)")
    joint_pains: List[str] = Field(default_factory=list, description="Articulações com desconforto ou dor pregressa")
    training_frequency_weekly: int = Field(default=3, ge=1, le=7, description="Dias disponíveis por semana")
    current_activity_level: Optional[str] = Field(default="iniciante", description="Nível de condicionamento")
    notes: Optional[str] = Field(default=None, max_length=500, description="Observações complementares")


class LeadScreeningResponse(BaseModel):
    lead_id: str
    trainer_id: str
    trainer_name: str
    trainer_whatsapp: Optional[str] = None
    biomechanical_insight: str
    whatsapp_direct_url: str
    created_at: str
    status: str = "registered"


class PublicShowcaseMetrics(BaseModel):
    rating_avg: float = Field(default=4.9, ge=1.0, le=5.0)
    rating_count: int = Field(default=24, ge=0)
    active_students_range: str = Field(default="15-30 alunos ativos")
    cref_verified: bool = Field(default=True)
    showcase_badges: List[str] = Field(
        default_factory=lambda: [
            "CREF Verificado",
            "Metodologia Individualizada",
            "Atendimento WhatsApp",
            "Suporte Contínuo",
        ]
    )
    transformation_stories_count: int = Field(default=12, ge=0)
