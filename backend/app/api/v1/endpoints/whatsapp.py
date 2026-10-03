from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import PlainTextResponse
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

# O Token de verificação que nós configuramos no painel da Meta
WHATSAPP_VERIFY_TOKEN = os.getenv("WHATSAPP_VERIFY_TOKEN", "mrcoach_seguranca_token_2026")

@router.get("/webhook")
async def verify_webhook(request: Request):
    """
    Rota exigida pela Meta (Facebook) para validar a propriedade do Webhook.
    A Meta envia um GET com hub.mode, hub.challenge e hub.verify_token.
    """
    mode = request.query_params.get("hub.mode")
    token = request.query_params.get("hub.verify_token")
    challenge = request.query_params.get("hub.challenge")

    if mode and token:
        if mode == "subscribe" and token == WHATSAPP_VERIFY_TOKEN:
            logger.info("Webhook do WhatsApp verificado com sucesso!")
            return PlainTextResponse(content=challenge, status_code=200)
        else:
            raise HTTPException(status_code=403, detail="Token de verificação inválido")
    
    raise HTTPException(status_code=400, detail="Parâmetros ausentes")


@router.post("/webhook")
async def receive_whatsapp_event(request: Request):
    """
    Fase 1 (Notificador Passivo): Rota para receber recibos de leitura e 
    respostas curtas dos alunos.
    """
    try:
        body = await request.json()
        
        # A Meta espera um 200 OK imediato
        # Na Fase 1, apenas logamos o recebimento (ex: "Mensagem Entregue", "Lida")
        if body.get("object") == "whatsapp_business_account":
            for entry in body.get("entry", []):
                for change in entry.get("changes", []):
                    value = change.get("value", {})
                    
                    # Se for status de mensagem (enviada, entregue, lida)
                    if "statuses" in value:
                        for status in value["statuses"]:
                            logger.info(f"Status da mensagem {status['id']}: {status['status']}")
                            
                    # Se for uma mensagem recebida (resposta do aluno)
                    elif "messages" in value:
                        for msg in value["messages"]:
                            logger.info(f"Mensagem recebida do aluno {msg['from']}: {msg.get('text', {}).get('body')}")
                            # TODO: Na Fase 2, enviar para a fila de processamento da IA aqui.
                            
            return {"status": "success"}
            
        return {"status": "ignored"}
        
    except Exception as e:
        logger.error(f"Erro ao processar webhook do WhatsApp: {e}")
        # Sempre retornamos 200 OK para a Meta não entrar em loop de retentativas
        return {"status": "error"}
