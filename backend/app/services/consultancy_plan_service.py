import re
# backend/app/services/consultancy_plan_service.py
import uuid
import secrets
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
import httpx

from app.core.config import settings
from app.services.supabase_service import supabase_service, to_valid_uuid_str, is_valid_uuid
from app.services.whatsapp_service import whatsapp_service
from app.services.payment_service import (
    PaymentProviderService,
    resolve_asaas_base_url,
    normalize_cpf_cnpj,
    normalize_br_phone,
)
from app.core.financial_security import (
    JwsSplitCommandService,
    FinancialAuditTrail,
)
from app.schemas.consultancy_plan import (
    ConsultancyPlanCreate,
    ConsultancyPlanUpdate,
    ConsultancyPlanResponse,
    PublicCheckoutRequest,
    PublicCheckoutResponse,
    InvoiceStatusResponse,
)

logger = logging.getLogger(__name__)

PLATFORM_FEE_PERCENT = 0.05  # Taxa híbrida de 5% da plataforma


class ConsultancyPlanService:
    """Gerencia os planos de consultoria do personal e o checkout público de novos alunos."""

    _mem_plans: Dict[str, Dict[str, Any]] = {}
    _mem_invoices: Dict[str, Dict[str, Any]] = {}

    @classmethod
    async def list_trainer_plans(
        cls, trainer_id: str, only_active: bool = False
    ) -> List[ConsultancyPlanResponse]:
        """Lista os planos de consultoria de um treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await supabase_service.get_client()

        if client and is_valid_uuid(t_uuid):
            try:
                q = client.table("trainer_consultancy_plans")\
                    .select("*")\
                    .eq("trainer_id", t_uuid)\
                    .order("sort_order", desc=False)\
                    .order("created_at", desc=False)
                if only_active:
                    q = q.eq("is_active", True)
                res = await q.execute()
                plans: List[ConsultancyPlanResponse] = []
                for row in (res.data or []):
                    features = row.get("features")
                    if isinstance(features, str):
                        import json
                        try:
                            features = json.loads(features)
                        except Exception:
                            features = []
                    plans.append(ConsultancyPlanResponse(
                        id=row["id"],
                        trainer_id=row["trainer_id"],
                        name=row["name"],
                        description=row.get("description"),
                        price_cents=row["price_cents"],
                        billing_period=row.get("billing_period", "monthly"),
                        features=features or [],
                        is_active=row.get("is_active", True),
                        sort_order=row.get("sort_order", 0),
                        created_at=row.get("created_at"),
                        updated_at=row.get("updated_at"),
                    ))
                if plans:
                    return plans
            except Exception as e:
                logger.warning(f"[ConsultancyPlanService] Erro ao listar planos no Supabase: {e}")

        # Fallback em memória
        mem_plans: List[ConsultancyPlanResponse] = []
        for p in cls._mem_plans.values():
            if p.get("trainer_id") == trainer_id or p.get("trainer_id") == t_uuid:
                if only_active and not p.get("is_active", True):
                    continue
                mem_plans.append(ConsultancyPlanResponse(**p))
        mem_plans.sort(key=lambda x: (x.sort_order, x.created_at or ""))
        return mem_plans

    @classmethod
    async def get_plan_by_id(cls, plan_id: str) -> Optional[ConsultancyPlanResponse]:
        """Busca um plano de consultoria por ID."""
        client = await supabase_service.get_client()
        if client and is_valid_uuid(plan_id):
            try:
                res = await client.table("trainer_consultancy_plans").select("*").eq("id", plan_id).maybe_single().execute()
                if res and res.data:
                    row = res.data
                    features = row.get("features")
                    if isinstance(features, str):
                        import json
                        try:
                            features = json.loads(features)
                        except Exception:
                            features = []
                    return ConsultancyPlanResponse(
                        id=row["id"],
                        trainer_id=row["trainer_id"],
                        name=row["name"],
                        description=row.get("description"),
                        price_cents=row["price_cents"],
                        billing_period=row.get("billing_period", "monthly"),
                        features=features or [],
                        is_active=row.get("is_active", True),
                        sort_order=row.get("sort_order", 0),
                        created_at=row.get("created_at"),
                        updated_at=row.get("updated_at"),
                    )
            except Exception as e:
                logger.warning(f"[ConsultancyPlanService] Erro ao buscar plano por ID: {e}")

        # Fallback memória
        if plan_id in cls._mem_plans:
            return ConsultancyPlanResponse(**cls._mem_plans[plan_id])
        return None

    @classmethod
    async def create_plan(
        cls, trainer_id: str, req: ConsultancyPlanCreate
    ) -> ConsultancyPlanResponse:
        """Cria um novo plano de consultoria para o treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)
        plan_id = str(uuid.uuid4())
        now_str = datetime.now(timezone.utc).isoformat()

        client = await supabase_service.get_client()
        if client and is_valid_uuid(t_uuid):
            try:
                ins = await client.table("trainer_consultancy_plans").insert({
                    "id": plan_id,
                    "trainer_id": t_uuid,
                    "name": req.name.strip(),
                    "description": req.description.strip() if req.description else None,
                    "price_cents": req.price_cents,
                    "billing_period": req.billing_period,
                    "features": req.features,
                    "is_active": req.is_active,
                    "sort_order": req.sort_order,
                    "created_at": now_str,
                    "updated_at": now_str,
                }).execute()
                if ins and ins.data:
                    row = ins.data[0]
                    return ConsultancyPlanResponse(
                        id=row["id"],
                        trainer_id=row["trainer_id"],
                        name=row["name"],
                        description=row.get("description"),
                        price_cents=row["price_cents"],
                        billing_period=row.get("billing_period", "monthly"),
                        features=row.get("features") or [],
                        is_active=row.get("is_active", True),
                        sort_order=row.get("sort_order", 0),
                        created_at=row.get("created_at"),
                        updated_at=row.get("updated_at"),
                    )
            except Exception as e:
                logger.error(f"[ConsultancyPlanService] Erro ao criar plano no Supabase: {e}")

        # Fallback memória
        resp = ConsultancyPlanResponse(
            id=plan_id,
            trainer_id=trainer_id,
            name=req.name.strip(),
            description=req.description,
            price_cents=req.price_cents,
            billing_period=req.billing_period,
            features=req.features,
            is_active=req.is_active,
            sort_order=req.sort_order,
            created_at=now_str,
            updated_at=now_str,
        )
        cls._mem_plans[plan_id] = resp.model_dump()
        return resp

    @classmethod
    async def update_plan(
        cls, plan_id: str, trainer_id: str, req: ConsultancyPlanUpdate
    ) -> Optional[ConsultancyPlanResponse]:
        """Atualiza um plano de consultoria pertencente ao treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)
        now_str = datetime.now(timezone.utc).isoformat()

        client = await supabase_service.get_client()
        if client and is_valid_uuid(plan_id) and is_valid_uuid(t_uuid):
            try:
                patch = {"updated_at": now_str}
                if req.name is not None:
                    patch["name"] = req.name.strip()
                if req.description is not None:
                    patch["description"] = req.description.strip()
                if req.price_cents is not None:
                    patch["price_cents"] = req.price_cents
                if req.billing_period is not None:
                    patch["billing_period"] = req.billing_period
                if req.features is not None:
                    patch["features"] = req.features
                if req.is_active is not None:
                    patch["is_active"] = req.is_active
                if req.sort_order is not None:
                    patch["sort_order"] = req.sort_order

                upd = await client.table("trainer_consultancy_plans")\
                    .update(patch)\
                    .eq("id", plan_id)\
                    .eq("trainer_id", t_uuid)\
                    .execute()
                if upd and upd.data:
                    row = upd.data[0]
                    return ConsultancyPlanResponse(
                        id=row["id"],
                        trainer_id=row["trainer_id"],
                        name=row["name"],
                        description=row.get("description"),
                        price_cents=row["price_cents"],
                        billing_period=row.get("billing_period", "monthly"),
                        features=row.get("features") or [],
                        is_active=row.get("is_active", True),
                        sort_order=row.get("sort_order", 0),
                        created_at=row.get("created_at"),
                        updated_at=row.get("updated_at"),
                    )
            except Exception as e:
                logger.error(f"[ConsultancyPlanService] Erro ao atualizar plano no Supabase: {e}")

        # Fallback memória
        if plan_id in cls._mem_plans and cls._mem_plans[plan_id].get("trainer_id") in (trainer_id, t_uuid):
            p = cls._mem_plans[plan_id]
            if req.name is not None: p["name"] = req.name
            if req.description is not None: p["description"] = req.description
            if req.price_cents is not None: p["price_cents"] = req.price_cents
            if req.billing_period is not None: p["billing_period"] = req.billing_period
            if req.features is not None: p["features"] = req.features
            if req.is_active is not None: p["is_active"] = req.is_active
            if req.sort_order is not None: p["sort_order"] = req.sort_order
            p["updated_at"] = now_str
            return ConsultancyPlanResponse(**p)
        return None

    @classmethod
    async def delete_plan(cls, plan_id: str, trainer_id: str) -> bool:
        """Exclui ou desativa um plano de consultoria."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await supabase_service.get_client()

        if client and is_valid_uuid(plan_id) and is_valid_uuid(t_uuid):
            try:
                res = await client.table("trainer_consultancy_plans")\
                    .delete()\
                    .eq("id", plan_id)\
                    .eq("trainer_id", t_uuid)\
                    .execute()
                if res and res.data:
                    return True
            except Exception as e:
                logger.error(f"[ConsultancyPlanService] Erro ao deletar plano no Supabase: {e}")

        if plan_id in cls._mem_plans:
            del cls._mem_plans[plan_id]
            return True
        return False

    @classmethod
    async def process_public_checkout(
        cls,
        username: str,
        req: PublicCheckoutRequest,
    ) -> PublicCheckoutResponse:
        """
        Processa o checkout transparente na Vitrine Pública do Personal:
        1. Valida o treinador e se seu CREF está ativo.
        2. Localiza o plano de consultoria contratado.
        3. Calcula taxa da plataforma (5%) e saldo líquido do treinador (95%).
        4. Gera cobrança Asaas (Pix com QR Code ou Cartão).
        5. Registra a fatura pendente na tabela `student_invoices`.
        """
        client = await supabase_service.get_client()
        clean_user = username.strip().lower()

        # 1. Localiza o perfil do treinador
        trainer = None
        if client:
            try:
                res = await client.table("profiles").select("*").eq("username", clean_user).maybe_single().execute()
                trainer = res.data if res else None
            except Exception as e:
                logger.warning(f"[Checkout] Erro ao buscar treinador {username}: {e}")

        if not trainer:
            # Fallback memória se username for mrcoach
            if clean_user == "mrcoach":
                trainer = {
                    "id": "6f645308-f1b2-4d73-ac45-9890c27e20d4",
                    "full_name": "Cleudson Cavalcante",
                    "professional_document": "CREF 012345-G/DF",
                }

        if not trainer:
            raise ValueError(f"Personal trainer '{username}' não encontrado.")

        # Validação do CREF
        cref = trainer.get("professional_document") or trainer.get("cref")
        if not cref:
            raise ValueError("Perfil profissional ainda não validado (CREF pendente).")

        trainer_id = trainer["id"]
        trainer_name = trainer.get("full_name") or "Personal Trainer"

        # Validação estrita da cota de alunos do plano SaaS do Treinador
        try:
            occupied = await supabase_service.count_trainer_occupied_slots(trainer_id)
            sub = await supabase_service.get_trainer_subscription(trainer_id)
            max_allowed = sub.max_students
        except Exception as q_err:
            logger.warning(f"[Checkout] Falha ao consultar cota do treinador {trainer_id}: {q_err}")
            occupied, max_allowed = 0, 999
        if occupied >= max_allowed:
            raise ValueError(
                f"As vagas para novos alunos da consultoria de {trainer_name} estão temporariamente esgotadas. "
                "Entre em contato diretamente com o personal para consultar a lista de espera."
            )

        # 2. Localiza o plano de consultoria
        plan = await cls.get_plan_by_id(req.plan_id)
        if not plan or not plan.is_active:
            raise ValueError("O plano de consultoria selecionado não está mais disponível.")

        amount_cents = plan.price_cents
        fee_cents = int(round(amount_cents * PLATFORM_FEE_PERCENT))
        net_cents = amount_cents - fee_cents
        invoice_id = str(uuid.uuid4())
        due_date_str = (datetime.now(timezone.utc) + timedelta(days=2)).strftime("%Y-%m-%d")

        # 3. Resolução da Carteira / Subconta Asaas do Treinador (Split BCB nº 4.893)
        trainer_email = trainer.get("email") or f"{clean_user}@shaipados.com"
        trainer_phone = trainer.get("phone") or trainer.get("public_whatsapp")
        trainer_doc = trainer.get("cpf") or trainer.get("professional_document") or ""

        wallet_data = await PaymentProviderService.get_or_create_trainer_asaas_wallet(
            trainer_id=str(trainer_id),
            trainer_name=trainer_name,
            trainer_email=trainer_email,
            cpf_cnpj=trainer_doc,
            phone=trainer_phone,
        )
        trainer_wallet_id = wallet_data.get("asaas_wallet_id")

        # 4. Assinatura Criptográfica JWS do Comando de Split (Resolução BCB nº 4.893)
        split_command_data = {
            "invoice_id": invoice_id,
            "trainer_id": str(trainer_id),
            "trainer_wallet_id": trainer_wallet_id,
            "gross_amount_cents": amount_cents,
            "platform_fee_percent": round(PLATFORM_FEE_PERCENT * 100.0, 2),
            "platform_fee_cents": fee_cents,
            "trainer_net_cents": net_cents,
            "payment_method": req.payment_method,
            "currency": "BRL",
            "compliance_standard": "BCB_4893_CYBERSECURITY_V1",
        }
        jws_split_token = JwsSplitCommandService.sign_split_command(split_command_data)

        # Trilha de Auditoria Criptográfica Imutável (Audit Trail BCB 4.893)
        if getattr(settings, "FINANCIAL_AUDIT_ENABLED", True):
            FinancialAuditTrail.record_event(
                event_type="SPLIT_COMMAND_CREATED",
                invoice_id=invoice_id,
                trainer_id=str(trainer_id),
                gross_amount_cents=amount_cents,
                platform_fee_cents=fee_cents,
                trainer_net_cents=net_cents,
                jws_token=jws_split_token,
            )

        # Regra de Split Asaas: 95% direto para a subconta do personal, 5% retido na conta master
        asaas_split_rules = []
        if trainer_wallet_id:
            asaas_split_rules.append({
                "walletId": trainer_wallet_id,
                "percentualValue": 95.0,
                "description": f"Repasse líquido consultoria {plan.name}",
            })

        # 5. Integração com Gateway Asaas (Pix transparente com QR Code e Split)
        asaas_key = getattr(settings, "ASAAS_API_KEY", "")
        is_production = getattr(settings, "ENVIRONMENT", "").lower() == "production"
        pix_code = None
        pix_qr_base64 = None
        asaas_payment_id = None
        checkout_url = f"https://sandbox.asaas.com/c/{invoice_id[:8]}"
        status_result = "pending"

        if req.payment_method == "PIX":
            clean_student_cpf = normalize_cpf_cnpj(req.student_cpf or "")
            if is_production and not asaas_key:
                raise ValueError("Gateway de pagamento Pix temporariamente indisponível. Tente novamente em instantes.")
            if is_production and not clean_student_cpf:
                raise ValueError("Informe um CPF válido (11 dígitos) para emissão do QR Code Pix pelo Banco Central.")

            if asaas_key:
                base_url = resolve_asaas_base_url(asaas_key, getattr(settings, "ASAAS_API_URL", ""))
                headers = {"access_token": asaas_key, "Content-Type": "application/json"}
                try:
                    with httpx.Client(timeout=15.0) as http_client:
                        # Cria ou reutiliza cliente Asaas
                        cust_id = PaymentProviderService._asaas_get_or_create_customer(
                            http_client, base_url, headers,
                            name=req.student_name,
                            email=req.student_email,
                            cpf_cnpj=clean_student_cpf,
                            phone=normalize_br_phone(req.student_phone),
                        )
                        # Gera cobrança Pix com Split Asaas
                        pay_payload = {
                            "customer": cust_id,
                            "billingType": "PIX",
                            "value": amount_cents / 100.0,
                            "dueDate": due_date_str,
                            "description": f"Consultoria {plan.name} - {trainer_name}",
                            "externalReference": invoice_id,
                        }
                        if asaas_split_rules:
                            pay_payload["split"] = asaas_split_rules
                        pay_res = http_client.post(f"{base_url}/payments", headers=headers, json=pay_payload)
                        if pay_res.status_code in (200, 201):
                            p_data = pay_res.json()
                            asaas_payment_id = p_data.get("id")
                            checkout_url = p_data.get("invoiceUrl") or checkout_url
                            qr_res = http_client.get(f"{base_url}/payments/{asaas_payment_id}/pixQrCode", headers=headers)
                            if qr_res.status_code == 200:
                                qr_d = qr_res.json()
                                pix_code = qr_d.get("payload")
                                pix_qr_base64 = qr_d.get("encodedImage")
                            elif is_production:
                                raise ValueError(
                                    PaymentProviderService._asaas_error_message(
                                        qr_res,
                                        "Não foi possível obter o QR Code Pix junto ao Banco Central. Verifique o CPF informado.",
                                    )
                                )
                        elif is_production:
                            raise ValueError(
                                PaymentProviderService._asaas_error_message(
                                    pay_res,
                                    "Não foi possível gerar a cobrança Pix. Verifique os dados informados.",
                                )
                            )
                except ValueError:
                    raise
                except Exception as e:
                    logger.warning(f"[Checkout] Falha ao comunicar com Asaas em tempo real: {e}")
                    if is_production:
                        raise ValueError("Instabilidade temporária ao gerar o QR Code Pix. Tente novamente em instantes.")

            # Fallback seguro apenas para ambiente de desenvolvimento/testes
            if not pix_code:
                if is_production:
                    raise ValueError("Não foi possível gerar o código Pix oficial. Verifique o CPF informado e tente novamente.")
                pix_code = (
                    f"00020126580014br.gov.bcb.pix0136{invoice_id}"
                    f"52040000530398654{amount_cents/100:06.2f}5802BR5925{trainer_name[:25]}"
                    f"6009SAO PAULO62070503***6304ABCD"
                )
        else:
            # Cartão de crédito transparente (Asaas Gateway)
            if not req.credit_card:
                raise ValueError("Informe os dados do cartão de crédito (número, titular, validade e CVV).")

            clean_card_num = re.sub(r"\D", "", req.credit_card.number)
            if len(clean_card_num) < 13 or len(clean_card_num) > 19:
                raise ValueError("Número de cartão de crédito inválido.")

            if len(req.credit_card.ccv.strip()) < 3:
                raise ValueError("Código de segurança (CVV) inválido.")

            clean_holder_cpf = normalize_cpf_cnpj(req.credit_card.holder_cpf or req.student_cpf or "")

            if asaas_key:
                if is_production and not clean_holder_cpf:
                    raise ValueError("Informe um CPF válido do titular do cartão de crédito.")
                base_url = resolve_asaas_base_url(asaas_key, getattr(settings, "ASAAS_API_URL", ""))
                headers = {"access_token": asaas_key, "Content-Type": "application/json"}
                try:
                    with httpx.Client(timeout=20.0) as http_client:
                        cust_id = PaymentProviderService._asaas_get_or_create_customer(
                            http_client, base_url, headers,
                            name=req.student_name,
                            email=req.student_email,
                            cpf_cnpj=clean_holder_cpf,
                            phone=normalize_br_phone(req.student_phone),
                        )
                        card_payload = {
                            "customer": cust_id,
                            "billingType": "CREDIT_CARD",
                            "value": amount_cents / 100.0,
                            "dueDate": due_date_str,
                            "description": f"Consultoria {plan.name} - {trainer_name}",
                            "externalReference": invoice_id,
                            "creditCard": {
                                "holderName": req.credit_card.holder_name.strip(),
                                "number": clean_card_num,
                                "expiryMonth": req.credit_card.expiry_month.strip(),
                                "expiryYear": req.credit_card.expiry_year.strip(),
                                "ccv": req.credit_card.ccv.strip(),
                            },
                            "creditCardHolderInfo": {
                                "name": req.credit_card.holder_name.strip(),
                                "email": req.student_email.strip().lower(),
                                "cpfCnpj": clean_holder_cpf,
                                "postalCode": re.sub(r"\D", "", req.credit_card.postal_code or "70000000"),
                                "addressNumber": req.credit_card.address_number or "1",
                                "phone": normalize_br_phone(req.student_phone),
                            }
                        }
                        if asaas_split_rules:
                            card_payload["split"] = asaas_split_rules
                        card_res = http_client.post(f"{base_url}/payments", headers=headers, json=card_payload)
                        if card_res.status_code in (200, 201):
                            c_data = card_res.json()
                            asaas_payment_id = c_data.get("id")
                            status_result = (
                                "paid"
                                if c_data.get("status") in ("CONFIRMED", "RECEIVED", "RECEIVED_IN_CASH", "DUNNING_RECEIVED")
                                else "pending"
                            )
                            checkout_url = c_data.get("invoiceUrl") or checkout_url
                        else:
                            err_msg = PaymentProviderService._asaas_error_message(card_res, "Cartão de crédito não autorizado.")
                            if is_production:
                                raise ValueError(err_msg)
                            else:
                                logger.info(f"[Checkout] Asaas sandbox ({err_msg}); aprovando para testes.")
                                status_result = "paid"
                except ValueError:
                    raise
                except Exception as e:
                    logger.warning(f"[Checkout] Falha ao transacionar cartão no Asaas: {e}")
                    if is_production:
                        raise ValueError("Instabilidade temporária na operadora de cartão. Tente novamente ou utilize o Pix.")
                    status_result = "paid"  # Fallback seguro apenas para ambiente de desenvolvimento/testes
            else:
                if is_production:
                    raise ValueError("Pagamento via cartão temporariamente indisponível. Utilize o Pix.")
                # Simulação aprovada apenas em ambiente dev/sandbox sem credencial
                status_result = "paid"

        # 4. Registra na tabela `student_invoices` inicialmente como 'pending'
        # para que process_student_payment_confirmation faça a transição atômica única -> 'paid'
        inv_record = {
            "id": invoice_id,
            "trainer_id": trainer_id,
            "plan_id": plan.id,
            "student_name": req.student_name.strip(),
            "student_email": req.student_email.strip().lower() if req.student_email else None,
            "student_phone": req.student_phone.strip() if req.student_phone else None,
            "title": f"Consultoria {plan.name} - {trainer_name}",
            "description": f"Plano {plan.name} contratado via Vitrine Pública",
            "amount_cents": amount_cents,
            "platform_fee_cents": fee_cents,
            "net_amount_cents": net_cents,
            "due_date": due_date_str,
            "status": "pending",
            "payment_method": req.payment_method.lower(),
            "paid_at": None,
            "payment_link": checkout_url,
            "pix_copy_paste": pix_code,
            "asaas_payment_id": asaas_payment_id,
            "asaas_wallet_id": trainer_wallet_id,
            "jws_split_token": jws_split_token,
            "split_status": "settled" if status_result == "paid" else "pending",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        if client:
            try:
                await client.table("student_invoices").insert(inv_record).execute()
            except Exception as e:
                logger.error(f"[Checkout] Erro ao gravar fatura no Supabase: {e}")

        mem_record = dict(inv_record)
        if asaas_payment_id:
            mem_record["asaas_id"] = asaas_payment_id
        mem_record["jws_split_token"] = jws_split_token
        mem_record["asaas_wallet_id"] = trainer_wallet_id
        cls._mem_invoices[invoice_id] = mem_record

        # Se o pagamento foi aprovado instantaneamente (Cartão de Crédito),
        # dispara imediatamente o ciclo financeiro, vínculo de aluno e boas-vindas:
        auth_info: Dict[str, Any] = {}
        if status_result == "paid":
            try:
                auth_info = await cls.process_student_payment_confirmation(
                    invoice_id=invoice_id,
                    payment_method=req.payment_method.lower(),
                    provider_payment_id=asaas_payment_id,
                )
            except Exception as e:
                logger.warning(f"[Checkout] Falha ao processar ciclo de confirmação imediato: {e}")

        return PublicCheckoutResponse(
            invoice_id=invoice_id,
            status=status_result,
            payment_method=req.payment_method,
            amount_cents=amount_cents,
            net_amount_cents=net_cents,
            platform_fee_cents=fee_cents,
            pix_copy_paste=pix_code,
            pix_qr_code_base64=pix_qr_base64,
            checkout_url=checkout_url,
            expires_at=(datetime.now(timezone.utc) + timedelta(hours=24)).isoformat(),
            message=f"Cobrança para o plano '{plan.name}' gerada com sucesso!",
            trainer_name=trainer_name,
            plan_name=plan.name,
            auth_email=auth_info.get("auth_email"),
            auth_token=auth_info.get("auth_token"),
            access_url=auth_info.get("access_url"),
            jws_split_token=jws_split_token,
            trainer_wallet_id=trainer_wallet_id,
        )

    @classmethod
    async def process_student_payment_confirmation(
        cls,
        invoice_id: str,
        payment_method: str = "pix",
        provider_payment_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Confirma o pagamento de uma consultoria (via Webhook Asaas ou aprovação de Cartão):
        1. Localiza a fatura em `student_invoices`.
        2. Idempotência estrita: se já paga, retorna imediatamente sem duplicar saldos ou mensagens.
        3. Marca fatura como 'paid' com timestamp de pagamento.
        4. Credita o valor líquido (net_amount_cents) na carteira do treinador (trainer_wallets).
        5. Vincula ou gera convite de ativação para o aluno:
           - Se aluno já possui conta em `profiles`: vincula ao treinador e ativa status.
           - Se aluno novo: cria registro em `invite_tokens` com link seguro de onboarding.
        6. Envia mensagem de boas-vindas no WhatsApp do aluno com link direto para PWA/anamnese.
        7. Notifica o treinador no WhatsApp com o valor creditado e novo aluno a bordo.
        """
        now_utc = datetime.now(timezone.utc)
        now_iso = now_utc.isoformat()
        client = await supabase_service.get_client()

        # 1. Localiza a fatura
        invoice = None
        if client and is_valid_uuid(invoice_id):
            try:
                res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                invoice = res.data if res else None
            except Exception as e:
                logger.error(f"[PaymentConfirmation] Erro ao buscar fatura {invoice_id}: {e}")

        # Fallback memória
        if not invoice and invoice_id in cls._mem_invoices:
            invoice = cls._mem_invoices[invoice_id]

        if not invoice:
            logger.warning(f"[PaymentConfirmation] Fatura {invoice_id} não encontrada.")
            return {"status": "not_found", "invoice_id": invoice_id}

        # 2. Idempotência estrita (tanto em memória quanto no Supabase onde status='paid')
        mem_inv = cls._mem_invoices.get(invoice_id)
        if invoice.get("status") == "paid" or (mem_inv and mem_inv.get("status") == "paid"):
            logger.info(f"[PaymentConfirmation] Fatura {invoice_id} já processada anteriormente. Ignorando duplicata.")
            return {"status": "already_paid", "invoice_id": invoice_id}

        trainer_id = invoice["trainer_id"]
        student_name = invoice.get("student_name") or "Aluno"
        first_name = student_name.split()[0]
        student_phone = invoice.get("student_phone") or ""
        student_email = invoice.get("student_email") or ""
        amount_cents = invoice.get("amount_cents", 0)
        net_cents = invoice.get("net_amount_cents") or int(round(amount_cents * 0.95))

        # 3. Marca fatura como paga em memória e no Supabase
        paid_at_iso = invoice.get("paid_at") or now_iso
        invoice["status"] = "paid"
        invoice["paid_at"] = paid_at_iso
        invoice["processed_at"] = now_iso
        invoice["payment_method"] = payment_method.lower()
        invoice["split_status"] = "settled"
        if provider_payment_id:
            invoice["asaas_id"] = provider_payment_id
        cls._mem_invoices[invoice_id] = invoice

        if client and is_valid_uuid(invoice_id):
            try:
                await client.table("student_invoices").update({
                    "status": "paid",
                    "paid_at": paid_at_iso,
                    "payment_method": payment_method.lower(),
                    "split_status": "settled",
                }).eq("id", invoice_id).execute()
            except Exception as e:
                logger.error(f"[PaymentConfirmation] Erro ao atualizar status da fatura {invoice_id}: {e}")

        # Registro de liquidação de split na Trilha de Auditoria Criptográfica (BCB 4.893)
        if getattr(settings, "FINANCIAL_AUDIT_ENABLED", True):
            FinancialAuditTrail.record_event(
                event_type="SPLIT_SETTLED",
                invoice_id=invoice_id,
                trainer_id=str(trainer_id),
                gross_amount_cents=amount_cents,
                platform_fee_cents=amount_cents - net_cents,
                trainer_net_cents=net_cents,
                jws_token=invoice.get("jws_split_token") or "settlement_direct",
            )

        # 4. Credita o valor líquido na carteira do treinador
        if client and is_valid_uuid(trainer_id):
            try:
                w_res = await client.table("trainer_wallets").select("balance_cents").eq("trainer_id", trainer_id).maybe_single().execute()
                current_bal = w_res.data.get("balance_cents", 0) if w_res and w_res.data else 0
                new_bal = current_bal + net_cents
                await client.table("trainer_wallets").upsert({
                    "trainer_id": trainer_id,
                    "balance_cents": new_bal,
                    "updated_at": now_iso,
                }).execute()
                logger.info(f"[PaymentConfirmation] R$ {net_cents/100:.2f} creditados na carteira do treinador {trainer_id}. Novo saldo: R$ {new_bal/100:.2f}")
            except Exception as e:
                logger.error(f"[PaymentConfirmation] Erro ao creditar carteira do treinador {trainer_id}: {e}")

        # 5. Localiza dados do Treinador para mensagens
        trainer_name = "Seu Personal Trainer"
        trainer_phone = None
        if client and is_valid_uuid(trainer_id):
            try:
                t_res = await client.table("profiles").select("full_name, phone, public_whatsapp").eq("id", trainer_id).maybe_single().execute()
                if t_res and t_res.data:
                    trainer_name = t_res.data.get("full_name") or trainer_name
                    trainer_phone = t_res.data.get("public_whatsapp") or t_res.data.get("phone")
            except Exception as e:
                logger.warning(f"[PaymentConfirmation] Erro ao buscar perfil do treinador {trainer_id}: {e}")

        # 6. Vinculação do Aluno / Geração de Convite de Onboarding
        student_profile = None
        clean_phone = re.sub(r"\D", "", student_phone)
        norm_phone = clean_phone[2:] if clean_phone.startswith("55") and len(clean_phone) > 11 else clean_phone

        if client:
            try:
                if student_email:
                    p_res = await client.table("profiles").select("id, full_name, email, phone").eq("email", student_email.strip().lower()).maybe_single().execute()
                    student_profile = p_res.data if p_res else None
                if not student_profile and norm_phone:
                    p_res = await client.table("profiles").select("id, full_name, email, phone").ilike("phone", f"%{norm_phone}%").maybe_single().execute()
                    student_profile = p_res.data if p_res else None
            except Exception as e:
                logger.warning(f"[PaymentConfirmation] Erro ao buscar profile do aluno: {e}")

        invite_token = None
        frontend_base = (getattr(settings, "APP_FRONTEND_URL", "") or "https://shaipados.com").rstrip("/")
        access_url = frontend_base

        if student_profile:
            # Aluno já possui cadastro: vincula ao treinador e ativa
            s_id = student_profile["id"]
            if client and is_valid_uuid(s_id):
                try:
                    await client.table("profiles").update({
                        "trainer_id": trainer_id,
                        "role": "client",
                        "subscription_status": "active",
                    }).eq("id", s_id).execute()

                    # Vincula student_id na fatura
                    await client.table("student_invoices").update({
                        "student_id": s_id,
                    }).eq("id", invoice_id).execute()
                except Exception as e:
                    logger.warning(f"[PaymentConfirmation] Falha ao atualizar vínculo de aluno existente: {e}")

            wa_student_text = (
                f"Olá, *{first_name}*! 🎉\n\n"
                f"O seu pagamento da consultoria com o Personal *{trainer_name}* foi confirmado com sucesso!\n\n"
                f"Seu acesso já está liberado no aplicativo. Acesse para iniciar sua avaliação física e conferir seus treinos:\n"
                f"👉 {access_url}\n\n"
                f"Bora buscar o shape com alto nível! 💪"
            )
        else:
            # Aluno novo: gera convite seguro de ativação e anamnese
            invite_token = secrets.token_hex(32)
            expires_at = (now_utc + timedelta(days=30)).isoformat()

            if client:
                try:
                    await client.table("invite_tokens").insert({
                        "token": invite_token,
                        "trainer_id": trainer_id,
                        "channel": "whatsapp" if student_phone else "email",
                        "target_name": student_name,
                        "target_phone": student_phone or None,
                        "target_email": student_email or None,
                        "expires_at": expires_at,
                        "created_at": now_iso,
                    }).execute()
                except Exception as e:
                    logger.warning(f"[PaymentConfirmation] Erro ao criar invite_token: {e}")

            access_url = f"{frontend_base}/#/invite/{invite_token}"
            wa_student_text = (
                f"Olá, *{first_name}*! 🎉\n\n"
                f"O seu pagamento da consultoria com o Personal *{trainer_name}* foi confirmado com sucesso!\n\n"
                f"Clique no link seguro abaixo para criar seu acesso, instalar o app e preencher sua avaliação física inicial:\n"
                f"👉 {access_url}\n\n"
                f"Bora começar a sua transformação! 💪"
            )

        # 7. Disparo WhatsApp para o Aluno
        if student_phone:
            try:
                await whatsapp_service.send_text_with_fallback(
                    number=student_phone,
                    text=wa_student_text,
                    trainer_id=trainer_id,
                )
                logger.info(f"[PaymentConfirmation] WhatsApp de boas-vindas enviado para o aluno {student_phone}")
            except Exception as e:
                logger.warning(f"[PaymentConfirmation] Erro não impeditivo ao enviar WhatsApp para o aluno: {e}")

        # 8. Autenticação Instantânea SaaS (Zero Password Barrier para Aluno Pós-Pagamento)
        direct_auth_email: Optional[str] = student_email.strip().lower() if student_email else None
        direct_auth_token: Optional[str] = None

        if client:
            temp_pwd = f"MrCoach_Pwa_{secrets.token_hex(8)}"
            try:
                if student_profile:
                    # Atualiza credencial temporária para login direto
                    await supabase_service.admin_update_user_password(student_profile["id"], temp_pwd)
                    direct_auth_email = student_profile.get("email") or direct_auth_email
                    direct_auth_token = temp_pwd
                else:
                    # Cria conta do aluno no Supabase Auth com acesso liberado imediato (domínio sintético isolado)
                    target_email = direct_auth_email or f"aluno_{clean_phone or secrets.token_hex(4)}@aluno.mrcoach.internal"
                    created_u = await supabase_service.admin_create_user(
                        email=target_email,
                        password=temp_pwd,
                        full_name=student_name,
                        role="client",
                        phone=clean_phone or None,
                        trainer_id=trainer_id,
                        provisioned_by_backend=True,
                    )
                    direct_auth_email = target_email
                    direct_auth_token = temp_pwd
                    # Vincula student_id na fatura
                    await client.table("student_invoices").update({
                        "student_id": created_u["user_id"],
                    }).eq("id", invoice_id).execute()
            except Exception as e:
                logger.warning(f"[PaymentConfirmation] Não foi possível provisionar login direto: {e}")

        # 9. Notifica o Treinador no WhatsApp
        if trainer_phone:
            val_formatado = f"R$ {net_cents / 100:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
            wa_trainer_text = (
                f"🚀 *Novo Aluno Confirmado!*\n\n"
                f"Fala, *{trainer_name}*!\n"
                f"O pagamento de *{student_name}* para a sua consultoria foi confirmado com sucesso! 🎉\n\n"
                f"💰 Valor líquido creditado na carteira: *{val_formatado}*\n"
                f"📲 O link de boas-vindas e ficha inicial já foi enviado no WhatsApp do aluno.\n\n"
                f"Acompanhe pelo seu painel: {frontend_base}"
            )
            try:
                await whatsapp_service.send_text_with_fallback(
                    number=trainer_phone,
                    text=wa_trainer_text,
                    trainer_id=trainer_id,
                )
                logger.info(f"[PaymentConfirmation] Notificação de novo aluno enviada para o treinador {trainer_phone}")
            except Exception as e:
                logger.warning(f"[PaymentConfirmation] Erro ao notificar treinador no WhatsApp: {e}")

        return {
            "status": "processed",
            "invoice_id": invoice_id,
            "trainer_id": trainer_id,
            "student_name": student_name,
            "net_amount_cents": net_cents,
            "access_url": access_url,
            "token": invite_token,
            "auth_email": direct_auth_email,
            "auth_token": direct_auth_token,
        }

    @classmethod
    async def process_student_payment_cancellation_or_refund(
        cls,
        invoice_id: str,
        event: str = "PAYMENT_REFUNDED",
    ) -> Dict[str, Any]:
        """
        Processa de forma idempotente o cancelamento, exclusão ou estorno (refund/chargeback)
        de uma fatura de aluno. Caso a fatura já tivesse sido paga e creditada na carteira
        do treinador, realiza o estorno proporcional do saldo líquido (net_amount_cents).
        """
        now_iso = datetime.now(timezone.utc).isoformat()
        client = await supabase_service.get_client()
        invoice = None

        if client and is_valid_uuid(invoice_id):
            try:
                res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                invoice = res.data if res else None
            except Exception as e:
                logger.error(f"[PaymentRefund] Erro ao consultar fatura {invoice_id}: {e}")

        if not invoice and invoice_id in cls._mem_invoices:
            invoice = cls._mem_invoices[invoice_id]

        prev_status = (invoice or {}).get("status", "pending")
        was_paid = prev_status == "paid"

        if invoice:
            invoice["status"] = "canceled"
            cls._mem_invoices[invoice_id] = invoice

        if client and is_valid_uuid(invoice_id):
            try:
                await client.table("student_invoices").update({"status": "canceled"}).eq("id", invoice_id).execute()
            except Exception as e:
                logger.error(f"[PaymentRefund] Erro ao cancelar fatura {invoice_id} no Supabase: {e}")

        # Se estava paga e sofreu estorno/chargeback, reverte o crédito líquido da carteira do personal
        reversed_cents = 0
        if was_paid and invoice and event in ("PAYMENT_REFUNDED", "PAYMENT_CHARGEBACK_REQUESTED"):
            trainer_id = invoice.get("trainer_id")
            amount_cents = invoice.get("amount_cents", 0)
            net_cents = invoice.get("net_amount_cents") or int(round(amount_cents * 0.95))
            reversed_cents = net_cents
            if client and is_valid_uuid(trainer_id):
                try:
                    w_res = await client.table("trainer_wallets").select("balance_cents").eq("trainer_id", trainer_id).maybe_single().execute()
                    current_bal = w_res.data.get("balance_cents", 0) if w_res and w_res.data else 0
                    new_bal = max(0, current_bal - net_cents)
                    await client.table("trainer_wallets").upsert({
                        "trainer_id": trainer_id,
                        "balance_cents": new_bal,
                        "updated_at": now_iso,
                    }).execute()
                    logger.warning(
                        f"[PaymentRefund] Estorno de R$ {net_cents/100:.2f} aplicado na carteira do treinador {trainer_id} "
                        f"devido a '{event}' na fatura {invoice_id}."
                    )
                except Exception as e:
                    logger.error(f"[PaymentRefund] Erro ao estornar carteira do treinador {trainer_id}: {e}")

        return {
            "status": "canceled",
            "invoice_id": invoice_id,
            "was_paid": was_paid,
            "reversed_cents": reversed_cents,
        }

    @classmethod
    async def get_invoice_status(
        cls,
        invoice_id: str,
        simulate_paid: bool = False,
    ) -> Optional[InvoiceStatusResponse]:
        """
        Consulta o status atual de uma fatura de aluno (student_invoices).
        Permite consulta em tempo real (polling) pelo app ou verificação manual.
        """
        client = await supabase_service.get_client()
        invoice = None

        if client and is_valid_uuid(invoice_id):
            try:
                res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                invoice = res.data if res else None
            except Exception as e:
                logger.error(f"[InvoiceStatus] Erro ao buscar fatura {invoice_id} no Supabase: {e}")

        if not invoice and invoice_id in cls._mem_invoices:
            invoice = cls._mem_invoices[invoice_id]

        if not invoice:
            return None

        status = invoice.get("status", "pending")
        auth_data: Dict[str, Any] = {}

        # Simulação ou processamento se solicitado em ambiente seguro
        if status != "paid" and simulate_paid and getattr(settings, "ENVIRONMENT", "").lower() != "production":
            logger.info(f"[InvoiceStatus] Simulação de pagamento aprovado para fatura {invoice_id}")
            auth_data = await cls.process_student_payment_confirmation(
                invoice_id=invoice_id,
                payment_method=invoice.get("payment_method") or "pix",
            )
            if client and is_valid_uuid(invoice_id):
                try:
                    res = await client.table("student_invoices").select("*").eq("id", invoice_id).maybe_single().execute()
                    if res and res.data:
                        invoice = res.data
                except Exception:
                    pass
            status = invoice.get("status", "paid")

        # Se ainda pendente e houver gateway Asaas ativo, consulta status direto no gateway
        if status != "paid":
            asaas_key = getattr(settings, "ASAAS_API_KEY", "")
            if asaas_key:
                try:
                    base_url = resolve_asaas_base_url(asaas_key, getattr(settings, "ASAAS_API_URL", ""))
                    headers = {"access_token": asaas_key}
                    with httpx.Client(timeout=10.0) as http_client:
                        r = http_client.get(f"{base_url}/payments", headers=headers, params={"externalReference": invoice_id})
                        if r.status_code == 200:
                            data = r.json().get("data", [])
                            if data and data[0].get("status") in ("CONFIRMED", "RECEIVED", "RECEIVED_IN_CASH", "DUNNING_RECEIVED"):
                                auth_data = await cls.process_student_payment_confirmation(
                                    invoice_id=invoice_id,
                                    payment_method=data[0].get("billingType", "PIX").lower(),
                                    provider_payment_id=data[0].get("id"),
                                )
                                status = "paid"
                except Exception as gw_err:
                    logger.warning(f"[InvoiceStatus] Erro ao consultar Asaas para {invoice_id}: {gw_err}")

        trainer_id = invoice.get("trainer_id")
        trainer_name = "Personal Trainer"
        if client and is_valid_uuid(trainer_id):
            try:
                t_res = await client.table("profiles").select("full_name").eq("id", trainer_id).maybe_single().execute()
                if t_res and t_res.data:
                    trainer_name = t_res.data.get("full_name") or trainer_name
            except Exception:
                pass

        plan_id = invoice.get("plan_id")
        plan_name = invoice.get("title") or "Consultoria Personal"
        if plan_id:
            try:
                p = await cls.get_plan_by_id(plan_id)
                if p:
                    plan_name = p.name
            except Exception:
                pass

        return InvoiceStatusResponse(
            invoice_id=invoice_id,
            status=status,
            is_paid=(status == "paid"),
            paid_at=invoice.get("paid_at"),
            trainer_id=trainer_id,
            trainer_name=trainer_name,
            plan_name=plan_name,
            amount_cents=invoice.get("amount_cents", 0),
            auth_email=auth_data.get("auth_email"),
            auth_token=auth_data.get("auth_token"),
            access_url=auth_data.get("access_url"),
        )

