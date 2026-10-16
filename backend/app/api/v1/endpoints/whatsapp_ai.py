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
    clean_target = "".join(c for c in (digits or "") if c.isdigit())
    if not client or len(clean_target) < 8:
        return None

    # 1. Verifica se quem está mandando mensagem é o próprio treinador (teste de conexão)
    try:
        t_res = await client.table("profiles").select("id, full_name, phone, public_whatsapp").eq("id", trainer_id).maybe_single().execute()
        if t_res and t_res.data:
            for field in ("phone", "public_whatsapp"):
                t_ph = "".join(c for c in (t_res.data.get(field) or "") if c.isdigit())
                if len(t_ph) >= 8 and t_ph[-8:] == clean_target[-8:]:
                    return {
                        "id": trainer_id,
                        "full_name": t_res.data.get("full_name") or "Professor",
                        "trainer_id": trainer_id,
                        "role": "trainer_self_test",
                    }
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao checar autoteste do treinador: {e}")

    # 2. Busca entre os alunos vinculados ao treinador (profiles)
    try:
        res = await client.table("profiles").select("id, full_name, trainer_id, role, subscription_status, phone") \
            .eq("role", "client").eq("trainer_id", trainer_id).execute()
        for p in res.data or []:
            p_phone = "".join(c for c in (p.get("phone") or "") if c.isdigit())
            if len(p_phone) >= 8 and p_phone[-8:] == clean_target[-8:]:
                if str(p.get("subscription_status") or "").lower() == "suspended":
                    return None
                return p
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar alunos vinculados: {e}")

    # 3. Busca entre os convites pendentes do treinador (invite_tokens)
    try:
        inv_res = await client.table("invite_tokens").select("id, target_name, trainer_id, target_phone") \
            .eq("trainer_id", trainer_id).is_("used_at", "null").execute()
        for inv in inv_res.data or []:
            inv_phone = "".join(c for c in (inv.get("target_phone") or "") if c.isdigit())
            if len(inv_phone) >= 8 and inv_phone[-8:] == clean_target[-8:]:
                return {
                    "id": inv["id"],
                    "full_name": inv.get("target_name") or "Aluno",
                    "trainer_id": trainer_id,
                    "role": "client",
                    "is_pending_invite": True,
                }
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar invite_tokens: {e}")

    # 4. Fallback: busca em qualquer perfil de cliente no sistema cujo telefone coincida
    try:
        all_res = await client.table("profiles").select("id, full_name, trainer_id, role, subscription_status, phone") \
            .eq("role", "client").execute()
        for p in all_res.data or []:
            p_phone = "".join(c for c in (p.get("phone") or "") if c.isdigit())
            if len(p_phone) >= 8 and p_phone[-8:] == clean_target[-8:]:
                if str(p.get("subscription_status") or "").lower() == "suspended":
                    return None
                return p
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar fallback de cliente: {e}")

    return None


def _plan_summary(plan) -> str:
    lines = [f"Ficha: {plan.workout_plan_title}"]
    for split in plan.splits:
        ex = "; ".join(f"{e.name} {e.sets}x{e.reps} desc {e.rest_seconds}s" for e in split.exercises)
        lines.append(f"Treino {split.split_identifier} ({split.split_name}): {ex}")
    return "\n".join(lines)


import unicodedata


def _normalize_command(text: str) -> str:
    cleaned = text.strip().lower()
    normalized = unicodedata.normalize("NFD", cleaned)
    without_accents = "".join(c for c in normalized if unicodedata.category(c) != "Mn")
    return without_accents.strip("?!.,:; ")


MENU_GREETINGS = {"oi", "ola", "menu", "ajuda", "0", "bom dia", "boa tarde", "boa noite"}
MENU_WORKOUT = {"1", "treino", "meu treino", "ficha", "qual meu treino", "minha ficha"}
MENU_STREAK = {"2", "streak", "ofensiva", "foguinho", "minha ofensiva"}
MENU_APP = {"3", "app", "link", "aplicativo", "acesso"}
PHASE2_ALLOWED_PLANS = {"pro", "elite", "studio"}
APP_URL = "https://shaipados-labs.web.app"


