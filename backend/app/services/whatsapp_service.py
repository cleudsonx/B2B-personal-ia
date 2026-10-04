import httpx
import os
import logging

logger = logging.getLogger(__name__)

# Configurações da Evolution API (Padrão para quando subirmos o container)
EVOLUTION_API_URL = os.getenv("EVOLUTION_API_URL", "http://localhost:8080")
EVOLUTION_API_KEY = os.getenv("EVOLUTION_API_KEY", "429683C4C977415CAAFCE14D7735BE3E")

class WhatsAppService:
    async def create_instance(self, instance_name: str) -> dict:
        """Cria uma nova instância no Evolution API para o Professor."""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{EVOLUTION_API_URL}/instance/create",
                    headers={"apikey": EVOLUTION_API_KEY},
                    json={
                        "instanceName": instance_name,
                        "qrcode": True,
                        "integration": "WHATSAPP-BAILEYS"
                    }
                )
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Erro ao criar instância WhatsApp: {e}")
                raise

    async def get_instance_state(self, instance_name: str) -> dict:
        """Verifica se o WhatsApp do Professor está conectado."""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(
                    f"{EVOLUTION_API_URL}/instance/connectionState/{instance_name}",
                    headers={"apikey": EVOLUTION_API_KEY}
                )
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Erro ao buscar estado da instância: {e}")
                raise

    async def send_text_message(self, instance_name: str, number: str, text: str) -> dict:
        """Envia uma mensagem de texto simples pelo WhatsApp."""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{EVOLUTION_API_URL}/message/sendText/{instance_name}",
                    headers={"apikey": EVOLUTION_API_KEY},
                    json={
                        "number": number,
                        "options": {
                            "delay": 1200,
                            "presence": "composing"
                        },
                        "textMessage": {
                            "text": text
                        }
                    }
                )
                response.raise_for_status()
                return response.json()
            except Exception as e:
                logger.error(f"Erro ao enviar mensagem WhatsApp: {e}")
                raise

whatsapp_service = WhatsAppService()

