from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional, Any
from app.services.supabase_service import supabase_service

router = APIRouter()

class TrainerPublicProfile(BaseModel):
    id: str
    full_name: str
    bio: Optional[str] = None
    specialties: Optional[List[str]] = []
    public_whatsapp: Optional[str] = None
    photo_url: Optional[str] = None
    username: Optional[str] = None

@router.get("/trainers/{username}", response_model=TrainerPublicProfile, summary="Obter Perfil Público do Treinador")
async def get_public_trainer_profile(username: str):
    """
    Retorna os dados públicos de um Personal Trainer usando o seu username (slug) ou ID.
    Esta rota não exige autenticação e é usada para renderizar a Landing Page B2B.
    """
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Database connection error")

    try:
        # Tenta buscar pelo username
        response = await client.table("profiles")\
            .select("id, full_name, bio, specialties, public_whatsapp, photo_url, username, role")\
            .eq("username", username)\
            .maybe_single()\
            .execute()
        
        # Fallback: Se não achou por username, tenta por ID (se for UUID válido)
        if not response or not response.data:
            response = await client.table("profiles")\
                .select("id, full_name, bio, specialties, public_whatsapp, photo_url, username, role")\
                .eq("id", username)\
                .maybe_single()\
                .execute()

        if not response or not response.data:
            raise HTTPException(status_code=404, detail="Treinador não encontrado.")

        data = response.data
        if data.get("role") != "trainer":
            raise HTTPException(status_code=403, detail="Perfil não é de um treinador.")

        # Garantir que specialties seja lista
        specialties = data.get("specialties")
        if not isinstance(specialties, list):
            specialties = []

        return TrainerPublicProfile(
            id=data.get("id"),
            full_name=data.get("full_name") or "Treinador",
            bio=data.get("bio"),
            specialties=specialties,
            public_whatsapp=data.get("public_whatsapp"),
            photo_url=data.get("photo_url"),
            username=data.get("username")
        )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")
