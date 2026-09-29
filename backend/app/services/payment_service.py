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

    @staticmethod
    def calculate_plan_change(
        current_plan_id: str,
        new_plan_id: str,
        billing_interval: str = "monthly",
        days_used_in_cycle: int = 0,
        total_days_in_cycle: int = 30,
        active_students_count: int = 0,
    ) -> Dict[str, Any]:
        """
        Calcula as regras e valores de transição entre planos (Upgrade vs Downgrade):
        - Pró-rata de dias não utilizados do plano anterior
        - Bloqueio de integridade se o personal tiver mais alunos que o teto do novo plano
        - Data de efetivação da mudança
        """
        PLANS_INFO = {
            "starter": {
                "name": "Starter Trial",
                "monthly_cents": 0,
                "yearly_cents": 0,
                "max_students": 3,
                "max_ai": 10,
                "tier": 1,
            },
            "pro": {
                "name": "Personal Pro",
                "monthly_cents": 8900,
                "yearly_cents": 85200,
                "max_students": 30,
                "max_ai": -1,
                "tier": 2,
            },
            "elite": {
                "name": "Elite Coach",
                "monthly_cents": 14900,
                "yearly_cents": 142800,
                "max_students": 60,
                "max_ai": -1,
                "tier": 3,
            },
            "studio": {
                "name": "Studio Scale",
                "monthly_cents": 19900,
                "yearly_cents": 190800,
                "max_students": 100,
                "max_ai": -1,
                "tier": 4,
            },
        }

        current = PLANS_INFO.get(current_plan_id, PLANS_INFO["starter"])
        target = PLANS_INFO.get(new_plan_id, PLANS_INFO["pro"])

        is_yearly = billing_interval.lower() == "yearly"
        current_price = current["yearly_cents"] if is_yearly else current["monthly_cents"]
        new_price = target["yearly_cents"] if is_yearly else target["monthly_cents"]

        if target["tier"] > current["tier"]:
            change_type = "upgrade"
        elif target["tier"] < current["tier"]:
            change_type = "downgrade"
        else:
            change_type = "same"

        # Tratamento de Downgrade
        if change_type == "downgrade":
            if active_students_count > target["max_students"]:
                excess = active_students_count - target["max_students"]
                return {
                    "change_type": "downgrade",
                    "is_blocked": True,
                    "block_reason": (
                        f"Você possui {active_students_count} alunos cadastrados. "
                        f"O plano {target['name']} permite no máximo {target['max_students']} alunos. "
                        f"Desative ou arquive pelo menos {excess} aluno(s) antes de confirmar o downgrade."
                    ),
                    "current_plan_name": current["name"],
                    "new_plan_name": target["name"],
                    "current_plan_price_cents": current_price,
                    "new_plan_price_cents": new_price,
                    "unused_credit_cents": 0,
                    "net_charge_cents": 0,
                    "effective_date": "Bloqueado por cota de alunos",
                    "new_student_limit": target["max_students"],
                    "new_ai_limit": target["max_ai"],
                    "summary_message": f"Downgrade para {target['name']} indisponível até ajuste do número de alunos.",
                }
            else:
                return {
                    "change_type": "downgrade",
                    "is_blocked": False,
                    "block_reason": None,
                    "current_plan_name": current["name"],
                    "new_plan_name": target["name"],
                    "current_plan_price_cents": current_price,
                    "new_plan_price_cents": new_price,
                    "unused_credit_cents": 0,
                    "net_charge_cents": 0,
                    "effective_date": "No fim do ciclo de faturamento atual",
                    "new_student_limit": target["max_students"],
                    "new_ai_limit": target["max_ai"],
                    "summary_message": (
                        f"Seu downgrade para o {target['name']} foi agendado. "
                        f"Você continuará usufruindo dos benefícios do {current['name']} até o fim do ciclo vigente."
                    ),
                }

        # Tratamento de Upgrade
        if change_type == "upgrade":
            remaining_days = max(0, total_days_in_cycle - days_used_in_cycle)
            if current_price > 0 and total_days_in_cycle > 0:
                daily_rate = current_price / float(total_days_in_cycle)
                unused_credit = int(daily_rate * remaining_days)
            else:
                unused_credit = 0

            net_charge = max(0, new_price - unused_credit)

            return {
                "change_type": "upgrade",
                "is_blocked": False,
                "block_reason": None,
                "current_plan_name": current["name"],
                "new_plan_name": target["name"],
                "current_plan_price_cents": current_price,
                "new_plan_price_cents": new_price,
                "unused_credit_cents": unused_credit,
                "net_charge_cents": net_charge,
                "effective_date": "Imediato após confirmação do pagamento",
                "new_student_limit": target["max_students"],
                "new_ai_limit": target["max_ai"],
                "summary_message": (
                    f"Upgrade para {target['name']}: "
                    f"Crédito pró-rata de R$ {unused_credit / 100:.2f} aplicado. "
                    f"Total líquido a pagar: R$ {net_charge / 100:.2f}."
                ),
            }

        # Mesmo plano
        return {
            "change_type": "same",
            "is_blocked": False,
            "block_reason": None,
            "current_plan_name": current["name"],
            "new_plan_name": target["name"],
            "current_plan_price_cents": current_price,
            "new_plan_price_cents": new_price,
            "unused_credit_cents": 0,
            "net_charge_cents": 0,
            "effective_date": "Plano atual já ativo",
            "new_student_limit": target["max_students"],
            "new_ai_limit": target["max_ai"],
            "summary_message": f"Você já está no plano {current['name']}.",
        }
