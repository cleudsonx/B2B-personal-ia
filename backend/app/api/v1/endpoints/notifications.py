import logging
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.notification import (
    NotificationRouteRequest,
    RoutingDecision,
    NotificationDispatchResult,
)
from app.services.notification_router_service import notification_router_service
from app.api.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/matrix-rules",
    response_model=List[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Consultar Regras da Matriz de Roteamento Multicanal",
    description="Retorna as regras oficiais da Matriz de Roteamento (Mr. Coach AI 3.0) com canais e custos estimados.",
)
async def get_matrix_rules() -> List[Dict[str, Any]]:
    return [
        {
            "category": "habit_reminder",
            "name": "Lembretes de Hábito (Água, Streak, Timer)",
            "primary_channel": "push_app",
            "cost_brl": 0.0,
            "rule": "Canal interno mobile ilimitado a custo zero (0 tokens Meta).",
        },
        {
            "category": "in_app_support",
            "name": "Dúvidas do Aluno / Suporte Biomecânico",
            "primary_channel": "in_app",
            "cost_brl": 0.0,
            "rule": "Mr. Coach AI no App ou WhatsApp se janela receptiva de 24h aberta.",
        },
        {
            "category": "workout_released",
            "name": "Nova Ficha Liberada pelo Treinador",
            "primary_channel": "hybrid_dual",
            "cost_brl": 0.04,
            "rule": "Push imediato no App + WhatsApp oficial Meta Cloud API.",
        },
        {
            "category": "billing_renewal",
            "name": "Cobrança de Mensalidade / Link de Renovação",
            "primary_channel": "whatsapp",
            "cost_brl": 0.04,
            "rule": "WhatsApp prioritário com link Pix/Cartão e conversão máxima.",
        },
        {
            "category": "retention_alert",
            "name": "Radar de Retenção (Aluno ausente >4 dias)",
            "primary_channel": "whatsapp",
            "cost_brl": 0.04,
            "rule": "WhatsApp oficial com trava anti-spam rigorosa de 48h.",
        },
    ]


@router.post(
    "/route-decision",
    response_model=RoutingDecision,
    status_code=status.HTTP_200_OK,
    summary="Avaliar Decisão de Roteamento Multicanal",
    description="Calcula os canais adequados, custo e checagem de anti-spam para uma notificação sem realizar o disparo.",
)
async def evaluate_notification_route(
    request: NotificationRouteRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> RoutingDecision:
    return notification_router_service.evaluate_routing(request)


@router.post(
    "/dispatch",
    response_model=NotificationDispatchResult,
    status_code=status.HTTP_200_OK,
    summary="Rotear e Despachar Notificação Multicanal",
    description="Avalia a Matriz Inteligente e executa o disparo seguro pelo canal adequado (Push App ou WhatsApp).",
)
async def dispatch_notification(
    request: NotificationRouteRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> NotificationDispatchResult:
    return await notification_router_service.dispatch(request)
