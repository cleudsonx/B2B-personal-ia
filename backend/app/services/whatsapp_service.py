import logging
import re
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_INSTANCE_RE = re.compile(r"^trainer_([0-9a-f]{32})$")


def instance_name_for(trainer_id: str) -> str:
    """Nome de instância determinístico e reversível: trainer_<uuid sem hifens>."""
    return "trainer_" + trainer_id.replace("-", "").lower()


def trainer_id_from_instance(instance: str) -> Optional[str]:
    """Inverso de instance_name_for. Retorna None se o nome não for de um professor."""
    m = _INSTANCE_RE.match(instance or "")
    if not m:
        return None
    h = m.group(1)
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:]}"


class WhatsAppService:
    def __init__(self, provider: Optional[str] = None, api_key: Optional[str] = None):
        self.provider = (provider or settings.WHATSAPP_PROVIDER).lower()
        self.evolution_key = api_key if api_key is not None else settings.EVOLUTION_API_KEY

    @staticmethod
    def _base() -> str:
        return settings.EVOLUTION_API_URL.rstrip("/")

    def _headers(self) -> dict:
        if self.provider == "mock":
            return {}
        if not self.evolution_key:
            raise RuntimeError("EVOLUTION_API_KEY não configurada.")
        return {"apikey": self.evolution_key}

    async def create_instance(self, instance_name: str, number: Optional[str] = None) -> dict:
        """Cria a instância do professor e registra o webhook do Consultor IA."""
        if self.provider == "mock":
            return {"status": "mock", "instanceName": instance_name, "mode": "mock"}

        payload: dict = {
            "instanceName": instance_name,
            "qrcode": True,
            "integration": "WHATSAPP-BAILEYS",
        }
        if number:
            payload["number"] = number  # habilita pairingCode (sem QR)
        if settings.PUBLIC_BACKEND_URL and settings.EVOLUTION_WEBHOOK_TOKEN:
            payload["webhook"] = {
                "url": settings.PUBLIC_BACKEND_URL.rstrip("/") + "/api/v1/whatsapp/webhook",
                "byEvents": False,
                "base64": False,
                "headers": {"apikey": settings.EVOLUTION_WEBHOOK_TOKEN},
                "events": ["MESSAGES_UPSERT"],
            }
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.post(f"{self._base()}/instance/create", headers=self._headers(), json=payload)
            r.raise_for_status()
            return r.json()

    async def connect_instance(self, instance_name: str, number: Optional[str] = None) -> dict:
        """Gera novo pairingCode/QR para uma instância já existente."""
        if self.provider == "mock":
            return {"status": "mock", "instanceName": instance_name, "mode": "mock"}
        params = {"number": number} if number else None
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.get(
                f"{self._base()}/instance/connect/{instance_name}", headers=self._headers(), params=params
            )
            r.raise_for_status()
            return r.json()

    async def set_webhook(self, instance_name: str) -> dict:
        """Configura ou atualiza o webhook na Evolution API para receber mensagens em tempo real."""
        if self.provider == "mock":
            return {"status": "mock"}
        backend_url = settings.PUBLIC_BACKEND_URL or "https://b2b-personal-ia-backend.onrender.com"
        webhook_token = settings.EVOLUTION_WEBHOOK_TOKEN or "mrcoach_evolution_webhook_sec_2026_tok"
        payload = {
            "webhook": {
                "enabled": True,
                "url": f"{backend_url.rstrip('/')}/api/v1/whatsapp/webhook",
                "byEvents": False,
                "base64": False,
                "headers": {"apikey": webhook_token},
                "events": ["MESSAGES_UPSERT"],
            }
        }
        async with httpx.AsyncClient(timeout=20) as client:
            try:
                r = await client.post(f"{self._base()}/webhook/set/{instance_name}", headers=self._headers(), json=payload)
                r.raise_for_status()
                return r.json()
            except Exception as e:
                logger.warning("[WhatsApp] Falha ao configurar webhook para %s: %s", instance_name, e)
                return {"status": "error", "error": str(e)}

    async def get_instance_state(self, instance_name: str) -> dict:
        if self.provider == "mock":
            return {"status": "connected", "instanceName": instance_name, "mode": "mock"}
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(
                f"{self._base()}/instance/connectionState/{instance_name}", headers=self._headers()
            )
            r.raise_for_status()
            return r.json()

    async def delete_instance(self, instance_name: str) -> dict:
        """Exclui a instância na Evolution API (limpando sessões antigas ou zumbis)."""
        if self.provider == "mock":
            return {"status": "success", "mode": "mock"}
        async with httpx.AsyncClient(timeout=15) as client:
            try:
                r = await client.delete(f"{self._base()}/instance/delete/{instance_name}", headers=self._headers())
                r.raise_for_status()
                return r.json()
            except Exception as e:
                logger.warning("[WhatsApp] Erro ao deletar instância %s: %s", instance_name, e)
                return {"status": "error", "error": str(e)}

    @staticmethod
    def _format_phone(phone: str) -> str:
        """Extrai dígitos e garante DDI 55 para números brasileiros de 10 ou 11 dígitos."""
        digits = "".join(c for c in (phone or "") if c.isdigit())
        if len(digits) in (10, 11):
            digits = f"55{digits}"
        return digits

    async def resolve_whatsapp_number(self, instance_name: str, number: str) -> str:
        """Resolve o JID correto no WhatsApp (trata a questão do 9º dígito no Brasil)."""
        clean = self._format_phone(number)
        if self.provider == "mock" or not clean:
            return clean
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                r = await client.post(
                    f"{self._base()}/chat/whatsappNumbers/{instance_name}",
                    headers=self._headers(),
                    json={"numbers": [clean]},
                )
                if r.status_code == 200:
                    data = r.json()
                    if isinstance(data, list) and data:
                        first = data[0]
                        if first.get("exists") and first.get("jid"):
                            jid_num = first["jid"].split("@")[0]
                            return jid_num
        except Exception as e:
            logger.warning("[WhatsApp] Não foi possível resolver JID prévio para %s: %s", clean, e)
        return clean

    async def send_text_message(self, instance_name: str, number: str, text: str) -> dict:
        """Envia texto (payload Evolution v2)."""
        if self.provider == "mock":
            return {"status": "success", "mode": "mock", "instanceName": instance_name, "number": number, "text": text}
        target_number = await self.resolve_whatsapp_number(instance_name, number)
        async with httpx.AsyncClient(timeout=35) as client:
            r = await client.post(
                f"{self._base()}/message/sendText/{instance_name}",
                headers=self._headers(),
                json={"number": target_number, "text": text},
            )
            r.raise_for_status()
            return r.json()

    async def notify_new_workout(
        self,
        trainer_id: str,
        student_name: str,
        student_phone: str,
        workout_title: str,
        trainer_name: str = "Seu Treinador",
    ) -> dict:
        """Notificação proativa (Fase 3): avisa o aluno que o treinador liberou um novo treino."""
        number = self._format_phone(student_phone)
        if not number:
            logger.warning("[WhatsApp] Telefone inválido ao notificar novo treino para %s.", student_name)
            return {"status": "skipped", "reason": "invalid_phone"}

        instance = instance_name_for(trainer_id)
        text = (
            f"🚀 *Treino Atualizado no Mr. Coach!*\n\n"
            f"Fala, {student_name}! {trainer_name} acabou de liberar sua nova programação: *{workout_title}*.\n\n"
            f"Acesse agora pelo app ou digite *1* aqui para ver o resumo:\n"
            f"https://shaipados-labs.web.app"
        )
        try:
            return await self.send_text_message(instance, number, text)
        except Exception as e:
            logger.warning(
                "[WhatsApp] Não foi possível enviar notificação de novo treino (instância %s): %s",
                instance,
                e,
            )
            return {"status": "skipped", "reason": str(e)}

    async def notify_streak_risk(
        self,
        trainer_id: str,
        student_name: str,
        student_phone: str,
        current_streak: int,
        trainer_name: str = "Seu Treinador",
    ) -> dict:
        """Notificação proativa (Fase 3): alerta de recuperação de ofensiva (streak em risco)."""
        number = self._format_phone(student_phone)
        if not number:
            logger.warning("[WhatsApp] Telefone inválido ao notificar risco de ofensiva para %s.", student_name)
            return {"status": "skipped", "reason": "invalid_phone"}

        instance = instance_name_for(trainer_id)
        text = (
            f"🔥 *Atenção à sua Ofensiva, {student_name}!*\n\n"
            f"Você está com *{current_streak} dias* de consistência, mas notamos sua falta nos últimos dias. "
            f"Bora treinar hoje para não zerar seu progresso?\n\n"
            f"Seu treino já está pronto no Mr. Coach:\n"
            f"https://shaipados-labs.web.app"
        )
        try:
            return await self.send_text_message(instance, number, text)
        except Exception as e:
            logger.warning(
                "[WhatsApp] Não foi possível enviar alerta de ofensiva (instância %s): %s",
                instance,
                e,
            )
            return {"status": "skipped", "reason": str(e)}


whatsapp_service = WhatsAppService()

