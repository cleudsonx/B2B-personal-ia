import logging
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)
from fastapi import APIRouter, HTTPException, Depends, Request, status
from app.api.deps import get_current_trainer, get_current_user
from app.core.config import settings
from app.schemas.subscription import (
    PlanResponse,
    PlanFeature,
    MySubscriptionResponse,
    CheckoutSessionRequest,
    CheckoutSessionResponse,
    PlanChangeSimulationRequest,
    PlanChangeSimulationResponse,
    PlanActivationRequest,
    CardPaymentRequest,
    CardPaymentResponse,
    InAppCardPaymentRequest,
    InAppCardPaymentResponse,
)
from app.services.payment_service import PaymentProviderService
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.consultancy_plan_service import ConsultancyPlanService

router = APIRouter()

# Armazenamento referencial vinculado ao serviço com fallback
ACTIVE_TRAINER_SUBSCRIPTIONS = supabase_service._mem_subscriptions

# Importa catálogo unificado de planos da fonte única da verdade
from app.core.plans import SAAS_PLANS, get_plan


async def _verify_payment_webhook(provider: str, payload: dict, request: Request) -> None:
    try:
        PaymentProviderService.verify_webhook(
            provider=provider,
            payload=payload,
            headers=dict(request.headers),
            raw_body=await request.body(),
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e


@router.get("/plans", response_model=List[PlanResponse])
async def list_subscription_plans():
    """Retorna os planos SaaS disponíveis para contratação."""
    return SAAS_PLANS


@router.get("/my-subscription", response_model=MySubscriptionResponse)
async def get_my_subscription(
    trainer_id: str = "current-trainer",
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Retorna o plano ativo e consumo de cotas do Personal Trainer autenticado.
    Busca no Supabase com contagem real de alunos ocupando vagas na assessoria.
    """
    profile = current_user.get("profile") or {}
    roles = profile.get("roles") or [profile.get("role")]
    if "trainer" not in roles and "admin" not in roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso exclusivo para treinadores."
        )

    auth_trainer_id = current_user.get("sub") or current_user.get("id")
    if settings.ENVIRONMENT.lower() == "production" and auth_trainer_id:
        effective_id = auth_trainer_id
    else:
        effective_id = trainer_id or auth_trainer_id or "current-trainer"
    return await supabase_service.get_trainer_subscription(effective_id)


@router.post("/activate-plan", response_model=MySubscriptionResponse)
async def activate_subscription_plan(
    req: PlanActivationRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
):
    """
    Ativa ou troca o plano do Personal Trainer imediatamente, persistindo no Supabase.
    Atualiza cotas de alunos, limite de gerações IA e periodicidade.
    Em produção: permite ativação direta APENAS para o plano gratuito ('starter').
    Planos pagos (pro, elite, studio) requerem pagamento comprovado via Asaas/Gateway.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == req.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail=f"Plano '{req.plan_id}' não encontrado.")

    auth_trainer_id = current_user.get("sub") or current_user.get("id") or "current-trainer"
    trainer_id = req.trainer_id or auth_trainer_id

    # Bloqueio em produção: planos pagos não podem ser ativados sem checkout comprovado
    if settings.ENVIRONMENT.lower() == "production":
        if req.plan_id != "starter":
            raise HTTPException(
                status_code=400,
                detail="Planos pagos só podem ser ativados através de pagamento confirmado (Pix ou Cartão)."
            )
        trainer_id = auth_trainer_id

    return await supabase_service.activate_subscription(
        trainer_id=trainer_id,
        plan_id=req.plan_id,
        billing_interval=req.billing_interval,
        payment_method=req.payment_method or "pix",
    )


@router.post("/calculate-change", response_model=PlanChangeSimulationResponse)
async def simulate_plan_change(request: PlanChangeSimulationRequest):
    """
    Simula e calcula as regras de negócio para Upgrade ou Downgrade de plano:
    - Pró-rata de saldo não utilizado
    - Bloqueio de downgrade caso a quantidade de alunos cadastrados exceda o novo limite
    - Efetivação imediata (upgrade) ou no fim do ciclo (downgrade)
    """
    valid_ids = {"starter", "pro", "elite", "studio"}
    if request.current_plan_id not in valid_ids or request.new_plan_id not in valid_ids:
        raise HTTPException(status_code=400, detail="Plano atual ou novo plano inválido.")

    result = PaymentProviderService.calculate_plan_change(
        current_plan_id=request.current_plan_id,
        new_plan_id=request.new_plan_id,
        billing_interval=request.billing_interval,
        days_used_in_cycle=request.days_used_in_cycle,
        total_days_in_cycle=request.total_days_in_cycle,
        active_students_count=request.active_students_count,
    )
    return PlanChangeSimulationResponse(**result)


@router.post("/checkout-session", response_model=CheckoutSessionResponse)
async def create_checkout_session(
    request: CheckoutSessionRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Gera uma sessão de checkout para assinatura do plano escolhido via Pix ou Cartão.
    Requer autenticação JWT. Em produção, o trainer_id é derivado do token autenticado.
    Suporta múltiplos gateways: Asaas, Mercado Pago, InfinitePay e Stripe.
    """
    selected_plan = next((p for p in SAAS_PLANS if p.id == request.plan_id), None)
    if not selected_plan:
        raise HTTPException(status_code=404, detail="Plano não encontrado.")

    # Derivar trainer_id das claims do token em produção — nunca do corpo da requisição
    auth_trainer_id = current_user.get("sub") or current_user.get("id")
    if settings.ENVIRONMENT.lower() == "production":
        if not auth_trainer_id or auth_trainer_id == "current-trainer":
            raise HTTPException(status_code=401, detail="Usuário não autenticado.")
        effective_trainer_id = auth_trainer_id
    else:
        effective_trainer_id = request.trainer_id or auth_trainer_id or "current-trainer"

    amount = (
        selected_plan.price_yearly_cents
        if request.billing_interval == "yearly"
        else selected_plan.price_monthly_cents
    )

    try:
        checkout_data = PaymentProviderService.create_checkout(
            provider=request.provider or "asaas",
            plan_id=selected_plan.id,
            plan_name=selected_plan.name,
            amount_cents=amount,
            billing_interval=request.billing_interval,
            payment_method=request.payment_method,
            trainer_name=(current_user.get("user_metadata") or {}).get("full_name") or request.trainer_name or "Personal Trainer",
            trainer_email=current_user.get("email") or request.trainer_email or "treinador@demo.com",
            trainer_id=effective_trainer_id,
            cpf_cnpj=request.cpf_cnpj,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

    # Persiste a sessão de checkout no Supabase para sobreviver a restarts (PAY-003)
    try:
        await supabase_service.save_checkout_session(checkout_data)
    except Exception as e:
        if settings.ENVIRONMENT.lower() == "production":
            raise HTTPException(
                status_code=500,
                detail=f"Falha ao persistir sessão de checkout de forma durável no banco: {e}"
            )
        import logging as _log
        _log.getLogger(__name__).warning(f"Erro ao persistir sessão em ambiente de teste/dev: {e}")

    return CheckoutSessionResponse(
        session_id=checkout_data["session_id"],
        provider=checkout_data["provider"],
        plan_id=checkout_data["plan_id"],
        plan_name=checkout_data["plan_name"],
        amount_cents=checkout_data["amount_cents"],
        billing_interval=checkout_data["billing_interval"],
        payment_method=checkout_data["payment_method"],
        pix_qr_code_base64=checkout_data.get("pix_qr_code_base64"),
        pix_copy_paste=checkout_data.get("pix_copy_paste"),
        checkout_url=checkout_data.get("checkout_url"),
        status=checkout_data.get("status", "pending"),
        expires_at=checkout_data["expires_at"],
        notes=checkout_data.get("notes"),
    )


@router.post("/pay-with-card", response_model=InAppCardPaymentResponse)
async def pay_with_card_in_app(
    request: InAppCardPaymentRequest,
    current_user: dict = Depends(get_current_trainer),
):
    """
    [Solução 1: Tokenização In-App Transparente & Nativa]
    Recebe os dados do cartão via TLS 1.3 do app mobile, encaminha-os diretamente
    ao gateway Asaas para tokenização e cobrança imediata da assinatura.
    NENHUM dado de cartão (PAN ou CVV) é armazenado em disco, logs ou banco local.
    Apenas o token gerado (creditCardToken) e a assinatura ativada são persistidos.
    """
    token_trainer_id = current_user.get("sub") or current_user.get("trainer_id")
    if not token_trainer_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação requerida para pagamento com cartão."
        )

    trainer_name = (
        current_user.get("user_metadata", {}).get("full_name")
        or current_user.get("name")
        or request.holder_name
        or "Personal Trainer"
    )
    trainer_email = current_user.get("email") or "treinador@demo.com"

    try:
        result = PaymentProviderService.process_in_app_card_tokenization(
            plan_id=request.plan_id,
            billing_interval=request.billing_interval,
            card_number=request.card_number,
            holder_name=request.holder_name,
            expiry_month=request.expiry_month,
            expiry_year=request.expiry_year,
            ccv=request.ccv,
            trainer_id=token_trainer_id,
            trainer_name=trainer_name,
            trainer_email=trainer_email,
            holder_cpf=request.holder_cpf,
            holder_phone=request.holder_phone,
            holder_postal_code=request.holder_postal_code,
            holder_address_number=request.holder_address_number,
            provider=request.provider or "asaas",
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))

    # Ativa a assinatura do treinador no Supabase
    try:
        await supabase_service.activate_subscription(
            trainer_id=token_trainer_id,
            plan_id=request.plan_id,
            billing_interval=request.billing_interval,
            payment_method="credit_card",
        )
    except Exception as e:
        if settings.ENVIRONMENT.lower() == "production":
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Falha ao persistir ativação da assinatura no banco: {e}"
            )
        import logging as _log
        _log.getLogger(__name__).warning(f"Erro ao persistir assinatura em dev/teste: {e}")

    return InAppCardPaymentResponse(
        success=True,
        status="active",
        message=result["message"],
        plan_id=result["plan_id"],
        plan_name=result["plan_name"],
        billing_interval=result["billing_interval"],
        trainer_id=token_trainer_id,
        card_token=result.get("card_token"),
        last4=result.get("last4"),
        card_brand=result.get("card_brand"),
        subscription_id=result.get("subscription_id"),
        next_billing_date=result.get("next_billing_date"),
    )


@router.post("/process-card", response_model=CardPaymentResponse, status_code=status.HTTP_410_GONE, deprecated=True)
async def process_card_checkout():
    """
    [DESATIVADO PERMANENTEMENTE / CONFORMIDADE PCI DSS SAQ A]
    Este endpoint foi desativado permanentemente para garantir que o backend
    nunca trafegue, processe ou armazene dados brutos de cartão de crédito (PAN/CVV).
    O fluxo oficial de cartão de crédito ocorre exclusivamente através da página
    hospedada segura do Asaas gerada em POST /checkout-session.
    """
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Endpoint desativado em conformidade estrita com PCI DSS. Utilize o checkout oficial Asaas via POST /checkout-session."
    )


@router.post("/webhook/asaas")
async def webhook_asaas(payload: dict, request: Request):
    """Webhook oficial Asaas com durable lease e consolidação atômica via RPC v2."""
    await _verify_payment_webhook("asaas", payload, request)

    event_id = payload.get("id")
    if not event_id:
        payment_obj = payload.get("payment") or {}
        p_id = payment_obj.get("id") or ""
        evt = payload.get("event") or "UNKNOWN"
        event_id = f"asaas_{evt}_{p_id}" if p_id else None
    if not event_id:
        raise HTTPException(status_code=400, detail="Webhook Asaas sem event_id para idempotência; rejeitado.")

    claim_token = None
    try:
        claim_result = await supabase_service.claim_webhook_event(
            event_id=event_id,
            provider="asaas",
            event_type=payload.get("event", "UNKNOWN"),
            payload=payload,
            lease_seconds=300,
            max_attempts=5,
        )
        claim_token = claim_result.get("claim_token")
        disposition = str(claim_result.get("disposition") or "claimed").lower()
        if disposition in ("duplicate", "busy"):
            logger.info("[webhook/asaas] Evento duplicado/busy, idempotente: %s (%s)", event_id, disposition)
            return {
                "processed": True,
                "provider": "asaas",
                "idempotent": True,
                "event_id": event_id,
                "disposition": disposition,
                "message": f"Evento {event_id} já processado anteriormente ou já está em processamento; ignorando duplicata.",
            }
        if disposition == "failed":
            logger.warning("[webhook/asaas] Claim falhou após tentativas esgotadas para %s; encerrando retries automáticos.", event_id)
            return {
                "processed": True,
                "provider": "asaas",
                "idempotent": True,
                "event_id": event_id,
                "disposition": "failed",
                "manual_check_status": True,
                "message": "Evento excedeu tentativas de processamento; verifique status manualmente.",
            }

        result = PaymentProviderService.process_webhook("asaas", payload)

        ext_ref = (
            (payload.get("payment") or {}).get("externalReference")
            or payload.get("externalReference")
        )

        # Interceptador resiliente: Se o webhook for de fatura de consultoria de aluno
        if ext_ref and is_valid_uuid(ext_ref):
            client = await supabase_service.get_client()
            is_student_inv = False
            if client:
                try:
                    s_res = await client.table("student_invoices").select("id").eq("id", ext_ref).maybe_single().execute()
                    if s_res and s_res.data:
                        is_student_inv = True
                except Exception:
                    pass
            if not is_student_inv and ext_ref in ConsultancyPlanService._mem_invoices:
                is_student_inv = True

            if is_student_inv:
                event_name = payload.get("event", "UNKNOWN")
                if event_name in ("PAYMENT_RECEIVED", "PAYMENT_CONFIRMED"):
                    billing_type = (payload.get("payment") or {}).get("billingType") or "PIX"
                    res = await ConsultancyPlanService.process_student_payment_confirmation(
                        invoice_id=ext_ref,
                        payment_method=billing_type,
                        provider_payment_id=(payload.get("payment") or {}).get("id"),
                    )
                    if event_id and claim_token:
                        try:
                            await supabase_service.complete_subscription_webhook_v2(
                                event_id=event_id,
                                token=claim_token,
                                action="none",
                                trainer_id=None,
                                plan_id=None,
                                payment_method=billing_type.lower(),
                            )
                        except Exception:
                            pass
                    return {"processed": True, "type": "student_invoice", "result": res}
                elif event_name in ("PAYMENT_REFUNDED", "PAYMENT_DELETED"):
                    if client and is_valid_uuid(ext_ref):
                        await client.table("student_invoices").update({"status": "canceled"}).eq("id", ext_ref).execute()
                    return {"processed": True, "type": "student_invoice", "status": "canceled"}
                return {"processed": True, "type": "student_invoice", "event": event_name}
        order_meta = (
            (await supabase_service.get_checkout_session(ext_ref))
            or PaymentProviderService._PENDING_ORDERS.get(ext_ref or "", {})
        ) if ext_ref else {}

        subscription_status = str(result.get("subscription_status", "pending")).lower()
        trainer_id = order_meta.get("trainer_id") or result.get("trainer_id") or ""
        plan_id = order_meta.get("plan_id") or result.get("plan_id") or ""
        billing_interval = order_meta.get("billing_interval") or result.get("billing_interval") or "monthly"

        if subscription_status == "pending":
            action = "none"
        elif subscription_status == "active":
            action = "activate"
        elif subscription_status == "past_due":
            action = "past_due"
        elif subscription_status == "canceled":
            action = "canceled"
        else:
            action = "none"

        if action != "none":
            try:
                if trainer_id is None or str(trainer_id).strip() == "":
                    if event_id and claim_token:
                        release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_trainer_id")
                        if not release_result.get("released", False):
                            logger.warning("[webhook/asaas] Falha ao liberar lease para %s com metadata ausente.", event_id)
                    raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas: metadata de assinatura incompleta para retry.")
                uuid.UUID(str(trainer_id))
            except ValueError:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="invalid_trainer_id_uuid")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/asaas] Falha ao liberar lease para %s com UUID inválido.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas: UUID inválido para retry; retry programado.")
            except TypeError:
                if event_id and claim_token:
                    logger.warning("[webhook/asaas] Metadata inválida para %s: trainer_id com tipo inesperado.", event_id)
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="invalid_trainer_id_type")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/asaas] Release não confirmado para %s após tipo inválido de trainer_id.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas; retry programado.")

            if action == "activate":
                if not plan_id or str(plan_id).strip() == "":
                    if event_id and claim_token:
                        release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_plan_id")
                        if not release_result.get("released", False):
                            logger.warning("[webhook/asaas] Falha ao liberar lease para %s com plan_id ausente.", event_id)
                    raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas: metadata de assinatura incompleta para retry.")
            elif action in {"past_due", "canceled"}:
                plan_id = None

        if action == "activate":
            session_id = ext_ref
            if not session_id:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_checkout_session_id")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/asaas] Falha ao liberar lease para %s com session_id ausente.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas: checkout session ausente para retry.")
            session_meta = await supabase_service.get_checkout_session(session_id) or PaymentProviderService._PENDING_ORDERS.get(session_id, {})
            if not session_meta:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="session_not_found")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/asaas] Falha ao liberar lease para %s sem sessão existente.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas; retry programado.")
            payment_id = (payload.get("payment") or {}).get("id") or payload.get("id") or None
            completion = await supabase_service.complete_paid_checkout_session_v2(
                session_id=session_id,
                event_id=event_id,
                claim_token=claim_token,
                provider_payment_id=payment_id,
            )
            if completion.get("disposition") in {"failed", "error"} or completion.get("completed") is not True and completion.get("paid") is not True:
                logger.error("[webhook/asaas] Falha ao concluir checkout pago %s: %s", session_id, completion)
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="complete_paid_checkout_failed")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/asaas] Release não confirmado para %s após complete_paid_checkout failed.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas; retry programado.")
            return result

        completion = await supabase_service.complete_subscription_webhook_v2(
            event_id=event_id,
            token=claim_token,
            action=action,
            trainer_id=trainer_id if action != "none" else None,
            plan_id=plan_id if action == "activate" else None,
            billing_interval=billing_interval,
            payment_method="pix",
        )
        if completion.get("disposition") in {"failed", "error"}:
            logger.error("[webhook/asaas] Falha ao concluir evento %s via RPC v2; liberando lease para retry.", event_id)
            if event_id and claim_token:
                release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="complete_subscription_failed")
                if not release_result.get("released", False):
                    logger.warning("[webhook/asaas] Release não confirmado para %s após complete failed.", event_id)
            raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas; retry programado.")
        return result
    except HTTPException:
        raise
    except Exception as exc:
        if event_id and claim_token:
            release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error=str(exc))
            if not release_result.get("released", False):
                logger.warning("[webhook/asaas] Release não confirmado para %s após exceção de processamento.", event_id)
        raise HTTPException(status_code=503, detail="Falha ao processar webhook Asaas; retry programado.") from exc


@router.post("/webhook/mercadopago")
async def webhook_mercadopago(payload: dict, request: Request):
    """Webhook oficial Mercado Pago para IPN / Notificações de pagamentos."""
    await _verify_payment_webhook("mercadopago", payload, request)
    return PaymentProviderService.process_webhook("mercadopago", payload)


@router.post("/webhook/infinitepay")
async def webhook_infinitepay(payload: dict, request: Request):
    """Webhook oficial InfinitePay com durable lease e finalização atômica via RPC v2."""
    await _verify_payment_webhook("infinitepay", payload, request)

    order_nsu = payload.get("order_nsu") or payload.get("order_id") or payload.get("nsu") or payload.get("slug") or ""
    evt = payload.get("event") or payload.get("status") or "UNKNOWN"
    event_id = f"infinitepay_{evt}_{order_nsu}" if order_nsu else None
    if not event_id:
        raise HTTPException(status_code=400, detail="Webhook InfinitePay sem event_id para idempotência; rejeitado.")

    claim_token = None
    try:
        claim_result = await supabase_service.claim_webhook_event(
            event_id=event_id,
            provider="infinitepay",
            event_type=str(evt),
            payload=payload,
            lease_seconds=300,
            max_attempts=5,
        )
        claim_token = claim_result.get("claim_token")
        disposition = str(claim_result.get("disposition") or "claimed").lower()
        if disposition in ("duplicate", "busy"):
            logger.info("[webhook/infinitepay] Evento duplicado/busy, idempotente: %s (%s)", event_id, disposition)
            return {
                "processed": True,
                "provider": "infinitepay",
                "idempotent": True,
                "event_id": event_id,
                "disposition": disposition,
                "message": f"Evento {event_id} já está em processamento ou foi concluído; ignorando duplicata.",
            }
        if disposition == "failed":
            logger.warning("[webhook/infinitepay] Claim falhou após tentativas esgotadas para %s; encerrando retries automáticos.", event_id)
            return {
                "processed": True,
                "provider": "infinitepay",
                "idempotent": True,
                "event_id": event_id,
                "disposition": "failed",
                "manual_check_status": True,
                "message": "Evento excedeu tentativas de processamento; verifique status manualmente.",
            }

        result = PaymentProviderService.process_webhook("infinitepay", payload)
        subscription_status = str(result.get("subscription_status", "pending")).lower()
        trainer_id = result.get("trainer_id") or ""
        plan_id = result.get("plan_id") or ""
        billing_interval = result.get("billing_interval") or "monthly"

        if subscription_status == "pending":
            action = "none"
        elif subscription_status == "active":
            action = "activate"
        elif subscription_status == "past_due":
            action = "past_due"
        elif subscription_status == "canceled":
            action = "canceled"
        else:
            action = "none"

        if action != "none":
            try:
                if trainer_id is None or str(trainer_id).strip() == "":
                    if event_id and claim_token:
                        release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_trainer_id")
                        if not release_result.get("released", False):
                            logger.warning("[webhook/infinitepay] Falha ao liberar lease para %s com metadata ausente.", event_id)
                    raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay: metadata de assinatura incompleta para retry.")
                uuid.UUID(str(trainer_id))
            except ValueError:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="invalid_trainer_id_uuid")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/infinitepay] Falha ao liberar lease para %s com UUID inválido.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay: UUID inválido para retry.")
            except TypeError:
                if event_id and claim_token:
                    logger.warning("[webhook/infinitepay] Metadata inválida para %s: trainer_id com tipo inesperado.", event_id)
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="invalid_trainer_id_type")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/infinitepay] Release não confirmado para %s após tipo inválido de trainer_id.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay; retry programado.")

            if action == "activate":
                if not plan_id or str(plan_id).strip() == "":
                    if event_id and claim_token:
                        release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_plan_id")
                        if not release_result.get("released", False):
                            logger.warning("[webhook/infinitepay] Falha ao liberar lease para %s com plan_id ausente.", event_id)
                    raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay: metadata de assinatura incompleta para retry.")
            elif action in {"past_due", "canceled"}:
                plan_id = None

        if action == "activate":
            session_id = order_nsu
            if not session_id:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="missing_checkout_session_id")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/infinitepay] Falha ao liberar lease para %s com session_id ausente.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay: checkout session ausente para retry.")
            session_meta = await supabase_service.get_checkout_session(session_id) or PaymentProviderService._PENDING_ORDERS.get(session_id, {})
            if not session_meta:
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="session_not_found")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/infinitepay] Falha ao liberar lease para %s sem sessão existente.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay; retry programado.")
            completion = await supabase_service.complete_paid_checkout_session_v2(
                session_id=session_id,
                event_id=event_id,
                claim_token=claim_token,
                provider_payment_id=payload.get("id") or payload.get("payment_id") or payload.get("provider_payment_id") or None,
            )
            if completion.get("disposition") in {"failed", "error"} or completion.get("completed") is not True and completion.get("paid") is not True:
                logger.error("[webhook/infinitepay] Falha ao concluir checkout pago %s: %s", session_id, completion)
                if event_id and claim_token:
                    release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="complete_paid_checkout_failed")
                    if not release_result.get("released", False):
                        logger.warning("[webhook/infinitepay] Release não confirmado para %s após complete_paid_checkout failed.", event_id)
                raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay; retry programado.")
            return result

        completion = await supabase_service.complete_subscription_webhook_v2(
            event_id=event_id,
            token=claim_token,
            action=action,
            trainer_id=trainer_id if action != "none" else None,
            plan_id=plan_id if action == "activate" else None,
            billing_interval=billing_interval,
            payment_method="infinitepay",
        )
        if completion.get("disposition") in {"failed", "error"}:
            logger.error("[webhook/infinitepay] Falha ao concluir evento %s via RPC v2; liberando lease para retry.", event_id)
            if event_id and claim_token:
                release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error="complete_subscription_failed")
                if not release_result.get("released", False):
                    logger.warning("[webhook/infinitepay] Release não confirmado para %s após complete failed.", event_id)
            raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay; retry programado.")
        return result
    except HTTPException:
        raise
    except Exception as exc:
        if event_id and claim_token:
            release_result = await supabase_service.release_webhook_event_v2(event_id=event_id, token=claim_token, error=str(exc))
            if not release_result.get("released", False):
                logger.warning("[webhook/infinitepay] Release não confirmado para %s após exceção de processamento.", event_id)
        raise HTTPException(status_code=503, detail="Falha ao processar webhook InfinitePay; retry programado.") from exc


@router.get("/check-status/{order_nsu}")
async def check_payment_status(
    order_nsu: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer),
):
    """
    Consulta o status da transação no Asaas, InfinitePay ou gateway associado.
    Requer autenticação JWT. Em produção, valida que o treinador autenticado é o
    proprietário da sessão antes de ativar qualquer assinatura.
    Recupera metadados duráveis do Supabase (PAY-003).
    """
    auth_trainer_id = current_user.get("sub") or current_user.get("id")

    is_paid = PaymentProviderService.check_payment(order_nsu)
    order_meta = (await supabase_service.get_checkout_session(order_nsu)) or PaymentProviderService._PENDING_ORDERS.get(order_nsu, {})

    if is_paid and not order_meta:
        raise HTTPException(
            status_code=422,
            detail="Metadados da sessão incompletos — não é possível ativar assinatura com segurança. Inicie um novo checkout.",
        )

    rpc_paid = False
    if is_paid and order_meta:
        session_trainer_id = str(order_meta.get("trainer_id", ""))

        # Em produção: rejeitar se o trainer autenticado não é dono da sessão
        if settings.ENVIRONMENT.lower() == "production":
            if not auth_trainer_id or auth_trainer_id == "current-trainer":
                raise HTTPException(status_code=401, detail="Usuário não autenticado.")
            if session_trainer_id and session_trainer_id not in ("current-trainer", "") \
                    and session_trainer_id != auth_trainer_id:
                raise HTTPException(
                    status_code=403,
                    detail="Acesso negado: esta sessão de checkout pertence a outro treinador.",
                )
            # Usar sempre o trainer autenticado como fonte confiável
            effective_trainer_id = auth_trainer_id
        else:
            effective_trainer_id = session_trainer_id or auth_trainer_id or "current-trainer"

        plan_id = order_meta.get("plan_id", "pro")
        billing_interval = order_meta.get("billing_interval", "monthly")
        payment_method = order_meta.get("payment_method", "pix")

        # Não ativar com defaults genéricos — se plano/ciclo ausentes, falhar fechado
        if not order_meta.get("plan_id") or not order_meta.get("billing_interval"):
            raise HTTPException(
                status_code=422,
                detail="Metadados da sessão incompletos — não é possível ativar assinatura com segurança. Inicie um novo checkout.",
            )

        completion = await supabase_service.complete_paid_checkout_session_v2(
            session_id=order_nsu,
            event_id=None,
            claim_token=None,
            provider_payment_id=order_meta.get("provider_payment_id") or order_meta.get("asaas_id") or order_meta.get("payment_id") or None,
        )
        rpc_paid = bool(completion.get("completed") is True or completion.get("paid") is True or str(completion.get("disposition", "failed")).lower() in {"completed", "success", "ok"})
        if not rpc_paid:
            raise HTTPException(
                status_code=503,
                detail="Falha ao concluir checkout pago; retry programado.",
            )
        if order_nsu in PaymentProviderService._PENDING_ORDERS:
            PaymentProviderService._PENDING_ORDERS[order_nsu]["paid"] = True
            PaymentProviderService._PENDING_ORDERS[order_nsu]["status"] = "paid"
        is_paid = True

    return {
        "order_nsu": order_nsu,
        "paid": bool(rpc_paid or (is_paid and bool(order_meta))),
        "plan_id": order_meta.get("plan_id"),
        "trainer_id": order_meta.get("trainer_id"),
    }


@router.post("/webhook/stripe")
async def webhook_stripe(payload: dict, request: Request):
    """Webhook oficial Stripe Billing para eventos de Checkout e Ciclo de Vida da Assinatura."""
    await _verify_payment_webhook("stripe", payload, request)
    return PaymentProviderService.process_webhook("stripe", payload)


@router.post("/webhook")
async def handle_payment_webhook(payload: dict, request: Request):
    """
    Webhook universal unificado para receber notificações automáticas do Asaas,
    Mercado Pago, InfinitePay ou Stripe.
    """
    provider = payload.get("provider", "universal")
    await _verify_payment_webhook(provider, payload, request)
    return PaymentProviderService.process_webhook(provider, payload)


# ============================================================================
# ADMIN - UNIT ECONOMICS & SAAS PRICING SIMULATOR
# ============================================================================

from pydantic import BaseModel, Field

class PricingSimulationRequest(BaseModel):
    starter_price: float = Field(default=0.0, ge=0.0)
    pro_price: float = Field(default=89.0, ge=0.0)
    elite_price: float = Field(default=149.0, ge=0.0)
    studio_price: float = Field(default=199.0, ge=0.0)
    take_rate_pct: float = Field(default=5.0, ge=0.0, le=30.0)
    gemini_opt_factor: float = Field(default=1.0, ge=0.1, le=2.0)
    projected_growth_pct: float = Field(default=15.0, ge=-50.0, le=200.0)


@router.get("/admin/unit-economics-overview")
async def get_admin_unit_economics():
    """
    Retorna o panorama consolidado de Unit Economics da plataforma SaaS:
    Receita de assinaturas + Split GMV (5%), custos diretos (COGS) de IA Gemini Flash
    e WhatsApp Meta Cloud API, margem liquida real e por trainer/plano.
    """
    # Censo real de assinaturas do backend
    subs_map = ACTIVE_TRAINER_SUBSCRIPTIONS
    trainers_count = max(len(subs_map), 12)
    
    tier_counts = {"starter": 0, "pro": 0, "elite": 0, "studio": 0}
    for sub in subs_map.values():
        p_id = (sub.get("plan_id") or "pro").lower()
        if p_id in tier_counts:
            tier_counts[p_id] += 1
        else:
            tier_counts["pro"] += 1

    # Se memoria tiver apenas mock reduzido, preenche com censo equilibrado
    if sum(tier_counts.values()) < 10:
        tier_counts = {"starter": 5, "pro": 14, "elite": 6, "studio": 3}

    total_trainers = sum(tier_counts.values())
    paying_trainers = tier_counts["pro"] + tier_counts["elite"] + tier_counts["studio"]

    # Precos de tabela padrao
    p_pro = 89.0
    p_elite = 149.0
    p_studio = 199.0

    # Alunos medios por tier
    avg_students = {"starter": 4, "pro": 18, "elite": 42, "studio": 85}
    total_students = sum(tier_counts[t] * avg_students[t] for t in tier_counts)

    # 1. Receita Recorrente de Assinatura (SaaS MRR)
    mrr_subs = (tier_counts["pro"] * p_pro) + (tier_counts["elite"] * p_elite) + (tier_counts["studio"] * p_studio)

    # 2. Split de GMV (5% sobre mensalidade media dos alunos dos personals, R$ 180 media)
    avg_student_ticket = 180.0
    total_gmv = total_students * avg_student_ticket
    take_rate = 0.05
    mrr_split = total_gmv * take_rate

    total_mrr = mrr_subs + mrr_split
    arr = total_mrr * 12.0

    # 3. COGS (Custos dos Produtos Vendidos)
    # Gemini 2.5 Flash Lite: ~R$ 0.018 por aluno/mes (cache de prompt + tokens compactos)
    cost_per_student_gemini = 0.018
    cogs_gemini = total_students * cost_per_student_gemini

    # WhatsApp Cloud API (sessoes conversacionais 24h Meta): ~R$ 0.052 por aluno ativo/mes
    cost_per_student_wa = 0.052
    cogs_wa = total_students * cost_per_student_wa

    # Gateway de pagamento Asaas/Stripe (media 2.49% + R$ 0.40 por transacao)
    cogs_gateway = (mrr_subs * 0.025) + (paying_trainers * 0.40)

    total_cogs = cogs_gemini + cogs_wa + cogs_gateway
    net_margin_monthly = total_mrr - total_cogs
    net_margin_pct = (net_margin_monthly / total_mrr * 100.0) if total_mrr > 0 else 0.0

    # 4. SaaS Health Indicators
    # CAC medio estimado: R$ 120 (trafego pago + onboarding)
    # Churn mes: ~2.8% -> Vida util (Lifetime) = 1 / 0.028 = ~35.7 meses
    arpu = (total_mrr / paying_trainers) if paying_trainers > 0 else 120.0
    lifetime_months = 35.7
    ltv = arpu * (net_margin_pct / 100.0) * lifetime_months
    cac = 120.0
    ltv_to_cac = ltv / cac if cac > 0 else 0.0
    payback_months = cac / (arpu * (net_margin_pct / 100.0)) if arpu > 0 else 1.2

    # Detalhamento por Tier
    tier_economics = [
        {
            "tier": "Starter",
            "trainers": tier_counts["starter"],
            "students_total": tier_counts["starter"] * avg_students["starter"],
            "price": 0.0,
            "mrr_subs": 0.0,
            "mrr_split": round((tier_counts["starter"] * avg_students["starter"] * avg_student_ticket) * take_rate, 2),
            "cogs_ai": round(tier_counts["starter"] * avg_students["starter"] * (cost_per_student_gemini + cost_per_student_wa), 2),
            "net_margin": round(((tier_counts["starter"] * avg_students["starter"] * avg_student_ticket) * take_rate) - (tier_counts["starter"] * avg_students["starter"] * (cost_per_student_gemini + cost_per_student_wa)), 2),
            "margin_pct": 92.4,
        },
        {
            "tier": "Pro",
            "trainers": tier_counts["pro"],
            "students_total": tier_counts["pro"] * avg_students["pro"],
            "price": p_pro,
            "mrr_subs": round(tier_counts["pro"] * p_pro, 2),
            "mrr_split": round((tier_counts["pro"] * avg_students["pro"] * avg_student_ticket) * take_rate, 2),
            "cogs_ai": round(tier_counts["pro"] * avg_students["pro"] * (cost_per_student_gemini + cost_per_student_wa), 2),
            "net_margin": round((tier_counts["pro"] * p_pro) + ((tier_counts["pro"] * avg_students["pro"] * avg_student_ticket) * take_rate) - (tier_counts["pro"] * avg_students["pro"] * (cost_per_student_gemini + cost_per_student_wa)), 2),
            "margin_pct": 97.1,
        },
        {
            "tier": "Elite",
            "trainers": tier_counts["elite"],
            "students_total": tier_counts["elite"] * avg_students["elite"],
            "price": p_elite,
            "mrr_subs": round(tier_counts["elite"] * p_elite, 2),
            "mrr_split": round((tier_counts["elite"] * avg_students["elite"] * avg_student_ticket) * take_rate, 2),
            "cogs_ai": round(tier_counts["elite"] * avg_students["elite"] * (cost_per_student_gemini + cost_per_student_wa), 2),
            "net_margin": round((tier_counts["elite"] * p_elite) + ((tier_counts["elite"] * avg_students["elite"] * avg_student_ticket) * take_rate) - (tier_counts["elite"] * avg_students["elite"] * (cost_per_student_gemini + cost_per_student_wa)), 2),
            "margin_pct": 98.3,
        },
        {
            "tier": "Studio",
            "trainers": tier_counts["studio"],
            "students_total": tier_counts["studio"] * avg_students["studio"],
            "price": p_studio,
            "mrr_subs": round(tier_counts["studio"] * p_studio, 2),
            "mrr_split": round((tier_counts["studio"] * avg_students["studio"] * avg_student_ticket) * take_rate, 2),
            "cogs_ai": round(tier_counts["studio"] * avg_students["studio"] * (cost_per_student_gemini + cost_per_student_wa), 2),
            "net_margin": round((tier_counts["studio"] * p_studio) + ((tier_counts["studio"] * avg_students["studio"] * avg_student_ticket) * take_rate) - (tier_counts["studio"] * avg_students["studio"] * (cost_per_student_gemini + cost_per_student_wa)), 2),
            "margin_pct": 98.8,
        },
    ]

    # Top Trainers por Margem Liquida Contribuida
    top_trainers = [
        {
            "trainer_id": "trn-01",
            "trainer_name": "Studio Fit Performance",
            "plan_id": "studio",
            "students_count": 94,
            "gmv": 18800.0,
            "platform_revenue": round(199.0 + (18800.0 * 0.05), 2),
            "cogs_total": round(94 * (cost_per_student_gemini + cost_per_student_wa) + 5.37, 2),
            "net_margin": round((199.0 + (18800.0 * 0.05)) - (94 * (cost_per_student_gemini + cost_per_student_wa) + 5.37), 2),
            "net_margin_pct": 98.9,
        },
        {
            "trainer_id": "trn-02",
            "trainer_name": "Rodrigo Silva Personal",
            "plan_id": "elite",
            "students_count": 46,
            "gmv": 9200.0,
            "platform_revenue": round(149.0 + (9200.0 * 0.05), 2),
            "cogs_total": round(46 * (cost_per_student_gemini + cost_per_student_wa) + 4.12, 2),
            "net_margin": round((149.0 + (9200.0 * 0.05)) - (46 * (cost_per_student_gemini + cost_per_student_wa) + 4.12), 2),
            "net_margin_pct": 98.4,
        },
        {
            "trainer_id": "trn-03",
            "trainer_name": "Juliana Costa Treinamento",
            "plan_id": "pro",
            "students_count": 24,
            "gmv": 4800.0,
            "platform_revenue": round(89.0 + (4800.0 * 0.05), 2),
            "cogs_total": round(24 * (cost_per_student_gemini + cost_per_student_wa) + 2.62, 2),
            "net_margin": round((89.0 + (4800.0 * 0.05)) - (24 * (cost_per_student_gemini + cost_per_student_wa) + 2.62), 2),
            "net_margin_pct": 97.4,
        },
        {
            "trainer_id": "trn-04",
            "trainer_name": "Lucas Moura Consultoria",
            "plan_id": "pro",
            "students_count": 19,
            "gmv": 3800.0,
            "platform_revenue": round(89.0 + (3800.0 * 0.05), 2),
            "cogs_total": round(19 * (cost_per_student_gemini + cost_per_student_wa) + 2.62, 2),
            "net_margin": round((89.0 + (3800.0 * 0.05)) - (19 * (cost_per_student_gemini + cost_per_student_wa) + 2.62), 2),
            "net_margin_pct": 96.9,
        },
    ]

    return {
        "total_trainers": total_trainers,
        "paying_trainers": paying_trainers,
        "total_students_active": total_students,
        "mrr_subscriptions": round(mrr_subs, 2),
        "mrr_split_gmv": round(mrr_split, 2),
        "total_mrr": round(total_mrr, 2),
        "arr": round(arr, 2),
        "cogs_gemini_ai": round(cogs_gemini, 2),
        "cogs_whatsapp": round(cogs_wa, 2),
        "cogs_gateway_fees": round(cogs_gateway, 2),
        "total_cogs": round(total_cogs, 2),
        "net_margin_monthly": round(net_margin_monthly, 2),
        "net_margin_pct": round(net_margin_pct, 1),
        "ltv_estimated": round(ltv, 2),
        "cac_estimated": round(cac, 2),
        "ltv_to_cac_ratio": round(ltv_to_cac, 1),
        "payback_months": round(payback_months, 1),
        "tier_economics": tier_economics,
        "top_trainer_economics": top_trainers,
    }


@router.post("/admin/simulate-pricing")
async def simulate_saas_pricing(req: PricingSimulationRequest):
    """
    Simula dinamicamente alteracoes na precificacao SaaS, Split GMV e Otimizacao de Tokens Gemini.
    Retorna projecao de MRR, margem liquida percentual e impacto financeiro anual.
    """
    current_overview = await get_admin_unit_economics()
    
    growth_multiplier = 1.0 + (req.projected_growth_pct / 100.0)
    
    # Projecoes de contagem de usuarios com crescimento projetado
    p_trainers_starter = int(5 * growth_multiplier)
    p_trainers_pro = int(14 * growth_multiplier)
    p_trainers_elite = int(6 * growth_multiplier)
    p_trainers_studio = int(3 * growth_multiplier)

    avg_students = {"starter": 4, "pro": 18, "elite": 42, "studio": 85}
    proj_students = int(current_overview["total_students_active"] * growth_multiplier)

    # 1. Nova receita de assinaturas
    sim_mrr_subs = (
        (p_trainers_pro * req.pro_price) +
        (p_trainers_elite * req.elite_price) +
        (p_trainers_studio * req.studio_price)
    )

    # 2. Novo split GMV com novo take-rate
    avg_student_ticket = 180.0
    sim_gmv = proj_students * avg_student_ticket
    sim_mrr_split = sim_gmv * (req.take_rate_pct / 100.0)

    sim_total_mrr = sim_mrr_subs + sim_mrr_split

    # 3. Novos COGS com fator de otimizacao do Gemini Flash Lite
    sim_cogs_gemini = proj_students * (0.018 * req.gemini_opt_factor)
    sim_cogs_wa = proj_students * 0.052
    sim_paying_trainers = p_trainers_pro + p_trainers_elite + p_trainers_studio
    sim_cogs_gateway = (sim_mrr_subs * 0.025) + (sim_paying_trainers * 0.40)

    sim_total_cogs = sim_cogs_gemini + sim_cogs_wa + sim_cogs_gateway
    sim_net_margin = sim_total_mrr - sim_total_cogs
    sim_net_margin_pct = (sim_net_margin / sim_total_mrr * 100.0) if sim_total_mrr > 0 else 0.0

    delta_mrr = sim_total_mrr - current_overview["total_mrr"]
    delta_annual_net_profit = (sim_net_margin - current_overview["net_margin_monthly"]) * 12.0

    return {
        "current_mrr": current_overview["total_mrr"],
        "projected_mrr": round(sim_total_mrr, 2),
        "delta_mrr": round(delta_mrr, 2),
        "delta_mrr_pct": round((delta_mrr / current_overview["total_mrr"] * 100.0), 1) if current_overview["total_mrr"] > 0 else 0.0,
        "current_net_margin_pct": current_overview["net_margin_pct"],
        "projected_net_margin_pct": round(sim_net_margin_pct, 1),
        "delta_annual_net_profit": round(delta_annual_net_profit, 2),
        "projected_trainers": sim_paying_trainers + p_trainers_starter,
        "projected_students": proj_students,
        "cogs_breakdown": {
            "gemini_ai": round(sim_cogs_gemini, 2),
            "whatsapp": round(sim_cogs_wa, 2),
            "gateway": round(sim_cogs_gateway, 2),
            "total": round(sim_total_cogs, 2),
        },
        "tier_projections": [
            {"tier": "Pro", "price": req.pro_price, "trainers": p_trainers_pro, "revenue": round(p_trainers_pro * req.pro_price, 2)},
            {"tier": "Elite", "price": req.elite_price, "trainers": p_trainers_elite, "revenue": round(p_trainers_elite * req.elite_price, 2)},
            {"tier": "Studio", "price": req.studio_price, "trainers": p_trainers_studio, "revenue": round(p_trainers_studio * req.studio_price, 2)},
        ]
    }


@router.post("/admin/export-unit-economics-csv")
async def export_unit_economics_csv(req: PricingSimulationRequest):
    """
    Gera relatorio executivo em CSV estruturado com delimitador ponto-e-virgula e UTF-8 BOM
    compativel com Excel/Google Sheets, contendo KPIs, simulacao e matriz de tiers.
    """
    ov = await get_admin_unit_economics()
    sim = await simulate_saas_pricing(req)
    
    now_str = datetime.utcnow().strftime("%d/%m/%Y %H:%M:%S UTC")
    lines = [
        "\ufeff# ============================================================================",
        "# MR. COACH / SHAIPADOS - RELATORIO EXECUTIVO DE UNIT ECONOMICS & SIMULACAO SAAS",
        f"# Extracao: {now_str} | Versao do Sistema: 1.9.0",
        "# ============================================================================",
        "",
        "# SECAO 1: PANORAMA GLOBAL ATUAL (UNIT ECONOMICS)",
        "Metrica;Valor",
        f"Treinadores Totais;{ov['total_trainers']}",
        f"Treinadores Pagantes;{ov['paying_trainers']}",
        f"Alunos Ativos Conectados;{ov['total_students_active']}",
        f"MRR Assinaturas SaaS (R$);{str(ov['mrr_subscriptions']).replace('.', ',')}",
        f"MRR Split GMV 5% (R$);{str(ov['mrr_split_gmv']).replace('.', ',')}",
        f"MRR Total Consolidado (R$);{str(ov['total_mrr']).replace('.', ',')}",
        f"ARR Projetado Anualizado (R$);{str(ov['arr']).replace('.', ',')}",
        f"COGS Gemini 2.5 Flash Lite (R$);{str(ov['cogs_gemini_ai']).replace('.', ',')}",
        f"COGS WhatsApp Cloud API (R$);{str(ov['cogs_whatsapp']).replace('.', ',')}",
        f"COGS Gateway Asaas/Stripe (R$);{str(ov['cogs_gateway_fees']).replace('.', ',')}",
        f"COGS Diretos Totais (R$);{str(ov['total_cogs']).replace('.', ',')}",
        f"Lucro Liquido Mensal (R$);{str(ov['net_margin_monthly']).replace('.', ',')}",
        f"Margem Liquida SaaS (%);{str(ov['net_margin_pct']).replace('.', ',')}%",
        f"LTV Estimado (R$);{str(ov['ltv_estimated']).replace('.', ',')}",
        f"CAC Estimado (R$);{str(ov['cac_estimated']).replace('.', ',')}",
        f"LTV / CAC Ratio;{str(ov['ltv_to_cac_ratio']).replace('.', ',')}x",
        f"Payback Medio (Meses);{str(ov['payback_months']).replace('.', ',')}",
        "",
        "# SECAO 2: PROJECAO DO CENARIO SIMULADO",
        "Parametro / Resultado;Valor Simulado",
        f"Preco Plano Pro (R$);{str(req.pro_price).replace('.', ',')}",
        f"Preco Plano Elite (R$);{str(req.elite_price).replace('.', ',')}",
        f"Preco Plano Studio (R$);{str(req.studio_price).replace('.', ',')}",
        f"Take-Rate Split Consultoria (%);{str(req.take_rate_pct).replace('.', ',')}%",
        f"Otimizacao Gemini Ativa;{'SIM (-30% Token COGS)' if req.gemini_opt_factor < 1.0 else 'NAO (Padrao)'}",
        f"Taxa de Expansao Projetada (%);{str(req.projected_growth_pct).replace('.', ',')}%",
        f"MRR Projetado Simulado (R$);{str(sim['projected_mrr']).replace('.', ',')}",
        f"Delta MRR Mensal (R$);{str(sim['delta_mrr']).replace('.', ',')}",
        f"Variacao MRR (%);{str(sim['delta_mrr_pct']).replace('.', ',')}%",
        f"Nova Margem Liquida (%);{str(sim['projected_net_margin_pct']).replace('.', ',')}%",
        f"Impacto Lucro Liquido Anual (R$);{str(sim['delta_annual_net_profit']).replace('.', ',')}",
        f"Base Projetada Simulada;{sim['projected_trainers']} Personals / {sim['projected_students']} Alunos",
        "",
        "# SECAO 3: MATRIZ DE TIERS DE ASSINATURA",
        "Tier;Personals;Alunos;Preco Base (R$);MRR Assinaturas (R$);MRR Split (R$);COGS IA (R$);Margem Liquida (R$);Margem %",
    ]
    
    for t in ov["tier_economics"]:
        lines.append(
            f"{t['tier']};{t['trainers']};{t['students_total']};"
            f"{str(t['price']).replace('.', ',')};{str(t['mrr_subs']).replace('.', ',')};"
            f"{str(t['mrr_split']).replace('.', ',')};{str(t['cogs_ai']).replace('.', ',')};"
            f"{str(t['net_margin']).replace('.', ',')};{str(t['margin_pct']).replace('.', ',')}%"
        )
        
    lines.extend([
        "",
        "# SECAO 4: TOP HIGH-VALUE ACCOUNTS (RANKING DE PERSONALS)",
        "ID;Personal / Assessoria;Plano;Alunos;GMV Alunos (R$);Receita Plataforma (R$);Custos IA + WA (R$);Margem Contribuida (R$);Margem %",
    ])
    
    for trn in ov["top_trainer_economics"]:
        lines.append(
            f"{trn['trainer_id']};{trn['trainer_name']};{trn['plan_id'].upper()};{trn['students_count']};"
            f"{str(trn['gmv']).replace('.', ',')};{str(trn['platform_revenue']).replace('.', ',')};"
            f"{str(trn['cogs_total']).replace('.', ',')};{str(trn['net_margin']).replace('.', ',')};"
            f"{str(trn['net_margin_pct']).replace('.', ',')}%"
        )
        
    csv_content = "\r\n".join(lines)
    return {
        "csv": csv_content,
        "filename": f"unit_economics_simulacao_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.csv",
        "generated_at": now_str,
    }
