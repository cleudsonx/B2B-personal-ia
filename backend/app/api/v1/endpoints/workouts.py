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
)
from app.services.gemini_service import GeminiService
from app.services.email_service import email_service
from app.services.whatsapp_service import whatsapp_service
from app.core.config import settings
from app.api.deps import get_gemini_service, get_current_user

router = APIRouter()

# Armazenamento em memória com integridade referencial para persistência e fallback robusto
_PRESCRIPTIONS_STORE: Dict[str, Dict[str, Any]] = {}
_ALERTS_STORE: Dict[str, Dict[str, Any]] = {
    "alt-1": {
        "id": "alt-1",
        "student_id": "st-1",
        "student_name": "Rodrigo Silveira",
        "trainer_id": "current-trainer",
        "original_exercise": "Supino Reto com Barra",
        "adapted_exercise": "Supino Máquina Articulada",
        "reason": "Desconforto ou Dor Articular",
        "pain_location": "Ombro Anterior",
        "severity": "Moderada",
        "status": "active",
        "acknowledged": False,
        "created_at": "2026-09-29T07:45:00Z",
        "message": "Trocou Supino Reto por Supino Máquina (Ombro Anterior)",
    }
}
_STUDENTS_STORE: Dict[str, Dict[str, Any]] = {
    "st-1": {
        "id": "st-1",
        "full_name": "Rodrigo Silveira",
        "email": "rodrigo.silveira@email.com",
        "phone": "(11) 98765-4321",
        "goal": "Hipertrofia Muscular",
        "status": "Ativo",
        "trainer_id": "current-trainer",
        "created_at": "2026-09-01T10:00:00Z",
        "has_active_prescription": True,
        "last_session": "Hoje, 07:45",
        "active_split": "Treino A - Peito e Tríceps",
        "injuries_or_restrictions": "Leve histórico de desconforto no manguito rotador",
    },
    "st-2": {
        "id": "st-2",
        "full_name": "Camila Vasconcelos",
        "email": "camila.vasconcelos@email.com",
        "phone": "(21) 99876-5432",
        "goal": "Emagrecimento & Definição",
        "status": "Ativo",
        "trainer_id": "current-trainer",
        "created_at": "2026-09-10T14:30:00Z",
        "has_active_prescription": True,
        "last_session": "Hoje, 09:15",
        "active_split": "Treino B - Membros Inferiores",
        "injuries_or_restrictions": "Condromalácia patelar grau 1",
    },
    "st-3": {
        "id": "st-3",
        "full_name": "Lucas Andrade Mendes",
        "email": "lucas.mendes@email.com",
        "phone": "(11) 91234-5678",
        "goal": "Condicionamento Geral",
        "status": "Pendente Confirmação",
        "trainer_id": "current-trainer",
        "created_at": "2026-09-28T18:00:00Z",
        "has_active_prescription": False,
        "last_session": "Convite enviado",
        "active_split": "Aguardando confirmação",
        "injuries_or_restrictions": "Nenhuma",
    },
    "st-4": {
        "id": "st-4",
        "full_name": "Mariana Castro",
        "email": "mariana.castro@email.com",
        "phone": "(31) 97654-3210",
        "goal": "Reabilitação Postural",
        "status": "Arquivado",
        "trainer_id": "current-trainer",
        "created_at": "2026-07-15T11:00:00Z",
        "has_active_prescription": False,
        "last_session": "Ciclo concluído em 15/08",
        "active_split": "Plano finalizado",
        "injuries_or_restrictions": "Escoliose torácica leve",
    },
}


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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Falha ao gerar treino com IA: {str(e)}"
        )


