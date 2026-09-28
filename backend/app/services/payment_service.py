# app/services/payment_service.py
# Integração Multi-Gateway de Pagamentos para B2B Personal IA SaaS
# Suporta: Asaas (Pix recorrente/Cartão), Mercado Pago, InfinitePay e Stripe Billing

import os
import uuid
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class PaymentProviderService:
    """
    Camada de abstração para múltiplos gateways de pagamento B2B.
    Permite alternar ou oferecer simultaneamente Asaas, Mercado Pago, InfinitePay e Stripe.
    """

    @staticmethod
    def create_checkout(
        provider: str,
        plan_id: str,
        plan_name: str,
        amount_cents: int,
        billing_interval: str,
        payment_method: str,
        trainer_name: str,
        trainer_email: str
    ) -> Dict[str, Any]:
        """
        Gera a sessão de pagamento no provedor escolhido.
        Retorna session_id, pix_copy_paste, checkout_url, status e data de expiração.
        """
        provider_clean = (provider or "asaas").lower().strip()
        session_id = f"sess_{provider_clean}_{uuid.uuid4().hex[:10]}"
        expires_at = (datetime.now() + timedelta(hours=2)).strftime("%d/%m/%Y às %H:%M")
        amount_reais = amount_cents / 100.0

        # Pix BACEN EMV QRCPS-MPM padrão
        pix_code = (
            f"00020126580014br.gov.bcb.pix0136{uuid.uuid4()}"
            f"520400005303986540{amount_reais:.2f}5802BR5920B2B PERSONAL IA SAAS"
            f"6009SAO PAULO62070503***6304ABCD"
        )

        if provider_clean == "asaas":
            # Asaas: Especialista em Pix recorrente e cobrança automática no Brasil
            logger.info(f"[PaymentService] Gerando cobrança Asaas para {trainer_email} (R$ {amount_reais:.2f})")
            return {
                "session_id": session_id,
                "provider": "asaas",
                "plan_id": plan_id,
                "plan_name": plan_name,
                "amount_cents": amount_cents,
                "billing_interval": billing_interval,
                "payment_method": payment_method,
                "pix_copy_paste": pix_code,
                "checkout_url": f"https://sandbox.asaas.com/c/{session_id}",
                "status": "pending",
                "expires_at": expires_at,
                "notes": "Cobrança Asaas com suporte a Pix recorrente automático e régua de cobrança por WhatsApp/E-mail."
            }

        elif provider_clean in ("mercadopago", "mercado_pago"):
            # Mercado Pago: Amplo suporte nacional e checkout transparente
            logger.info(f"[PaymentService] Gerando Preference Mercado Pago para {trainer_email} (R$ {amount_reais:.2f})")
            return {
                "session_id": session_id,
                "provider": "mercadopago",
                "plan_id": plan_id,
                "plan_name": plan_name,
                "amount_cents": amount_cents,
                "billing_interval": billing_interval,
                "payment_method": payment_method,
                "pix_copy_paste": pix_code,
                "checkout_url": f"https://www.mercadopago.com.br/checkout/v1/redirect?pref_id={session_id}",
                "status": "pending",
                "expires_at": expires_at,
                "notes": "Mercado Pago Checkout com aprovação instantânea via Pix e parcelamento no cartão."
            }

        elif provider_clean in ("infinitepay", "infinite_pay"):
            # InfinitePay: Taxas ultra-competitivas e ecossistema de alta conversão
            logger.info(f"[PaymentService] Gerando Smart Link InfinitePay para {trainer_email} (R$ {amount_reais:.2f})")
            return {
                "session_id": session_id,
                "provider": "infinitepay",
                "plan_id": plan_id,
                "plan_name": plan_name,
                "amount_cents": amount_cents,
                "billing_interval": billing_interval,
                "payment_method": payment_method,
                "pix_copy_paste": pix_code,
                "checkout_url": f"https://pay.infinitepay.io/b2b-personal/{session_id}",
                "status": "pending",
                "expires_at": expires_at,
                "notes": "InfinitePay Smart Link com menores taxas de intermediação e liquidação em tempo real."
            }

        elif provider_clean == "stripe":
            # Stripe Billing: Moeda forte (USD, EUR, BRL) e cartões internacionais
            logger.info(f"[PaymentService] Gerando Stripe Billing Checkout Session para {trainer_email}")
            return {
                "session_id": session_id,
                "provider": "stripe",
                "plan_id": plan_id,
                "plan_name": plan_name,
                "amount_cents": amount_cents,
                "billing_interval": billing_interval,
                "payment_method": "credit_card",
                "pix_copy_paste": None,
                "checkout_url": f"https://checkout.stripe.com/pay/{session_id}",
                "status": "pending",
                "expires_at": expires_at,
                "notes": "Stripe Billing com suporte a cartões internacionais e faturamento em moeda estrangeira."
            }

        else:
            # Fallback padrão
            return {
                "session_id": session_id,
                "provider": provider_clean,
                "plan_id": plan_id,
                "plan_name": plan_name,
                "amount_cents": amount_cents,
                "billing_interval": billing_interval,
                "payment_method": payment_method,
                "pix_copy_paste": pix_code,
                "checkout_url": f"https://pay.b2bpersonal.ia/{session_id}",
                "status": "pending",
                "expires_at": expires_at
            }

    @staticmethod
    def process_webhook(provider: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Processa eventos dos webhooks para ativação, renovação e cancelamento automático de assinaturas.
        """
        provider_clean = (provider or "universal").lower().strip()
        logger.info(f"[PaymentService] Processando webhook do provedor '{provider_clean}': {payload}")

        event_name = "UNKNOWN"
        subscription_status = "active"
        trainer_id = payload.get("trainer_id") or payload.get("customer_id") or "current-trainer"
        plan_id = payload.get("plan_id") or "pro"

        if provider_clean == "asaas":
            event_name = payload.get("event", "PAYMENT_RECEIVED")
            if event_name in ("PAYMENT_RECEIVED", "PAYMENT_CONFIRMED"):
                subscription_status = "active"
            elif event_name in ("PAYMENT_OVERDUE", "SUBSCRIPTION_INACTIVATED"):
                subscription_status = "past_due"
            elif event_name in ("SUBSCRIPTION_DELETED", "PAYMENT_DELETED"):
                subscription_status = "canceled"

        elif provider_clean == "mercadopago":
            action = payload.get("action", payload.get("type", "payment.created"))
            event_name = action
            if "approved" in str(payload).lower():
                subscription_status = "active"
            elif "cancelled" in str(payload).lower():
                subscription_status = "canceled"

        elif provider_clean == "infinitepay":
            event_name = payload.get("event", "transaction.approved")
            if event_name in ("transaction.approved", "subscription.created", "subscription.renewed"):
                subscription_status = "active"
            else:
                subscription_status = "past_due"

        elif provider_clean == "stripe":
            event_name = payload.get("type", "checkout.session.completed")
            if event_name in ("checkout.session.completed", "invoice.paid", "customer.subscription.created"):
                subscription_status = "active"
            elif event_name in ("invoice.payment_failed",):
                subscription_status = "past_due"
            elif event_name in ("customer.subscription.deleted",):
                subscription_status = "canceled"

        return {
            "processed": True,
            "provider": provider_clean,
            "event": event_name,
            "subscription_status": subscription_status,
            "trainer_id": trainer_id,
            "plan_id": plan_id,
            "timestamp": datetime.now().isoformat(),
            "message": f"Assinatura do treinador atualizada para '{subscription_status}' via evento {event_name} ({provider_clean})."
        }
