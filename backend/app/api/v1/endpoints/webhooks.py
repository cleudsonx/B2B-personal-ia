from typing import Dict, Any, Optional
from fastapi import APIRouter, Request, BackgroundTasks, HTTPException, status
import logging
import json

from app.core.config import settings
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.gemini_service import GeminiService
from app.services.payment_service import PaymentProviderService
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.schemas.workout import BiomechanicalAlertCreate

logger = logging.getLogger(__name__)

router = APIRouter()
gemini_service = GeminiService()


async def process_anamnesis_update(student_id: str, new_restrictions: str, trainer_id: str):
    logger.info(f"Iniciando verificação de segurança biomecânica para o aluno {student_id}")

    # 1. Fetch active workout
    active_plan = await supabase_service.get_active_prescription(student_id)
    if not active_plan:
        logger.info(f"Aluno {student_id} não possui plano ativo. Análise pulada.")
        return

    # 2. Serialize workout safely
    workout_json = json.dumps(active_plan.model_dump(), default=str, ensure_ascii=False)

    # 3. Request Gemini Analysis
    try:
        safety_report = await gemini_service.analyze_biomechanical_safety(new_restrictions, workout_json)

        if not safety_report.get("is_safe", True):
            dangerous = safety_report.get("dangerous_exercises", [])
            names = [ex.get("exercise_name", "") for ex in dangerous]
            alert_message = f"ALERTA DE SEGURANÇA: {len(dangerous)} exercícios perigosos detectados devido à restrição '{new_restrictions}'. Exercícios: {', '.join(names)}. Recomendação: {safety_report.get('recommendation', '')}"

            # 4. Create Alert in database
            student = await supabase_service.get_student_by_id(student_id)
            student_name = student.full_name if student else "Aluno"

            alert = BiomechanicalAlertCreate(
                student_id=student_id,
                student_name=student_name,
                trainer_id=trainer_id,
                original_exercise=", ".join(names) if names else "Vários",
                adapted_exercise="Revisão Necessária via IA",
                reason=alert_message,
                pain_location="Geral/Perfil",
                severity="Alta",
                workout_id=active_plan.id
            )
            await supabase_service.create_biomechanical_alert(alert)
            logger.warning(f"Alerta biomecânico gerado para o aluno {student_id}: {alert_message}")

    except Exception as e:
        logger.error(f"Erro ao processar análise biomecânica com a IA: {e}")


