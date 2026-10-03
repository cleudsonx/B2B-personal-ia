from fastapi import APIRouter, Depends, HTTPException
from app.services.whatsapp_service import whatsapp_service
import uuid

router = APIRouter()

@router.post("/connect")
async def connect_whatsapp():
    \"\"\"
    Gera uma nova instância e retorna o QR Code (Base64) para o Professor escanear.
    Nota: Em produção, o instance_name será vinculado ao UUID do trainer logado.
    \"\"\"
    # TODO: Pegar o user_id real do JWT
    simulated_trainer_id = str(uuid.uuid4())
    instance_name = f"trainer_{simulated_trainer_id[:8]}"
    
    try:
        data = await whatsapp_service.create_instance(instance_name)
        # Retorna o Base64 do QRCode para o Flutter renderizar na tela
        return {
            "instance_name": instance_name,
            "qr_code_base64": data.get("qrcode", {}).get("base64"),
            "message": "Escaneie este QR Code no seu WhatsApp."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail="A Evolution API está offline ou não configurada.")

@router.get("/status/{instance_name}")
async def get_status(instance_name: str):
    \"\"\"Verifica se a instância do WhatsApp está conectada.\"\"\"
    try:
        data = await whatsapp_service.get_instance_state(instance_name)
        return {"state": data.get("instance", {}).get("state", "UNKNOWN")}
    except Exception as e:
        raise HTTPException(status_code=500, detail="Erro ao buscar status.")
