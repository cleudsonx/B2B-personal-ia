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
    "Você é o assistente virtual do personal trainer do aluno, respondendo pelo WhatsApp com excelência e segurança. "
    "Responda em português, em no máximo 4 frases curtas, tom amigável, motivador e profissional. "
    "Baseie-se na ficha de treino e na anamnese clínica do aluno (objetivos, restrições e dores relatadas). "
    "Dúvidas sobre postura, cadência, amplitude, descanso e substituição de aparelhos são bem-vindas. "
    "Se o aluno relatar desconforto articular, oriente a não forçar e sugira adaptações seguras condizentes com a ficha. "
    "NUNCA diagnostique doenças, prescreva medicamentos ou altere a estrutura base da ficha sem autorização do treinador. "
    "Se houver dor aguda ou dúvida complexa, oriente a parar e avise que notificará o professor."
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
MENU_TRAINER_NOTE = {"4", "recado", "falar com professor", "deixar recado", "avisar professor"}
MENU_BIOHUB = {"5", "bio", "biohub", "bio-hub", "peso", "imc", "meu peso", "meu imc", "medidas", "minhas medidas"}

PHASE2_ALLOWED_PLANS = {
    "pro",
    "personal_pro",
    "elite",
    "elite_coach",
    "coach_elite",
    "studio",
    "shaipados_studio",
}


def _is_greeting(cmd: str) -> bool:
    if cmd in MENU_GREETINGS:
        return True
    starters = ("oi", "ola", "bom dia", "boa tarde", "boa noite", "opa", "fala mestre", "fala prof")
    for st in starters:
        if cmd == st or cmd.startswith(f"{st} ") or cmd.startswith(f"{st},") or cmd.startswith(f"{st}!"):
            if len(cmd) < 90 or "gostaria de tirar uma duvida" in cmd or "sou aluno" in cmd:
                if not any(k in cmd for k in ("exercicio", "substitu", "dor", "execut", "como faco", "posso trocar", "sinto")):
                    return True
    return False


def _is_acute_pain(cmd: str) -> bool:
    pain_triggers = (
        "dor aguda", "travei a coluna", "dor no peito", "dor forte",
        "lesionei", "machuquei", "muita dor", "estou com muita dor",
        "dor insuportavel", "dor insuportável", "dor no coracao",
        "falta de ar", "tontura forte"
    )
    return any(p in cmd for p in pain_triggers)


def is_phase2_ai_allowed(sub: Any) -> bool:
    """Verifica se o treinador possui plano com IA 24h liberada (Pro, Elite Coach e Studio)."""
    if not sub:
        return False
    plan_id = str(getattr(sub, "plan_id", "") or "").lower().replace("-", "_").strip()
    plan_name = str(getattr(sub, "plan_name", "") or "").lower().strip()

    # Starter é plano básico: fica com a triagem gratuita de custo zero
    if plan_id in {"starter", "free", "basic"} or "starter" in plan_name:
        return False

    if plan_id in PHASE2_ALLOWED_PLANS:
        return True

    for keyword in ("elite", "pro", "studio"):
        if keyword in plan_id or keyword in plan_name:
            return True

    return False


APP_URL = "https://shaipados-labs.web.app"


