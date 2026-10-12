import logging
import secrets
import uuid
import urllib.parse
from datetime import datetime, timezone
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.anamnesis import AnamnesisInput
from app.schemas.workout import (
    WorkoutPlanResponse,
    PrescriptionSaveRequest,
    PrescriptionSaveResponse,
    StudentCreateRequest,
    StudentUpdateRequest,
    StudentStatusUpdateRequest,
    StudentResponse,
    BiomechanicalAlertCreate,
    BiomechanicalAlertResponse,
    StudentInviteRequest,
    StudentInviteResponse,
    GamificationResponse,
    NotifyTrainerOnboardingRequest,
    NotifyTrainerOnboardingResponse,
)
from app.services.gemini_service import GeminiService
from app.services.email_service import email_service
from app.services.whatsapp_service import whatsapp_service
from app.services.supabase_service import supabase_service, is_valid_uuid, to_valid_uuid_str
from app.core.config import settings
from app.api.deps import get_gemini_service, get_current_user, get_current_client, get_current_trainer

router = APIRouter()

# Aliases para compatibilidade e fallback referencial
_STUDENTS_STORE = supabase_service._mem_students
_PRESCRIPTIONS_STORE = supabase_service._mem_prescriptions
_ALERTS_STORE = supabase_service._mem_alerts
_STUDENT_STATUS_LABELS = {
    "ativo": "Ativo",
    "active": "Ativo",
    "arquivado": "Arquivado",
    "canceled": "Arquivado",
    "inativo": "Inativo",
    "pendente confirmação": "Pendente Confirmação",
    "pendente confirmacao": "Pendente Confirmação",
    "acesso suspenso": "Acesso suspenso",
    "suspended": "Acesso suspenso",
}


def _normalize_student_status(value: str) -> str:
    normalized = _STUDENT_STATUS_LABELS.get(value.strip().casefold())
    if normalized is None:
        raise HTTPException(status_code=422, detail="Status de aluno inválido.")
    return normalized


def _should_check_student_slot(existing_status: str, target_status: str) -> bool:
    current = existing_status.strip().casefold()
    target = target_status.strip().casefold()
    if target in ("arquivado", "inativo", "acesso suspenso"):
        return False
    if current in ("acesso suspenso", "suspended") and target == "ativo":
        return False
    return True


