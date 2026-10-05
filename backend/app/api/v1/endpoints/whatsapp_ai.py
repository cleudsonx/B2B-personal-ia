"""
Consultor Ativo (IA no WhatsApp).

Recebe o webhook `messages.upsert` da Evolution API, identifica o aluno pelo
telefone, monta um contexto ENXUTO (ficha ativa + restrições) e responde com um
modelo barato (flash-lite). Pensado para custo mínimo e segurança:
- só responde alunos cadastrados (número desconhecido é ignorado);
- limite de mensagens por aluno/dia;
- resposta curta (max tokens) e sem aconselhamento médico.
"""
import hmac
import logging
import time
from collections import defaultdict
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException, Request, status
from google.genai import types

from app.core.config import settings
from app.services.gemini_service import gemini_service
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import trainer_id_from_instance, whatsapp_service

logger = logging.getLogger(__name__)
router = APIRouter()

DAILY_LIMIT_PER_STUDENT = 15
MAX_QUESTION_CHARS = 500
AI_MODELS = ["gemini-2.5-flash-lite", "gemini-2.5-flash"]

# Contador em memória (suficiente para 1 instância; migrar p/ Redis/Supabase depois).
_usage: Dict[str, Dict[str, Any]] = defaultdict(lambda: {"day": 0, "count": 0})

SYSTEM_PROMPT = (
    "Você é o assistente virtual do personal trainer do aluno, respondendo pelo WhatsApp. "
    "Responda em português, em no máximo 4 frases curtas, tom amigável e motivador. "
    "Baseie-se SOMENTE na ficha de treino fornecida. Dúvidas sobre execução, cadência, "
    "descanso e substituição de exercício são bem-vindas. "
    "NUNCA diagnostique, prescreva medicamentos ou altere a ficha: se houver dor, lesão "
    "ou mal-estar, oriente a parar e falar com o professor/médico. "
    "Se não souber, diga que vai avisar o professor."
)


def _extract_text(data: Dict[str, Any]) -> Optional[str]:
    msg = data.get("message") or {}
    return msg.get("conversation") or (msg.get("extendedTextMessage") or {}).get("text")


def _within_limit(student_id: str) -> bool:
    today = int(time.time() // 86400)
    entry = _usage[student_id]
    if entry["day"] != today:
        entry["day"], entry["count"] = today, 0
    if entry["count"] >= DAILY_LIMIT_PER_STUDENT:
        return False
    entry["count"] += 1
    return True


async def _find_student_by_phone(digits: str, trainer_id: str) -> Optional[Dict[str, Any]]:
    client = await supabase_service.get_client()
    if not client or len(digits) < 10:
        return None
    suffix = digits[-9:]  # tolera DDI/DDD e nono dígito
    res = await client.table("profiles").select("id, full_name, trainer_id, role") \
        .eq("role", "client").eq("trainer_id", trainer_id).ilike("phone", f"%{suffix}").limit(1).execute()
    return res.data[0] if res.data else None


def _plan_summary(plan) -> str:
    lines = [f"Ficha: {plan.workout_plan_title}"]
    for split in plan.splits:
        ex = "; ".join(f"{e.name} {e.sets}x{e.reps} desc {e.rest_seconds}s" for e in split.exercises)
        lines.append(f"Treino {split.split_identifier} ({split.split_name}): {ex}")
    return "\n".join(lines)


async def _answer(instance: str, number: str, digits: str, question: str) -> None:
    try:
        trainer_id = trainer_id_from_instance(instance)
        if not trainer_id:
            return
        # Só atende alunos VINCULADOS ao professor dono desta instância.
        student = await _find_student_by_phone(digits, trainer_id)
        if not student:
            return  # número desconhecido: silêncio (evita custo e spam)

        if not _within_limit(student["id"]):
            await whatsapp_service.send_text_message(
                instance, number,
                "Você atingiu o limite de dúvidas de hoje 😊 Seu professor vai te responder em breve!",
            )
            return

        plan = await supabase_service.get_active_prescription(student["id"])
        if not plan:
            await whatsapp_service.send_text_message(
                instance, number,
                "Ainda não encontrei uma ficha ativa para você. Vou avisar seu professor! 💪",
            )
            return

        prompt = (
            f"Aluno: {student.get('full_name') or 'Aluno'}\n{_plan_summary(plan)}\n\n"
            f"Pergunta: {question[:MAX_QUESTION_CHARS]}"
        )
        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT, temperature=0.4, max_output_tokens=300
        )
        response = await gemini_service._generate_with_fallback_async(
            candidate_models=AI_MODELS, contents=prompt, config=config, per_model_timeout=12.0
        )
        await whatsapp_service.send_text_message(instance, number, response.text.strip())
    except Exception as e:
        logger.error(f"[WhatsAppAI] Falha ao responder: {e}")


@router.post("/webhook", status_code=status.HTTP_200_OK, summary="Webhook Evolution API (Consultor Ativo)")
async def evolution_webhook(request: Request, background: BackgroundTasks):
    # Fail-closed: sem segredo configurado ou com segredo errado, nada é processado.
    expected = settings.EVOLUTION_WEBHOOK_TOKEN
    received = request.headers.get("apikey", "")
    if not expected or not hmac.compare_digest(received.encode(), expected.encode()):
        raise HTTPException(status_code=401, detail="Webhook não autorizado.")

    try:
        body = await request.json()
    except Exception:
        return {"status": "ignored"}

    if str(body.get("event", "")).lower().replace("_", ".") != "messages.upsert":
        return {"status": "ignored"}

    data = body.get("data") or {}
    key = data.get("key") or {}
    jid = key.get("remoteJid", "")
    if key.get("fromMe") or "@g.us" in jid or not jid:
        return {"status": "ignored"}  # ignora mensagens próprias e grupos

    text = _extract_text(data)
    if not text or not text.strip():
        return {"status": "ignored"}

    digits = "".join(c for c in jid.split("@")[0] if c.isdigit())
    background.add_task(_answer, body.get("instance", ""), digits, digits, text.strip())
    return {"status": "accepted"}