async def _answer(instance: str, number: str, digits: str, question: str) -> None:
    try:
        trainer_id = trainer_id_from_instance(instance)
        if not trainer_id:
            return
        # Identifica o aluno ou professor
        student = await _find_student_by_phone(digits, trainer_id)
        if not student:
            logger.info(f"[WhatsAppAI] Mensagem ignorada de número não cadastrado: {digits}")
            return  # número desconhecido: silêncio (evita custo e spam)

        nome = (student.get("full_name") or "Aluno").split()[0]
        cmd = _normalize_command(question)

        async def _reply(text_to_send: str, cost: str = "free", tokens: int = 0):
            await whatsapp_service.send_text_message(instance, number, text_to_send)
            try:
                await supabase_service.log_whatsapp_interaction(
                    trainer_id=trainer_id,
                    student_id=student.get("id"),
                    student_name=student.get("full_name") or "Aluno",
                    student_phone=digits,
                    channel="whatsapp",
                    message_in=question,
                    message_out=text_to_send,
                    cost_type=cost,
                    tokens_used=tokens,
                )
            except Exception as log_err:
                logger.debug(f"[WhatsAppAI] Falha ao gravar log transparente: {log_err}")

        # Se for o próprio treinador testando
        if student.get("role") == "trainer_self_test":
            await _reply(
                (
                    f"🧪 *Teste de Conexão Bem-Sucedido!*\n\n"
                    f"Olá, {nome}! O seu Robô WhatsApp do Mr. Coach está 100% ativo e operacional.\n\n"
                    f"Quando seus alunos mandarem mensagem aqui, eles receberão o menu automático e você não gastará tokens de IA nos comandos rápidos (1 = Ver Treino, 2 = Streak 🔥).\n\n"
                    f"Tudo pronto para atender seus alunos!"
                ),
                cost="free",
            )
            return

        # ---------------------------------------------------------------------
        # PASSO 2.1 — Triagem de Custo Zero (Menu Rápido sem consumo de tokens)
        # ---------------------------------------------------------------------
        if cmd in MENU_GREETINGS:
            await _reply(
                (
                    f"Olá, {nome}! 💪 Sou o assistente automático do seu treinador no Mr. Coach.\n\n"
                    "Digite uma opção:\n"
                    "*1* - Ver meu treino ativo\n"
                    "*2* - Ver minha ofensiva (Streak 🔥)\n"
                    "*3* - Link do App\n\n"
                    "Ou envie sua dúvida sobre algum exercício!"
                ),
                cost="free",
            )
            return

        if cmd in MENU_WORKOUT:
            plan = await supabase_service.get_active_prescription(student["id"])
            if not plan:
                await _reply(
                    "Ainda não encontrei uma ficha ativa para você. Vou avisar seu professor! 💪",
                    cost="free",
                )
                return
            await _reply(
                f"📋 *Seu Treino Ativo*\n\n{_plan_summary(plan)}\n\n📲 Acesse completo no app: {APP_URL}",
                cost="free",
            )
            return

        if cmd in MENU_STREAK:
            streak_days = 0
            try:
                gamification = await supabase_service.get_gamification_data(student["id"])
                streak_days = int((gamification or {}).get("current_streak") or 0)
            except Exception:
                streak_days = int(student.get("streak_days") or 0)

            if streak_days > 0:
                msg_streak = (
                    f"🔥 *{nome}, sua ofensiva atual é de {streak_days} dia(s) seguido(s)!*\n\n"
                    f"Continue firme na consistência! Registre seu treino de hoje no app: {APP_URL} 💪"
                )
            else:
                msg_streak = (
                    f"🔥 *{nome}, sua ofensiva está em 0 dias no momento.*\n\n"
                    f"Bora começar uma nova sequência hoje? Acesse seu treino e conclua a sessão no app: {APP_URL} 💪"
                )
            await _reply(msg_streak, cost="free")
            return

        if cmd in MENU_APP:
            await _reply(
                (
                    f"📲 *Acesso ao App Mr. Coach*\n\n"
                    f"Entre pelo link: {APP_URL}\n"
                    "Use seu e-mail cadastrado pelo treinador para visualizar sua ficha interativa, vídeos e registrar sua ofensiva! 💪"
                ),
                cost="free",
            )
            return

        # ---------------------------------------------------------------------
        # PASSO 2.2 — Trava Comercial da Fase 2 (Monetização por Plano)
        # ---------------------------------------------------------------------
        sub = await supabase_service.get_trainer_subscription(trainer_id)
        plan_id = str(getattr(sub, "plan_id", "") or "").lower()
        if plan_id == "starter" or plan_id not in PHASE2_ALLOWED_PLANS:
            await _reply(
                f"Recebi sua mensagem! Já encaminhei para o seu treinador responder pessoalmente. Para ver sua ficha agora, digite *1* ou acesse: {APP_URL} 💪",
                cost="free",
            )
            return

        # ---------------------------------------------------------------------
        # Consultor Ativo IA (Fase 2 — Planos Pro, Elite e Studio)
        # ---------------------------------------------------------------------
        if not _within_limit(student["id"]):
            await _reply(
                "Você atingiu o limite de dúvidas de hoje 😊 Seu professor vai te responder em breve!",
                cost="free",
            )
            return

        plan = await supabase_service.get_active_prescription(student["id"])
        if not plan:
            await _reply(
                "Ainda não encontrei uma ficha ativa para você. Vou avisar seu professor! 💪",
                cost="free",
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
        await _reply(response.text.strip(), cost="ai_gemini", tokens=len(response.text.split()))
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
