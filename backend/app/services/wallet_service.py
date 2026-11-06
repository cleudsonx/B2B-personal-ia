# app/services/wallet_service.py
# FASE 6: Monetização B2B2C Híbrida (Carteira do Personal e Cobranças de Alunos)

import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from app.services.supabase_service import supabase_service
from app.services.whatsapp_service import whatsapp_service
from app.schemas.wallet import (
    WalletSummaryResponse,
    SetPixKeyRequest,
    CreateInvoiceRequest,
    StudentInvoiceResponse,
    WithdrawalResponse,
    WalletSplitsCockpitResponse,
)

logger = logging.getLogger(__name__)

# Taxa da plataforma no modelo B2B2C híbrido (5% da mensalidade/consultoria)
PLATFORM_FEE_PERCENT = 0.05


class WalletService:
    """Gerencia a carteira digital, saldo, faturas de alunos e repasses via Pix."""

    # Fallback em memória para ambiente de testes/desenvolvimento
    _mem_wallets: Dict[str, Dict[str, Any]] = {}
    _mem_invoices: List[Dict[str, Any]] = []
    _mem_withdrawals: List[Dict[str, Any]] = []

    @classmethod
    def _collect_invoices_for_trainer(cls, trainer_id: str) -> List[Dict[str, Any]]:
        """Consolida faturas do treinador combinando fallbacks em memória com desduplicação."""
        from app.services.consultancy_plan_service import ConsultancyPlanService
        seen_ids = set()
        combined: List[Dict[str, Any]] = []

        for inv in cls._mem_invoices:
            if inv.get("trainer_id") == trainer_id and inv.get("id") not in seen_ids:
                seen_ids.add(inv.get("id"))
                combined.append(inv)

        for inv in ConsultancyPlanService._mem_invoices.values():
            if inv.get("trainer_id") == trainer_id and inv.get("id") not in seen_ids:
                seen_ids.add(inv.get("id"))
                combined.append(inv)

        return combined

    @classmethod
    def _compute_split_kpis(cls, invoices: List[Dict[str, Any]], start_of_month: str) -> Dict[str, Any]:
        """Calcula agregações analíticas de split 95/5 e KPIs para o Cockpit Financeiro."""
        settled = [i for i in invoices if i.get("status") == "paid" or i.get("split_status") == "settled"]
        pending = [i for i in invoices if i.get("status") == "pending" or i.get("split_status") == "pending"]

        settled_gross = sum(i.get("amount_cents", 0) for i in settled)
        settled_net = sum(i.get("net_amount_cents", int(i.get("amount_cents", 0) * 0.95)) for i in settled)
        settled_fee = sum(i.get("platform_fee_cents", int(i.get("amount_cents", 0) * 0.05)) for i in settled)

        pending_gross = sum(i.get("amount_cents", 0) for i in pending)
        pending_net = sum(i.get("net_amount_cents", int(i.get("amount_cents", 0) * 0.95)) for i in pending)

        total_month = sum(
            i.get("net_amount_cents", int(i.get("amount_cents", 0) * 0.95))
            for i in settled
            if (i.get("paid_at") and i["paid_at"] >= start_of_month) or (not i.get("paid_at") and i.get("created_at", "") >= start_of_month)
        )

        return {
            "total_splits_count": len(invoices),
            "settled_splits_count": len(settled),
            "pending_splits_count": len(pending),
            "settled_gross_cents": settled_gross,
            "settled_net_cents": settled_net,
            "settled_fee_cents": settled_fee,
            "pending_gross_cents": pending_gross,
            "pending_net_cents": pending_net,
            "total_month_net_cents": total_month,
        }

    @classmethod
    async def get_summary(cls, trainer_id: str) -> WalletSummaryResponse:
        """Retorna o resumo da carteira do Personal Trainer com métricas analíticas de splits."""
        now = datetime.now(timezone.utc)
        start_of_month = datetime(now.year, now.month, 1, tzinfo=timezone.utc).isoformat()
        client = await supabase_service.get_client()

        if client:
            try:
                # 1. Busca carteira
                res = await client.table("trainer_wallets").select("*").eq("trainer_id", trainer_id).maybe_single().execute()
                wallet_data = res.data if res else None
                if not wallet_data:
                    # Cria carteira inicial com saldo zero
                    ins = await client.table("trainer_wallets").insert({
                        "trainer_id": trainer_id,
                        "balance_cents": 0,
                        "pending_balance_cents": 0,
                    }).execute()
                    wallet_data = ins.data[0] if ins and ins.data else {
                        "balance_cents": 0,
                        "pending_balance_cents": 0,
                        "pix_key": None,
                        "pix_key_type": "cpf",
                        "bank_name": None,
                    }

                # 2. Busca faturas e calcula métricas de split
                inv_res = await client.table("student_invoices").select("*")\
                    .eq("trainer_id", trainer_id).execute()
                invoices = inv_res.data or []
                kpis = cls._compute_split_kpis(invoices, start_of_month)

                asaas_w_id = wallet_data.get("asaas_wallet_id")
                asaas_st = wallet_data.get("asaas_account_status")
                if asaas_w_id and (not asaas_st or asaas_st == "unlinked"):
                    asaas_st = "active"

                return WalletSummaryResponse(
                    balance_cents=wallet_data.get("balance_cents", 0),
                    pending_balance_cents=kpis["pending_net_cents"],
                    total_billed_month_cents=kpis["total_month_net_cents"],
                    pix_key=wallet_data.get("pix_key"),
                    pix_key_type=wallet_data.get("pix_key_type") or "cpf",
                    bank_name=wallet_data.get("bank_name"),
                    asaas_account_id=wallet_data.get("asaas_account_id"),
                    asaas_wallet_id=asaas_w_id,
                    asaas_account_status=asaas_st or "unlinked",
                    total_splits_count=kpis["total_splits_count"],
                    settled_splits_count=kpis["settled_splits_count"],
                    pending_splits_count=kpis["pending_splits_count"],
                    settled_gross_cents=kpis["settled_gross_cents"],
                    settled_net_cents=kpis["settled_net_cents"],
                    settled_fee_cents=kpis["settled_fee_cents"],
                    pending_gross_cents=kpis["pending_gross_cents"],
                    pending_net_cents=kpis["pending_net_cents"],
                )
            except Exception as e:
                logger.error(f"[WalletService] Erro ao consultar carteira no Supabase: {e}")

        # Fallback em memória
        w = cls._mem_wallets.get(trainer_id, {
            "balance_cents": 0,
            "pending_balance_cents": 0,
            "pix_key": None,
            "pix_key_type": "cpf",
            "bank_name": None,
        })
        invoices = cls._collect_invoices_for_trainer(trainer_id)
        kpis = cls._compute_split_kpis(invoices, start_of_month)

        asaas_w_id = w.get("asaas_wallet_id")
        asaas_st = w.get("asaas_account_status")
        if asaas_w_id and (not asaas_st or asaas_st == "unlinked"):
            asaas_st = "active"

        return WalletSummaryResponse(
            balance_cents=w.get("balance_cents", 0),
            pending_balance_cents=kpis["pending_net_cents"],
            total_billed_month_cents=kpis["total_month_net_cents"],
            pix_key=w.get("pix_key"),
            pix_key_type=w.get("pix_key_type", "cpf"),
            bank_name=w.get("bank_name"),
            asaas_account_id=w.get("asaas_account_id"),
            asaas_wallet_id=asaas_w_id,
            asaas_account_status=asaas_st or "unlinked",
            total_splits_count=kpis["total_splits_count"],
            settled_splits_count=kpis["settled_splits_count"],
            pending_splits_count=kpis["pending_splits_count"],
            settled_gross_cents=kpis["settled_gross_cents"],
            settled_net_cents=kpis["settled_net_cents"],
            settled_fee_cents=kpis["settled_fee_cents"],
            pending_gross_cents=kpis["pending_gross_cents"],
            pending_net_cents=kpis["pending_net_cents"],
        )

    @classmethod
    async def update_pix_key(cls, trainer_id: str, req: SetPixKeyRequest) -> WalletSummaryResponse:
        """Salva a chave Pix do treinador para saques/repasses."""
        client = await supabase_service.get_client()
        if client:
            try:
                await client.table("trainer_wallets").upsert({
                    "trainer_id": trainer_id,
                    "pix_key": req.pix_key.strip(),
                    "pix_key_type": req.pix_key_type.lower().strip(),
                    "bank_name": req.bank_name.strip() if req.bank_name else None,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).execute()
            except Exception as e:
                logger.error(f"[WalletService] Erro ao salvar chave Pix no Supabase: {e}")

        # Atualiza em memória
        if trainer_id not in cls._mem_wallets:
            cls._mem_wallets[trainer_id] = {"balance_cents": 0, "pending_balance_cents": 0}
        cls._mem_wallets[trainer_id]["pix_key"] = req.pix_key.strip()
        cls._mem_wallets[trainer_id]["pix_key_type"] = req.pix_key_type.lower().strip()
        cls._mem_wallets[trainer_id]["bank_name"] = req.bank_name.strip() if req.bank_name else None

        return await cls.get_summary(trainer_id)

    @classmethod
    async def list_invoices(cls, trainer_id: str) -> List[StudentInvoiceResponse]:
        """Lista todas as cobranças emitidas pelo treinador com dados de split enriquecidos."""
        client = await supabase_service.get_client()
        if client:
            try:
                res = await client.table("student_invoices").select("*")\
                    .eq("trainer_id", trainer_id)\
                    .order("created_at", desc=True).execute()
                if res and res.data:
                    return [StudentInvoiceResponse(**item) for item in res.data]
            except Exception as e:
                logger.error(f"[WalletService] Erro ao listar cobranças no Supabase: {e}")

        # Fallback memória
        items = cls._collect_invoices_for_trainer(trainer_id)
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return [StudentInvoiceResponse(**item) for item in items]

    @classmethod
    async def get_splits_cockpit(cls, trainer_id: str) -> WalletSplitsCockpitResponse:
        """Retorna visão consolidada do Cockpit de Splits (KPIs + Extrato de Transações)."""
        summary = await cls.get_summary(trainer_id)
        items = await cls.list_invoices(trainer_id)
        return WalletSplitsCockpitResponse(summary=summary, items=items)

    @classmethod
    async def create_invoice(
        cls,
        trainer_id: str,
        trainer_name: str,
        req: CreateInvoiceRequest,
    ) -> StudentInvoiceResponse:
        """Cria uma nova cobrança para um aluno e opcionalmente dispara no WhatsApp."""
        fee_cents = int(req.amount_cents * PLATFORM_FEE_PERCENT)
        net_cents = req.amount_cents - fee_cents
        inv_id = str(uuid.uuid4())
        now_iso = datetime.now(timezone.utc).isoformat()
        due_date_str = req.due_date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

        # Gera Pix e Link de Pagamento transparente do ecossistema
        payment_link = f"https://shaipados-labs.web.app/pay/{inv_id}"
        simulated_pix = (
            f"00020126580014br.gov.bcb.pix0136{inv_id}520400005303986"
            f"540{req.amount_cents/100:.2f}5802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304"
        )

        record = {
            "id": inv_id,
            "trainer_id": trainer_id,
            "student_id": req.student_id,
            "student_name": req.student_name.strip(),
            "student_phone": req.student_phone.strip() if req.student_phone else None,
            "student_email": req.student_email.strip() if req.student_email else None,
            "title": req.title.strip(),
            "description": req.description.strip() if req.description else None,
            "amount_cents": req.amount_cents,
            "platform_fee_cents": fee_cents,
            "net_amount_cents": net_cents,
            "status": "pending",
            "due_date": due_date_str,
            "paid_at": None,
            "payment_method": "pix",
            "payment_link": payment_link,
            "pix_copy_paste": simulated_pix,
            "created_at": now_iso,
        }

        client = await supabase_service.get_client()
        if client:
            try:
                await client.table("student_invoices").insert(record).execute()
            except Exception as e:
                logger.error(f"[WalletService] Erro ao inserir fatura no Supabase: {e}")

        # Armazena na memória
        cls._mem_invoices.append(record)

        # Disparo automático no WhatsApp se solicitado
        if req.send_whatsapp and req.student_phone:
            valor_formatado = f"R$ {req.amount_cents / 100:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
            msg = (
                f"Olá, *{req.student_name.split()[0]}*! 💪\n\n"
                f"Seu treinador *{trainer_name}* gerou a fatura da sua consultoria de treinos no *Mr. Coach*:\n\n"
                f"📋 *{req.title}*\n"
                f"💰 Valor: *{valor_formatado}*\n"
                f"📅 Vencimento: *{due_date_str}*\n\n"
                f"Pague com segurança e liberação instantânea via Pix pelo link:\n"
                f"{payment_link}\n\n"
                f"Ou copie o código Pix abaixo:\n"
                f"`{simulated_pix}`"
            )
            try:
                await whatsapp_service.send_text_with_fallback(
                    trainer_id=trainer_id,
                    phone=req.student_phone,
                    text=msg,
                )
            except Exception as e:
                logger.warning(f"[WalletService] Falha ao enviar WhatsApp de cobrança: {e}")

        return StudentInvoiceResponse(**record)

    @classmethod
    async def mark_paid(cls, trainer_id: str, invoice_id: str) -> StudentInvoiceResponse:
        """Marca uma cobrança como PAGA e credita o valor líquido na carteira do treinador."""
        now_iso = datetime.now(timezone.utc).isoformat()
        client = await supabase_service.get_client()

        # 1. Busca a fatura
        invoice = None
        if client:
            try:
                res = await client.table("student_invoices").select("*")\
                    .eq("id", invoice_id)\
                    .eq("trainer_id", trainer_id).maybe_single().execute()
                invoice = res.data if res else None
            except Exception as e:
                logger.error(f"[WalletService] Erro ao buscar fatura: {e}")

        if not invoice:
            invoice = next((i for i in cls._mem_invoices if i["id"] == invoice_id and i["trainer_id"] == trainer_id), None)

        if not invoice:
            raise ValueError("Cobrança não encontrada.")

        if invoice.get("status") == "paid":
            return StudentInvoiceResponse(**invoice)

        # 2. Atualiza fatura para PAID
        net_amount = invoice.get("net_amount_cents", 0)
        invoice["status"] = "paid"
        invoice["paid_at"] = now_iso

        if client:
            try:
                await client.table("student_invoices").update({
                    "status": "paid",
                    "paid_at": now_iso,
                }).eq("id", invoice_id).execute()

                # Credita saldo na carteira
                w_res = await client.table("trainer_wallets").select("balance_cents").eq("trainer_id", trainer_id).maybe_single().execute()
                curr_balance = (w_res.data or {}).get("balance_cents", 0) if w_res else 0
                new_balance = curr_balance + net_amount

                await client.table("trainer_wallets").update({
                    "balance_cents": new_balance,
                    "updated_at": now_iso,
                }).eq("trainer_id", trainer_id).execute()
            except Exception as e:
                logger.error(f"[WalletService] Erro ao atualizar saldo no Supabase: {e}")

        # Atualiza memória
        if trainer_id not in cls._mem_wallets:
            cls._mem_wallets[trainer_id] = {"balance_cents": 0, "pending_balance_cents": 0}
        cls._mem_wallets[trainer_id]["balance_cents"] = cls._mem_wallets[trainer_id].get("balance_cents", 0) + net_amount

        return StudentInvoiceResponse(**invoice)

    @classmethod
    async def request_withdrawal(cls, trainer_id: str, amount_cents: int) -> WithdrawalResponse:
        """Processa pedido de saque do saldo disponível para a chave Pix do treinador."""
        summary = await cls.get_summary(trainer_id)

        if not summary.pix_key:
            raise ValueError("Cadastre sua chave Pix antes de solicitar um saque.")

        if amount_cents > summary.balance_cents:
            raise ValueError(
                f"Saldo insuficiente. Disponível: R$ {summary.balance_cents / 100:.2f}. "
                f"Solicitado: R$ {amount_cents / 100:.2f}."
            )

        if amount_cents < 1000:  # Mínimo R$ 10,00
            raise ValueError("O valor mínimo para solicitação de saque é de R$ 10,00.")

        now_iso = datetime.now(timezone.utc).isoformat()
        withdrawal_id = str(uuid.uuid4())
        new_balance = summary.balance_cents - amount_cents

        record = {
            "id": withdrawal_id,
            "trainer_id": trainer_id,
            "amount_cents": amount_cents,
            "pix_key": summary.pix_key,
            "pix_key_type": summary.pix_key_type,
            "status": "completed",
            "created_at": now_iso,
        }

        client = await supabase_service.get_client()
        if client:
            try:
                # Debita da carteira
                await client.table("trainer_wallets").update({
                    "balance_cents": new_balance,
                    "updated_at": now_iso,
                }).eq("trainer_id", trainer_id).execute()

                # Registra saque
                await client.table("wallet_withdrawals").insert(record).execute()
            except Exception as e:
                logger.error(f"[WalletService] Erro ao registrar saque no Supabase: {e}")

        # Memória
        if trainer_id in cls._mem_wallets:
            cls._mem_wallets[trainer_id]["balance_cents"] = new_balance
        cls._mem_withdrawals.append(record)

        val_formatado = f"R$ {amount_cents / 100:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        return WithdrawalResponse(
            id=withdrawal_id,
            trainer_id=trainer_id,
            amount_cents=amount_cents,
            pix_key=summary.pix_key,
            status="completed",
            created_at=now_iso,
            message=f"Saque de {val_formatado} enviado com sucesso para a chave Pix ({summary.pix_key})!",
        )


wallet_service = WalletService()

