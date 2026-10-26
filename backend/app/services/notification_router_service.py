import logging
from typing import Dict, Any, List
from app.schemas.notification import (
    NotificationRouteRequest,
    RoutingDecision,
    NotificationCategory,
    NotificationChannel,
    NotificationDispatchResult,
)
from app.services.whatsapp_service import WhatsAppService

logger = logging.getLogger(__name__)

# Custo estimado da Meta por mensagem de utilidade no Brasil (aprox. R$ 0,04)
META_UTILITY_MESSAGE_COST_BRL = 0.04


class NotificationRouterService:
    """
    Motor da Matriz Inteligente de Roteamento Multicanal do Mr. Coach AI 3.0.
    Garante custo R$ 0,00 para hábitos/alta frequência e aloca disparos pagos
    apenas para eventos de impacto comercial crítico, com travas anti-spam.
    """

    def __init__(self, whatsapp_svc: WhatsAppService | None = None):
        self.whatsapp_svc = whatsapp_svc or WhatsAppService()

    def evaluate_routing(self, req: NotificationRouteRequest) -> RoutingDecision:
        """
        Avalia o tipo de notificação conforme as regras da Matriz do Mr. Coach AI 3.0:
        1. Lembretes de Hábito (Água, Streak, Timer) -> PUSH_APP (R$ 0,00)
        2. Dúvidas / Suporte In-App -> IN_APP (R$ 0,00)
        3. Nova Ficha Liberada -> HYBRID_DUAL (Push App + WhatsApp)
        4. Cobrança de Mensalidade / Renovação -> WHATSAPP (ROI Máximo)
        5. Radar de Retenção (>4 dias ausente) -> WHATSAPP com Trava Anti-Spam de 48h
        """
        cat = req.category

        # 1. HÁBITOS E CONSISTÊNCIA: 100% Grátis no App
        if cat == NotificationCategory.HABIT_REMINDER:
            return RoutingDecision(
                category=cat,
                primary_channel=NotificationChannel.PUSH_APP,
                channels_to_dispatch=[NotificationChannel.PUSH_APP],
                estimated_cost_brl=0.0,
                requires_template=False,
                suppressed_by_cooldown=False,
                rationale="Lembretes de alta frequência rodam a custo zero dentro do App mobile.",
            )

        # 2. DÚVIDAS E SUPORTE CONTEXTUAL: Responde direto no App
        if cat == NotificationCategory.IN_APP_SUPPORT:
            return RoutingDecision(
                category=cat,
                primary_channel=NotificationChannel.IN_APP,
                channels_to_dispatch=[NotificationChannel.IN_APP],
                estimated_cost_brl=0.0,
                requires_template=False,
                suppressed_by_cooldown=False,
                rationale="Atendimento biomecânico e consultas de treino via Mr. Coach AI no App (custo zero).",
            )

        # 3. NOVA FICHA LIBERADA: Notificação Push imediata + WhatsApp
        if cat == NotificationCategory.WORKOUT_RELEASED:
            within_24h = (
                req.last_interaction_hours_ago is not None
                and req.last_interaction_hours_ago <= 24.0
            )
            cost = 0.0 if within_24h else META_UTILITY_MESSAGE_COST_BRL
            return RoutingDecision(
                category=cat,
                primary_channel=NotificationChannel.HYBRID_DUAL,
                channels_to_dispatch=[NotificationChannel.PUSH_APP, NotificationChannel.WHATSAPP],
                estimated_cost_brl=cost,
                requires_template=not within_24h,
                template_name=None if within_24h else "mrcoach_workout_ready",
                suppressed_by_cooldown=False,
                rationale=(
                    "Entrega imediata no App com cópia no WhatsApp. "
                    + ("Janela de 24h aberta (R$ 0,00)." if within_24h else f"Janela expirada: template oficial (~R$ {cost:.2f}).")
                ),
            )

        # 4. COBRANÇA DE MENSALIDADE / RENOVAÇÃO: WhatsApp Prioritário
        if cat == NotificationCategory.BILLING_RENEWAL:
            within_24h = (
                req.last_interaction_hours_ago is not None
                and req.last_interaction_hours_ago <= 24.0
            )
            cost = 0.0 if within_24h else META_UTILITY_MESSAGE_COST_BRL
            return RoutingDecision(
                category=cat,
                primary_channel=NotificationChannel.WHATSAPP,
                channels_to_dispatch=[NotificationChannel.WHATSAPP],
                estimated_cost_brl=cost,
                requires_template=not within_24h,
                template_name=None if within_24h else "mrcoach_billing_due",
                suppressed_by_cooldown=False,
                rationale="Impacto financeiro crítico: envio prioritário no WhatsApp com link direto de pagamento.",
            )

        # 5. RADAR DE RETENÇÃO (Aluno ausente >4 dias): WhatsApp com Trava Anti-Spam (48h)
        if cat == NotificationCategory.RETENTION_ALERT:
            # Trava anti-spam: não enviar se já disparou nas últimas 48h
            if req.last_notification_sent_hours_ago is not None and req.last_notification_sent_hours_ago < 48.0:
                hours_left = 48.0 - req.last_notification_sent_hours_ago
                return RoutingDecision(
                    category=cat,
                    primary_channel=NotificationChannel.WHATSAPP,
                    channels_to_dispatch=[],
                    estimated_cost_brl=0.0,
                    requires_template=False,
                    suppressed_by_cooldown=True,
                    cooldown_reason=f"Trava anti-spam de 48h ativa. Próximo disparo permitido em {hours_left:.1f}h.",
                    rationale="Bloqueado para proteger a reputação do número do personal contra denúncias de spam.",
                )

            within_24h = (
                req.last_interaction_hours_ago is not None
                and req.last_interaction_hours_ago <= 24.0
            )
            cost = 0.0 if within_24h else META_UTILITY_MESSAGE_COST_BRL
            return RoutingDecision(
                category=cat,
                primary_channel=NotificationChannel.WHATSAPP,
                channels_to_dispatch=[NotificationChannel.WHATSAPP],
                estimated_cost_brl=cost,
                requires_template=not within_24h,
                template_name=None if within_24h else "mrcoach_student_checkin",
                suppressed_by_cooldown=False,
                rationale="Alerta de retenção liberado (intervalo >48h respeitado). Envio no WhatsApp.",
            )

        # Fallback genérico de segurança
        return RoutingDecision(
            category=cat,
            primary_channel=NotificationChannel.PUSH_APP,
            channels_to_dispatch=[NotificationChannel.PUSH_APP],
            estimated_cost_brl=0.0,
            requires_template=False,
            suppressed_by_cooldown=False,
            rationale="Canal seguro padrão (Push no App).",
        )

    async def dispatch(self, req: NotificationRouteRequest) -> NotificationDispatchResult:
        """
        Executa a decisão da matriz, acionando os canais devidos (Push e/ou WhatsApp).
        """
        decision = self.evaluate_routing(req)

        if decision.suppressed_by_cooldown or not decision.channels_to_dispatch:
            return NotificationDispatchResult(
                decision=decision,
                dispatched_channels=[],
                status="suppressed",
                details={"reason": decision.cooldown_reason or "Nenhum canal acionado pela matriz."},
            )

        dispatched: List[NotificationChannel] = []
        details: Dict[str, Any] = {}

        # 1. Disparo de Push Notification no App
        if NotificationChannel.PUSH_APP in decision.channels_to_dispatch or decision.primary_channel == NotificationChannel.IN_APP:
            # Registrado localmente / canal in-app
            logger.info("Push emitido para recipient %s: %s", req.recipient_id, req.title)
            dispatched.append(NotificationChannel.PUSH_APP if NotificationChannel.PUSH_APP in decision.channels_to_dispatch else NotificationChannel.IN_APP)
            details["push"] = {
                "recipient_id": req.recipient_id,
                "title": req.title,
                "status": "delivered_in_app",
            }

        # 2. Disparo via WhatsApp (se canal incluído e telefone fornecido)
        if NotificationChannel.WHATSAPP in decision.channels_to_dispatch:
            if not req.phone:
                details["whatsapp"] = {"error": "Telefone não informado para envio de WhatsApp."}
            else:
                try:
                    res = await self.whatsapp_svc.send_message(
                        to=req.phone,
                        text=f"*{req.title}*\n\n{req.body}",
                        trainer_id=req.trainer_id,
                        template_name=decision.template_name,
                    )
                    dispatched.append(NotificationChannel.WHATSAPP)
                    details["whatsapp"] = {
                        "phone": req.phone,
                        "template": decision.template_name,
                        "response": res,
                    }
                except Exception as ex:
                    logger.error("Falha ao despachar WhatsApp no roteamento: %s", ex)
                    details["whatsapp"] = {"error": str(ex)}

        overall_status = "success" if dispatched else "failed"
        return NotificationDispatchResult(
            decision=decision,
            dispatched_channels=dispatched,
            status=overall_status,
            details=details,
        )


notification_router_service = NotificationRouterService()
