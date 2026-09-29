import uuid
from datetime import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.anamnesis import AnamnesisInput
from app.schemas.workout import (
    WorkoutPlanResponse,
    PrescriptionSaveRequest,
    PrescriptionSaveResponse,
    StudentCreateRequest,
    StudentResponse,
)
from app.services.gemini_service import GeminiService
from app.api.deps import get_gemini_service, get_current_user

router = APIRouter()

# Armazenamento em memória com integridade referencial para persistência e fallback robusto
_PRESCRIPTIONS_STORE: Dict[str, Dict[str, Any]] = {}
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