@router.post(
    "/generate-plan",
    response_model=WorkoutPlanResponse,
    status_code=status.HTTP_200_OK,
    summary="Gerar Periodização e Ficha Completa via IA",
    description="Gera uma divisão de treinos personalizada (A, B, C...) com volumes e restrições biomecânicas respeitadas."
)
async def generate_workout_plan(
    data: AnamnesisInput,
    gemini_svc: GeminiService = Depends(get_gemini_service),
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> WorkoutPlanResponse:
    trainer_id = current_user.get("sub") or "current-trainer"
    sub = await supabase_service.get_trainer_subscription(trainer_id)

    # Reserva atômica da cota mensal antes de chamar o Gemini (Prevenção de Race Conditions - AI-001)
    reserved = await supabase_service.reserve_monthly_ai_quota(trainer_id, sub.max_ai_generations)
    if not reserved:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {sub.max_ai_generations} gerações de IA por mês atingido no plano '{sub.plan_name}'. "
                   f"Faça upgrade para o plano Personal Pro para gerar fichas ilimitadas."
        )

    try:
        plan = await gemini_svc.generate_workout_plan(
            objective=data.objective,
            training_level=data.training_level,
            days_per_week=data.days_per_week,
            workout_location=data.workout_location,
            injuries_or_restrictions=data.injuries_or_restrictions or "Nenhuma restrição articular.",
            split_type=data.split_type or "Automático (IA Sugere)",
            target_focus=data.target_focus,
            additional_notes=data.additional_notes
        )
        return plan
    except ValueError as e:
        await supabase_service.release_monthly_ai_quota(trainer_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    except Exception as e:
        await supabase_service.release_monthly_ai_quota(trainer_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao gerar treino com IA: {str(e)}"
        )


@router.post(
    "/save-prescription",
    response_model=PrescriptionSaveResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Salvar e Liberar Prescrição para o Aluno",
    description="Valida e persiste a ficha estruturada no Supabase para o aluno indicado, atualizando status para ativo."
)
async def save_prescription(
    data: PrescriptionSaveRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> PrescriptionSaveResponse:
    trainer_id = current_user.get("sub") or "current-trainer"
    try:
        return await supabase_service.save_prescription(trainer_id, data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get(
    "/client/{client_id}/active",
    response_model=WorkoutPlanResponse,
    status_code=status.HTTP_200_OK,
    summary="Buscar Ficha Ativa do Aluno",
    description="Retorna a periodização ativa atribuída a um aluno específico."
)
async def get_active_prescription_for_client(
    client_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> WorkoutPlanResponse:
    plan = await supabase_service.get_active_prescription(client_id)
    if not plan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Nenhuma ficha ativa encontrada para o aluno '{client_id}'."
        )
    return plan


async def _count_trainer_occupied_slots(trainer_id: str, exclude_student_id: str = None) -> int:
    """Retorna o número de alunos ocupando vaga ativa na consultoria (não arquivados / não inativos)."""
    return await supabase_service.count_trainer_occupied_slots(trainer_id)


async def _get_trainer_max_students(trainer_id: str) -> int:
    """Busca o limite do plano SaaS ativo do treinador (Starter=3, Pro=30, Elite=60, Studio=100)."""
    from app.api.v1.endpoints.subscriptions import ACTIVE_TRAINER_SUBSCRIPTIONS
    if trainer_id in ACTIVE_TRAINER_SUBSCRIPTIONS:
        return ACTIVE_TRAINER_SUBSCRIPTIONS[trainer_id].max_students
    if "current-trainer" in ACTIVE_TRAINER_SUBSCRIPTIONS:
        return ACTIVE_TRAINER_SUBSCRIPTIONS["current-trainer"].max_students
    sub = await supabase_service.get_trainer_subscription(trainer_id)
    return sub.max_students


def _require_student_owner(student: StudentResponse, current_user: Dict[str, Any]) -> str:
    trainer_id = current_user.get("sub")
    if not trainer_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você não tem permissão para administrar este aluno.",
        )
    t1 = to_valid_uuid_str(trainer_id)
    t2 = to_valid_uuid_str(student.trainer_id) if student.trainer_id else ""
    if (
        student.trainer_id != trainer_id
        and t1 != t2
        and student.trainer_id != "current-trainer"
        and trainer_id != "current-trainer"
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você não tem permissão para administrar este aluno.",
        )
    return trainer_id


@router.post(
    "/students",
    response_model=StudentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar Novo Aluno com Validação e Confirmação",
    description="Registra aluno com validação de formato de e-mail e vinculação com o personal trainer no Supabase."
)
async def create_student(
    data: StudentCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> StudentResponse:
    # Validação simples de integridade de e-mail
    if "@" not in data.email or "." not in data.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Endereço de e-mail inválido."
        )

    trainer_id = current_user.get("sub") or "current-trainer"

    # Verifica duplicidade no treinador
    existing_students = await supabase_service.list_students(trainer_id)
    for st in existing_students:
        if st.email.lower() == data.email.strip().lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Já existe um aluno cadastrado com o e-mail '{data.email}'."
            )

    # Validação estrita da cota de alunos do plano SaaS
    occupied = await _count_trainer_occupied_slots(trainer_id)
    max_allowed = await _get_trainer_max_students(trainer_id)
    if occupied >= max_allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {max_allowed} alunos ativos atingido no seu plano atual. "
                   f"Faça upgrade do plano ou arquive alunos inativos antes de cadastrar novos."
        )

    return await supabase_service.create_student(trainer_id, data)


