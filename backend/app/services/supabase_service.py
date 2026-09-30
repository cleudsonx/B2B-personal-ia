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
                    return max(len(occupied), mem_count)
                except Exception as e:
                    logger.warning(f"Erro ao contar alunos no Supabase ({e}).")

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

                if students:
                    return students
            except Exception as e:
                logger.warning(f"Erro ao listar alunos no Supabase ({e}). Utilizando fallback.")

        # Fallback local
        for s in self._mem_students.values():
            if s.get("trainer_id") in (trainer_id, t_uuid, "current-trainer"):
                students.append(StudentResponse(**s))
        return students

    async def get_student_by_id(self, student_id: str) -> Optional[StudentResponse]:
        """Busca um aluno específico por ID."""
        if student_id in self._mem_students:
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
        return None

    async def create_student(self, trainer_id: str, req: StudentCreateRequest) -> StudentResponse:
        """Cadastra um novo aluno gerando usuário e perfil no Supabase."""
        t_uuid = to_valid_uuid_str(trainer_id)
        client = await self.get_client()

        if client:
            try:
                # 1. Cria usuário no Supabase Auth via Admin API
                user_res = await client.auth.admin.create_user({
                    "email": req.email,
                    "password": f"TempPass_{uuid.uuid4().hex[:8]}!",
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
                self._mem_students[student_id] = student_resp.model_dump()
                return student_resp
            except Exception as e:
                logger.error(f"Erro ao criar aluno no Supabase Auth/DB: {e}. Usando fallback.")

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

        # Atualiza fallback de memória
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
                await client.table("profiles").delete().eq("id", s_uuid).execute()
                try:
                    await client.auth.admin.delete_user(s_uuid)
                except Exception:
                    pass
            except Exception as e:
                logger.error(f"Erro ao excluir aluno do Supabase: {e}")

        if student_id in self._mem_students:
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
                logger.error(f"Erro ao salvar prescrição no Supabase: {e}. Usando fallback local.")

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

        # Fallback de memória
        if client_id in self._mem_prescriptions:
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
                if alerts:
                    return alerts
            except Exception as e:
                logger.error(f"Erro ao listar alertas no Supabase: {e}")

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

        if alert_id in self._mem_alerts:
            self._mem_alerts[alert_id]["acknowledged"] = True
            self._mem_alerts[alert_id]["status"] = "acknowledged"
            return True
        return True

    # =========================================================================
    # ASSINATURAS SAAS (SUBSCRIPTIONS + PLANS)
    # =========================================================================

    async def get_trainer_subscription(self, trainer_id: str) -> MySubscriptionResponse:
        """Recupera a assinatura ativa do treinador a partir do Supabase ou cache."""
        if trainer_id in self._mem_subscriptions:
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
                    ai_used = self.get_ai_generations_used(trainer_id)
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

        # Fallback padrão (Personal Pro ativo)
        curr_students = await self.count_trainer_occupied_slots(trainer_id)
        ai_used = self.get_ai_generations_used(trainer_id)
        default_sub = MySubscriptionResponse(
            plan_id="pro",
            plan_name="Personal Pro",
            status="active",
            billing_interval="monthly",
            current_students=curr_students,
            max_students=30,
            ai_generations_used=ai_used,
            max_ai_generations=-1,
            trial_days_remaining=None,
            next_billing_date=(datetime.now() + timedelta(days=24)).strftime("%d/%m/%Y"),
            payment_method="pix",
            can_create_student=curr_students < 30,
            can_generate_ai=True,
        )
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
        self._mem_subscriptions[trainer_id] = sub_resp
        self._mem_subscriptions["current-trainer"] = sub_resp
        return sub_resp


# Instância singleton global do serviço
supabase_service = SupabaseService()
