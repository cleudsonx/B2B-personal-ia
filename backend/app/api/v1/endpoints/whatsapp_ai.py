"""
Consultor Ativo (IA no WhatsApp).

Recebe o webhook `messages.upsert` da Evolution API, identifica o aluno pelo
telefone, monta um contexto ENXUTO (ficha ativa + restrições) e responde com um
modelo barato (flash-lite). Pensado para custo mínimo e segurança:
- só responde alunos cadastrados (número desconhecido é ignorado);
- limite de mensagens por aluno/dia;
- resposta curta (max tokens) e sem aconselhamento médico.
"""
import base64
import hmac
import logging
import re
import time
from collections import defaultdict
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field

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


class WhatsAppButtonPayload(BaseModel):
    id: str = Field(..., max_length=256)
    title: str = Field(..., max_length=20)


class AgentWhatsAppOutput(BaseModel):
    reply: str
    interaction_type: str = "text"  # "text" ou "reply_buttons"
    buttons: Optional[List[WhatsAppButtonPayload]] = None
    cost_type: str = "free"
    tokens_used: int = 0

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


def _extract_media_info(data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Detecta se a mensagem recebida é um áudio ou nota de voz (PTT), seja Evolution ou Meta."""
    msg = data.get("message") or {}
    audio = msg.get("audioMessage") or msg.get("voiceMessage")
    if audio:
        return {
            "type": "audio",
            "mimetype": audio.get("mimetype") or "audio/ogg; codecs=opus",
            "seconds": audio.get("seconds", 0),
        }
    if data.get("type") == "audio" and "audio" in data:
        meta_audio = data["audio"]
        return {
            "type": "audio",
            "mimetype": meta_audio.get("mime_type") or "audio/ogg",
            "id": meta_audio.get("id"),
            "seconds": 0,
        }
    return None


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

    # 4. Quando a instância pertence a um treinador específico, não cruzamos com alunos de outros professores
    # O isolamento por treinador é estritamente garantido (aluno pode treinar com múltiplos professores).

    return None


async def _find_student_by_phone_global(digits: str) -> Optional[Dict[str, Any]]:
    """
    Busca o aluno pelo telefone em toda a base da plataforma quando a mensagem
    chega no número central (mr_coach_instance), identificando seu professor responsável.
    """
    client = await supabase_service.get_client()
    clean_target = "".join(c for c in (digits or "") if c.isdigit())
    if not client or len(clean_target) < 8:
        return None

    # 1. Busca em profiles de clientes ativos
    try:
        res = await client.table("profiles").select("id, full_name, trainer_id, role, subscription_status, phone") \
            .eq("role", "client").execute()
        for p in res.data or []:
            p_phone = "".join(c for c in (p.get("phone") or "") if c.isdigit())
            if len(p_phone) >= 8 and p_phone[-8:] == clean_target[-8:]:
                if str(p.get("subscription_status") or "").lower() == "suspended":
                    return None
                return p
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar aluno globalmente: {e}")

    # 2. Busca em convites pendentes
    try:
        inv_res = await client.table("invite_tokens").select("id, target_name, trainer_id, target_phone") \
            .is_("used_at", "null").execute()
        for inv in inv_res.data or []:
            inv_phone = "".join(c for c in (inv.get("target_phone") or "") if c.isdigit())
            if len(inv_phone) >= 8 and inv_phone[-8:] == clean_target[-8:]:
                return {
                    "id": inv["id"],
                    "full_name": inv.get("target_name") or "Aluno",
                    "trainer_id": inv.get("trainer_id"),
                    "role": "client",
                    "is_pending_invite": True,
                }
    except Exception as e:
        logger.warning(f"[WhatsAppAI] Erro ao buscar convite globalmente: {e}")

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
MENU_FINANCIAL = {
    "6",
    "pix",
    "cartao",
    "cartao de credito",
    "cartão",
    "cartão de crédito",
    "pagar",
    "pagamento",
    "fatura",
    "mensalidade",
    "renovar",
    "link de pagamento",
    "pagar com cartao",
    "pagar c cartao",
}

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


ANATOMICAL_LOCATIONS = {
    "joelho": "Joelho",
    "joelhos": "Joelho",
    "ombro": "Ombro",
    "ombros": "Ombro",
    "lombar": "Lombar",
    "coluna": "Coluna / Lombar",
    "costas": "Costas",
    "cotovelo": "Cotovelo",
    "cotovelos": "Cotovelo",
    "punho": "Punho",
    "punhos": "Punho",
    "pulso": "Punho",
    "pulsos": "Punho",
    "quadril": "Quadril",
    "gluteo": "Glúteo",
    "tornozelo": "Tornozelo",
    "tornozelos": "Tornozelo",
    "pescoco": "Pescoço / Cervical",
    "cervical": "Pescoço / Cervical",
    "trapezio": "Trapézio",
}

PAIN_KEYWORDS = (
    "dor", "dores", "doendo", "doer", "fisgada", "pontada", "estalo", "estalando",
    "lesao", "machuquei", "machucou", "incomodo", "desconforto"
)

PAIN_NEGATIONS = (
    "sem dor", "sem dores", "nenhuma dor", "zero dor", "zero dores",
    "sem desconforto", "nao senti dor", "nao senti nada", "sem lesao", "100%", "tudo bem", "tudo certo"
)


def parse_workout_feedback(text: str) -> Dict[str, Any]:
    """
    Analisa a mensagem do aluno e extrai com custo zero de tokens:
    - rpe: int (1 a 10) ou None
    - is_pain: bool
    - pain_location: str ou None (ex: 'Joelho', 'Ombro', 'Lombar')
    - pain_severity: str ('Moderada' ou 'Alta')
    - pain_description: str ou None
    """
    cmd = _normalize_command(text)

    # 1. Extração de RPE / PSE / Esforço
    rpe_val: Optional[int] = None
    m1 = re.search(r'\b(?:rpe|pse|esforco|nota|intensidade|percepcao)\s*[:=]?\s*(\d{1,2})\b', cmd)
    if m1:
        val = int(m1.group(1))
        if 1 <= val <= 10:
            rpe_val = val

    if rpe_val is None:
        m2 = re.search(r'\b(\d{1,2})\s*(?:/|de)\s*10\b', cmd)
        if m2:
            val = int(m2.group(1))
            if 1 <= val <= 10:
                rpe_val = val

    if rpe_val is None:
        if cmd.isdigit() and 1 <= int(cmd) <= 10:
            rpe_val = int(cmd)
        else:
            m3 = re.match(r'^rpe\s*(\d{1,2})$', cmd)
            if m3:
                val = int(m3.group(1))
                if 1 <= val <= 10:
                    rpe_val = val

    # 2. Extração de Alerta de Desconforto / Dor Articular
    is_pain = False
    pain_location: Optional[str] = None
    pain_severity = "Moderada"

    has_negation = any(neg in cmd for neg in PAIN_NEGATIONS)
    has_pain_kw = any(kw in cmd for kw in PAIN_KEYWORDS)

    if has_pain_kw:
        is_negated = has_negation and not any(k in cmd for k in ("mas dor", "mas senti", "porem senti", "porem dor", "so no ", "so na "))
        if not is_negated:
            for term, canonical in ANATOMICAL_LOCATIONS.items():
                if re.search(r'\b' + re.escape(term) + r'\b', cmd):
                    pain_location = canonical
                    is_pain = True
                    break
            if not pain_location:
                is_pain = True
                pain_location = "Articular Geral"

            if _is_acute_pain(cmd) or any(w in cmd for w in ("muita dor", "dor forte", "aguda", "travou", "insuportavel")):
                pain_severity = "Alta"

    return {
        "rpe": rpe_val,
        "is_pain": is_pain,
        "pain_location": pain_location,
        "pain_severity": pain_severity,
        "pain_description": text[:200] if is_pain else None,
    }


BIOMECHANICAL_EQUIVALENTS: Dict[str, List[str]] = {
    "leg press": ["Agachamento Búlgaro", "Hack Squat", "Passada Halteres"],
    "agachamento": ["Leg Press 45", "Agachamento Hack", "Agachamento Goblet"],
    "extensora": ["Agachamento Búlgaro", "Afundo c/ Halteres", "Sissy Squat"],
    "flexora": ["Stiff c/ Halteres", "Elevação Pélvica", "Flexora em Pé"],
    "supino": ["Supino Halteres", "Supino Máquina", "Flexão de Braço"],
    "supino reto": ["Supino Halteres", "Supino Articulado", "Flexão Solo"],
    "supino inclinado": ["Supino Inc Halteres", "Supino Inc Máquina", "Crucifixo Inclinado"],
    "crossover": ["Crucifixo Halteres", "Peck Deck", "Crucifixo no Banco"],
    "peck deck": ["Crucifixo Halteres", "Crossover Polia", "Supino Halteres"],
    "puxada": ["Puxada Triângulo", "Barra Fixa Assistida", "Pulldown Cabo"],
    "remada": ["Remada Halteres", "Remada Baixa Cabo", "Remada Cavalinho"],
    "elevacao lateral": ["Elevação Lateral Cabo", "Elevação Halteres", "Face Pull"],
    "desenvolvimento": ["Desenvolvimento Halteres", "Desenvolvimento Máquina", "Arnold Press"],
    "triceps": ["Tríceps Corda", "Tríceps Francês", "Tríceps Testa"],
    "biceps": ["Rosca Halteres", "Rosca Martelo", "Rosca Scott"],
    "panturrilha": ["Panturrilha em Pé", "Panturrilha Leg", "Panturrilha Sentado"],
}


def find_exercise_swap_candidates(cmd: str, plan_text: str = "") -> List[str]:
    """
    Identifica qual exercício/máquina o aluno precisa substituir (a partir da mensagem ou da ficha ativa)
    e retorna até 2 sugestões biomecânicas equivalentes para botões interativos de 1 toque.
    """
    # Ordena chaves por comprimento decrescente para priorizar termos compostos (ex: 'supino inclinado' antes de 'supino')
    for key in sorted(BIOMECHANICAL_EQUIVALENTS.keys(), key=len, reverse=True):
        if key in cmd:
            return BIOMECHANICAL_EQUIVALENTS[key][:2]

    if plan_text:
        plan_lower = plan_text.lower()
        for key in sorted(BIOMECHANICAL_EQUIVALENTS.keys(), key=len, reverse=True):
            if key in plan_lower:
                return BIOMECHANICAL_EQUIVALENTS[key][:2]

    return ["Halteres", "Articulado"]


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


async def handle_deterministic_button(
    digits: str,
    button_id: str,
    trainer_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Executa ações determinísticas O(1) sem custo de LLM disparadas por botões interativos
    (ou atalhos numéricos no fallback da Evolution API).
    Suporta:
    1. confirm_swap|workout_id|exercise_name: Registra adaptação pontual da sessão em adaptation_logs
       e notifica o personal trainer em student_pulse_events SEM modificar a ficha permanente.
    2. rpe_log|workout_id|rpe_value: Registra a percepção de esforço pós-treino em student_pulse_events.
    3. fin_pix|invoice_id: Busca e devolve o código Pix Copia e Cola instantâneo de student_invoices.
    4. menu_act|action: Executa ações rápidas de menu (treino, streak, biohub).
    """
    clean_digits = "".join(c for c in (digits or "") if c.isdigit())
    student = None
    if trainer_id:
        student = await _find_student_by_phone(clean_digits, trainer_id)
    if not student:
        student = await _find_student_by_phone_global(clean_digits)
        if student and not trainer_id:
            trainer_id = student.get("trainer_id")

    nome = (student.get("full_name") or "Aluno").split()[0] if student else "Aluno"
    parts = (button_id or "").split("|")
    action_type = parts[0] if parts else ""

    # 1. Substituição de Exercício em 1 Toque (confirm_swap)
    # REGRA INVIOLÁVEL: NUNCA altera a ficha permanente do mesociclo em 'workouts'.
    # Registra exclusivamente como 'Adaptação da Sessão de Hoje' em adaptation_logs e student_pulse_events.
    if action_type == "confirm_swap":
        workout_id = parts[1] if len(parts) > 1 else "active"
        exercise_name = parts[2] if len(parts) > 2 else "Exercício Adaptado"

        if student:
            client = await supabase_service.get_client()
            if client:
                try:
                    await client.table("adaptation_logs").insert({
                        "client_id": student["id"],
                        "trainer_id": trainer_id or student.get("trainer_id"),
                        "original_exercise": "Substituição Solicitada",
                        "adapted_exercise": exercise_name,
                        "reason": "Adaptação da Sessão de Hoje (WhatsApp 1-Toque)",
                        "adaptation_details": {
                            "source": "whatsapp_interactive",
                            "workout_id": workout_id,
                            "session_adaptation": True,
                            "exercise": exercise_name,
                        },
                        "viewed_by_trainer": False,
                    }).execute()
                except Exception as e_ad:
                    logger.warning("[WhatsApp Button] Erro ao registrar adaptation_logs: %s", e_ad)

                try:
                    await client.table("student_pulse_events").insert({
                        "student_id": student["id"],
                        "trainer_id": trainer_id or student.get("trainer_id"),
                        "event_type": "exercise_swap_session",
                        "event_data": {
                            "workout_id": workout_id,
                            "exercise": exercise_name,
                            "source": "whatsapp_button",
                        },
                    }).execute()
                except Exception as e_pulse:
                    logger.debug("[WhatsApp Button] Erro ao registrar student_pulse_events: %s", e_pulse)

        return {
            "reply": (
                f"✅ *Adaptação Registrada, {nome}!*\n\n"
                f"Para a sua sessão de hoje, você realizará *{exercise_name}*.\n\n"
                f"O seu professor foi avisado no radar do Mr. Coach. Sua ficha oficial do mesociclo segue intacta. "
                f"Excelente treino! 💪"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 1.1 Manter Prescrição Original (keep_original)
    if action_type == "keep_original":
        return {
            "reply": (
                f"💪 *Prescrição Mantida, {nome}!* Sem problemas! Vamos manter o exercício original conforme a ficha "
                f"prescrita pelo seu treinador. Concentre-se na técnica, respire fundo e faça uma ótima série! 🔥"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 2. Registro de Percepção Subjetiva de Esforço (rpe_log)
    if action_type == "rpe_log":
        workout_id = parts[1] if len(parts) > 1 else "active"
        rpe_val = parts[2] if len(parts) > 2 else "8"

        if student:
            try:
                from app.schemas.student_pulse import StudentPulseEventCreate
                await supabase_service.create_student_pulse_event(
                    StudentPulseEventCreate(
                        student_id=student["id"],
                        student_name=student.get("full_name") or nome,
                        trainer_id=trainer_id or student.get("trainer_id") or "trainer",
                        event_type="rpe_feedback",
                        severity="info",
                        title=f"RPE {rpe_val}/10 Registrado ({nome})",
                        description=f"Aluno confirmou percepção de esforço RPE {rpe_val}/10 via botão WhatsApp.",
                        metadata={
                            "workout_id": workout_id,
                            "rpe": rpe_val,
                            "source": "whatsapp_button",
                        },
                    )
                )
            except Exception as e_pulse:
                logger.debug("[WhatsApp Button] Erro ao registrar RPE em pulse: %s", e_pulse)

        return {
            "reply": (
                f"🔥 *Esforço Registrado (RPE {rpe_val})!*\n\n"
                f"Sensacional, {nome}! Sua percepção de esforço foi computada no radar do seu treinador.\n\n"
                f"Agora hidrate-se e descanse bem para a recuperação muscular! 💪"
            ),
            "cost_type": "free",
            "tokens_used": 0,
            "rpe": rpe_val,
        }

    # 3. Fluxo Financeiro: Código Pix Instantâneo (fin_pix)
    if action_type == "fin_pix":
        invoice_id = parts[1] if len(parts) > 1 else ""
        pix_code = None
        amount_val = None

        client = await supabase_service.get_client()
        if client and invoice_id:
            try:
                inv_res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                if inv_res and inv_res.data:
                    inv = inv_res.data
                    pix_code = inv.get("pix_copy_paste") or inv.get("pix_code")
                    amount_val = inv.get("amount")
            except Exception as e_inv:
                logger.warning("[WhatsApp Button] Erro ao buscar fatura %s: %s", invoice_id, e_inv)

        if not pix_code:
            from app.services.consultancy_plan_service import ConsultancyPlanService
            mem_inv = ConsultancyPlanService._mem_invoices.get(invoice_id)
            if mem_inv:
                pix_code = mem_inv.get("pix_copy_paste")
                amount_val = mem_inv.get("amount")

        if pix_code:
            val_txt = f" de R$ {float(amount_val):.2f}" if amount_val else ""
            return {
                "reply": (
                    f"💠 *Código Pix Copia e Cola — Mr. Coach*\n\n"
                    f"Aqui está o código Pix da sua mensalidade{val_txt}:\n\n"
                    f"```{pix_code}```\n\n"
                    f"Copie a chave acima e efetue o pagamento no aplicativo do seu banco. "
                    f"Assim que compensado, seu acesso é renovado em segundos! ⚡"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }
        else:
            return {
                "reply": (
                    f"💠 *Pagamento via Pix — Mr. Coach*\n\n"
                    f"{nome}, você pode gerar seu Pix atualizado ou pagar diretamente no app:\n"
                    f"{APP_URL}\n\n"
                    f"Qualquer dúvida, fale diretamente com seu professor! 💪"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }

    # 3.1 Fluxo Financeiro: Link Cartão de Crédito / Checkout (fin_link)
    if action_type == "fin_link":
        invoice_id = parts[1] if len(parts) > 1 else ""
        pay_url = None
        amount_val = None

        client = await supabase_service.get_client()
        if client and invoice_id:
            try:
                inv_res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                if inv_res and inv_res.data:
                    inv = inv_res.data
                    pay_url = inv.get("invoice_url") or inv.get("payment_url") or inv.get("bank_slip_url")
                    amount_val = inv.get("amount")
            except Exception as e_inv:
                logger.warning("[WhatsApp Button] Erro ao buscar link de pagamento %s: %s", invoice_id, e_inv)

        if not pay_url:
            from app.services.consultancy_plan_service import ConsultancyPlanService
            mem_inv = ConsultancyPlanService._mem_invoices.get(invoice_id)
            if mem_inv:
                pay_url = mem_inv.get("invoice_url") or mem_inv.get("payment_url")
                amount_val = mem_inv.get("amount")

        target_url = pay_url or f"{APP_URL}"
        val_txt = f" (R$ {float(amount_val):.2f})" if amount_val else ""
        return {
            "reply": (
                f"💳 *Pagamento com Cartão de Crédito — Mr. Coach*\n\n"
                f"{nome}, você pode pagar ou parcelar sua mensalidade{val_txt} com total segurança pelo link oficial:\n\n"
                f"🔗 {target_url}\n\n"
                f"Assim que a operadora aprovar, seu acesso aos treinos e suporte com seu personal é renovado automaticamente! 🚀"
            ),
            "cost_type": "free",
            "tokens_used": 0,
        }

    # 3.2 Fluxo Financeiro: Consulta de Pagamento Realizado (fin_paid)
    if action_type == "fin_paid":
        invoice_id = parts[1] if len(parts) > 1 else ""
        inv_status = "pending"

        client = await supabase_service.get_client()
        if client and invoice_id:
            try:
                inv_res = await client.table("student_invoices").select("status").eq("id", invoice_id).maybe_single().execute()
                if inv_res and inv_res.data:
                    inv_status = str(inv_res.data.get("status") or "pending").lower()
            except Exception as e_inv:
                logger.warning("[WhatsApp Button] Erro ao verificar status da fatura %s: %s", invoice_id, e_inv)

        if inv_status in ("paid", "received", "confirmed"):
            return {
                "reply": (
                    f"✅ *Pagamento já Confirmado, {nome}!*\n\n"
                    f"Seu pagamento foi compensado com sucesso pelo banco. Sua consultoria e treinos estão 100% ativos!\n\n"
                    f"Acesse o app e continue firme na consistência: {APP_URL} 💪"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }
        else:
            return {
                "reply": (
                    f"⏳ *Processamento Bancário em Andamento, {nome}!*\n\n"
                    f"Pagamentos via Pix são compensados em até 5 minutos. Pagamentos via Cartão ou Boleto podem levar alguns instantes para a operadora confirmar.\n\n"
                    f"Assim que o gateway confirmar a transação, seu acesso será atualizado automaticamente e você receberá uma confirmação aqui! ⚡"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }

    # 4. Ações de Menu Rápido (menu_act)
    if action_type == "menu_act":
        sub_act = parts[1] if len(parts) > 1 else ""
        if sub_act in ("workout", "workout_today", "treino") and student:
            return await process_whatsapp_question(trainer_id or "", student, "1")
        elif sub_act in ("streak", "ofensiva") and student:
            return await process_whatsapp_question(trainer_id or "", student, "2")
        elif sub_act in ("bio", "biohub", "medidas") and student:
            return await process_whatsapp_question(trainer_id or "", student, "5")
        elif sub_act in ("note", "note_trainer", "recado") and student:
            return await process_whatsapp_question(trainer_id or "", student, "4")
        elif sub_act in ("app", "link") and student:
            return await process_whatsapp_question(trainer_id or "", student, "3")

    # Fallback seguro e contextual para botões desconhecidos (NUNCA responde com treino indevido!)
    return {
        "reply": (
            f"Opção recebida com sucesso, {nome}! 💪\n\n"
            f"Se precisar consultar seu treino, ver sua ofensiva ou tirar dúvidas de postura e exercícios, "
            f"é só mandar uma mensagem ou digitar *menu* a qualquer momento!"
        ),
        "cost_type": "free",
        "tokens_used": 0,
    }


async def process_whatsapp_question(
    trainer_id: str,
    student: Dict[str, Any],
    question: str,
    audio_bytes: Optional[bytes] = None,
    audio_mimetype: Optional[str] = None,
) -> Dict[str, Any]:
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

    # 2. Saudações e Mensagens de Abertura (Triagem de Custo Zero com Botões Interativos)
    if _is_greeting(cmd):
        return {
            "reply": (
                f"Olá, {nome}! 💪 Sou o assistente automático do seu treinador no Mr. Coach.\n\n"
                "Escolha uma opção rápida abaixo ou envie sua dúvida sobre execução, postura ou substituição de exercício!"
            ),
            "interaction_type": "reply_buttons",
            "buttons": [
                {"id": "menu_act|workout", "title": "Ver Treino 📋"},
                {"id": "menu_act|streak", "title": "Streak 🔥"},
                {"id": "menu_act|bio", "title": "Bio-Hub 🧬"},
            ],
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

    # 6.6 Opção 6: Informações de Pagamento / Fatura / Pix / Cartão - Custo Zero (0 Tokens)
    if cmd in MENU_FINANCIAL or any(k in cmd for k in ("pagar", "pagamento", "fatura", "mensalidade", "chave pix", "pagar c/ cartao")):
        inv_data = None
        client = await supabase_service.get_client()
        if client:
            try:
                inv_res = await client.table("student_invoices").select("*").eq("student_id", student["id"]).order("due_date", desc=True).limit(1).execute()
                if inv_res and inv_res.data:
                    inv_data = inv_res.data[0]
            except Exception as e_fin:
                logger.debug(f"[WhatsAppAI] Falha ao buscar fatura do aluno: {e_fin}")

        if inv_data:
            pix = inv_data.get("pix_copy_paste") or inv_data.get("pix_code")
            card_url = inv_data.get("invoice_url") or inv_data.get("payment_url") or APP_URL
            amount = inv_data.get("amount")
            val_txt = f" de R$ {float(amount):.2f}" if amount else ""
            status = str(inv_data.get("status") or "").lower()

            if status in ("paid", "received", "confirmed"):
                return {
                    "reply": (
                        f"✅ *Mensalidade em Dia, {nome}!*\n\n"
                        f"Identificamos que a sua última mensalidade{val_txt} já está quitada com sucesso.\n\n"
                        f"Seus treinos e acompanhamento seguem 100% liberados! Acesse o app: {APP_URL} 💪"
                    ),
                    "cost_type": "free",
                    "tokens_used": 0,
                }

            pix_block = f"\n\n💠 *Pix Copia e Cola:*\n```{pix}```" if pix else ""
            return {
                "reply": (
                    f"💳 *Informações de Pagamento — {nome}*\n\n"
                    f"Sua mensalidade{val_txt} está disponível para quitação:{pix_block}\n\n"
                    f"🔗 *Cartão de Crédito ou Boleto:* {card_url}\n\n"
                    f"Após o pagamento, a liberação é imediata no sistema! ⚡"
                ),
                "interaction_type": "reply_buttons",
                "buttons": [
                    {"id": f"fin_pix|{inv_data.get('id', '')}", "title": "💠 Gerar Pix"},
                    {"id": f"fin_link|{inv_data.get('id', '')}", "title": "💳 Pagar c/ Cartão"},
                    {"id": f"fin_paid|{inv_data.get('id', '')}", "title": "✅ Já paguei"},
                ],
                "cost_type": "free",
                "tokens_used": 0,
            }
        else:
            return {
                "reply": (
                    f"💳 *Informações Financeiras — Mr. Coach*\n\n"
                    f"{nome}, você pode gerenciar suas mensalidades, emitir Pix ou pagar no cartão diretamente pelo app:\n"
                    f"{APP_URL}\n\n"
                    f"Qualquer dúvida sobre valores ou planos, seu professor está à disposição! 💪"
                ),
                "cost_type": "free",
                "tokens_used": 0,
            }

    # 6.7. Check-in Pós-Treino, RPE e Desconforto Articular (Frente 2 — Custo Zero / 0 Tokens)
    feedback = parse_workout_feedback(question)
    if feedback.get("rpe") is not None or feedback.get("is_pain"):
        rpe_num = feedback.get("rpe")
        is_pain = bool(feedback.get("is_pain"))
        loc = feedback.get("pain_location") or "Articular"
        sev = feedback.get("pain_severity") or "Moderada"

        # 1. Se informou RPE, registra no barramento de eventos (Student Pulse)
        if rpe_num is not None:
            try:
                from app.schemas.student_pulse import StudentPulseEventCreate
                await supabase_service.create_student_pulse_event(
                    StudentPulseEventCreate(
                        student_id=student["id"],
                        student_name=student.get("full_name") or nome,
                        trainer_id=trainer_id,
                        event_type="rpe_feedback",
                        severity="info",
                        title=f"RPE {rpe_num}/10 Registrado ({nome})",
                        description=f"Aluno relatou percepção de esforço RPE {rpe_num}/10 via WhatsApp.",
                        metadata={
                            "rpe": rpe_num,
                            "source": "whatsapp_text",
                            "text": question[:120],
                        },
                    )
                )
            except Exception as e_rpe:
                logger.debug(f"[WhatsAppAI] Falha ao registrar RPE em pulse: {e_rpe}")

        # 2. Se informou desconforto articular, registra alerta biomecânico no radar
        if is_pain:
            try:
                from app.schemas.workout import BiomechanicalAlertCreate
                await supabase_service.create_biomechanical_alert(
                    BiomechanicalAlertCreate(
                        student_id=student["id"],
                        student_name=student.get("full_name") or nome,
                        trainer_id=trainer_id,
                        original_exercise="Sessão de Treino",
                        adapted_exercise="Adaptação Biomecânica Solicitada",
                        reason=f"Aluno relatou desconforto via WhatsApp: {question[:150]}",
                        pain_location=loc,
                        severity=sev,
                        status="active",
                    )
                )
            except Exception as e_pain:
                logger.debug(f"[WhatsAppAI] Falha ao registrar alerta biomecânico: {e_pain}")

        # 3. Retorno empático e seguro ao aluno
        if rpe_num is not None and is_pain:
            reply = (
                f"🔥 *RPE {rpe_num}/10 Computado com Sucesso, {nome}!*\n\n"
                f"⚠️ *Alerta Articular ({loc}):* Já registrei seu relato de desconforto diretamente no radar do seu treinador.\n\n"
                f"Por segurança, evite sobrecarregar essa articulação hoje, aplique compressa fria se necessário e descanse. "
                f"O seu professor foi notificado e avaliará os próximos treinos! 💪"
            )
            return {
                "reply": reply,
                "cost_type": "free",
                "tokens_used": 0,
                "is_alert": True,
                "rpe": rpe_num,
                "pain_location": loc,
            }
        elif rpe_num is not None:
            reply = (
                f"🔥 *Esforço Registrado (RPE {rpe_num}/10), {nome}!* Sensacional!\n\n"
                f"Sua percepção de esforço foi computada no radar do seu treinador.\n\n"
                f"Agora hidrate-se bem, alimente-se e tenha uma excelente recuperação muscular! 💪"
            )
            return {
                "reply": reply,
                "cost_type": "free",
                "tokens_used": 0,
                "rpe": rpe_num,
            }
        else:
            reply = (
                f"⚠️ *Atenção, {nome}! Relato de Desconforto Registrado*\n\n"
                f"Acabei de avisar o seu treinador sobre o incômodo no *{loc}* no painel do Mr. Coach.\n\n"
                f"Recomendação imediata: evite exercícios que forcem a região e descanse a articulação. "
                f"Se a dor for aguda ou persistir, procure orientação médica. Cuide-se! 💪"
            )
            return {
                "reply": reply,
                "cost_type": "free",
                "tokens_used": 0,
                "is_alert": True,
                "pain_location": loc,
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

    if audio_bytes:
        prompt = (
            f"Aluno: {student.get('full_name') or 'Aluno'}{anamnesis_ctx}\n"
            f"Ficha Ativa do Aluno:\n{_plan_summary(plan)}\n\n"
            "O aluno enviou este áudio na academia com uma dúvida de treino. "
            "Escute o áudio, compreenda a dúvida e responda com excelência técnica cinesiológica e tom amigável. "
            "Responda em português claro, em no máximo 4 frases curtas, orientações seguras e sem aconselhamento médico. "
            "Se for dúvida sobre aparelho ocupado, sugira variação biomecanicamente equivalente condizente com a ficha. "
            "Se for desconforto articular, oriente a não forçar."
        )
        contents = [
            types.Part.from_bytes(data=audio_bytes, mime_type=audio_mimetype or "audio/ogg"),
            prompt,
        ]
    else:
        prompt = (
            f"Aluno: {student.get('full_name') or 'Aluno'}{anamnesis_ctx}\n"
            f"{_plan_summary(plan)}\n\n"
            f"Pergunta: {question[:MAX_QUESTION_CHARS]}"
        )
        contents = prompt

    config = types.GenerateContentConfig(
        system_instruction=SYSTEM_PROMPT, temperature=0.4, max_output_tokens=300
    )
    response = await gemini_service._generate_with_fallback_async(
        candidate_models=AI_MODELS, contents=contents, config=config, per_model_timeout=14.0
    )
    reply_text = response.text.strip()
    
    # Se a pergunta for sobre substituição de exercício ou áudio na academia, gera botões de confirmação em 1 toque
    swap_triggers = ("trocar", "substitu", "ocupad", "lotad", "cheio", "quebrad", "outro exercicio", "outra opcao", "alternativa", "tem outro")
    buttons = None
    if any(t in cmd for t in swap_triggers) or audio_bytes:
        candidates = find_exercise_swap_candidates(cmd, _plan_summary(plan) if plan else "")
        btn1_title = f"Trocar: {candidates[0]}"[:20]
        btn2_title = f"Trocar: {candidates[1]}"[:20] if len(candidates) > 1 else "Trocar p/ Halteres"
        buttons = [
            {"id": f"confirm_swap|active|{candidates[0]}", "title": btn1_title},
            {"id": f"confirm_swap|active|{candidates[1] if len(candidates) > 1 else 'Halteres'}", "title": btn2_title},
            {"id": "keep_original|active", "title": "Manter Original"},
        ]

    res_dict: Dict[str, Any] = {
        "reply": reply_text,
        "cost_type": "ai_gemini_voice" if audio_bytes else "ai_gemini",
        "tokens_used": len(reply_text.split()),
    }
    if buttons:
        res_dict["interaction_type"] = "reply_buttons"
        res_dict["buttons"] = buttons
    return res_dict


async def _answer(
    instance: str,
    number: str,
    digits: str,
    question: str,
    message_key: Optional[Dict[str, Any]] = None,
    media_info: Optional[Dict[str, Any]] = None,
) -> None:
    try:
        # 1. Identifica o treinador responsável (instância do professor ou número oficial da plataforma)
        trainer_id = trainer_id_from_instance(instance)
        student = None
        if trainer_id:
            student = await _find_student_by_phone(digits, trainer_id)
        else:
            # Mensagem recebida na instância oficial da Plataforma (ex: mr_coach_instance)
            student = await _find_student_by_phone_global(digits)
            if student:
                trainer_id = student.get("trainer_id")

        if not trainer_id or not student:
            logger.info(f"[WhatsAppAI] Mensagem ignorada de número não cadastrado: {digits} (instância: {instance})")
            return

        # 2. Processa áudio caso tenha sido enviado uma nota de voz (PTT / audioMessage)
        audio_bytes = None
        audio_mimetype = None
        if media_info and media_info.get("type") == "audio" and message_key:
            try:
                media_res = await whatsapp_service.get_base64_from_media(instance, message_key)
                if media_res and media_res.get("base64"):
                    b64_str = media_res["base64"]
                    if "," in b64_str:
                        b64_str = b64_str.split(",", 1)[1]
                    audio_bytes = base64.b64decode(b64_str)
                    audio_mimetype = media_res.get("mimetype") or media_info.get("mimetype") or "audio/ogg"
            except Exception as e:
                logger.warning(f"[WhatsAppAI] Falha ao recuperar áudio: {e}")

        result = await process_whatsapp_question(
            trainer_id=trainer_id,
            student=student,
            question=question,
            audio_bytes=audio_bytes,
            audio_mimetype=audio_mimetype,
        )
        text_to_send = result.get("reply") or ""
        cost = result.get("cost_type") or "free"
        tokens = result.get("tokens_used") or 0

        # Envia a resposta de volta (com botões nativos ou graceful degradation se houver botões)
        buttons = result.get("buttons")
        if buttons:
            await whatsapp_service.send_interactive_with_fallback(
                number=number,
                text=text_to_send,
                buttons=buttons,
                trainer_id=trainer_id,
            )
        else:
            await whatsapp_service.send_text_message(instance, number, text_to_send)
        try:
            await supabase_service.log_whatsapp_interaction(
                trainer_id=trainer_id,
                student_id=student.get("id"),
                student_name=student.get("full_name") or "Aluno",
                student_phone=digits,
                channel="whatsapp_voice" if audio_bytes else "whatsapp",
                message_in=f"[Mensagem de Áudio ({media_info.get('seconds', 0)}s)]" if audio_bytes else question,
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
    media_info = _extract_media_info(data)

    if (not text or not text.strip()) and not media_info:
        return {"status": "ignored"}

    digits = "".join(c for c in jid.split("@")[0] if c.isdigit())
    background.add_task(
        _answer,
        body.get("instance", ""),
        digits,
        digits,
        text.strip() if text else "",
        key,
        media_info,
    )
    return {"status": "accepted"}


async def process_meta_cloud_event(entry_payload: Dict[str, Any]) -> None:
    """
    Processador de eventos em background da Meta Cloud API oficial.
    Suporta:
    - Mensagens de texto com IA e menu de custo zero.
    - Botões interativos nativos (quick reply) com execução determinística O(1).
    - Idempotência rigorosa garantida via wamid em processed_webhook_events.
    """
    changes = entry_payload.get("changes") or []
    for change in changes:
        value = change.get("value") or {}
        messages = value.get("messages") or []
        for msg in messages:
            msg_id = msg.get("id")
            from_num = msg.get("from")
            if not msg_id or not from_num:
                continue

            # Idempotência estrita: evita reprocessamento de retentativas da Meta
            if await supabase_service.is_event_processed(msg_id):
                logger.info("[Meta Cloud Webhook] Evento %s já consolidado previamente.", msg_id)
                continue

            msg_type = msg.get("type")
            digits = "".join(c for c in from_num if c.isdigit())

            # 1. Clique em Botão Interativo (Quick Reply / Interactive Button)
            if msg_type == "interactive":
                btn_reply = msg.get("interactive", {}).get("button_reply") or {}
                button_id = btn_reply.get("id") or ""
                button_title = btn_reply.get("title") or ""
                logger.info("[Meta Cloud Webhook] Botão interativo acionado por %s: %s ('%s')", from_num, button_id, button_title)

                handler_res = await handle_deterministic_button(digits, button_id)
                reply_text = handler_res.get("reply") or "Opção registrada com sucesso!"

                await whatsapp_service.send_text_with_fallback(number=digits, text=reply_text)
                await supabase_service.record_processed_event(
                    event_id=msg_id,
                    provider="meta_cloud",
                    event_type="interactive_button_click",
                    payload={"from": from_num, "button_id": button_id},
                )

            # 2. Mensagem de Texto Livre
            elif msg_type == "text":
                text_body = msg.get("text", {}).get("body", "").strip()
                if not text_body:
                    continue

                student = await _find_student_by_phone_global(digits)
                trainer_id = student.get("trainer_id") if student else None

                if not student or not trainer_id:
                    logger.info("[Meta Cloud Webhook] Mensagem de número não cadastrado: %s", digits)
                    await supabase_service.record_processed_event(
                        event_id=msg_id,
                        provider="meta_cloud",
                        event_type="text_unregistered",
                        payload={"from": from_num},
                    )
                    continue

                ai_res = await process_whatsapp_question(
                    trainer_id=trainer_id,
                    student=student,
                    question=text_body,
                )
                reply_text = ai_res.get("reply") or ""
                buttons = ai_res.get("buttons")

                if buttons:
                    await whatsapp_service.send_interactive_with_fallback(
                        number=digits,
                        text=reply_text,
                        buttons=buttons,
                        trainer_id=trainer_id,
                    )
                else:
                    await whatsapp_service.send_text_with_fallback(
                        number=digits,
                        text=reply_text,
                        trainer_id=trainer_id,
                    )

                await supabase_service.record_processed_event(
                    event_id=msg_id,
                    provider="meta_cloud",
                    event_type="text_processed",
                    payload={"from": from_num, "text": text_body[:100]},
                )
