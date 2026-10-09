import asyncio
import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from supabase import AsyncClient, create_async_client
from app.core.config import settings
from app.schemas.workout import (
    StudentResponse,
    StudentCreateRequest,
    StudentUpdateRequest,
    PrescriptionSaveRequest,
    PrescriptionSaveResponse,
    WorkoutPlanResponse,
    BiomechanicalAlertCreate,
    BiomechanicalAlertResponse,
)
from app.schemas.subscription import MySubscriptionResponse

logger = logging.getLogger(__name__)

# Fallback UUID padrão para ambiente demo/dev quando o trainer_id for literal
DEFAULT_DEMO_TRAINER_ID = "631e76b9-3cb0-454f-8fd9-1d450e5560d6"
DEFAULT_DEMO_STUDENT_ID = "0b988373-cd16-404f-b02c-c5e1aac7ec3f"


def is_valid_uuid(val: str) -> bool:
    try:
        uuid.UUID(str(val))
        return True
    except (ValueError, AttributeError, TypeError):
        return False


def to_valid_uuid_str(raw_id: str, default: Optional[str] = None) -> str:
    """
    Garante que qualquer identificador retornado seja um UUID válido.
    Converte strings literais (como 'current-trainer' ou 'st-1') em UUIDs
    determinísticos compatíveis com as constraints do PostgreSQL.
    """
    if not raw_id:
        return default or DEFAULT_DEMO_TRAINER_ID
    if is_valid_uuid(raw_id):
        return str(raw_id)
    if raw_id in ("current-trainer", "trainer-demo", "dev-user-0000-0000-000000000001"):
        return DEFAULT_DEMO_TRAINER_ID
    # Converte identificadores de teste para UUID determinístico via namespace
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, raw_id))


