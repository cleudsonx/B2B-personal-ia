import logging
from typing import Any, Dict, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.services.whatsapp_service import instance_name_for, whatsapp_service

logger = logging.getLogger(__name__)
router = APIRouter()


class ConnectRequest(BaseModel):
    number: Optional[str] = None  # DDI+DDD+número; habilita código de pareamento


def _trainer_id(user: Dict[str, Any]) -> str:
    sub = user.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Usuário não autenticado.")
    return sub


@router.post("/connect")
async def connect_whatsapp(req: ConnectRequest, user: Dict[str, Any] = Depends(get_current_user)):
    """Conecta o WhatsApp do professor autenticado (instância dele, nunca de outro)."""
    instance = instance_name_for(_trainer_id(user))
    number = "".join(c for c in (req.number or "") if c.isdigit()) or None
    try:
        try:
            data = await whatsapp_service.create_instance(instance, number)
        except httpx.HTTPStatusError as e:
            # 403/409: instância já existe -> apenas gera novo código
            if e.response.status_code in (403, 409):
                data = await whatsapp_service.connect_instance(instance, number)
            else:
                raise
        qr = data.get("qrcode") if isinstance(data.get("qrcode"), dict) else data
        return {
            "instance_name": instance,
            "pairingCode": qr.get("pairingCode"),
            "qr_code_base64": qr.get("base64"),
        }
    except RuntimeError as e:
        logger.error(f"[WhatsApp] Configuração ausente: {e}")
        raise HTTPException(status_code=503, detail="Integração WhatsApp não configurada.")
    except Exception as e:
        logger.error(f"[WhatsApp] Falha ao conectar: {e}")
        raise HTTPException(status_code=502, detail="Não foi possível falar com o servidor de WhatsApp.")


@router.get("/status")
async def get_status(user: Dict[str, Any] = Depends(get_current_user)):
    """Estado da conexão do WhatsApp do professor autenticado."""
    instance = instance_name_for(_trainer_id(user))
    try:
        data = await whatsapp_service.get_instance_state(instance)
        return {"state": data.get("instance", {}).get("state", "UNKNOWN")}
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return {"state": "NOT_CREATED"}
        raise HTTPException(status_code=502, detail="Erro ao consultar o WhatsApp.")
    except Exception:
        raise HTTPException(status_code=502, detail="Erro ao consultar o WhatsApp.")
