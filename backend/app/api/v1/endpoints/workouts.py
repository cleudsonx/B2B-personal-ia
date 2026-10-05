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
)
from app.services.gemini_service import GeminiService
from app.services.email_service import email_service
from app.services.whatsapp_service import whatsapp_service
from app.services.supabase_service import supabase_service, is_valid_uuid, to_valid_uuid_str
from app.core.config import settings
from app.api.deps import get_gemini_service, get_current_user

router = APIRouter()

# Aliases para compatibilidade e fallback referencial
_STUDENTS_STORE = supabase_service._mem_students
_PRESCRIPTIONS_STORE = supabase_service._mem_prescriptions
_ALERTS_STORE = supabase_service._mem_alerts


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
    current_user: Dict[str, Any] = Depends(get_current_user)
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> PrescriptionSaveResponse:
    trainer_id = data.trainer_id or current_user.get("sub") or "current-trainer"
    return await supabase_service.save_prescription(trainer_id, data)


@router.get(
    "/client/{client_id}/active",
    response_model=WorkoutPlanResponse,
    status_code=status.HTTP_200_OK,
    summary="Buscar Ficha Ativa do Aluno",
    description="Retorna a periodização ativa atribuída a um aluno específico."
)
async def get_active_prescription_for_client(
    client_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
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


@router.post(
    "/students",
    response_model=StudentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar Novo Aluno com Validação e Confirmação",
    description="Registra aluno com validação de formato de e-mail e vinculação com o personal trainer no Supabase."
)
async def create_student(
    data: StudentCreateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentResponse:
    # Validação simples de integridade de e-mail
    if "@" not in data.email or "." not in data.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Endereço de e-mail inválido."
        )

    trainer_id = data.trainer_id or current_user.get("sub") or "current-trainer"

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
    current_user: Dict[str, Any] = Depends(get_current_user)
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentResponse:
    existing_student = await supabase_service.get_student_by_id(student_id)
    if not existing_student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    trainer_id = existing_student.trainer_id or current_user.get("sub") or "current-trainer"

    if data.status is not None and data.status.lower() not in ("arquivado", "inativo"):
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentResponse:
    existing_student = await supabase_service.get_student_by_id(student_id)
    if not existing_student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    trainer_id = existing_student.trainer_id or current_user.get("sub") or "current-trainer"
    new_status = data.status.lower()

    if new_status not in ("arquivado", "inativo"):
        occupied = await _count_trainer_occupied_slots(trainer_id, exclude_student_id=student_id)
        max_allowed = await _get_trainer_max_students(trainer_id)
        if occupied >= max_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Não é possível reativar o aluno '{existing_student.full_name}'. "
                       f"O limite de {max_allowed} alunos ativos do seu plano atual já foi atingido. "
                       f"Faça upgrade de plano ou arquive outro aluno para liberar uma vaga."
            )

    updated = await supabase_service.update_student_status(student_id, trainer_id, data.status)
    return updated


