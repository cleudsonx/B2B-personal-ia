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
                    self._mem_subscriptions[key]["status"] = new_status
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
    ) -> bool:
        """
        Reivindica atomicamente o processamento de um evento de webhook (PAY-004).
        Retorna True se este processo obteve a posse exclusiva do evento.
        Retorna False se o evento já foi processado ou está sendo processado concorrentemente.
        """
        if not event_id:
            return True

        # 1. Modo de desenvolvimento / memória local
        if not self._is_production():
            if event_id in self._mem_processed_events:
                return False
            self._mem_processed_events[event_id] = {
                "event_id": event_id,
                "provider": provider,
                "event_type": event_type,
                "status": "processing",
                "claimed_at": datetime.now(timezone.utc).isoformat(),
            }
            return True

        # 2. Modo produção com Supabase
        client = await self.get_client()
        if not client:
            raise RuntimeError("Cliente Supabase indisponível para claim atômico de webhook em produção.")

        try:
            # Tenta inserção com ignore_duplicates (ON CONFLICT (event_id) DO NOTHING)
            res = await client.table("processed_webhook_events").upsert(
                {
                    "event_id": event_id,
                    "provider": provider,
                    "event_type": event_type,
                    "payload": payload or {},
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                },
                on_conflict="event_id",
                ignore_duplicates=True,
            ).execute()
            if res.data and len(res.data) > 0:
                self._mem_processed_events[event_id] = {"event_id": event_id, "status": "processing"}
                return True
            else:
                # Conflito atômico: outro worker já reivindicou o evento
                return False
        except Exception as e:
            err_msg = str(e).lower()
            if "duplicate" in err_msg or "conflict" in err_msg or "unique" in err_msg:
                return False
            logger.error(f"Erro ao reivindicar webhook atomicamente {event_id}: {e}")
            self._raise_if_production("reivindicar evento de webhook atomicamente", e)
            return False

    async def release_webhook_claim(self, event_id: str) -> None:
        """
        Libera o claim atômico de um evento de webhook caso seu processamento
        tenha sido interrompido por ausência de metadados, permitindo que retries
        legítimos do gateway de pagamento sejam processados futuramente.
        """
        if not event_id:
            return

        self._mem_processed_events.pop(event_id, None)

        if not self._is_production():
            return

        client = await self.get_client()
        if not client:
            return

        try:
            await client.table("processed_webhook_events").delete().eq("event_id", event_id).execute()
            logger.info(f"[Supabase] Claim do evento de webhook {event_id} liberado para retry.")
        except Exception as e:
            logger.warning(f"Erro ao liberar claim de webhook {event_id} no Supabase: {e}")

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
                        if p.get("subscription_status") != "canceled" and p.get("id") != exclude_student_id
                    ]
                    return len(occupied) if self._is_production() else max(len(occupied), mem_count)
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

    async def acknowledge_alert(self, alert_id: str) -> bool:
        """Marca o alerta como visto/reconhecido pelo treinador."""
        client = await self.get_client()

        if client and is_valid_uuid(alert_id):
            try:
                res = await client.table("adaptation_logs")\
                    .update({"viewed_by_trainer": True})\
                    .eq("id", alert_id)\
                    .execute()
                if res.data:
                    return True
            except Exception as e:
                logger.error(f"Erro ao marcar alerta no Supabase: {e}")
                self._raise_if_production("reconhecer alerta biomecânico", e)

        if not self._is_production() and alert_id in self._mem_alerts:
            self._mem_alerts[alert_id]["acknowledged"] = True
            self._mem_alerts[alert_id]["status"] = "acknowledged"
            return True
        return True

    # =========================================================================
    # ASSINATURAS SAAS (SUBSCRIPTIONS + PLANS)
    # =========================================================================

    async def get_trainer_subscription(self, trainer_id: str) -> MySubscriptionResponse:
        """Recupera a assinatura ativa do treinador a partir do Supabase ou cache."""
        if not self._is_production() and trainer_id in self._mem_subscriptions:
            cached = self._mem_subscriptions[trainer_id]
            curr_students = await self.count_trainer_occupied_slots(trainer_id)
            ai_used = self.get_ai_generations_used(trainer_id)
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
        if trainer_id and is_valid_uuid(trainer_id):
            user_metadata["trainer_id"] = trainer_id
        if professional_document_type:
            user_metadata["professional_document_type"] = professional_document_type
        if professional_document:
            user_metadata["professional_document"] = professional_document
            user_metadata["cref_or_registry"] = professional_document

        user_id = None
        if client and hasattr(client, "auth") and hasattr(client.auth, "admin"):
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
                    raise ValueError("Este e-mail já está cadastrado no sistema.")
                raise e

        if not user_id:
            user_id = str(uuid.uuid4())

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
                if trainer_id and is_valid_uuid(trainer_id):
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
supabase_service = SupabaseService()