async def process_whatsapp_question(trainer_id: str, student: Dict[str, Any], question: str) -> Dict[str, Any]:
    """Processa a mensagem com triagem de custo zero, guardrails de dor e IA biomecânica com anamnese."""
    nome = (student.get("full_name") or "Aluno").split()[0]
    cmd = _normalize_command(question)

    # 1. Se for o próprio treinador testando
    if student.get("role") == "trainer_self_test":
        return {
            "reply": (
                f"🧪 *Teste de Conexão Bem-Sucedido!*\n\n"
                f"Olá, {nome}! O seu Robô WhatsApp do Mr. Coach está 100% ativo e operacional.\n\n"
                f"Quando seus alunos mandarem mensagem aqui, eles receberão o menu automático e você não gastará tokens de IA nos comandos rápidos (1 = Ver Treino, 2 = Streak 🔥, 4 = Recado, 5 = Bio-Hub).\n\n"
                f"Tudo pronto para atender seus alunos!"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 2. Saudações e Mensagens de Abertura (Triagem de Custo Zero)
    if _is_greeting(cmd):
        return {
            "reply": (
                f"Olá, {nome}! 💪 Sou o assistente automático do seu treinador no Mr. Coach.\n\n"
                "Digite uma opção:\n"
                "*1* - Ver meu treino ativo\n"
                "*2* - Ver minha ofensiva (Streak 🔥)\n"
                "*3* - Link do App\n"
                "*4* - Deixar recado para o professor\n"
                "*5* - Meu Bio-Hub (Peso, IMC e Meta)\n\n"
                "Ou envie sua dúvida sobre execução, postura ou substituição de exercício!"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 3. Opção 1: Ficha ativa
    if cmd in MENU_WORKOUT:
        plan = await supabase_service.get_active_prescription(student["id"])
        if not plan:
            return {
                "reply": "Ainda não encontrei uma ficha ativa para você. Vou avisar seu professor! 💪",
                "cost_type": "free",
                "tokens_used": 0,
            }
        return {
            "reply": f"📋 *Seu Treino Ativo*\n\n{_plan_summary(plan)}\n\n📲 Acesse completo no app: {APP_URL}",
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 4. Opção 2: Streak e consistência
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
        return {
            "reply": msg_streak,
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 5. Opção 3: Link do app
    if cmd in MENU_APP:
        return {
            "reply": (
                f"📲 *Acesso ao App Mr. Coach*\n\n"
                f"Entre pelo link: {APP_URL}\n"
                "Use seu e-mail cadastrado pelo treinador para visualizar sua ficha interativa, vídeos e registrar sua ofensiva! 💪"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 6. Opção 4: Deixar recado para o treinador (ou recado direto com prefixo "recado:")
    if cmd in MENU_TRAINER_NOTE or "deixar recado" in cmd or cmd.startswith("recado:") or cmd.startswith("recado "):
        note_body = ""
        if ":" in question:
            note_body = question.split(":", 1)[1].strip()
        elif cmd.startswith("recado ") and len(question.strip()) > 7:
            note_body = question.strip()[7:].strip()

        if note_body:
            try:
                client = await supabase_service.get_client()
                if client:
                    await client.table("adaptation_logs").insert({
                        "client_id": student["id"],
                        "trainer_id": trainer_id,
                        "original_exercise": "Recado via WhatsApp",
                        "adapted_exercise": "Atenção Solicitada",
                        "reason": note_body[:200],
                        "adaptation_details": {
                            "student_name": student.get("full_name") or nome,
                            "pain_location": "Recado do Aluno",
                            "severity": "Moderada",
                        },
                        "viewed_by_trainer": False,
                    }).execute()
            except Exception as note_err:
                logger.debug(f"[WhatsAppAI] Falha ao registrar recado: {note_err}")

            return {
                "reply": (
                    f"✅ *Recado Registrado, {nome}!*\n\n"
                    f"Já enviei um alerta direto para o painel do seu treinador com a sua mensagem:\n"
                    f"_\"{note_body[:150]}\"_\n\n"
                    f"Ele verá assim que abrir o Mr. Coach! 💪"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }

        return {
            "reply": (
                f"📝 *Recado para o Professor*\n\n"
                f"{nome}, para enviar um aviso prioritário direto para o painel do seu treinador, envie:\n"
                f"*recado: sua mensagem aqui*\n\n"
                "Exemplo: _recado: hoje treinei mais leve pois dormi pouco._ 💪"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 6.5 Opção 5: Meu Bio-Hub (Peso, IMC e Meta) - Custo Zero (0 Tokens)
    if cmd in MENU_BIOHUB:
        bio_data: Dict[str, Any] = {}
        try:
            bio_data = await supabase_service.get_student_latest_biohub(student["id"])
        except Exception as e:
            logger.debug(f"[WhatsAppAI] Fallback biohub: {e}")

        weight = bio_data.get("weight_kg") or student.get("weight_kg")
        height = bio_data.get("height_cm") or student.get("height_cm")
        bmi = bio_data.get("bmi")
        bmi_cat = bio_data.get("bmi_category") or "Não calculado"
        bf = bio_data.get("body_fat_pct")
        muscle = bio_data.get("muscle_mass_kg")
        goal = bio_data.get("objective") or student.get("goal") or "Hipertrofia e Saúde"

        if not bmi and weight and height and float(height) > 40:
            h_m = float(height) / 100.0
            bmi = round(float(weight) / (h_m * h_m), 1)
            bmi_cat = "Peso ideal" if 18.5 <= bmi < 25 else ("Sobrepeso" if bmi < 30 else "Atenção nutricional")

        if not weight and not height:
            return {
                "reply": (
                    f"🧬 *Seu Bio-Hub — Mr. Coach*\n\n"
                    f"{nome}, você ainda não possui medidas registradas no Bio-Hub.\n"
                    f"🎯 *Meta Atual:* {goal}\n\n"
                    f"📲 Acesse a aba *Bio-Hub* no app para atualizar seu peso e acompanhar seu IMC: {APP_URL} 💪"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }

        lines = [f"🧬 *Seu Bio-Hub — {nome}*"]
        if weight:
            lines.append(f"⚖️ *Peso Atual:* {weight} kg")
        if height:
            lines.append(f"📏 *Altura:* {int(float(height))} cm")
        if bmi:
            lines.append(f"📊 *IMC:* {bmi} ({bmi_cat})")
        if bf is not None:
            lines.append(f"💧 *Gordura Corporal (BF):* {bf}%")
        if muscle is not None:
            lines.append(f"💪 *Massa Muscular:* {muscle} kg")
        lines.append(f"🎯 *Objetivo:* {goal}")
        lines.append(f"\n📲 Atualize suas medidas na aba *Bio-Hub* do app:\n{APP_URL}")

        return {
            "reply": "\n".join(lines),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 7. Safety Guardrail: Alerta de dor aguda / lesão
    if _is_acute_pain(cmd):
        try:
            client = await supabase_service.get_client()
            if client:
                await client.table("biomechanical_alerts").insert({
                    "student_id": student["id"],
                    "trainer_id": trainer_id,
                    "type": "whatsapp_pain_report",
                    "severity": "high",
                    "details": f"Aluno relatou dor/lesão via WhatsApp: '{question[:200]}'",
                    "status": "pending",
                }).execute()
        except Exception as alert_err:
            logger.debug(f"[WhatsAppAI] Falha ao registrar alerta de dor: {alert_err}")

        return {
            "reply": (
                f"⚠️ *Atenção, {nome}!* Por segurança biomecânica, *interrompa imediatamente o exercício*.\n\n"
                f"Já registrei um alerta prioritário no painel do seu treinador para que ele avalie seu caso. "
                f"Se a dor persistir ou for aguda, procure atendimento médico. Cuide-se! 💪"
            ),
            "cost_type": "free",
            "tokens_used": 0,
            "is_alert": True,
        }

    # 8. Trava Comercial do Treinador (Monetização por Plano)
    sub = await supabase_service.get_trainer_subscription(trainer_id)
    if not is_phase2_ai_allowed(sub):
        return {
            "reply": f"Recebi sua mensagem! Já encaminhei para o seu treinador responder pessoalmente. Para ver sua ficha agora, digite *1* ou acesse: {APP_URL} 💪",
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 9. Limite diário por aluno
    if not _within_limit(student["id"]):
        return {
            "reply": "Você atingiu o limite de dúvidas de hoje 😊 Seu professor vai te responder em breve!",
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 10. Busca Ficha Ativa
    plan = await supabase_service.get_active_prescription(student["id"])
    if not plan:
        return {
            "reply": "Ainda não encontrei uma ficha ativa para você. Vou avisar seu professor! 💪",
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 11. Busca Anamnese Expandida (Objetivos, Lesões e Restrições Físicas)
    anamnesis_ctx = ""
    try:
        anam = await supabase_service.get_student_anamnesis(student["id"])
        if anam:
            parts = []
            if anam.get("objective"):
                parts.append(f"Objetivo: {anam['objective']}")
            if anam.get("injuries_or_restrictions"):
                parts.append(f"Lesões/Restrições/Dores: {anam['injuries_or_restrictions']}")
            if anam.get("training_level") or anam.get("experience_level"):
                parts.append(f"Nível de Treino: {anam.get('training_level') or anam.get('experience_level')}")
            if anam.get("medical_conditions"):
                parts.append(f"Condições Médicas: {anam['medical_conditions']}")
            if parts:
                anamnesis_ctx = "\nAnamnese do Aluno:\n- " + "\n- ".join(parts)
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar anamnese: {e}")

    prompt = (
        f"Aluno: {student.get('full_name') or 'Aluno'}{anamnesis_ctx}\n"
        f"{_plan_summary(plan)}\n\n"
        f"Pergunta: {question[:MAX_QUESTION_CHARS]}"
    )
    config = types.GenerateContentConfig(
        system_instruction=SYSTEM_PROMPT, temperature=0.4, max_output_tokens=300
    )
    response = await gemini_service._generate_with_fallback_async(
        candidate_models=AI_MODELS, contents=prompt, config=config, per_model_timeout=12.0
    )
    reply_text = response.text.strip()
    return {
        "reply": reply_text,
        "cost_type": "ai_gemini",
        "tokens_used": len(reply_text.split()),
    }


async def _answer(instance: str, number: str, digits: str, question: str) -> None:
    try:
        trainer_id = trainer_id_from_instance(instance)
        if not trainer_id:
            return
        student = await _find_student_by_phone(digits, trainer_id)
        if not student:
            logger.info(f"[WhatsAppAI] Mensagem ignorada de número não cadastrado: {digits}")
            return

        result = await process_whatsapp_question(trainer_id, student, question)
        text_to_send = result.get("reply") or ""
        cost = result.get("cost_type") or "free"
        tokens = result.get("tokens_used") or 0

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