@router.delete(
    "/students/{student_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir Aluno",
    description="Remove o aluno e desvincula prescrições ativas no Supabase."
)
async def delete_student(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    trainer_id = current_user.get("sub") or "current-trainer"
    await supabase_service.delete_student(student_id, trainer_id)
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> BiomechanicalAlertResponse:
    if not data.trainer_id:
        data.trainer_id = current_user.get("sub") or "current-trainer"
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[BiomechanicalAlertResponse]:
    return await supabase_service.list_trainer_alerts(trainer_id)


@router.patch(
    "/alerts/{alert_id}/acknowledge",
    response_model=BiomechanicalAlertResponse,
    status_code=status.HTTP_200_OK,
    summary="Marcar Alerta como Ciente / Revisado",
    description="Permite ao treinador registrar ciência no card do aluno."
)
async def acknowledge_alert(
    alert_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> BiomechanicalAlertResponse:
    success = await supabase_service.acknowledge_alert(alert_id)
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
        trainer_id="trainer",
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentInviteResponse:
    trainer_id = payload.trainer_id or current_user.get("id") or current_user.get("sub") or "current-trainer"
    trainer_name = payload.trainer_name or current_user.get("user_metadata", {}).get("full_name") or current_user.get("full_name")
    trainer_cref = ""

    # Se for UUID válido, busca perfil no Supabase para garantir nome e registro reais do professor
    client = await supabase_service.get_client()
    if client and is_valid_uuid(trainer_id):
        try:
            t_res = await client.table("profiles").select("*").eq("id", to_valid_uuid_str(trainer_id)).maybe_single().execute()
            if t_res and t_res.data:
                td = t_res.data
                if not trainer_name or trainer_name == "Roberto Mendes":
                    trainer_name = td.get("full_name") or trainer_name
                trainer_cref = td.get("professional_document") or td.get("cref") or td.get("cref_or_registry") or ""
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
                   f"Faça upgrade do plano ou arquive alunos inativos antes de convidar novos."
        )

    # Cria o aluno no Supabase vinculado ao trainer_id real
    created_student = await supabase_service.create_student(
        trainer_id=trainer_id,
        req=StudentCreateRequest(
            full_name=payload.full_name,
            email=payload.email,
            phone=payload.phone,
            goal=payload.objective or "Hipertrofia Muscular",
            injuries_or_restrictions=payload.injuries_or_restrictions or "Aguardando avaliação clínica",
        )
    )
    student_id = created_student.id

    # Gera link seguro de onboarding/convite com parâmetros reais do professor
    query_params = {
        "student_id": student_id,
        "trainer_id": trainer_id,
        "trainer_name": trainer_name,
    }
    if trainer_cref:
        query_params["cref"] = trainer_cref
    if hasattr(created_student, 'temp_password') and created_student.temp_password:
        query_params["token"] = created_student.temp_password

    invitation_link = f"{settings.APP_FRONTEND_URL}/#onboarding?{urllib.parse.urlencode(query_params)}"

    # 1. Envio de E-mail via Resend/Mock
    email_status = "skipped"
    if payload.send_email:
        email_res = await email_service.send_student_invitation_email(
            student_email=payload.email,
            student_name=payload.full_name,
            trainer_name=trainer_name,
            confirmation_url=invitation_link,
        )
        email_status = email_res.get("status", "sent")

    # 2. Formata mensagem e URL de WhatsApp
    clean_phone = "".join(filter(str.isdigit, payload.phone or ""))
    if clean_phone and not clean_phone.startswith("55") and len(clean_phone) in (10, 11):
        clean_phone = f"55{clean_phone}"

    whatsapp_msg = (
        f"Olá, {payload.full_name}! 💪\n\n"
        f"Seu Personal Trainer *Prof. {trainer_name}* convidou você para treinar no *Mr. Coach* — a plataforma com biomecânica 3D e acompanhamento exclusivo.\n\n"
        f"🔗 Clique no link abaixo para ativar sua conta e preencher sua avaliação em 3 minutos:\n"
        f"{invitation_link}\n\n"
        f"_Bons treinos e foco na técnica!_"
    )
    whatsapp_url = f"https://wa.me/{clean_phone}?text={urllib.parse.quote(whatsapp_msg)}" if clean_phone else ""

    # Se solicitado disparo direto via WhatsApp service
    whatsapp_status = "ready_url"
    if payload.send_whatsapp and clean_phone:
        wa_res = await whatsapp_service.send_text_message(settings.EVOLUTION_INSTANCE, clean_phone, whatsapp_msg)
        whatsapp_status = wa_res.get("status", "sent")

    return StudentInviteResponse(
        id=student_id,
        email=payload.email,
        full_name=payload.full_name,
        status="Pendente Confirmação",
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
    description="Retorna dados de gamificação como dias seguidos (streak) e progresso diário. Atualmente simulado para demonstração."
)
async def get_gamification_data(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> GamificationResponse:
    # A lógica de gamificação pode ser conectada ao Supabase analisando
    # a tabela de histórico de treinos concluídos (workouts_history / completed_sessions).
    # Como solicitado, estamos inicializando com um mock funcional
    
    return GamificationResponse(
        current_streak=3, # Mock: 3 dias de ofensiva
        daily_goal_progress=0.75 # Mock: 75% concluído do treino de hoje
    )
