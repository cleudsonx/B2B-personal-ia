from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional, Any
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.ai_news_service import get_ai_news

router = APIRouter()


@router.get("/ai-news", summary="Notícias oficiais recentes sobre IA")
async def list_ai_news():
    return await get_ai_news()

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

    clean_user = username.strip()

    try:
        # 1. Tenta buscar pelo username (case-insensitive para máxima usabilidade de URLs)
        response = await client.table("profiles")\
            .select("id, full_name, bio, specialties, public_whatsapp, photo_url, avatar_url, username, role, cref, professional_document")\
            .ilike("username", clean_user)\
            .eq("role", "trainer")\
            .maybe_single()\
            .execute()
        
        # 2. Fallback: Se não achou por username, tenta por ID (apenas se for UUID válido)
        if (not response or not response.data) and is_valid_uuid(clean_user):
            response = await client.table("profiles")\
                .select("id, full_name, bio, specialties, public_whatsapp, photo_url, avatar_url, username, role, cref, professional_document")\
                .eq("id", clean_user)\
                .eq("role", "trainer")\
                .maybe_single()\
                .execute()

        if not response or not response.data:
            raise HTTPException(status_code=404, detail="Treinador não encontrado.")

        data = response.data
        if data.get("role") != "trainer":
            raise HTTPException(status_code=403, detail="Perfil não é de um treinador.")

        # Trava de CREF
        cref_val = data.get("cref") or ""
        doc_val = data.get("professional_document") or ""
        if not str(cref_val).strip() and not str(doc_val).strip():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Perfil profissional ainda não validado (CREF pendente)"
            )

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
            photo_url=data.get("photo_url") or data.get("avatar_url"),
            username=data.get("username")
        )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