@router.post("/supabase/anamnesis", status_code=status.HTTP_200_OK, summary="Supabase Webhook para Anamnese")
async def anamnesis_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Webhook chamado pelo Supabase quando o perfil de um aluno é atualizado (especificamente clinical_restrictions).
    """
    try:
        payload = await request.json()
    except Exception:
        return {"status": "ignored", "reason": "invalid payload"}

    record = payload.get("record", {})
    old_record = payload.get("old_record", {})

    # Check if this is an update and clinical_restrictions actually changed
    new_restrictions = record.get("clinical_restrictions")
    old_restrictions = old_record.get("clinical_restrictions")

    if new_restrictions and new_restrictions != old_restrictions:
        student_id = record.get("id")
        trainer_id = record.get("trainer_id")

        if student_id and trainer_id:
            background_tasks.add_task(process_anamnesis_update, student_id, new_restrictions, trainer_id)
            return {"status": "processing", "message": "Triggered AI biomechanical safety check in background."}

    return {"status": "ignored", "reason": "No meaningful restriction changes."}


async def send_anti_churn_overdue_whatsapp(invoice_id: str, client_db: Any = None):
    """Dispara mensagem proativa amigável via WhatsApp com botão interativo para gerar Pix Copia e Cola instantâneo."""
    try:
        from app.services.whatsapp_service import whatsapp_service
        phone = None
        student_name = "Aluno"
        amount = 0.0
        trainer_id = None

        if client_db and is_valid_uuid(invoice_id):
            res = await client_db.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
            if res and res.data:
                inv = res.data
                amount = float(inv.get("amount") or 0.0)
                trainer_id = inv.get("trainer_id")
                student_id = inv.get("student_id") or inv.get("client_id")
                if student_id:
                    st_res = await client_db.table("profiles").select("full_name, phone").eq("id", student_id).maybe_single().execute()
                    if st_res and st_res.data:
                        student_name = st_res.data.get("full_name") or student_name
                        phone = st_res.data.get("phone")

        if not phone:
            mem_inv = ConsultancyPlanService._mem_invoices.get(invoice_id)
            if mem_inv:
                amount = float(mem_inv.get("amount") or 0.0)
                phone = mem_inv.get("customer_phone")
                student_name = mem_inv.get("customer_name") or student_name

        if phone:
            first_name = (student_name or "Aluno").split()[0]
            val_txt = f" no valor de R$ {amount:.2f}" if amount > 0 else ""
            msg = (
                f"👋 *Olá, {first_name}! Tudo bem?*\n\n"
                f"Passando para avisar que a fatura da sua consultoria{val_txt} venceu.\n\n"
                f"Para manter seu acesso ao app, seus treinos atualizados e acompanhamento sem interrupções, "
                f"clique no botão abaixo para gerar o Pix Copia e Cola instantâneo: 👇"
            )
            buttons = [
                {"id": f"fin_pix|{invoice_id}", "title": "💠 Gerar Pix Agora"},
            ]
            await whatsapp_service.send_interactive_with_fallback(
                number=phone,
                text=msg,
                buttons=buttons,
                trainer_id=trainer_id,
            )
            logger.info(f"[Anti-Churn/Asaas] Notificação WhatsApp enviada para {phone} (fatura: {invoice_id})")
    except Exception as e:
        logger.warning(f"[Anti-Churn/Asaas] Falha ao enviar notificação WhatsApp de fatura vencida: {e}")


@router.post("/asaas", status_code=status.HTTP_200_OK, summary="Webhook Oficial Asaas (Consultorias e Assinaturas)")
async def asaas_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Webhook unificado para eventos do Gateway Asaas:
    1. Pagamentos de consultoria de alunos via vitrine pública (student_invoices):
       - Confirma pagamento (PAYMENT_RECEIVED / PAYMENT_CONFIRMED)
       - Credita a carteira do treinador (trainer_wallets)
       - Vincula aluno e dispara WhatsApp com link PWA de ativação
    2. Eventos de assinaturas SaaS dos treinadores (fallback transparente).
    """
    raw_body = await request.body()
    try:
        payload = json.loads(raw_body.decode("utf-8")) if raw_body else {}
    except Exception:
        payload = {}

    headers = dict(request.headers)

    # 1. Validação de autenticação e integridade do webhook
    try:
        PaymentProviderService.verify_webhook("asaas", payload, headers, raw_body)
    except Exception as e:
        logger.warning(f"[Webhook/Asaas] Falha na autenticação do webhook: {e}")
        raise HTTPException(status_code=401, detail=str(e))

    event = payload.get("event", "UNKNOWN")
    payment_obj = payload.get("payment") or {}
    ext_ref = payment_obj.get("externalReference") or payload.get("externalReference") or ""

    logger.info(f"[Webhook/Asaas] Evento '{event}' recebido com externalReference='{ext_ref}'")

    # 2. Verifica se a cobrança é de uma consultoria de aluno (student_invoices)
    client = await supabase_service.get_client()
    is_student_invoice = False

    if is_valid_uuid(ext_ref):
        if client:
            try:
                res = await client.table("student_invoices").select("id").eq("id", ext_ref).maybe_single().execute()
                if res and res.data:
                    is_student_invoice = True
            except Exception as e:
                logger.warning(f"[Webhook/Asaas] Erro ao consultar student_invoices: {e}")

        if not is_student_invoice and ext_ref in ConsultancyPlanService._mem_invoices:
            is_student_invoice = True

    # 3. Processamento de Fatura de Aluno
    if is_student_invoice:
        if event in ("PAYMENT_RECEIVED", "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED_IN_CASH", "PAYMENT_DUNNING_RECEIVED"):
            billing_type = payment_obj.get("billingType") or "PIX"
            payment_id = payment_obj.get("id")
            result = await ConsultancyPlanService.process_student_payment_confirmation(
                invoice_id=ext_ref,
                payment_method=billing_type,
                provider_payment_id=payment_id,
            )
            return {
                "processed": True,
                "type": "student_invoice",
                "event": event,
                "invoice_id": ext_ref,
                "result": result,
            }
        elif event in ("PAYMENT_REFUNDED", "PAYMENT_DELETED", "PAYMENT_CHARGEBACK_REQUESTED"):
            refund_res = await ConsultancyPlanService.process_student_payment_cancellation_or_refund(
                invoice_id=ext_ref,
                event=event,
            )
            return {
                "processed": True,
                "type": "student_invoice",
                "event": event,
                "invoice_id": ext_ref,
                "status": "canceled",
                "result": refund_res,
            }
        elif event in ("PAYMENT_OVERDUE",):
            if ext_ref in ConsultancyPlanService._mem_invoices:
                ConsultancyPlanService._mem_invoices[ext_ref]["status"] = "overdue"
            if client and is_valid_uuid(ext_ref):
                try:
                    await client.table("student_invoices").update({"status": "overdue"}).eq("id", ext_ref).execute()
                except Exception as e:
                    logger.error(f"[Webhook/Asaas] Erro ao marcar fatura {ext_ref} como vencida: {e}")

            # Disparo proativo Anti-Churn com botão interativo Pix 1-Toque
            background_tasks.add_task(send_anti_churn_overdue_whatsapp, ext_ref, client)

            return {
                "processed": True,
                "type": "student_invoice",
                "event": event,
                "invoice_id": ext_ref,
                "status": "overdue",
            }
        else:
            return {
                "processed": True,
                "type": "student_invoice",
                "event": event,
                "invoice_id": ext_ref,
                "status": "ignored",
            }

    # 4. Caso não seja fatura de aluno, trata como assinatura SaaS do Treinador:
    # Delega ao fluxo durável com lease e ativação atômica no Supabase quando houver sessão/evento válido
    has_event_id = bool(payload.get("id") or payment_obj.get("id"))
    if has_event_id and ext_ref:
        session_meta = (
            await supabase_service.get_checkout_session(ext_ref)
            or PaymentProviderService._PENDING_ORDERS.get(ext_ref)
        )
        if session_meta:
            from app.api.v1.endpoints.subscriptions import webhook_asaas as durable_webhook_asaas
            sub_res = await durable_webhook_asaas(payload, request)
            return {
                "processed": True,
                "type": "trainer_subscription",
                "event": event,
                "result": sub_res,
            }

    sub_res = PaymentProviderService.process_webhook("asaas", payload)
    return {
        "processed": True,
        "type": "trainer_subscription",
        "event": event,
        "result": sub_res,
    }