@router.get(
    "/students",
    response_model=List[StudentResponse],
    status_code=status.HTTP_200_OK,
    summary="Listar Alunos do Treinador",
    description="Retorna a lista de alunos com status de confirmação e vínculo ao personal logado."
)
async def list_students(
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> List[StudentResponse]:
    trainer_id = current_user.get("sub") or "current-trainer"
    return await supabase_service.list_students(trainer_id)


@router.put(
    "/students/{student_id}",
    response_model=StudentResponse,
    status_code=status.HTTP_200_OK,
    summary="Atualizar Dados do Aluno",
    description="Permite ao treinador editar nome, objetivo, telefone e histórico/restrições articulares no Supabase."
)
async def update_student(
    student_id: str,
    data: StudentUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> StudentResponse:
    existing_student = await supabase_service.get_student_by_id(student_id)
    if not existing_student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    trainer_id = _require_student_owner(existing_student, current_user)

    if data.status is not None:
        data.status = _normalize_student_status(data.status)

    if data.status is not None and _should_check_student_slot(existing_student.status, data.status):
        occupied = await _count_trainer_occupied_slots(trainer_id, exclude_student_id=student_id)
        max_allowed = await _get_trainer_max_students(trainer_id)
        if occupied >= max_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Não é possível reativar o aluno '{existing_student.full_name}'. "
                       f"O limite de {max_allowed} alunos ativos do seu plano atual já foi atingido. "
                       f"Faça upgrade de plano ou arquive outro aluno para liberar uma vaga."
            )

    updated = await supabase_service.update_student(student_id, trainer_id, data)
    return updated


@router.patch(
    "/students/{student_id}/status",
    response_model=StudentResponse,
    status_code=status.HTTP_200_OK,
    summary="Alterar Status do Aluno (Ativar / Arquivar)",
    description="Permite arquivar aluno ao fim do ciclo ou reativar aluno antigo sem perda de dados."
)
async def update_student_status(
    student_id: str,
    data: StudentStatusUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> StudentResponse:
    existing_student = await supabase_service.get_student_by_id(student_id)
    if not existing_student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    trainer_id = _require_student_owner(existing_student, current_user)
    new_status = _normalize_student_status(data.status)

    if _should_check_student_slot(existing_student.status, new_status):
        occupied = await _count_trainer_occupied_slots(trainer_id, exclude_student_id=student_id)
        max_allowed = await _get_trainer_max_students(trainer_id)
        if occupied >= max_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Não é possível reativar o aluno '{existing_student.full_name}'. "
                       f"O limite de {max_allowed} alunos ativos do seu plano atual já foi atingido. "
                       f"Faça upgrade de plano ou arquive outro aluno para liberar uma vaga."
            )

    updated = await supabase_service.update_student_status(student_id, trainer_id, new_status)
    return updated


@router.delete(
    "/students/{student_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir Aluno",
    description="Remove o aluno e desvincula prescrições ativas no Supabase."
)
async def delete_student(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> Dict[str, Any]:
    existing_student = await supabase_service.get_student_by_id(student_id)
    if not existing_student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado.",
        )
    trainer_id = _require_student_owner(existing_student, current_user)
    deleted = await supabase_service.delete_student(student_id, trainer_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Não foi possível excluir o aluno.",
        )
    return {
        "status": "success",
        "message": f"Aluno '{student_id}' excluído com sucesso.",
        "student_id": student_id,
    }


@router.post(
    "/adaptations/alert",
    response_model=BiomechanicalAlertResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar Alerta Biomecânico do Treino Presencial",
    description="Disparado quando o aluno relata dor articular ou solicita adaptação no espaço de treino."
)
async def register_biomechanical_alert(
    data: BiomechanicalAlertCreate,
    current_user: Dict[str, Any] = Depends(get_current_client)
) -> BiomechanicalAlertResponse:
    if data.student_id != current_user.get("sub"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="O alerta deve pertencer ao aluno autenticado.")
    trainer_id = (current_user.get("profile") or {}).get("trainer_id")
    if not trainer_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Aluno sem treinador vinculado.")
    data.trainer_id = trainer_id
    return await supabase_service.create_biomechanical_alert(data)


@router.get(
    "/trainer/{trainer_id}/alerts",
    response_model=List[BiomechanicalAlertResponse],
    status_code=status.HTTP_200_OK,
    summary="Listar Alertas Biomecânicos para o Treinador",
    description="Retorna alertas de dor e trocas de exercício ocorridos durante treinos presenciais."
)
async def list_trainer_alerts(
    trainer_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> List[BiomechanicalAlertResponse]:
    authenticated_trainer_id = current_user.get("sub")
    if not authenticated_trainer_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuário não autenticado.")
    if trainer_id != authenticated_trainer_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acesso negado aos alertas deste treinador.")
    return await supabase_service.list_trainer_alerts(authenticated_trainer_id)


@router.patch(
    "/alerts/{alert_id}/acknowledge",
    response_model=BiomechanicalAlertResponse,
    status_code=status.HTTP_200_OK,
    summary="Marcar Alerta como Ciente / Revisado",
    description="Permite ao treinador registrar ciência no card do aluno."
)
async def acknowledge_alert(
    alert_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> BiomechanicalAlertResponse:
    trainer_id = current_user.get("sub")
    if not trainer_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuário não autenticado.")
    success = await supabase_service.acknowledge_alert(alert_id, trainer_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alerta '{alert_id}' não encontrado."
        )

    # Retorna o alerta marcado como acknowledged
    return BiomechanicalAlertResponse(
        id=alert_id,
        student_id="student",
        student_name="Aluno",
        trainer_id=trainer_id,
        original_exercise="",
        adapted_exercise="",
        reason="Adaptação ciente",
        status="acknowledged",
        acknowledged=True,
        created_at=datetime.now(timezone.utc).isoformat(),
        message="Alerta biomecânico reconhecido pelo treinador."
    )


@router.post(
    "/students/invite",
    response_model=StudentInviteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Convidar Aluno via E-mail Profissional e WhatsApp",
    description="Gera convite exclusivo, persiste no Supabase, envia e-mail com template customizado e formata URL de ativação rápida no WhatsApp."
)
async def invite_student(
    payload: StudentInviteRequest,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> StudentInviteResponse:
    trainer_id = current_user.get("sub") or "current-trainer"
    trainer_profile = current_user.get("profile") or {}
    trainer_metadata = current_user.get("user_metadata") or {}
    trainer_name = trainer_metadata.get("full_name") or trainer_profile.get("full_name")
    trainer_cref = ""
    trainer_avatar_url = ""

    # Se for UUID válido, busca perfil no Supabase para garantir nome, foto e registro reais do professor
    client = await supabase_service.get_client()
    if client and is_valid_uuid(trainer_id):
        try:
            t_res = await client.table("profiles").select("*").eq("id", to_valid_uuid_str(trainer_id)).maybe_single().execute()
            if t_res and t_res.data:
                td = t_res.data
                if not trainer_name or trainer_name == "Roberto Mendes":
                    trainer_name = td.get("full_name") or trainer_name
                trainer_cref = td.get("professional_document") or td.get("cref") or td.get("cref_or_registry") or ""
                trainer_avatar_url = td.get("photo_url") or td.get("avatar_url") or ""
        except Exception:
            pass

    if not trainer_name or trainer_name == "Roberto Mendes":
        trainer_name = "Seu Treinador"

    # Validação estrita da cota de alunos do plano SaaS
    occupied = await _count_trainer_occupied_slots(trainer_id)
    max_allowed = await _get_trainer_max_students(trainer_id)
    if occupied >= max_allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Limite de {max_allowed} alunos ativos atingido no seu plano atual. "
                   f"Faça upgrade do plano ou arquive alunos inativos antes de cadastrar novos."
        )

    invite_token = secrets.token_urlsafe(32)
    try:
        invite_record = await supabase_service.create_student_invite(
            token=invite_token,
            trainer_id=trainer_id,
            email=payload.email,
            phone=payload.phone,
            full_name=payload.full_name,
            objective=payload.objective or "Hipertrofia Muscular",
            injuries_or_restrictions=payload.injuries_or_restrictions or "Nenhuma restrição relatada.",
        )
    except Exception as e:
        if "limite" in str(e).lower() or "23514" in str(e):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Limite de {max_allowed} alunos ativos atingido no seu plano atual. "
                       f"Faça upgrade do plano ou arquive alunos inativos antes de cadastrar novos."
            ) from e
        logger.error("Falha ao reservar vaga para convite: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Não foi possível reservar a vaga para este convite.",
        ) from e
    invitation_link = f"{settings.APP_FRONTEND_URL.rstrip('/')}/#/invite/{invite_record['token']}"

    # 1. Envio de E-mail via Resend/Mock com foto e avatar do professor
    email_status = "skipped"
    if payload.send_email:
        email_res = await email_service.send_student_invitation_email(
            student_email=payload.email,
            student_name=payload.full_name,
            trainer_name=trainer_name,
            trainer_avatar_url=trainer_avatar_url,
            confirmation_url=invitation_link,
        )
        email_status = email_res.get("status", "sent")

    # 2. Formata mensagem e URL de WhatsApp
    clean_phone = "".join(filter(str.isdigit, payload.phone or ""))
    if clean_phone and not clean_phone.startswith("55") and len(clean_phone) in (10, 11):
        clean_phone = f"55{clean_phone}"

    whatsapp_msg = (
        f"Olá, {payload.full_name}! Seu convite para o *Mr. Coach* está pronto. 🚀\n\n"
        f"Acesse pelo link exclusivo abaixo para iniciar seus treinos comigo:\n"
        f"{invitation_link}\n\n"
        f"Prof. {trainer_name}\n"
        f"Seu Personal Trainer"
    )
    whatsapp_url = f"https://wa.me/{clean_phone}?text={urllib.parse.quote(whatsapp_msg)}" if clean_phone else ""

    # Se solicitado disparo direto via WhatsApp service
    whatsapp_status = "ready_url"
    if payload.send_whatsapp and clean_phone:
        wa_res = await whatsapp_service.send_text_message(settings.EVOLUTION_INSTANCE, clean_phone, whatsapp_msg)
        whatsapp_status = wa_res.get("status", "sent")

    return StudentInviteResponse(
        id=invite_record["id"],
        email=payload.email,
        full_name=payload.full_name,
        status="Convite Pendente",
        invitation_link=invitation_link,
        whatsapp_url=whatsapp_url,
        email_status=email_status,
        whatsapp_status=whatsapp_status,
        message=f"Convite gerado com sucesso para {payload.full_name}."
    )


@router.get(
    "/gamification",
    response_model=GamificationResponse,
    status_code=status.HTTP_200_OK,
    summary="Buscar Dados de Gamificação do Aluno",
    description="Retorna dados de gamificação baseados na tabela workout_sessions do Supabase."
)
async def get_gamification_data(
    current_user: Dict[str, Any] = Depends(get_current_client)
) -> GamificationResponse:
    client_id = current_user.get("sub")
    if not client_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticação necessária para consultar gamificação."
        )

    try:
        data = await supabase_service.get_gamification_data(client_id)
    except Exception as exc:
        logging.exception("Gamificação indisponível por falha de persistência.")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Serviço de persistência indisponível no momento. Tente novamente mais tarde."
        ) from exc

    return GamificationResponse(
        current_streak=data.get("current_streak", 0),
        daily_goal_progress=data.get("daily_goal_progress", 0.0)
    )


