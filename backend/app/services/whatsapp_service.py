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
    @staticmethod
    def _base() -> str:
        return settings.EVOLUTION_API_URL.rstrip("/")

    @staticmethod
    def _headers() -> dict:
        if not settings.EVOLUTION_API_KEY:
            raise RuntimeError("EVOLUTION_API_KEY não configurada.")
        return {"apikey": settings.EVOLUTION_API_KEY}

    async def create_instance(self, instance_name: str, number: Optional[str] = None) -> dict:
        """Cria a instância do professor e registra o webhook do Consultor IA."""
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
        params = {"number": number} if number else None
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.get(
                f"{self._base()}/instance/connect/{instance_name}", headers=self._headers(), params=params
            )
            r.raise_for_status()
            return r.json()

    async def get_instance_state(self, instance_name: str) -> dict:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(
                f"{self._base()}/instance/connectionState/{instance_name}", headers=self._headers()
            )
            r.raise_for_status()
            return r.json()

    async def send_text_message(self, instance_name: str, number: str, text: str) -> dict:
        """Envia texto (payload Evolution v2)."""
        async with httpx.AsyncClient(timeout=20) as client:
            r = await client.post(
                f"{self._base()}/message/sendText/{instance_name}",
                headers=self._headers(),
                json={"number": number, "text": text, "delay": 1200},
            )
            r.raise_for_status()
            return r.json()


whatsapp_service = WhatsAppService()