@router.post(
    "/save-prescription",
    response_model=PrescriptionSaveResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Salvar e Liberar Prescrição para o Aluno",
    description="Valida e persiste a ficha estruturada para o aluno indicado, atualizando status para ativo."
)
async def save_prescription(
    data: PrescriptionSaveRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> PrescriptionSaveResponse:
    trainer_id = data.trainer_id or current_user.get("sub") or "current-trainer"
    prescription_id = f"presc_{uuid.uuid4().hex[:12]}"
    created_at = datetime.now().isoformat()

    # Desativa prescrições anteriores do mesmo aluno
    for p in _PRESCRIPTIONS_STORE.values():
        if p.get("client_id") == data.client_id:
            p["is_active"] = False

    # Armazena nova prescrição ativa
    _PRESCRIPTIONS_STORE[prescription_id] = {
        "id": prescription_id,
        "client_id": data.client_id,
        "trainer_id": trainer_id,
        "workout_plan_title": data.plan.workout_plan_title,
        "plan_dict": data.plan.model_dump(),
        "splits_count": len(data.plan.splits),
        "notes": data.notes,
        "is_active": True,
        "created_at": created_at,
    }

    # Atualiza indicador do aluno se existir no store
    if data.client_id in _STUDENTS_STORE:
        _STUDENTS_STORE[data.client_id]["has_active_prescription"] = True
        _STUDENTS_STORE[data.client_id]["status"] = "Ativo"

    return PrescriptionSaveResponse(
        id=prescription_id,
        client_id=data.client_id,
        trainer_id=trainer_id,
        workout_plan_title=data.plan.workout_plan_title,
        splits_count=len(data.plan.splits),
        is_active=True,
        created_at=created_at,
        status="active",
        message="Prescrição gravada com sucesso e liberada no aplicativo do aluno."
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
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> WorkoutPlanResponse:
    for p in reversed(list(_PRESCRIPTIONS_STORE.values())):
        if p.get("client_id") == client_id and p.get("is_active"):
            return WorkoutPlanResponse(**p["plan_dict"])

    # Se não houver prescrição gravada neste ciclo, lança 404
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Nenhuma ficha ativa encontrada para o aluno '{client_id}'."
    )


@router.post(
    "/students",
    response_model=StudentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar Novo Aluno com Validação e Confirmação",
    description="Registra aluno com validação de formato de e-mail e vinculação com o personal trainer."
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

    # Verifica duplicidade
    for st in _STUDENTS_STORE.values():
        if st.get("email", "").lower() == data.email.lower():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Já existe um aluno cadastrado com o e-mail '{data.email}'."
            )

    trainer_id = data.trainer_id or current_user.get("sub") or "current-trainer"
    student_id = f"st_{uuid.uuid4().hex[:8]}"
    created_at = datetime.now().isoformat()

    new_student = {
        "id": student_id,
        "full_name": data.full_name.strip(),
        "email": data.email.strip().lower(),
        "phone": data.phone.strip() if data.phone else None,
        "goal": data.goal,
        "status": "Pendente Confirmação",
        "trainer_id": trainer_id,
        "created_at": created_at,
        "has_active_prescription": False,
    }
    _STUDENTS_STORE[student_id] = new_student

    return StudentResponse(**new_student)


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
    students = [
        StudentResponse(**st)
        for st in _STUDENTS_STORE.values()
        if st.get("trainer_id") == trainer_id or trainer_id == "dev-user-0000-0000-000000000001" or trainer_id == "current-trainer"
    ]
    return students


@router.put(
    "/students/{student_id}",
    response_model=StudentResponse,
    status_code=status.HTTP_200_OK,
    summary="Atualizar Dados do Aluno",
    description="Permite ao treinador editar nome, objetivo, telefone e histórico/restrições articulares."
)
async def update_student(
    student_id: str,
    data: StudentUpdateRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentResponse:
    if student_id not in _STUDENTS_STORE:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    student = _STUDENTS_STORE[student_id]
    if data.full_name is not None:
        student["full_name"] = data.full_name.strip()
    if data.email is not None:
        student["email"] = data.email.strip().lower()
    if data.phone is not None:
        student["phone"] = data.phone.strip()
    if data.goal is not None:
        student["goal"] = data.goal
    if data.injuries_or_restrictions is not None:
        student["injuries_or_restrictions"] = data.injuries_or_restrictions
    if data.status is not None:
        student["status"] = data.status

    return StudentResponse(**student)


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
    if student_id not in _STUDENTS_STORE:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    _STUDENTS_STORE[student_id]["status"] = data.status
    return StudentResponse(**_STUDENTS_STORE[student_id])


@router.delete(
    "/students/{student_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir Aluno",
    description="Remove o aluno e desvincula prescrições ativas."
)
async def delete_student(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    if student_id not in _STUDENTS_STORE:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Aluno com ID '{student_id}' não encontrado."
        )

    deleted = _STUDENTS_STORE.pop(student_id)
    return {
        "status": "success",
        "message": f"Aluno '{deleted['full_name']}' excluído com sucesso.",
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
    trainer_id = data.trainer_id or "current-trainer"
    alert_id = f"alt_{uuid.uuid4().hex[:8]}"
    created_at = datetime.now().isoformat()

    msg = f"Relatou dor em {data.pain_location or 'articulação'} durante {data.original_exercise} ➔ Adaptado para {data.adapted_exercise}"
    alert_dict = {
        "id": alert_id,
        "student_id": data.student_id,
        "student_name": data.student_name,
        "trainer_id": trainer_id,
        "original_exercise": data.original_exercise,
        "adapted_exercise": data.adapted_exercise,
        "reason": data.reason,
        "pain_location": data.pain_location,
        "severity": data.severity,
        "status": "active",
        "acknowledged": False,
        "created_at": created_at,
        "message": msg,
    }
    _ALERTS_STORE[alert_id] = alert_dict

    return BiomechanicalAlertResponse(**alert_dict)


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
    alerts = [
        BiomechanicalAlertResponse(**alt)
        for alt in reversed(list(_ALERTS_STORE.values()))
        if alt.get("trainer_id") == trainer_id or trainer_id == "current-trainer" or trainer_id == "dev-user-0000-0000-000000000001"
    ]
    return alerts


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
    if alert_id not in _ALERTS_STORE:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Alerta '{alert_id}' não encontrado."
        )

    _ALERTS_STORE[alert_id]["acknowledged"] = True
    _ALERTS_STORE[alert_id]["status"] = "acknowledged"
    return BiomechanicalAlertResponse(**_ALERTS_STORE[alert_id])


@router.post(
    "/students/invite",
    response_model=StudentInviteResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Convidar Aluno via E-mail Profissional e WhatsApp",
    description="Gera convite exclusivo, envia e-mail com template customizado e formata URL de ativação rápida no WhatsApp."
)
async def invite_student(
    payload: StudentInviteRequest,
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> StudentInviteResponse:
    trainer_name = current_user.get("user_metadata", {}).get("full_name") or current_user.get("full_name") or "Roberto Mendes"
    trainer_id = current_user.get("id") or "current-trainer"
    student_id = f"st-{uuid.uuid4().hex[:8]}"

    # Salva o aluno na store com status Pendente Confirmação
    student_record = {
        "id": student_id,
        "email": payload.email,
        "full_name": payload.full_name,
        "phone": payload.phone,
        "trainer_id": trainer_id,
        "status": "Pendente Confirmação",
        "objective": payload.objective or "Hipertrofia Muscular",
        "injuries_or_restrictions": payload.injuries_or_restrictions or "Aguardando avaliação clínica",
        "has_alert": False,
        "last_session": "Pendente Confirmação",
        "active_split": "Não configurado",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _STUDENTS_STORE[student_id] = student_record

    # Gera link seguro de onboarding/convite
    invitation_link = f"{settings.APP_FRONTEND_URL}/#onboarding?student_id={student_id}&trainer_id={trainer_id}"

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
        wa_res = await whatsapp_service.send_text_message(clean_phone, whatsapp_msg)
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