class SupabaseService:
    def __init__(self):
        self._client: Optional[AsyncClient] = None
        self._client_loop = None
        self._is_ready: bool = False
        
        # Fallback de memória para resiliência offline em testes
        self._mem_students: Dict[str, Dict[str, Any]] = {}
        self._mem_prescriptions: Dict[str, Dict[str, Any]] = {}
        self._mem_alerts: Dict[str, Dict[str, Any]] = {}
        self._mem_subscriptions: Dict[str, Dict[str, Any]] = {}
        self._mem_ai_usage: Dict[str, int] = {}
        self._mem_processed_events: Dict[str, Dict[str, Any]] = {}
        self._mem_checkout_sessions: Dict[str, Dict[str, Any]] = {}

    @staticmethod
    def _extract_rpc_row(res_data: Any) -> tuple[Dict[str, Any], Any]:
        if isinstance(res_data, dict):
            return res_data, res_data
        if isinstance(res_data, list):
            if not res_data:
                return {}, None
            first = res_data[0]
            if isinstance(first, dict):
                return first, first
            return {}, first
        if isinstance(res_data, (bool, int, float, str)):
            return {}, res_data
        return {}, None

    @staticmethod
    def _normalize_rpc_bool(value: Any, default: bool = False) -> bool:
        if isinstance(value, bool):
            return value
        if value is None:
            return default
        if isinstance(value, (int, float)):
            return bool(value)
        if isinstance(value, str):
            lowered = value.strip().lower()
            if lowered in {"true", "t", "1", "yes", "y", "success", "completed"}:
                return True
            if lowered in {"false", "f", "0", "no", "n", "null", "none", ""}:
                return False
        return bool(value) if value not in (None, "", "null", "none") else default

    @staticmethod
    def _is_production() -> bool:
        return settings.ENVIRONMENT.lower() == "production"

    def _raise_if_production(self, operation: str, error: Exception) -> None:
        if self._is_production():
            raise RuntimeError(f"Falha ao {operation} no Supabase.") from error

    def get_ai_generations_used(self, trainer_id: str) -> int:
        """Retorna o número de gerações de IA utilizadas pelo treinador no ciclo."""
        t_uuid = to_valid_uuid_str(trainer_id)
        return self._mem_ai_usage.get(trainer_id, self._mem_ai_usage.get(t_uuid, 0))

    def increment_ai_generations(self, trainer_id: str) -> int:
        """Incrementa o contador de gerações de IA consumidas."""
        t_uuid = to_valid_uuid_str(trainer_id)
        current = self.get_ai_generations_used(trainer_id) + 1
        self._mem_ai_usage[trainer_id] = current
        self._mem_ai_usage[t_uuid] = current
        return current

    async def get_monthly_ai_generations_used(self, trainer_id: str) -> int:
        if not self._is_production():
            return self.get_ai_generations_used(trainer_id)

        client = await self.get_client()
        trainer_uuid = to_valid_uuid_str(trainer_id)
        period_start = datetime.now(timezone.utc).date().replace(day=1).isoformat()
        try:
            res = await client.table("trainer_ai_usage")\
                .select("generations_used")\
                .eq("trainer_id", trainer_uuid)\
                .eq("period_start", period_start)\
                .limit(1)\
                .execute()
            return int(res.data[0]["generations_used"]) if res.data else 0
        except Exception as e:
            logger.error(f"Erro ao consultar uso mensal de IA: {e}")
            self._raise_if_production("consultar uso mensal de IA", e)
            return 0

    async def increment_monthly_ai_generations(self, trainer_id: str) -> int:
        if not self._is_production():
            return self.increment_ai_generations(trainer_id)

        client = await self.get_client()
        trainer_uuid = to_valid_uuid_str(trainer_id)
        period_start = datetime.now(timezone.utc).date().replace(day=1).isoformat()
        try:
            res = await client.rpc("increment_trainer_ai_usage", {
                "p_trainer_id": trainer_uuid,
                "p_period_start": period_start,
            }).execute()
            result = res.data
            if isinstance(result, list) and result:
                result = result[0]
            if isinstance(result, dict):
                result = result.get("increment_trainer_ai_usage")
            if result is None:
                raise RuntimeError("A função de uso mensal não retornou um contador.")
            return int(result)
        except Exception as e:
            logger.error(f"Erro ao incrementar uso mensal de IA: {e}")
            self._raise_if_production("incrementar uso mensal de IA", e)
            raise

    async def reserve_monthly_ai_quota(self, trainer_id: str, max_generations: int) -> bool:
        """
        Reserva uma cota de IA de forma atômica antes de chamar o modelo.
        Garante que chamadas concorrentes nunca ultrapassem a franquia mensal.
        Retorna True se reservado com sucesso; False se a cota do mês foi esgotada.
        """
        if not self._is_production():
            current = self.get_ai_generations_used(trainer_id)
            if max_generations >= 0 and current >= max_generations:
                return False
            self.increment_ai_generations(trainer_id)
            return True

        client = await self.get_client()
        if not client:
            if self._is_production():
                raise RuntimeError("Cliente Supabase indisponível para reservar cota de IA em produção.")
            current = self.get_ai_generations_used(trainer_id)
            if max_generations >= 0 and current >= max_generations:
                return False
            self.increment_ai_generations(trainer_id)
            return True

        trainer_uuid = to_valid_uuid_str(trainer_id)
        period_start = datetime.now(timezone.utc).date().replace(day=1).isoformat()
        try:
            res = await client.rpc("reserve_trainer_ai_usage", {
                "p_trainer_id": trainer_uuid,
                "p_period_start": period_start,
                "p_max_generations": max_generations,
            }).execute()
            result = res.data
            if isinstance(result, list) and result:
                result = result[0]
            if isinstance(result, dict):
                result = result.get("reserve_trainer_ai_usage")
            return bool(result)
        except Exception as e:
            if self._is_production():
                logger.error(f"Erro ao executar RPC reserve_trainer_ai_usage em produção: {e}")
                self._raise_if_production("reservar cota de IA via RPC", e)
            # Fallback exclusivo para ambiente de desenvolvimento local
            logger.warning(f"RPC reserve_trainer_ai_usage indisponível ({e}) em desenvolvimento. Usando fallback de consulta/incremento.")
            used = await self.get_monthly_ai_generations_used(trainer_id)
            if max_generations >= 0 and used >= max_generations:
                return False
            await self.increment_monthly_ai_generations(trainer_id)
            return True

    async def release_monthly_ai_quota(self, trainer_id: str) -> None:
        """Libera a cota previamente reservada caso a chamada ao modelo de IA falhe."""
        if not self._is_production():
            t_uuid = to_valid_uuid_str(trainer_id)
            for k in (trainer_id, t_uuid):
                if k in self._mem_ai_usage and self._mem_ai_usage[k] > 0:
                    self._mem_ai_usage[k] -= 1
            return

        client = await self.get_client()
        trainer_uuid = to_valid_uuid_str(trainer_id)
        period_start = datetime.now(timezone.utc).date().replace(day=1).isoformat()
        try:
            await client.rpc("release_trainer_ai_usage", {
                "p_trainer_id": trainer_uuid,
                "p_period_start": period_start,
            }).execute()
        except Exception as e:
            logger.warning(f"Erro ao liberar cota de IA pós-falha: {e}")

    async def save_checkout_session(self, session_data: Dict[str, Any]) -> None:
        """
        Persiste os metadados da sessão de checkout para sobreviver a restarts e trocas de worker.
        Garante que session_id, trainer_id, plan_id, billing_interval e valores fiquem duráveis.
        """
        session_id = session_data.get("session_id")
        if not session_id:
            return

        if not self._is_production():
            self._mem_checkout_sessions[session_id] = dict(session_data)
            return

        client = await self.get_client()
        if not client:
            raise RuntimeError("Cliente Supabase indisponível para persistir sessão de checkout em produção.")

        trainer_uuid = to_valid_uuid_str(session_data.get("trainer_id", ""))
        payload = {
            "session_id": session_id,
            "provider": session_data.get("provider", "asaas"),
            "provider_payment_id": session_data.get("asaas_id") or session_data.get("provider_payment_id"),
            "trainer_id": trainer_uuid,
            "plan_id": session_data.get("plan_id", "pro"),
            "billing_interval": session_data.get("billing_interval", "monthly"),
            "payment_method": session_data.get("payment_method", "pix"),
            "amount_cents": session_data.get("amount_cents", 0),
            "status": session_data.get("status", "pending"),
            "checkout_url": session_data.get("checkout_url"),
            "pix_copy_paste": session_data.get("pix_copy_paste"),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        try:
            await client.table("checkout_sessions").upsert(payload, on_conflict="session_id").execute()
            self._mem_checkout_sessions[session_id] = dict(session_data)
            logger.info(f"[Supabase] Sessão de checkout {session_id} persistida com sucesso.")
        except Exception as e:
            self._mem_checkout_sessions.pop(session_id, None)
            logger.error(f"Erro ao persistir sessão de checkout {session_id} no Supabase: {e}")
            self._raise_if_production("salvar sessão de checkout", e)

    async def get_checkout_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """
        Recupera os metadados completos da sessão de checkout (do banco persistido ou fallback).
        """
        if not session_id:
            return None

        # 1. Verifica memória local primeiro
        if session_id in self._mem_checkout_sessions:
            return self._mem_checkout_sessions[session_id]

        if not self._is_production():
            return None

        # 2. Em produção, busca no Supabase persistido
        client = await self.get_client()
        if not client:
            return None

        try:
            res = await client.table("checkout_sessions").select("*").eq("session_id", session_id).limit(1).execute()
            if res.data:
                session_row = res.data[0]
                self._mem_checkout_sessions[session_id] = session_row
                return session_row
        except Exception as e:
            logger.warning(f"Erro ao buscar sessão de checkout {session_id} no Supabase: {e}")

        return None

    async def update_subscription_status(self, trainer_id: str, new_status: str) -> None:
        """
        Atualiza o status da assinatura de um treinador no Supabase.
        Usado pelos webhooks de pagamento para registrar cancelamento ('canceled') ou
        inadimplência ('past_due') sem recalcular plano ou ciclo.
        Em desenvolvimento usa o fallback em memória.
        """
        if not self._is_production():
            t_uuid = to_valid_uuid_str(trainer_id)
            for key in (trainer_id, t_uuid):
                if key in self._mem_subscriptions:
                    sub = self._mem_subscriptions[key]
                    if isinstance(sub, dict):
                        sub["status"] = new_status
                    elif hasattr(sub, "status"):
                        sub.status = new_status
            logger.info(f"[Dev] Assinatura {trainer_id} -> status={new_status}")
            return

        client = await self.get_client()
        if not client:
            return
        trainer_uuid = to_valid_uuid_str(trainer_id)
        try:
            await client.table("subscriptions").update(
                {"status": new_status, "updated_at": datetime.now(timezone.utc).isoformat()}
            ).eq("trainer_id", trainer_uuid).eq("status", "active").execute()
            logger.info(f"[Supabase] Assinatura do treinador {trainer_uuid} atualizada para '{new_status}'.")
        except Exception as e:
            logger.error(f"Erro ao atualizar status de assinatura no Supabase: {e}")
            self._raise_if_production("atualizar status de assinatura", e)

    async def claim_webhook_event(
        self,
        event_id: str,
        provider: str,
        event_type: str,
        payload: Optional[Dict[str, Any]] = None,
        lease_seconds: int = 300,
        max_attempts: int = 5,
    ) -> Dict[str, Any]:
        """
        Reivindica um evento de webhook em modo durable lease.
        Retorna um dicionário estruturado com disposition, claim_token e metadata.
        Se não houver event_id, preserva a compatibilidade do comportamento legado.
        """
        generated_token = str(uuid.uuid4())
        if not event_id:
            return {
                "disposition": "claimed",
                "claim_token": generated_token,
                "event_id": event_id,
                "legacy": True,
            }

        if not self._is_production():
            record = self._mem_processed_events.get(event_id)
            now = datetime.now(timezone.utc)
            now_iso = now.isoformat()
            attempts = int(record.get("attempts", 0)) if record else 0
            lease = int(record.get("lease_seconds", lease_seconds)) if record else lease_seconds
            max_attempts_value = int(record.get("max_attempts", max_attempts)) if record else max_attempts

            if record and record.get("status") == "completed":
                return {"disposition": "duplicate", "claim_token": record.get("claim_token") or generated_token, "event_id": event_id}

            if record and record.get("status") in ("processing", "leased", "released"):
                claimed_at_raw = record.get("claimed_at")
                claimed_at = None
                if claimed_at_raw:
                    try:
                        claimed_at = datetime.fromisoformat(str(claimed_at_raw).replace("Z", "+00:00"))
                    except ValueError:
                        claimed_at = now
                lease_expired = bool(claimed_at and (now - claimed_at).total_seconds() >= lease)
                if lease_expired:
                    if attempts >= max_attempts_value:
                        record.update({
                            "status": "failed",
                            "last_error": "lease_expired",
                            "claim_token": None,
                            "failed_at": now_iso,
                        })
                        return {"disposition": "failed", "claim_token": record.get("claim_token") or generated_token, "event_id": event_id}
                    record.update({
                        "status": "processing",
                        "attempts": attempts + 1,
                        "provider": provider,
                        "event_type": event_type,
                        "payload": payload or record.get("payload") or {},
                        "claim_token": generated_token,
                        "claimed_at": now_iso,
                        "lease_seconds": lease_seconds,
                        "max_attempts": max_attempts,
                    })
                    return {"disposition": "claimed", "claim_token": generated_token, "event_id": event_id}
                if attempts >= max_attempts_value:
                    record.update({"status": "failed", "last_error": "max_attempts_reached", "claim_token": None})
                    return {"disposition": "failed", "claim_token": record.get("claim_token") or generated_token, "event_id": event_id}
                if record.get("status") == "released":
                    record.update({
                        "status": "processing",
                        "attempts": attempts + 1,
                        "provider": provider,
                        "event_type": event_type,
                        "payload": payload or record.get("payload") or {},
                        "claim_token": generated_token,
                        "claimed_at": now_iso,
                        "lease_seconds": lease_seconds,
                        "max_attempts": max_attempts,
                    })
                    return {"disposition": "claimed", "claim_token": generated_token, "event_id": event_id}
                return {"disposition": "busy", "claim_token": record.get("claim_token") or generated_token, "event_id": event_id}

            self._mem_processed_events[event_id] = {
                "event_id": event_id,
                "provider": provider,
                "event_type": event_type,
                "status": "processing",
                "payload": payload or {},
                "claim_token": generated_token,
                "attempts": 1,
                "claimed_at": now_iso,
                "lease_seconds": lease_seconds,
                "max_attempts": max_attempts,
            }
            return {"disposition": "claimed", "claim_token": generated_token, "event_id": event_id}

        client = await self.get_client()
        if not client:
            raise RuntimeError("Cliente Supabase indisponível para claim atômico de webhook em produção.")

        try:
            token = str(uuid.uuid4())
            res = await client.rpc(
                "claim_webhook_event_v2",
                {
                    "p_event_id": event_id,
                    "p_provider": provider,
                    "p_event_type": event_type,
                    "p_payload": payload or {},
                    "p_token": token,
                    "p_lease_seconds": lease_seconds,
                    "p_max_attempts": max_attempts,
                },
            ).execute()
            rows = res.data if isinstance(res.data, list) else ([res.data] if res.data else [])
            if not rows:
                raise RuntimeError(f"claim_webhook_event_v2 retornou vazio para {event_id}: contrato/integridade inválidos.")
            row = rows[0] if rows else {}
            disposition = str(row.get("disposition") or "failed").lower()
            claim_token = row.get("claim_token") or token
            return {"disposition": disposition, "claim_token": str(claim_token), "event_id": event_id}
        except Exception as e:
            logger.warning(f"RPC claim_webhook_event_v2 falhou para {event_id}: {e}")
            raise

    async def claim_webhook_event_v2(
        self,
        event_id: str,
        provider: str,
        event_type: str,
        payload: Optional[Dict[str, Any]] = None,
        lease_seconds: int = 300,
        max_attempts: int = 5,
    ) -> Dict[str, Any]:
        """Alias explícito para o contrato v2 de durable lease."""
        return await self.claim_webhook_event(
            event_id=event_id,
            provider=provider,
            event_type=event_type,
            payload=payload,
            lease_seconds=lease_seconds,
            max_attempts=max_attempts,
        )

    async def complete_paid_checkout_session_v2(
        self,
        session_id: Optional[str],
        event_id: Optional[str] = None,
        claim_token: Optional[str] = None,
        provider_payment_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Completa checkout pago de forma idempotente e atômica em produção e em memória."""
        if not session_id:
            return {"session_id": session_id, "paid": False, "completed": False, "disposition": "failed", "error": "missing_session_id"}

        if bool(event_id) != bool(claim_token):
            return {"session_id": session_id, "paid": False, "completed": False, "disposition": "failed", "error": "invalid_event_claim_pair"}

        token_uuid = None
        if claim_token is not None:
            try:
                token_uuid = uuid.UUID(str(claim_token))
            except (TypeError, ValueError, AttributeError):
                return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "invalid_claim_token"}

        if not self._is_production():
            session = self._mem_checkout_sessions.get(session_id)
            if not session:
                from app.services.payment_service import PaymentProviderService
                session = PaymentProviderService._PENDING_ORDERS.get(session_id)
            if session is None:
                return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "session_not_found"}

            current_status = str(session.get("status", "pending") or "pending").lower()
            trainer_id = session.get("trainer_id")
            plan_id = session.get("plan_id")
            billing_interval = str(session.get("billing_interval") or "monthly").lower()
            if billing_interval not in {"monthly", "yearly"}:
                return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "invalid_billing_interval"}

            if event_id:
                record = self._mem_processed_events.get(event_id)
                if record is None or str(record.get("status", "")).lower() != "processing":
                    return {
                        "session_id": session_id,
                        "event_id": event_id,
                        "paid": False,
                        "completed": False,
                        "disposition": "failed",
                        "error": "invalid_event_claim_pair",
                    }
                record_claim = record.get("claim_token")
                if record_claim is None or str(record_claim) != str(token_uuid):
                    return {
                        "session_id": session_id,
                        "event_id": event_id,
                        "paid": False,
                        "completed": False,
                        "disposition": "failed",
                        "error": "invalid_claim_token",
                    }

            if current_status in {"failed", "canceled", "cancelled", "expired"}:
                return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "checkout_session_status_not_activable"}

            if current_status == "pending":
                if not trainer_id or not plan_id:
                    return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "missing_checkout_metadata"}

                payment_method = str(session.get("payment_method") or session.get("provider") or "asaas").strip() or "asaas"
                await self.activate_subscription(
                    trainer_id=str(trainer_id),
                    plan_id=str(plan_id),
                    billing_interval=billing_interval,
                    payment_method=payment_method,
                )

                session["status"] = "paid"
                session["paid"] = True
                session["updated_at"] = datetime.now(timezone.utc).isoformat()
                if provider_payment_id:
                    session["provider_payment_id"] = provider_payment_id
            elif provider_payment_id:
                session["provider_payment_id"] = provider_payment_id
                session["updated_at"] = datetime.now(timezone.utc).isoformat()

            if event_id:
                record = self._mem_processed_events.setdefault(event_id, {})
                record.update({
                    "event_id": event_id,
                    "status": "completed",
                    "completed_at": datetime.now(timezone.utc).isoformat(),
                    "claim_token": None,
                    "last_error": None,
                })

            return {"session_id": session_id, "event_id": event_id, "paid": True, "completed": True, "disposition": "completed"}

        client = await self.get_client()
        if not client:
            return {"session_id": session_id, "paid": False, "completed": False, "disposition": "failed", "error": "supabase_unavailable"}

        try:
            res = await client.rpc(
                "complete_paid_checkout_session_v2",
                {
                    "p_session_id": session_id,
                    "p_event_id": event_id,
                    "p_claim_token": token_uuid,
                    "p_provider_payment_id": provider_payment_id,
                },
            ).execute()
            row, payload = self._extract_rpc_row(res.data)
            ok = False
            if isinstance(payload, bool):
                ok = payload
            elif isinstance(payload, dict):
                ok = self._normalize_rpc_bool(payload.get("completed", payload.get("success", payload.get("paid"))), default=False)
            elif isinstance(payload, str):
                ok = self._normalize_rpc_bool(payload, default=False)
            elif isinstance(payload, (int, float)):
                ok = self._normalize_rpc_bool(payload, default=False)
            elif row:
                ok = self._normalize_rpc_bool(row.get("completed", row.get("success", row.get("paid"))), default=False)
            disposition = "completed" if ok else "failed"
            if isinstance(row, dict) and row.get("disposition"):
                disposition = str(row.get("disposition", disposition)).lower()
            return {
                "session_id": session_id,
                "event_id": event_id,
                "paid": ok,
                "completed": ok,
                "disposition": disposition,
                "error": row.get("error") if isinstance(row, dict) else None,
            }
        except Exception as e:
            logger.warning(f"Falha ao concluir checkout pago {session_id} via RPC v2: {e}")
            return {"session_id": session_id, "paid": False, "completed": False, "event_id": event_id, "disposition": "failed", "error": "rpc_complete_unavailable"}

    async def release_webhook_event_v2(
        self,
        event_id: str,
        token: Optional[str] = None,
        error: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Libera somente o lease atual para retry, preservando contagem de tentativas."""
        if not event_id:
            return {"released": False, "event_id": event_id, "claim_token": token}

        if not self._is_production():
            record = self._mem_processed_events.get(event_id)
            if not record:
                return {"released": True, "event_id": event_id, "claim_token": token, "legacy": True}
            if token and record.get("claim_token") and str(record.get("claim_token")) != str(token):
                return {"released": False, "event_id": event_id, "claim_token": token}

            attempts = int(record.get("attempts", 0) or 0)
            max_attempts = int(record.get("max_attempts", 5) or 5)
            record["last_error"] = error
            record["released_at"] = datetime.now(timezone.utc).isoformat()
            if attempts >= max_attempts:
                record["status"] = "failed"
                record["claim_token"] = None
                return {"released": True, "event_id": event_id, "claim_token": token, "disposition": "failed"}
            record["status"] = "released"
            record["claim_token"] = None
            return {"released": True, "event_id": event_id, "claim_token": token}

        client = await self.get_client()
        if not client:
            return {"released": False, "event_id": event_id, "claim_token": token}

        try:
            res = await client.rpc(
                "release_webhook_event_v2",
                {
                    "p_event_id": event_id,
                    "p_token": token,
                    "p_error": error,
                },
            ).execute()
            row, payload = self._extract_rpc_row(res.data)
            released = False
            if isinstance(payload, bool):
                released = payload
            elif isinstance(payload, dict):
                released = self._normalize_rpc_bool(payload.get("released", payload.get("success")), default=False)
            elif isinstance(payload, str):
                released = self._normalize_rpc_bool(payload, default=False)
            elif isinstance(payload, (int, float)):
                released = self._normalize_rpc_bool(payload, default=False)
            elif row:
                released = self._normalize_rpc_bool(row.get("released", row.get("success")), default=False)
            return {"released": released, "event_id": event_id, "claim_token": token}
        except Exception as e:
            logger.warning(f"Falha ao liberar claim de webhook {event_id} via RPC v2: {e}")
            return {"released": False, "event_id": event_id, "claim_token": token}

    async def release_webhook_claim(self, event_id: str) -> None:
        """Alias retrocompatível para liberar o claim de um evento."""
        await self.release_webhook_event_v2(event_id=event_id)

    async def complete_subscription_webhook_v2(
        self,
        event_id: str,
        token: Optional[str],
        action: str,
        trainer_id: Optional[str] = None,
        plan_id: Optional[str] = None,
        billing_interval: str = "monthly",
        payment_method: str = "asaas",
    ) -> Dict[str, Any]:
        """Finaliza o evento de webhook de forma atômica e persiste a ação do pagamento."""
        if not event_id:
            return {"event_id": event_id, "disposition": "completed", "action": action}

        if not self._is_production():
            record = self._mem_processed_events.get(event_id, {})
            if token and record.get("claim_token") and str(record.get("claim_token")) != str(token):
                return {"event_id": event_id, "disposition": "failed", "error": "invalid_claim_token"}

            if action != "none":
                if not trainer_id or str(trainer_id).strip() == "":
                    return {"event_id": event_id, "disposition": "failed", "error": "missing_trainer_id"}
                try:
                    uuid.UUID(str(trainer_id))
                except (TypeError, ValueError, AttributeError):
                    return {"event_id": event_id, "disposition": "failed", "error": "invalid_trainer_id"}
                if action == "activate":
                    if not plan_id or str(plan_id).strip() == "":
                        return {"event_id": event_id, "disposition": "failed", "error": "missing_plan_id"}
                elif action in {"past_due", "canceled"}:
                    plan_id = None

            if action == "activate" and trainer_id and plan_id:
                self._mem_subscriptions[str(trainer_id)] = {
                    "trainer_id": trainer_id,
                    "plan_id": plan_id,
                    "status": "active",
                    "billing_interval": billing_interval,
                    "payment_provider": payment_method,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            elif action == "past_due" and trainer_id:
                self._mem_subscriptions[str(trainer_id)] = {
                    **self._mem_subscriptions.get(str(trainer_id), {}),
                    "trainer_id": trainer_id,
                    "status": "past_due",
                    "billing_interval": billing_interval,
                    "payment_provider": payment_method,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            elif action == "canceled" and trainer_id:
                self._mem_subscriptions[str(trainer_id)] = {
                    **self._mem_subscriptions.get(str(trainer_id), {}),
                    "trainer_id": trainer_id,
                    "status": "canceled",
                    "billing_interval": billing_interval,
                    "payment_provider": payment_method,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }

            record.update({
                "event_id": event_id,
                "status": "completed",
                "completed_at": datetime.now(timezone.utc).isoformat(),
                "action": action,
                "trainer_id": trainer_id,
                "plan_id": plan_id,
                "billing_interval": billing_interval,
                "payment_method": payment_method,
                "claim_token": token,
            })
            self._mem_processed_events[event_id] = record
            return {"event_id": event_id, "disposition": "completed", "action": action}

        client = await self.get_client()
        if not client:
            return {"event_id": event_id, "disposition": "failed", "error": "supabase_unavailable"}

        if action != "none":
            if not trainer_id or str(trainer_id).strip() == "":
                return {"event_id": event_id, "disposition": "failed", "error": "missing_trainer_id"}
            try:
                uuid.UUID(str(trainer_id))
            except (TypeError, ValueError, AttributeError):
                return {"event_id": event_id, "disposition": "failed", "error": "invalid_trainer_id"}
            if action == "activate":
                if not plan_id or str(plan_id).strip() == "":
                    return {"event_id": event_id, "disposition": "failed", "error": "missing_plan_id"}
            elif action in {"past_due", "canceled"}:
                plan_id = None

        try:
            res = await client.rpc(
                "complete_subscription_webhook_v2",
                {
                    "p_event_id": event_id,
                    "p_token": token,
                    "p_action": action,
                    "p_trainer_id": trainer_id,
                    "p_plan_id": plan_id,
                    "p_billing_interval": billing_interval,
                    "p_payment_method": payment_method,
                },
            ).execute()
            row, payload = self._extract_rpc_row(res.data)
            disposition = "failed"
            completed = False
            if isinstance(payload, bool):
                completed = payload
            elif isinstance(payload, dict):
                completed = self._normalize_rpc_bool(payload.get("completed", payload.get("success")), default=False)
            elif isinstance(payload, str):
                completed = self._normalize_rpc_bool(payload, default=False)
            elif isinstance(payload, (int, float)):
                completed = self._normalize_rpc_bool(payload, default=False)
            elif row:
                completed = self._normalize_rpc_bool(row.get("completed", row.get("success")), default=False)
            if row and row.get("disposition"):
                disposition = str(row.get("disposition", "failed")).lower()
            elif completed:
                disposition = "completed"
            return {
                "event_id": event_id,
                "disposition": disposition,
                "action": str(row.get("action") or action).lower(),
            }
        except Exception as e:
            logger.warning(f"Falha ao completar evento de assinatura {event_id} via RPC v2: {e}")
            return {"event_id": event_id, "disposition": "failed", "error": "rpc_complete_unavailable"}

    async def is_event_processed(self, event_id: str) -> bool:
        """Verifica se um evento de webhook já foi processado anteriormente (idempotência)."""
        if not event_id:
            return False

        if not self._is_production():
            return event_id in self._mem_processed_events

        client = await self.get_client()
        if not client:
            return event_id in self._mem_processed_events

        try:
            res = await client.table("processed_webhook_events")\
                .select("event_id")\
                .eq("event_id", event_id)\
                .limit(1)\
                .execute()
            return bool(res.data)
        except Exception as e:
            logger.warning(f"Erro ao verificar idempotência de webhook {event_id}: {e}")
            # Em caso de falha de conexão, checa fallback em memória para não bloquear
            return event_id in self._mem_processed_events

    async def record_processed_event(
        self,
        event_id: str,
        provider: str,
        event_type: str,
        payload: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Registra um evento de webhook como processado de forma atômica e persistente."""
        if not event_id:
            return False

        event_record = {
            "event_id": event_id,
            "provider": provider,
            "event_type": event_type,
            "status": "completed",
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }
        self._mem_processed_events[event_id] = event_record

        if not self._is_production():
            return True

        client = await self.get_client()
        if not client:
            return True

        try:
            await client.table("processed_webhook_events").upsert({
                "event_id": event_id,
                "provider": provider,
                "event_type": event_type,
                "payload": payload or {},
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }, on_conflict="event_id").execute()
            logger.info(f"[Supabase] Evento de webhook {event_id} ({provider}) consolidado com sucesso.")
            return True
        except Exception as e:
            logger.warning(f"Erro ao persistir evento de webhook {event_id} no Supabase: {e}")
            return False

    async def get_client(self) -> Optional[AsyncClient]:
        """Obtém ou inicializa o cliente assíncrono do Supabase de forma segura."""
        current_loop = None
        try:
            current_loop = asyncio.get_running_loop()
        except RuntimeError:
            pass

        if self._client is not None and self._client_loop is current_loop and current_loop and not current_loop.is_closed():
            return self._client

        key = settings.SUPABASE_SECRET_KEY or settings.SUPABASE_KEY
        url = settings.SUPABASE_URL

        if not url or not key:
            if self._is_production():
                raise RuntimeError("Supabase URL ou chave não configurados em produção.")
            logger.warning("Supabase URL ou Key não configurados. Operando em modo de fallback em memória.")
            return None

        try:
            self._client = await create_async_client(url, key)
            self._client_loop = current_loop
            self._is_ready = True
            logger.info("Cliente assíncrono do Supabase conectado com sucesso.")
            return self._client
        except Exception as e:
            logger.error(f"Falha ao conectar com o Supabase: {e}. Operando em modo de fallback em memória.")
            self._raise_if_production("conectar", e)
            return None

    # =========================================================================
    # ALUNOS (PROFILES + ANAMNESIS)
    # =========================================================================

    async def create_student_invite(
        self,
        *,
        token: str,
        trainer_id: str,
        email: str,
        phone: Optional[str],
        full_name: str,
        objective: str,
        injuries_or_restrictions: str,
        channel: str = "email",
    ) -> Dict[str, str]:
        client = await self.get_client()
        if not client:
            if self._is_production():
                raise RuntimeError("Supabase indisponível; o convite não foi persistido.")
            return {"id": str(uuid.uuid4()), "token": token, "expires_at": ""}

        try:
            result = await client.rpc("create_student_invite", {
                "p_token": token,
                "p_trainer_id": to_valid_uuid_str(trainer_id),
                "p_channel": channel,
                "p_target_email": email.strip().lower(),
                "p_target_phone": phone,
                "p_target_name": full_name,
                "p_objective": objective,
                "p_injuries_or_restrictions": injuries_or_restrictions,
            }).execute()
            if not result.data:
                raise RuntimeError("O banco não retornou o convite criado.")
            return result.data[0]
        except Exception as e:
            logger.error("Erro ao reservar vaga e criar convite pendente no Supabase: %s", e)
            self._raise_if_production("criar convite pendente", e)
            raise

    async def count_trainer_occupied_slots(self, trainer_id: str, exclude_student_id: Optional[str] = None) -> int:
        """Conta quantos alunos ativos/pendentes consomem cota do treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)

        mem_count = sum(
            1 for sid, s in self._mem_students.items()
            if sid != exclude_student_id
            and s.get("trainer_id") in (trainer_id, t_uuid, "current-trainer")
            and str(s.get("status", "")).lower() not in ("arquivado", "inativo", "canceled")
        )

        if is_valid_uuid(trainer_id):
            client = await self.get_client()
            if client:
                try:
                    res = await client.table("profiles")\
                        .select("id, subscription_status")\
                        .eq("trainer_id", t_uuid)\
                        .eq("role", "client")\
                        .execute()
                    occupied = [
                        p for p in res.data
                        if str(p.get("subscription_status") or "active").lower()
                        not in ("arquivado", "inativo", "canceled")
                        and p.get("id") != exclude_student_id
                    ]
                    pending_res = await client.table("invite_tokens")\
                        .select("id")\
                        .eq("trainer_id", t_uuid)\
                        .is_("used_at", "null")\
                        .gt("expires_at", datetime.now(timezone.utc).isoformat())\
                        .execute()
                    total_occupied = len(occupied) + len(pending_res.data or [])
                    return total_occupied if self._is_production() else max(total_occupied, mem_count)
                except Exception as e:
                    logger.warning(f"Erro ao contar alunos no Supabase ({e}).")
                    self._raise_if_production("contar alunos", e)

        return mem_count

    async def list_students(self, trainer_id: str) -> List[StudentResponse]:
        """Lista os alunos vinculados ao personal trainer."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()
        students: List[StudentResponse] = []

        if client:
            try:
                # 1. Busca perfis de clientes do treinador
                prof_res = await client.table("profiles")\
                    .select("*")\
                    .eq("trainer_id", t_uuid)\
                    .eq("role", "client")\
                    .order("created_at", desc=True)\
                    .execute()

                client_ids = [p["id"] for p in prof_res.data]

                # 2. Busca anamneses e treinos ativos em paralelo
                anam_map = {}
                if client_ids:
                    anam_res = await client.table("anamnesis")\
                        .select("client_id, objective, injuries_or_restrictions")\
                        .in_("client_id", client_ids)\
                        .execute()
                    for a in anam_res.data:
                        anam_map[a["client_id"]] = a

                workout_map = {}
                if client_ids:
                    work_res = await client.table("workouts")\
                        .select("client_id, title, is_active")\
                        .in_("client_id", client_ids)\
                        .eq("is_active", True)\
                        .execute()
                    for w in work_res.data:
                        workout_map[w["client_id"]] = w

                for p in prof_res.data:
                    cid = p["id"]
                    anam = anam_map.get(cid, {})
                    work = workout_map.get(cid)

                    # Status mapping
                    sub_status = p.get("subscription_status", "trial")
                    if sub_status == "canceled":
                        ui_status = "Arquivado"
                    elif sub_status == "active":
                        ui_status = "Ativo"
                    else:
                        ui_status = "Pendente Confirmação" if not work else "Ativo"

                    students.append(StudentResponse(
                        id=cid,
                        full_name=p.get("full_name") or "Aluno",
                        email=p.get("phone") and f"aluno.{cid[:8]}@shaipados.com" or f"aluno.{cid[:8]}@shaipados.com",
                        phone=p.get("phone"),
                        goal=anam.get("objective") or "Hipertrofia Muscular",
                        status=ui_status,
                        trainer_id=t_uuid,
                        created_at=p.get("created_at") or datetime.now(timezone.utc).isoformat(),
                        has_active_prescription=work is not None,
                        last_session="Sessão recente" if work else "Aguardando treino",
                        active_split=work.get("title") if work else None,
                        injuries_or_restrictions=anam.get("injuries_or_restrictions") or "Nenhuma restrição relatada",
                    ))

                invite_res = await client.table("invite_tokens")\
                    .select("id, target_email, target_phone, target_name, objective, injuries_or_restrictions, created_at")\
                    .eq("trainer_id", t_uuid)\
                    .is_("used_at", "null")\
                    .gt("expires_at", datetime.now(timezone.utc).isoformat())\
                    .order("created_at", desc=True)\
                    .execute()
                for invite in invite_res.data or []:
                    students.append(StudentResponse(
                        id=invite["id"],
                        full_name=invite.get("target_name") or "Novo aluno",
                        email=invite.get("target_email") or "",
                        phone=invite.get("target_phone"),
                        goal=invite.get("objective") or "Hipertrofia Muscular",
                        status="Convite Pendente",
                        trainer_id=t_uuid,
                        created_at=invite.get("created_at") or datetime.now(timezone.utc).isoformat(),
                        has_active_prescription=False,
                        last_session="Aguardando cadastro",
                        active_split="Convite enviado",
                        injuries_or_restrictions=invite.get("injuries_or_restrictions"),
                    ))

                return students
            except Exception as e:
                logger.warning(f"Erro ao listar alunos no Supabase ({e}). Utilizando fallback.")
                self._raise_if_production("listar alunos", e)

        # Fallback local
        for s in self._mem_students.values():
            if s.get("trainer_id") in (trainer_id, t_uuid, "current-trainer"):
                students.append(StudentResponse(**s))
        return students

    async def get_student_by_id(self, student_id: str) -> Optional[StudentResponse]:
        """Busca um aluno específico por ID."""
        if not self._is_production() and student_id in self._mem_students:
            return StudentResponse(**self._mem_students[student_id])

        s_uuid = to_valid_uuid_str(student_id)
        if is_valid_uuid(student_id):
            client = await self.get_client()
            if client:
                try:
                    res = await client.table("profiles").select("*").eq("id", s_uuid).execute()
                    if res.data:
                        p = res.data[0]
                        sub_st = p.get("subscription_status", "trial")
                        ui_st = "Arquivado" if sub_st == "canceled" else "Ativo"
                        return StudentResponse(
                            id=p["id"],
                            full_name=p.get("full_name") or "Aluno",
                            email=f"aluno.{p['id'][:8]}@shaipados.com",
                            phone=p.get("phone"),
                            goal="Hipertrofia Muscular",
                            status=ui_st,
                            trainer_id=p.get("trainer_id") or "current-trainer",
                            created_at=p.get("created_at") or datetime.now(timezone.utc).isoformat(),
                            has_active_prescription=False,
                        )
                except Exception as e:
                    logger.error(f"Erro ao buscar aluno por ID no Supabase: {e}")
                    self._raise_if_production("buscar aluno", e)
        return None

    async def create_student(self, trainer_id: str, req: StudentCreateRequest) -> StudentResponse:
        """Cadastra um novo aluno gerando usuário e perfil no Supabase."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()
        is_production = settings.ENVIRONMENT.lower() == "production"

        if client is None and is_production:
            raise RuntimeError("Supabase indisponível; o cadastro do aluno não foi persistido.")

        if client:
            student_id = None
            try:
                # 1. Cria usuário no Supabase Auth via Admin API
                temp_password = f"TempPass_{uuid.uuid4().hex[:8]}!"
                user_res = await client.auth.admin.create_user({
                    "email": req.email,
                    "password": temp_password,
                    "email_confirm": True,
                    "user_metadata": {
                        "full_name": req.full_name,
                        "role": "client",
                        "phone": req.phone,
                        "trainer_id": t_uuid,
                    }
                })
                student_id = user_res.user.id

                # 2. Garante que o profile existe (o trigger handle_new_user já deve ter criado)
                await client.table("profiles").upsert({
                    "id": student_id,
                    "role": "client",
                    "full_name": req.full_name,
                    "phone": req.phone,
                    "trainer_id": t_uuid,
                    "subscription_status": "trial",
                }).execute()

                # 3. Registra a anamnese inicial
                await client.table("anamnesis").insert({
                    "client_id": student_id,
                    "trainer_id": t_uuid,
                    "objective": req.goal or "Hipertrofia Muscular",
                    "training_level": "Iniciante",
                    "days_per_week": 3,
                    "workout_location": "Academia Convencional",
                    "injuries_or_restrictions": req.injuries_or_restrictions or "Nenhuma restrição relatada.",
                }).execute()

                student_resp = StudentResponse(
                    id=student_id,
                    full_name=req.full_name,
                    email=req.email,
                    phone=req.phone,
                    goal=req.goal or "Hipertrofia Muscular",
                    status="Pendente Confirmação",
                    trainer_id=trainer_id,
                    created_at=datetime.now(timezone.utc).isoformat(),
                    has_active_prescription=False,
                    last_session="Convite gerado",
                    active_split="Aguardando confirmação",
                    injuries_or_restrictions=req.injuries_or_restrictions,
                )
                if not is_production:
                    self._mem_students[student_id] = student_resp.model_dump()
                return student_resp
            except Exception as e:
                logger.error(f"Erro ao criar aluno no Supabase Auth/DB: {e}")
                if is_production:
                    if student_id:
                        try:
                            await client.auth.admin.delete_user(student_id)
                        except Exception as cleanup_error:
                            logger.error(f"Falha ao remover usuário parcialmente criado: {cleanup_error}")
                    raise RuntimeError("Falha ao persistir o cadastro do aluno no Supabase.") from e

        # Fallback local
        mock_id = f"st-{uuid.uuid4().hex[:6]}"
        student_resp = StudentResponse(
            id=mock_id,
            full_name=req.full_name,
            email=req.email,
            phone=req.phone,
            goal=req.goal or "Hipertrofia Muscular",
            status="Pendente Confirmação",
            trainer_id=trainer_id,
            created_at=datetime.now(timezone.utc).isoformat(),
            has_active_prescription=False,
            last_session="Convite enviado",
            active_split="Aguardando confirmação",
            injuries_or_restrictions=req.injuries_or_restrictions,
        )
        self._mem_students[mock_id] = student_resp.model_dump()
        return student_resp

    async def update_student(self, student_id: str, trainer_id: str, req: StudentUpdateRequest) -> Optional[StudentResponse]:
        """Atualiza os dados de um aluno no Supabase."""
        s_uuid = to_valid_uuid_str(student_id)
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()

        if client and is_valid_uuid(student_id):
            try:
                prof_updates = {}
                if req.full_name is not None:
                    prof_updates["full_name"] = req.full_name
                if req.phone is not None:
                    prof_updates["phone"] = req.phone
                if req.status is not None:
                    prof_updates["subscription_status"] = "canceled" if req.status == "Arquivado" else "active"

                if prof_updates:
                    await client.table("profiles").update(prof_updates).eq("id", s_uuid).execute()

                anam_updates = {}
                if req.goal is not None:
                    anam_updates["objective"] = req.goal
                if req.injuries_or_restrictions is not None:
                    anam_updates["injuries_or_restrictions"] = req.injuries_or_restrictions

                if anam_updates:
                    await client.table("anamnesis").update(anam_updates).eq("client_id", s_uuid).execute()

            except Exception as e:
                logger.error(f"Erro ao atualizar aluno no Supabase: {e}")
                self._raise_if_production("atualizar aluno", e)

        # Atualiza fallback de memória
        if self._is_production() and is_valid_uuid(student_id):
            student = await self.get_student_by_id(student_id)
            if student is None:
                return None
            updates = {
                key: value
                for key, value in {
                    "full_name": req.full_name,
                    "phone": req.phone,
                    "goal": req.goal,
                    "injuries_or_restrictions": req.injuries_or_restrictions,
                    "status": req.status,
                }.items()
                if value is not None
            }
            return student.model_copy(update=updates)

        if student_id in self._mem_students:
            curr = self._mem_students[student_id]
            if req.full_name is not None: curr["full_name"] = req.full_name
            if req.email is not None: curr["email"] = req.email
            if req.phone is not None: curr["phone"] = req.phone
            if req.goal is not None: curr["goal"] = req.goal
            if req.injuries_or_restrictions is not None: curr["injuries_or_restrictions"] = req.injuries_or_restrictions
            if req.status is not None: curr["status"] = req.status
            return StudentResponse(**curr)

        return None

    async def update_student_status(self, student_id: str, trainer_id: str, new_status: str) -> Optional[StudentResponse]:
        """Altera o status do aluno (Ativo / Arquivado / Pendente)."""
        req = StudentUpdateRequest(status=new_status)
        return await self.update_student(student_id, trainer_id, req)

    async def delete_student(self, student_id: str, trainer_id: str) -> bool:
        """Exclui um aluno do sistema."""
        s_uuid = to_valid_uuid_str(student_id)
        client = await self.get_client()

        if client and is_valid_uuid(student_id):
            try:
                # O DELETE CASCADE do schema Postgres remove automaticamente anamnesis, workouts e logs
                res = await client.table("profiles").delete().eq("id", s_uuid).execute()
                if self._is_production() and not res.data:
                    return False
                try:
                    await client.auth.admin.delete_user(s_uuid)
                except Exception:
                    pass
            except Exception as e:
                logger.error(f"Erro ao excluir aluno do Supabase: {e}")
                self._raise_if_production("excluir aluno", e)

        if not self._is_production() and student_id in self._mem_students:
            del self._mem_students[student_id]
            return True
        return True

    # =========================================================================
    # PRESCRIÇÕES E FICHAS DE TREINO (WORKOUTS)
    # =========================================================================

    async def save_prescription(self, trainer_id: str, req: PrescriptionSaveRequest) -> PrescriptionSaveResponse:
        """Salva uma nova prescrição ativa para o aluno, desativando as anteriores."""
        t_uuid = to_valid_uuid_str(req.trainer_id or trainer_id)
        c_uuid = to_valid_uuid_str(req.client_id)
        client = await self.get_client()

        prescription_id = str(uuid.uuid4())

        if client and is_valid_uuid(c_uuid) and is_valid_uuid(t_uuid):
            try:
                # 1. Desativa prescrições anteriores deste aluno
                await client.table("workouts")\
                    .update({"is_active": False})\
                    .eq("client_id", c_uuid)\
                    .execute()

                # 2. Insere a nova prescrição ativa
                plan_dict = req.plan.model_dump()
                res = await client.table("workouts").insert({
                    "id": prescription_id,
                    "client_id": c_uuid,
                    "trainer_id": t_uuid,
                    "title": req.plan.workout_plan_title,
                    "notes_for_trainer": req.notes or req.plan.notes_for_trainer,
                    "plan_json": plan_dict,
                    "is_active": True,
                }).execute()

                # 3. Atualiza o status do aluno para Ativo
                await client.table("profiles").update({"subscription_status": "active"}).eq("id", c_uuid).execute()

                if res.data:
                    prescription_id = res.data[0]["id"]
            except Exception as e:
                logger.error(f"Erro ao salvar prescrição no Supabase: {e}")
                self._raise_if_production("salvar prescrição", e)

        # Armazena também em memória
        presc_entry = {
            "id": prescription_id,
            "client_id": req.client_id,
            "trainer_id": t_uuid,
            "workout_plan_title": req.plan.workout_plan_title,
            "splits_count": len(req.plan.splits),
            "is_active": True,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "plan_json": req.plan.model_dump(),
        }
        if not self._is_production():
            self._mem_prescriptions[req.client_id] = presc_entry

        return PrescriptionSaveResponse(
            id=prescription_id,
            client_id=req.client_id,
            trainer_id=t_uuid,
            workout_plan_title=req.plan.workout_plan_title,
            splits_count=len(req.plan.splits),
            is_active=True,
            created_at=presc_entry["created_at"],
            status="active",
            message=f"Ficha de treino '{req.plan.workout_plan_title}' aprovada e ativada com sucesso.",
        )

    async def get_active_prescription(self, client_id: str) -> Optional[WorkoutPlanResponse]:
        """Recupera a prescrição ativa do aluno."""
        c_uuid = to_valid_uuid_str(client_id)
        client = await self.get_client()

        if client and is_valid_uuid(c_uuid):
            try:
                res = await client.table("workouts")\
                    .select("plan_json")\
                    .eq("client_id", c_uuid)\
                    .eq("is_active", True)\
                    .order("created_at", desc=True)\
                    .limit(1)\
                    .execute()

                if res.data and res.data[0].get("plan_json"):
                    return WorkoutPlanResponse(**res.data[0]["plan_json"])
            except Exception as e:
                logger.error(f"Erro ao buscar prescrição ativa no Supabase: {e}")
                self._raise_if_production("buscar prescrição", e)

        # Fallback de memória
        if not self._is_production() and client_id in self._mem_prescriptions:
            entry = self._mem_prescriptions[client_id]
            if entry.get("is_active") and "plan_json" in entry:
                return WorkoutPlanResponse(**entry["plan_json"])

        return None

    # =========================================================================
    # ALERTAS BIOMECÂNICOS (ADAPTATION_LOGS)
    # =========================================================================

    async def create_biomechanical_alert(self, alert: BiomechanicalAlertCreate) -> BiomechanicalAlertResponse:
        """Registra uma substituição de exercício ou alerta biomecânico."""
        t_uuid = to_valid_uuid_str(alert.trainer_id)
        c_uuid = to_valid_uuid_str(alert.student_id)
        client = await self.get_client()

        alert_id = str(uuid.uuid4())
        created_at_str = datetime.now(timezone.utc).isoformat()

        if client and is_valid_uuid(c_uuid) and is_valid_uuid(t_uuid):
            try:
                details = {
                    "student_name": alert.student_name,
                    "pain_location": alert.pain_location,
                    "severity": alert.severity,
                    "details": alert.details or {},
                }
                res = await client.table("adaptation_logs").insert({
                    "id": alert_id,
                    "client_id": c_uuid,
                    "trainer_id": t_uuid,
                    "original_exercise": alert.original_exercise,
                    "adapted_exercise": alert.adapted_exercise,
                    "reason": alert.reason,
                    "adaptation_details": details,
                    "viewed_by_trainer": False,
                }).execute()
                if res.data:
                    alert_id = res.data[0]["id"]
            except Exception as e:
                logger.error(f"Erro ao salvar alerta no Supabase: {e}")
                self._raise_if_production("salvar alerta biomecânico", e)

        resp = BiomechanicalAlertResponse(
            id=alert_id,
            student_id=alert.student_id,
            student_name=alert.student_name,
            trainer_id=t_uuid,
            original_exercise=alert.original_exercise,
            adapted_exercise=alert.adapted_exercise,
            reason=alert.reason,
            pain_location=alert.pain_location,
            severity=alert.severity,
            status="active",
            acknowledged=False,
            created_at=created_at_str,
            message=f"{alert.student_name} adaptou '{alert.original_exercise}' por '{alert.adapted_exercise}'.",
        )
        if not self._is_production():
            self._mem_alerts[alert_id] = resp.model_dump()
        return resp

    async def list_trainer_alerts(self, trainer_id: str) -> List[BiomechanicalAlertResponse]:
        """Lista os alertas biomecânicos pendentes/recentes do treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()
        alerts: List[BiomechanicalAlertResponse] = []

        if client and is_valid_uuid(t_uuid):
            try:
                res = await client.table("adaptation_logs")\
                    .select("*")\
                    .eq("trainer_id", t_uuid)\
                    .order("created_at", desc=True)\
                    .limit(50)\
                    .execute()

                for row in res.data:
                    dt = row.get("adaptation_details") or {}
                    alerts.append(BiomechanicalAlertResponse(
                        id=row["id"],
                        student_id=row["client_id"],
                        student_name=dt.get("student_name") or "Aluno",
                        trainer_id=row["trainer_id"],
                        original_exercise=row["original_exercise"],
                        adapted_exercise=row["adapted_exercise"],
                        reason=row["reason"],
                        pain_location=dt.get("pain_location"),
                        severity=dt.get("severity") or "Moderada",
                        status="active" if not row.get("viewed_by_trainer") else "acknowledged",
                        acknowledged=bool(row.get("viewed_by_trainer")),
                        created_at=row.get("created_at") or datetime.now(timezone.utc).isoformat(),
                        message=f"Trocou {row['original_exercise']} por {row['adapted_exercise']}",
                    ))
                return alerts
            except Exception as e:
                logger.error(f"Erro ao listar alertas no Supabase: {e}")
                self._raise_if_production("listar alertas biomecânicos", e)

        # Fallback local
        for a in self._mem_alerts.values():
            if a.get("trainer_id") in (trainer_id, t_uuid, "current-trainer"):
                alerts.append(BiomechanicalAlertResponse(**a))
        return alerts

    async def acknowledge_alert(self, alert_id: str, trainer_id: str) -> bool:
        """Marca o alerta como visto/reconhecido pelo treinador."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()

        if client and is_valid_uuid(alert_id):
            try:
                res = await client.table("adaptation_logs")\
                    .update({"viewed_by_trainer": True})\
                    .eq("id", alert_id)\
                    .eq("trainer_id", t_uuid)\
                    .execute()
                if res.data:
                    return True
            except Exception as e:
                logger.error(f"Erro ao marcar alerta no Supabase: {e}")
                self._raise_if_production("reconhecer alerta biomecânico", e)

        if (
            not self._is_production()
            and alert_id in self._mem_alerts
            and self._mem_alerts[alert_id].get("trainer_id") in (trainer_id, t_uuid)
        ):
            self._mem_alerts[alert_id]["acknowledged"] = True
            self._mem_alerts[alert_id]["status"] = "acknowledged"
            return True
        return False

    # =========================================================================
    # ASSINATURAS SAAS (SUBSCRIPTIONS + PLANS)
    # =========================================================================

    async def get_trainer_subscription(self, trainer_id: str) -> MySubscriptionResponse:
        """Recupera a assinatura ativa do treinador a partir do Supabase ou cache."""
        if not self._is_production() and trainer_id in self._mem_subscriptions:
            cached = self._mem_subscriptions[trainer_id]
            curr_students = await self.count_trainer_occupied_slots(trainer_id)
            ai_used = self.get_ai_generations_used(trainer_id)
            if isinstance(cached, dict):
                plan_id = cached.get("plan_id", "pro")
                plan_max = 3 if plan_id == "starter" else (30 if plan_id == "pro" else (60 if plan_id == "elite" else 100))
                is_trial = plan_id == "starter"
                cached_status = cached.get("status", "active")
                max_ai = cached.get("max_ai_generations", 10 if is_trial else -1)
                can_gen = True if max_ai == -1 else (ai_used < max_ai)
                return MySubscriptionResponse(
                    plan_id=plan_id,
                    plan_name=cached.get("plan_name", plan_id.title()),
                    status=cached_status,
                    billing_interval=cached.get("billing_interval", "monthly"),
                    current_students=curr_students,
                    max_students=cached.get("max_students", plan_max),
                    ai_generations_used=ai_used,
                    max_ai_generations=max_ai,
                    trial_days_remaining=cached.get("trial_days_remaining", 14 if is_trial else None),
                    next_billing_date=cached.get("next_billing_date"),
                    payment_method=cached.get("payment_provider") or cached.get("payment_method", "pix"),
                    can_create_student=curr_students < cached.get("max_students", plan_max),
                    can_generate_ai=can_gen,
                )
            can_gen = True if cached.max_ai_generations == -1 else (ai_used < cached.max_ai_generations)
            return MySubscriptionResponse(
                plan_id=cached.plan_id,
                plan_name=cached.plan_name,
                status=cached.status,
                billing_interval=cached.billing_interval,
                current_students=curr_students,
                max_students=cached.max_students,
                ai_generations_used=ai_used,
                max_ai_generations=cached.max_ai_generations,
                trial_days_remaining=cached.trial_days_remaining,
                next_billing_date=cached.next_billing_date,
                payment_method=cached.payment_method,
                can_create_student=curr_students < cached.max_students,
                can_generate_ai=can_gen,
            )

        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()

        if client and is_valid_uuid(t_uuid):
            try:
                res = await client.table("subscriptions")\
                    .select("*, plans(*)")\
                    .eq("trainer_id", t_uuid)\
                    .execute()

                if res.data:
                    sub = res.data[0]
                    plan = sub.get("plans") or {}
                    current_students = await self.count_trainer_occupied_slots(t_uuid)
                    max_st = plan.get("max_students", 30)
                    ai_used = await self.get_monthly_ai_generations_used(trainer_id)
                    max_ai = plan.get("max_ai_generations_per_month", -1)

                    return MySubscriptionResponse(
                        plan_id=sub.get("plan_id", "pro"),
                        plan_name=plan.get("name", "Personal Pro"),
                        status=sub.get("status", "active"),
                        billing_interval=sub.get("billing_interval", "monthly"),
                        current_students=current_students,
                        max_students=max_st,
                        ai_generations_used=ai_used,
                        max_ai_generations=max_ai,
                        trial_days_remaining=14 if sub.get("status") == "trialing" else None,
                        next_billing_date=sub.get("current_period_end", "")[:10],
                        payment_method="pix",
                        can_create_student=current_students < max_st,
                        can_generate_ai=True if max_ai == -1 else (ai_used < max_ai),
                    )
            except Exception as e:
                logger.error(f"Erro ao buscar assinatura no Supabase: {e}")
                self._raise_if_production("buscar assinatura", e)

        # O fallback de produção respeita o menor plano até existir assinatura persistida.
        curr_students = await self.count_trainer_occupied_slots(trainer_id)
        ai_used = await self.get_monthly_ai_generations_used(trainer_id)
        default_is_production = self._is_production()
        default_plan_id = "starter" if default_is_production else "pro"
        default_plan_name = "Starter Trial" if default_is_production else "Personal Pro"
        default_max_students = 3 if default_is_production else 30
        default_max_ai = 10 if default_is_production else -1
        default_sub = MySubscriptionResponse(
            plan_id=default_plan_id,
            plan_name=default_plan_name,
            status="trialing" if default_is_production else "active",
            billing_interval="monthly",
            current_students=curr_students,
            max_students=default_max_students,
            ai_generations_used=ai_used,
            max_ai_generations=default_max_ai,
            trial_days_remaining=14 if default_is_production else None,
            next_billing_date=(datetime.now() + timedelta(days=24)).strftime("%d/%m/%Y"),
            payment_method="pix",
            can_create_student=curr_students < default_max_students,
            can_generate_ai=default_max_ai == -1 or ai_used < default_max_ai,
        )
        if not default_is_production:
            self._mem_subscriptions[trainer_id] = default_sub
        return default_sub

    async def activate_subscription(
        self, trainer_id: str, plan_id: str, billing_interval: str = "monthly", payment_method: str = "pix"
    ) -> MySubscriptionResponse:
        """Ativa ou atualiza o plano SaaS do treinador persistindo no Supabase."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()

        period_days = 365 if billing_interval == "yearly" else 30
        now = datetime.now(timezone.utc)
        period_end = now + timedelta(days=period_days)
        is_trial = plan_id == "starter"
        sub_status = "trialing" if is_trial else "active"

        PLAN_NAMES = {
            "starter": "Starter Trial",
            "pro": "Personal Pro",
            "elite": "Elite Coach",
            "studio": "Studio Scale",
        }
        plan_name = PLAN_NAMES.get(plan_id, plan_id.title())

        if client and is_valid_uuid(t_uuid):
            try:
                await client.table("subscriptions").upsert({
                    "trainer_id": t_uuid,
                    "plan_id": plan_id,
                    "status": sub_status,
                    "billing_interval": billing_interval,
                    "current_period_start": now.isoformat(),
                    "current_period_end": period_end.isoformat(),
                    "payment_provider": payment_method or "asaas",
                    "updated_at": now.isoformat(),
                }, on_conflict="trainer_id").execute()
            except Exception as e:
                logger.error(f"Erro ao persistir assinatura no Supabase: {e}")
                self._raise_if_production("persistir assinatura", e)

        curr_students = await self.count_trainer_occupied_slots(trainer_id)
        plan_max = 3 if plan_id == "starter" else (30 if plan_id == "pro" else (60 if plan_id == "elite" else 100))

        sub_resp = MySubscriptionResponse(
            plan_id=plan_id,
            plan_name=plan_name,
            status=sub_status,
            billing_interval=billing_interval,
            current_students=curr_students,
            max_students=plan_max,
            ai_generations_used=0,
            max_ai_generations=10 if is_trial else -1,
            trial_days_remaining=14 if is_trial else None,
            next_billing_date=period_end.strftime("%d/%m/%Y"),
            payment_method=payment_method,
            can_create_student=curr_students < plan_max,
            can_generate_ai=True,
        )
        if not self._is_production():
            self._mem_subscriptions[trainer_id] = sub_resp
            self._mem_subscriptions["current-trainer"] = sub_resp
        return sub_resp

    async def admin_create_user(
        self,
        email: str,
        password: str,
        full_name: str,
        role: str = "trainer",
        phone: Optional[str] = None,
        trainer_id: Optional[str] = None,
        invite_token: Optional[str] = None,
        professional_document_type: Optional[str] = None,
        professional_document: Optional[str] = None,
        photo_url: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Cria um usuário diretamente via Supabase Admin API com email_confirm=True,
        evitando falhas de envio de e-mail de confirmação SMTP e garantindo login imediato.
        """
        client = await self.get_client()
        user_metadata: Dict[str, Any] = {
            "full_name": full_name,
            "role": role,
        }
        if phone:
            user_metadata["phone"] = phone
        if role != "client" and trainer_id and is_valid_uuid(trainer_id):
            user_metadata["trainer_id"] = trainer_id
        if invite_token:
            user_metadata["invite_token"] = invite_token
        if professional_document_type:
            user_metadata["professional_document_type"] = professional_document_type
        if professional_document:
            user_metadata["professional_document"] = professional_document
            user_metadata["cref_or_registry"] = professional_document

        user_id = None
        if not client or not hasattr(client, "auth") or not hasattr(client.auth, "admin"):
            raise RuntimeError("Admin API do Supabase indisponível para criar usuário.")
        try:
            admin_res = await client.auth.admin.create_user({
                "email": email,
                "password": password,
                "email_confirm": True,
                "user_metadata": user_metadata,
            })
            if admin_res and hasattr(admin_res, "user") and admin_res.user:
                user_id = admin_res.user.id
        except Exception as e:
            err_str = str(e).lower()
            logger.error(f"Erro no admin.create_user do Supabase: {e}")
            if "already registered" in err_str or "unique" in err_str or "duplicate" in err_str:
                raise ValueError("Este e-mail já está cadastrado no sistema.") from e
            raise

        if not user_id:
            raise RuntimeError("O Supabase não retornou o usuário criado.")

        if client:
            try:
                profile_payload = {
                    "id": user_id,
                    "full_name": full_name,
                    "role": role,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
                if phone:
                    profile_payload["phone"] = phone
                if role != "client" and trainer_id and is_valid_uuid(trainer_id):
                    profile_payload["trainer_id"] = to_valid_uuid_str(trainer_id)
                if photo_url:
                    profile_payload["photo_url"] = photo_url
                    profile_payload["avatar_url"] = photo_url

                await client.table("profiles").upsert(profile_payload).execute()
            except Exception as e:
                logger.warning(f"Erro ao salvar perfil no profiles após admin_create_user: {e}")
                self._raise_if_production("salvar perfil do usuário", e)

        return {
            "success": True,
            "user_id": user_id,
            "email": email,
            "role": role,
            "message": "Usuário criado e confirmado com sucesso."
        }

    async def admin_update_user_password(self, user_id: str, new_password: str) -> bool:
        """Atualiza a senha do usuário via Supabase Admin API."""
        client = await self.get_client()
        if client and hasattr(client, "auth") and hasattr(client.auth, "admin"):
            try:
                await client.auth.admin.update_user_by_id(
                    user_id,
                    {"password": new_password}
                )
                logger.info(f"[SupabaseService] Senha do usuário {user_id} redefinida com sucesso.")
                return True
            except Exception as e:
                logger.error(f"[SupabaseService] Erro ao redefinir senha via Admin API: {e}")
                raise e
        return False

    async def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Busca o perfil do usuário, com JOIN no professor para retornar nome e foto."""
        client = await self.get_client()
        if client and is_valid_uuid(user_id):
            try:
                # Usando select com JOIN (para o trainer associado)
                # A tabela profiles tem um relacionamento com ela mesma via trainer_id
                res = await client.table("profiles").select(
                    "*, trainer:trainer_id(full_name, photo_url)"
                ).eq("id", user_id).execute()
                
                if res.data:
                    profile = res.data[0]
                    # Extrair o nome e foto do professor do dict 'trainer' e colocar na raiz para facilitar
                    trainer_data = profile.pop("trainer", None)
                    if trainer_data:
                        # Em caso de ser uma lista, pega o primeiro
                        if isinstance(trainer_data, list) and len(trainer_data) > 0:
                            trainer_data = trainer_data[0]
                        if isinstance(trainer_data, dict):
                            profile["trainer_name"] = trainer_data.get("full_name")
                            profile["trainer_photo_url"] = trainer_data.get("photo_url")
                    return profile
            except Exception as e:
                logger.error(f"Erro ao buscar perfil do usuário no Supabase: {e}")
                
        return None

# Instância singleton global do serviço

    async def get_gamification_data(self, client_id: str) -> dict:
        client = await self.get_client()
        if not client:
            raise RuntimeError("Cliente Supabase indisponível para consultar gamificação do aluno.")

        timezone_name = "UTC"
        try:
            from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

            profile_res = await client.table("profiles").select("timezone").eq("id", to_valid_uuid_str(client_id)).limit(1).execute()
            profile_rows = getattr(profile_res, "data", None) or []
            if profile_rows:
                tz_value = profile_rows[0].get("timezone")
                if isinstance(tz_value, str):
                    candidate = tz_value.strip()
                    if candidate:
                        try:
                            ZoneInfo(candidate)
                            timezone_name = candidate
                        except ZoneInfoNotFoundError:
                            timezone_name = "UTC"
        except Exception as exc:
            logger.warning(f"Timezone do perfil indisponível para gamificação; usando UTC: {exc}")
            timezone_name = "UTC"

        try:
            from zoneinfo import ZoneInfo

            res = await client.table("workout_sessions")\
                .select("completed_at, total_exercises, completed_exercises")\
                .eq("client_id", to_valid_uuid_str(client_id))\
                .order("completed_at", desc=True)\
                .execute()

            sessions = res.data if res and getattr(res, "data", None) else []
            if not sessions:
                return {"current_streak": 0, "daily_goal_progress": 0.0}

            local_tz = ZoneInfo(timezone_name)
            today_local = datetime.now(timezone.utc).astimezone(local_tz).date()

            valid_day_progress = {}
            valid_days = set()

            for session in sessions:
                if not isinstance(session, dict):
                    continue

                total_exercises = session.get("total_exercises")
                completed_exercises = session.get("completed_exercises")
                try:
                    total_value = int(total_exercises)
                    completed_value = int(completed_exercises)
                except (TypeError, ValueError):
                    continue

                if total_value <= 0 or completed_value <= 0:
                    continue

                completed_at = session.get("completed_at")
                if not isinstance(completed_at, str) or not completed_at.strip():
                    continue

                try:
                    dt = datetime.fromisoformat(completed_at.replace("Z", "+00:00"))
                except Exception:
                    continue

                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)

                local_dt = dt.astimezone(local_tz)
                local_day = local_dt.date()
                valid_days.add(local_day)

                ratio = completed_value / total_value
                current_total = valid_day_progress.get(local_day, 0.0)
                valid_day_progress[local_day] = min(1.0, current_total + ratio)

            if not valid_days:
                return {"current_streak": 0, "daily_goal_progress": 0.0}

            daily_progress = min(1.0, valid_day_progress.get(today_local, 0.0))

            if today_local not in valid_days:
                return {"current_streak": 0, "daily_goal_progress": daily_progress}

            streak = 1
            current_day = today_local - timedelta(days=1)
            while current_day in valid_days:
                streak += 1
                current_day -= timedelta(days=1)

            return {"current_streak": streak, "daily_goal_progress": daily_progress}

        except Exception as exc:
            logger.error(f"Erro ao consultar sessões de treino para gamificação: {exc}")
            raise RuntimeError("Falha ao consultar sessões de treino para gamificação do aluno.") from exc

supabase_service = SupabaseService()


