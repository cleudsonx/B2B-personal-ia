from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from app.services.supabase_service import supabase_service

router = APIRouter()


class DirectRegisterRequest(BaseModel):
    email: str
    password: str = Field(..., min_length=6)
    full_name: str
    role: str = Field("trainer", description="'trainer' ou 'client'")
    phone: Optional[str] = None
    trainer_id: Optional[str] = None
    professional_document_type: Optional[str] = None
    professional_document: Optional[str] = None


class DirectRegisterResponse(BaseModel):
    success: bool
    user_id: str
    email: str
    role: str
    message: str


@router.post("/register-direct", response_model=DirectRegisterResponse)
async def register_user_direct(req: DirectRegisterRequest):
    """
    Cadastra o usuário diretamente via Admin API do Supabase com email pré-confirmado,
    bypassing falhas de SMTP/rate-limit de e-mail de confirmação do Supabase.
    """
    try:
        res = await supabase_service.admin_create_user(
            email=str(req.email),
            password=req.password,
            full_name=req.full_name,
            role=req.role,
            phone=req.phone,
            trainer_id=req.trainer_id,
            professional_document_type=req.professional_document_type,
            professional_document=req.professional_document,
        )
        return DirectRegisterResponse(**res)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro interno ao criar conta: {str(e)}")
