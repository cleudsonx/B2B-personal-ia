import logging
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.clinical import (
    JointRegion,
    StudentClinicalProfile,
    BiomechanicalSafetyCheckRequest,
    BiomechanicalSafetyReport,
)
from app.services.cinesiology_engine import cinesiology_engine, CINESIOLOGY_KNOWLEDGE_BASE
from app.services.supabase_service import supabase_service
from app.api.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/catalog", summary="Catálogo Anatômico de Articulações e Vetores de Risco")
async def get_clinical_catalog():
    """
    Retorna o catálogo de articulações mapeadas, labels legíveis e vetores de risco
    para popular a Matriz Articular interativa no aplicativo.
    """
    catalog = []
    for joint_region, data in CINESIOLOGY_KNOWLEDGE_BASE.items():
        catalog.append({
            "joint": joint_region.value,
            "label": data["label"],
            "common_conditions": [kw.capitalize() for kw in data["keywords"][:5]],
            "avoid_vectors": [c["avoid_vector"] for c in data["contraindications"]],
            "default_substitute_tip": data.get("default_substitute", ""),
        })
    return {"joints": catalog}


@router.post(
    "/safety-check",
    response_model=BiomechanicalSafetyReport,
    summary="Avaliação Biomecânica de Segurança e Detecção de Contraindicações",
    description="Avalia um plano de treino contra a matriz articular do aluno e retorna contraindicações e alternativas protetoras."
)
async def evaluate_safety(
    req: BiomechanicalSafetyCheckRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> BiomechanicalSafetyReport:
    active_restrictions = req.restrictions or []

    # Se student_id foi passado e não há restrições explícitas no body, busca o perfil clínico do aluno
    if req.student_id and not active_restrictions:
        profile = await supabase_service.get_student_clinical_profile(req.student_id)
        if profile and profile.restrictions:
            active_restrictions = profile.restrictions
        elif profile and profile.general_clinical_notes:
            req.raw_restrictions_text = req.raw_restrictions_text or profile.general_clinical_notes

    report = cinesiology_engine.evaluate_workout_safety(
        workout_plan=req.workout_plan,
        restrictions=active_restrictions,
        raw_restrictions_text=req.raw_restrictions_text,
        auto_apply_substitutes=req.auto_apply_substitutes,
    )
    return report


@router.get(
    "/students/{student_id}/profile",
    response_model=StudentClinicalProfile,
    summary="Obter Perfil Clínico e Matriz Articular do Aluno"
)
async def get_student_clinical_profile(
    student_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> StudentClinicalProfile:
    profile = await supabase_service.get_student_clinical_profile(student_id)
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Perfil clínico do aluno não encontrado."
        )
    return profile


@router.put(
    "/students/{student_id}/profile",
    response_model=StudentClinicalProfile,
    summary="Atualizar Matriz Articular e Restrições Clínicas do Aluno"
)
async def update_student_clinical_profile(
    student_id: str,
    profile_data: StudentClinicalProfile,
    current_user: Dict[str, Any] = Depends(get_current_user),
) -> StudentClinicalProfile:
    if profile_data.student_id != student_id:
        profile_data.student_id = student_id

    trainer_id = current_user.get("sub") or current_user.get("id")
    updated = await supabase_service.save_student_clinical_profile(profile_data, trainer_id=trainer_id)
    return updated
