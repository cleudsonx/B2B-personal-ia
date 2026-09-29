import logging
from typing import Dict, Any, Optional
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


class WhatsAppService:
    """
    Serviço de mensageria WhatsApp para o ecossistema Mr. Coach.
    Suporta Evolution API (self-hosted / gratuito), Z-API ou modo Mock seguro.
    """

    def __init__(
        self,
        provider: str = "mock",
        evolution_url: Optional[str] = None,
        evolution_key: Optional[str] = None,
        evolution_instance: Optional[str] = None,
    ):
        self.provider = provider
        self.evolution_url = evolution_url or "http://localhost:8080"
        self.evolution_key = evolution_key or "mr_coach_secret_api_key_2026"
        self.evolution_instance = evolution_instance or "mr_coach_instance"

    async def send_text_message(self, phone: str, message: str) -> Dict[str, Any]:
        """
        Envia mensagem de texto para o número especificado.
        Se provider for 'mock', simula com sucesso e registra nos logs.
        """
        clean_phone = "".join(filter(str.isdigit, phone))
        if not clean_phone.startswith("55") and len(clean_phone) in (10, 11):
            clean_phone = f"55{clean_phone}"

        if self.provider == "mock" or not self.evolution_url:
            logger.info(f"[WhatsApp Mock] Enviando para {clean_phone}: {message[:60]}...")
            return {
                "status": "success",
                "mode": "mock",
                "recipient": clean_phone,
                "message_preview": message[:100],
            }

        # Evolution API v2 Integration
        try:
            url = f"{self.evolution_url.rstrip('/')}/message/sendText/{self.evolution_instance}"
            headers = {
                "apikey": self.evolution_key,
                "Content-Type": "application/json",
            }
            payload = {
                "number": clean_phone,
                "options": {
                    "delay": 1200,
                    "presence": "composing",
                    "linkPreview": True,
                },
                "textMessage": {"text": message},
            }

            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.post(url, headers=headers, json=payload)
                if response.status_code in (200, 201):
                    return {"status": "sent", "provider": "evolution", "data": response.json()}
                else:
                    logger.warning(f"Evolution API retornou status {response.status_code}: {response.text}")
                    return {"status": "error", "code": response.status_code, "detail": response.text}
        except Exception as e:
            logger.error(f"Erro ao disparar mensagem via Evolution API: {e}")
            return {"status": "failed", "error": str(e)}

    async def send_workout_plan_to_student(
        self,
        student_phone: str,
        student_name: str,
        trainer_name: str,
        plan_title: str,
        web_link: str = "https://cleudsonx.github.io/B2B-personal-ia/",
    ) -> Dict[str, Any]:
        """
        Envia a notificação da nova ficha estruturada para o WhatsApp do aluno.
        """
        message = (
            f"Olá {student_name}! 💪\n\n"
            f"Seu treinador *{trainer_name}* acabou de prescrever uma nova periodização personalizada para você no *Mr. Coach*:\n\n"
            f"📋 *{plan_title}*\n"
            f"🔗 Acesse suas fichas e acompanhe as cargas no espaço de treino aqui:\n"
            f"{web_link}\n\n"
            f"_Bons treinos e foco na biomecânica!_"
        )
        return await self.send_text_message(student_phone, message)

    async def send_pain_alert_to_trainer(
        self,
        trainer_phone: str,
        student_name: str,
        original_exercise: str,
        adapted_exercise: str,
        pain_location: str,
    ) -> Dict[str, Any]:
        """
        Notifica imediatamente o WhatsApp do treinador quando o aluno relata dor articular no treino presencial.
        """
        message = (
            f"🚨 *[ALERTA MR. COACH - TREINO PRESENCIAL]*\n\n"
            f"Seu aluno *{student_name}* relatou desconforto em: *{pain_location}*.\n"
            f"• Exercício Original: _{original_exercise}_\n"
            f"• Adaptado pela IA para: *{adapted_exercise}*\n\n"
            f"Abra o app *Mr. Coach* para verificar a sessão em tempo real."
        )
        return await self.send_text_message(trainer_phone, message)

    async def send_welcome_and_onboarding_confirmation(
        self,
        student_phone: str,
        student_name: str,
        trainer_name: str,
        objective: str,
        weekly_days: int = 4,
    ) -> Dict[str, Any]:
        """
        Envia mensagem de boas-vindas e confirmação de anamnese para o aluno no WhatsApp.
        """
        message = (
            f"Bem-vindo(a) ao *Mr. Coach*, {student_name}! 🏅\n\n"
            f"Sua avaliação biomecânica foi enviada com sucesso para o *Prof. {trainer_name}*.\n"
            f"• *Objetivo Central:* {objective}\n"
            f"• *Frequência Planejada:* {weekly_days} dias por semana\n\n"
            f"Seu treinador já está estruturando sua periodização com diretrizes de proteção articular e máxima eficiência de estímulo muscular.\n"
            f"Assim que o treino estiver liberado, você poderá acompanhar cada repetição e o mapa muscular 3D no app."
        )
        return await self.send_text_message(student_phone, message)

    async def send_anamnesis_completed_to_trainer(
        self,
        trainer_phone: str,
        trainer_name: str,
        student_name: str,
        objective: str,
        injuries_summary: str,
    ) -> Dict[str, Any]:
        """
        Notifica o treinador que um novo aluno completou a anamnese clínica.
        """
        message = (
            f"📋 *[NOVA ANAMNESE CONCLUÍDA - MR. COACH]*\n\n"
            f"Prof. {trainer_name}, seu aluno *{student_name}* concluiu a avaliação clínica!\n"
            f"• *Objetivo:* {objective}\n"
            f"• *Restrições/Articulações:* {injuries_summary}\n\n"
            f"Acesse o painel do Mr. Coach para gerar ou aprovar a periodização personalizada deste aluno."
        )
        return await self.send_text_message(trainer_phone, message)


whatsapp_service = WhatsAppService()
