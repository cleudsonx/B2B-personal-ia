from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


class NotificationCategory(str, Enum):
    HABIT_REMINDER = "habit_reminder"
    WORKOUT_RELEASED = "workout_released"
    BILLING_RENEWAL = "billing_renewal"
    RETENTION_ALERT = "retention_alert"
    IN_APP_SUPPORT = "in_app_support"


class NotificationChannel(str, Enum):
    PUSH_APP = "push_app"
    WHATSAPP = "whatsapp"
    HYBRID_DUAL = "hybrid_dual"
    IN_APP = "in_app"


class NotificationRouteRequest(BaseModel):
    recipient_id: str = Field(..., description="ID/UUID do aluno destinatário")
    trainer_id: Optional[str] = Field(None, description="ID do personal/treinador responsável")
    category: NotificationCategory = Field(..., description="Categoria funcional da mensagem na Matriz")
    title: str = Field(..., description="Título curto ou resumo do alerta")
    body: str = Field(..., description="Corpo do texto da mensagem")
    phone: Optional[str] = Field(None, description="Telefone com DDI e DDD (ex: 5511999999999)")
    last_interaction_hours_ago: Optional[float] = Field(
        None,
        description="Horas desde a última interação iniciada pelo aluno (Janela de 24h da Meta)"
    )
    last_notification_sent_hours_ago: Optional[float] = Field(
        None,
        description="Horas desde o último disparo similar para o aluno (para checagem da trava anti-spam)"
    )
    metadata: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Metadados auxiliares")


class RoutingDecision(BaseModel):
    category: NotificationCategory
    primary_channel: NotificationChannel
    channels_to_dispatch: List[NotificationChannel]
    estimated_cost_brl: float = Field(0.0, description="Custo estimado por envio em BRL")
    requires_template: bool = Field(False, description="Exige template oficial pré-aprovado pela Meta")
    template_name: Optional[str] = Field(None, description="Nome do template oficial da Meta caso aplicável")
    suppressed_by_cooldown: bool = Field(False, description="Mensagem suprimida pela trava anti-spam")
    cooldown_reason: Optional[str] = Field(None, description="Motivo do bloqueio caso suprimida")
    rationale: str = Field(..., description="Justificativa da decisão na Matriz Inteligente")


class NotificationDispatchResult(BaseModel):
    decision: RoutingDecision
    dispatched_channels: List[NotificationChannel]
    status: str = Field(..., description="success | suppressed | partial | failed")
    details: Dict[str, Any] = Field(default_factory=dict)
