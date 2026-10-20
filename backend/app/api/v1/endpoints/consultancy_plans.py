# backend/app/api/v1/endpoints/consultancy_plans.py
# FASE 6: Gestão de Planos de Consultoria do Personal Trainer

from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from app.api.deps import get_current_trainer
from app.services.consultancy_plan_service import ConsultancyPlanService
from app.schemas.consultancy_plan import (
    ConsultancyPlanCreate,
    ConsultancyPlanUpdate,
    ConsultancyPlanResponse,
)

router = APIRouter()


@router.get(
    "/trainers/consultancy-plans",
    response_model=List[ConsultancyPlanResponse],
    summary="Listar Planos de Consultoria do Treinador",
    description="Retorna todos os planos de consultoria cadastrados pelo personal logado.",
)
async def list_my_plans(
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> List[ConsultancyPlanResponse]:
    trainer_id = current_user.get("sub") or current_user.get("id")
    return await ConsultancyPlanService.list_trainer_plans(trainer_id, only_active=False)


@router.post(
    "/trainers/consultancy-plans",
    response_model=ConsultancyPlanResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Criar Novo Plano de Consultoria",
    description="Cadastra um plano de consultoria, ficha avulsa ou mentoria na vitrine do treinador.",
)
async def create_plan(
    req: ConsultancyPlanCreate,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> ConsultancyPlanResponse:
    trainer_id = current_user.get("sub") or current_user.get("id")
    return await ConsultancyPlanService.create_plan(trainer_id, req)


@router.put(
    "/trainers/consultancy-plans/{plan_id}",
    response_model=ConsultancyPlanResponse,
    summary="Editar Plano de Consultoria",
    description="Atualiza nome, descrição, preço, periodicidade ou status do plano.",
)
async def update_plan(
    plan_id: str,
    req: ConsultancyPlanUpdate,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> ConsultancyPlanResponse:
    trainer_id = current_user.get("sub") or current_user.get("id")
    updated = await ConsultancyPlanService.update_plan(plan_id, trainer_id, req)
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano não encontrado ou não pertence a este treinador.",
        )
    return updated


@router.delete(
    "/trainers/consultancy-plans/{plan_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir Plano de Consultoria",
    description="Remove um plano de consultoria da vitrine do treinador.",
)
async def delete_plan(
    plan_id: str,
    current_user: Dict[str, Any] = Depends(get_current_trainer)
) -> Dict[str, Any]:
    trainer_id = current_user.get("sub") or current_user.get("id")
    deleted = await ConsultancyPlanService.delete_plan(plan_id, trainer_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Plano não encontrado ou não pertence a este treinador.",
        )
    return {"ok": True, "message": "Plano excluído com sucesso."}
