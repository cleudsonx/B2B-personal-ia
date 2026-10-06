import logging
import json
from typing import Optional, Dict, Any
from app.services.supabase_service import supabase_service

logger = logging.getLogger(__name__)

async def log_audit_event(
    event_type: str,
    token: str,
    trainer_id: str,
    channel: str,
    target_email: Optional[str] = None,
    target_phone: Optional[str] = None,
    ip_address: Optional[str] = None,
    user_agent: Optional[str] = None,
    details: Optional[Dict[str, Any]] = None,
) -> bool:
    """
    Registra um evento de auditoria imutável na tabela public.audit_log.
    Executado com a service_role para garantir que nenhum usuário adultere o histórico.
    """
    try:
        client = await supabase_service.get_client()
        if not client:
            logger.error("[AuditService] Falha ao conectar ao Supabase para auditoria.")
            return False

        payload = {
            "event_type": event_type,
            "token": token,
            "trainer_id": str(trainer_id),
            "channel": channel,
            "target_email": target_email,
            "target_phone": target_phone,
            "ip_address": ip_address,
            "user_agent": user_agent,
            "details": details or {},
        }

        # Insere na audit_log
        await client.table("audit_log").insert(payload).execute()
        logger.info(f"[AuditService] Evento '{event_type}' registrado com sucesso para o token '{token}'.")
        return True
    except Exception as e:
        logger.error(f"[AuditService] Erro ao gravar evento de auditoria: {e}", exc_info=True)
        return False

