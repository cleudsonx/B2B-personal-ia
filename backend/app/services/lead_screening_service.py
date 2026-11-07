import urllib.parse
import uuid
import datetime
import logging
from typing import Optional, Dict, Any, List
from app.schemas.public_showcase import LeadScreeningRequest, LeadScreeningResponse
from app.services.supabase_service import supabase_service

logger = logging.getLogger(__name__)

# Fallback em memória para leads recebidos (assegura resiliência caso tabela não exista)
_MEM_PROSPECT_LEADS: List[Dict[str, Any]] = []


class LeadScreeningService:
    @staticmethod
    def generate_biomechanical_insight(req: LeadScreeningRequest) -> str:
        """Gera recomendações cinesiológicas determinísticas preliminares baseadas nas queixas."""
        pains_lower = [p.strip().lower() for p in req.joint_pains if p.strip()]
        
        insights = []
        if any("lombar" in p or "costas" in p or "coluna" in p for p in pains_lower):
            insights.append("Estabilização lombopélvica (anti-extensão/core) e fortalecimento de glúteo máximo antes de cargas axiais compressivas.")
        
        if any("ombro" in p or "manguito" in p for p in pains_lower):
            insights.append("Ativação prévia do manguito rotador, mobilidade de cintura escapular e controle do ritmo escapuloumeral.")
            
        if any("joelho" in p or "patela" in p for p in pains_lower):
            insights.append("Controle de valgo dinâmico, equilíbrio de torque quadríceps/isquiotibiais e amplitude articular progressiva.")
            
        if any("cervical" in p or "pescoço" in p or "trapezio" in p for p in pains_lower):
            insights.append("Alinhamento postural, descompressão cervical e fortalecimento dos depressores escapulares.")

        if not insights:
            insights.append("Prescrição de alta performance com periodização ondulatória e sobrecarga progressiva sem restrições articulares conhecidas.")

        return " ".join(insights)

    @staticmethod
    def build_whatsapp_direct_url(
        trainer_phone: Optional[str],
        trainer_name: str,
        req: LeadScreeningRequest,
        insight: str,
    ) -> str:
        """Constrói link direto do WhatsApp wa.me com mensagem de alta conversão pré-formatada."""
        clean_phone = "".join(filter(str.isdigit, str(trainer_phone or "")))
        if not clean_phone or len(clean_phone) < 10:
            # Fallback seguro caso personal não tenha whatsapp configurado
            clean_phone = "5511999999999"

        if not clean_phone.startswith("55") and len(clean_phone) in (10, 11):
            clean_phone = f"55{clean_phone}"

        pains_str = ", ".join(req.joint_pains) if req.joint_pains else "Nenhuma dor reportada"

        message_body = (
            f"Olá, Prof. {trainer_name}! 👋\n\n"
            f"Acabei de preencher a *Triagem Biomecânica Rápida* na sua Vitrine Oficial do Mr. Coach:\n\n"
            f"👤 *Nome:* {req.lead_name}\n"
            f"🎯 *Objetivo:* {req.goal}\n"
            f"🩹 *Desconfortos/Dores:* {pains_str}\n"
            f"📅 *Disponibilidade:* {req.training_frequency_weekly}x por semana ({req.current_activity_level})\n"
            f"💡 *Pré-análise Cinesiológica:* {insight}\n\n"
            f"Gostaria de agendar minha consultoria e saber sobre seus planos disponíveis!"
        )

        encoded_text = urllib.parse.quote(message_body)
        return f"https://wa.me/{clean_phone}?text={encoded_text}"

    @classmethod
    async def process_screening_lead(
        cls,
        trainer_id: str,
        trainer_name: str,
        trainer_phone: Optional[str],
        req: LeadScreeningRequest,
    ) -> LeadScreeningResponse:
        """Processa a triagem rápida, salva o lead e gera os links de contato direto."""
        lead_id = str(uuid.uuid4())
        created_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        insight = cls.generate_biomechanical_insight(req)
        whatsapp_url = cls.build_whatsapp_direct_url(
            trainer_phone=trainer_phone,
            trainer_name=trainer_name,
            req=req,
            insight=insight,
        )

        lead_record = {
            "id": lead_id,
            "trainer_id": trainer_id,
            "trainer_name": trainer_name,
            "lead_name": req.lead_name,
            "lead_phone": req.lead_phone,
            "goal": req.goal,
            "joint_pains": req.joint_pains,
            "training_frequency_weekly": req.training_frequency_weekly,
            "current_activity_level": req.current_activity_level,
            "notes": req.notes,
            "biomechanical_insight": insight,
            "created_at": created_at,
        }

        # Tenta persistir no Supabase (se a tabela prospect_leads estiver presente)
        client = await supabase_service.get_client()
        if client:
            try:
                await client.table("prospect_leads").insert(lead_record).execute()
            except Exception as e:
                logger.info(f"[LeadScreening] Supabase prospect_leads bypass (fallback em memória ativado): {e}")

        # Mantém histórico em memória resiliente
        _MEM_PROSPECT_LEADS.append(lead_record)

        return LeadScreeningResponse(
            lead_id=lead_id,
            trainer_id=trainer_id,
            trainer_name=trainer_name,
            trainer_whatsapp=trainer_phone,
            biomechanical_insight=insight,
            whatsapp_direct_url=whatsapp_url,
            created_at=created_at,
            status="registered",
        )