@router.post(
    "/notify-trainer-onboarding",
    response_model=NotifyTrainerOnboardingResponse,
    status_code=status.HTTP_200_OK,
    summary="Notificar Professor Imediatamente sobre Avaliação Concluída",
    description="Dispara alerta na central do app, WhatsApp e e-mail transacional para o personal trainer elaborar a periodização."
)
async def notify_trainer_onboarding(
    payload: NotifyTrainerOnboardingRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> NotifyTrainerOnboardingResponse:
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Serviço de dados indisponível no momento."
        )

    t_uuid = to_valid_uuid_str(payload.trainer_id)
    c_uuid = to_valid_uuid_str(payload.client_id)

    # 1. Busca dados de contato do professor no Supabase
    trainer_name = "Treinador"
    trainer_phone = None
    trainer_email = None

    try:
        t_res = await client.table("profiles").select("id, full_name, phone, public_whatsapp").eq("id", t_uuid).maybe_single().execute()
        if t_res and t_res.data:
            trainer_name = t_res.data.get("full_name") or trainer_name
            trainer_phone = t_res.data.get("public_whatsapp") or t_res.data.get("phone")
    except Exception as e:
        logging.warning(f"Erro ao buscar perfil do treinador para notificação: {e}")

    try:
        auth_user = await client.auth.admin.get_user_by_id(t_uuid)
        if auth_user and auth_user.user:
            trainer_email = auth_user.user.email
    except Exception as e:
        logging.warning(f"Erro ao buscar email do treinador no Auth: {e}")

    # 2. Registra o alerta de avaliação pendente na tabela adaptation_logs (alerta no app do professor)
    alert_id = None
    try:
        alert_payload = {
            "client_id": c_uuid,
            "trainer_id": t_uuid,
            "original_exercise": "Avaliação Biomecânica Concluída",
            "adapted_exercise": "Aguardando Elaboração de Ficha de Treino",
            "reason": f"A aluna {payload.student_name} concluiu a avaliação ({payload.objective}). Pronto para elaboração da periodização.",
            "adaptation_details": {
                "student_name": payload.student_name,
                "objective": payload.objective,
                "training_level": payload.training_level,
                "weekly_days": payload.weekly_days,
                "injuries_or_restrictions": payload.injuries_or_restrictions or "Nenhuma restrição relatada",
                "type": "new_student_assessment",
            },
            "viewed_by_trainer": False,
        }
        ins_res = await client.table("adaptation_logs").insert(alert_payload).execute()
        if ins_res and ins_res.data:
            alert_id = ins_res.data[0].get("id")
    except Exception as e:
        logging.warning(f"Erro ao registrar alerta em adaptation_logs: {e}")

    # 3. Disparo imediato via WhatsApp
    whatsapp_sent = False
    if trainer_phone:
        clean_phone = "".join(filter(str.isdigit, trainer_phone))
        if clean_phone and not clean_phone.startswith("55") and len(clean_phone) in (10, 11):
            clean_phone = f"55{clean_phone}"

        wa_msg = (
            f"🔔 *Mr. Coach - Nova Avaliação Concluída!*\n\n"
            f"Olá, Prof. {trainer_name}!\n"
            f"Sua aluna *{payload.student_name}* acabou de concluir a avaliação inicial e está aguardando sua ficha de treino:\n\n"
            f"🎯 *Objetivo:* {payload.objective}\n"
            f"📊 *Frequência:* {payload.weekly_days}x por semana ({payload.training_level})\n"
            f"⚠️ *Restrições:* {payload.injuries_or_restrictions or 'Nenhuma restrição relatada'}\n\n"
            f"Acesse o Mr. Coach para elaborar e liberar a periodização da aluna."
        )

        try:
            instance_name = f"trainer_{t_uuid.replace('-', '').lower()}"
            await whatsapp_service.send_text_message(
                instance_name=instance_name,
                number=clean_phone,
                text=wa_msg,
            )
            whatsapp_sent = True
        except Exception as e:
            logging.info(f"Aviso envio WhatsApp para o professor: {e}")

    # 4. Disparo de E-mail Transacional para o Professor
    email_sent = False
    if trainer_email and email_service.api_key:
        try:
            subject = f"[Mr. Coach] 📋 Nova Avaliação de {payload.student_name} Concluída - Elaborar Periodização"
            email_html = (
                f'<div style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px;background:#0A0F1D;color:#FFFFFF;border-radius:16px;">'
                f'<h2 style="color:#10B981;margin-top:0;">Nova Avaliação Concluída!</h2>'
                f'<p style="font-size:16px;line-height:1.6;">Olá, <strong>Prof. {trainer_name}</strong>!</p>'
                f'<p style="font-size:15px;line-height:1.6;">Sua aluna <strong>{payload.student_name}</strong> concluiu o formulário de anamnese biomecânica e está aguardando a sua prescrição:</p>'
                f'<div style="background:#131C31;padding:16px;border-radius:12px;margin:20px 0;border-left:4px solid #10B981;">'
                f'<p style="margin:4px 0;"><strong>🎯 Objetivo:</strong> {payload.objective}</p>'
                f'<p style="margin:4px 0;"><strong>📊 Frequência:</strong> {payload.weekly_days}x por semana ({payload.training_level})</p>'
                f'<p style="margin:4px 0;"><strong>⚠️ Restrições:</strong> {payload.injuries_or_restrictions or "Nenhuma"}</p>'
                f'</div>'
                f'<p style="font-size:14px;color:#94A3B8;">Acesse o painel Mr. Coach para gerar ou prescrever a ficha personalizada com IA.</p>'
                f'</div>'
            )
            # Envia via HTTP Resend se configurado
            async with httpx.AsyncClient(timeout=10) as http_client:
                await http_client.post(
                    "https://api.resend.com/emails",
                    headers={
                        "Authorization": f"Bearer {email_service.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "from": email_service.email_from,
                        "to": [trainer_email],
                        "subject": subject,
                        "html": email_html,
                    },
                )
                email_sent = True
        except Exception as e:
            logging.info(f"Aviso envio e-mail para o professor: {e}")

    return NotifyTrainerOnboardingResponse(
        status="success",
        message=f"Professor {trainer_name} notificado com sucesso sobre a avaliação de {payload.student_name}.",
        alert_id=alert_id,
        whatsapp_sent=whatsapp_sent,
        email_sent=email_sent,
    )

