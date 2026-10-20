from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel
from typing import List, Optional, Any
import base64
import uuid
from app.core.config import settings
from app.services.supabase_service import supabase_service, is_valid_uuid
from app.services.ai_news_service import get_ai_news
import time

_PUBLIC_TRAINER_CACHE: dict[str, tuple[float, Any]] = {}
_PUBLIC_PLANS_CACHE: dict[str, tuple[float, Any]] = {}
_PUBLIC_CACHE_TTL = 30  # 30 segundos de cache em memória


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
    cref: Optional[str] = None
    accepts_new_students: bool = True


@router.get("/trainers", response_model=List[TrainerPublicProfile], summary="Listar vitrines públicas de treinadores")
async def list_public_trainers(
    limit: int = Query(default=30, ge=1, le=50),
):
    """Lista vitrines configuradas e validadas, sem dados pessoais de contato."""
    if limit < 1 or limit > 50:
        raise HTTPException(status_code=422, detail="O limite deve ficar entre 1 e 50.")
    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=503, detail="Catálogo temporariamente indisponível.")

    try:
        response = await (
            client.table("profiles")
            .select(
                "id, full_name, username, bio, specialties, public_whatsapp, "
                "photo_url, avatar_url, role, professional_document, "
                "public_directory_enabled"
            )
            .eq("role", "trainer")
            .eq("public_directory_enabled", True)
            .limit(200)
            .execute()
        )
        profiles = response.data or []
        public_profiles = []
        for profile in profiles:
            username = (profile.get("username") or "").strip()
            bio = (profile.get("bio") or "").strip()
            document = (profile.get("professional_document") or "").strip()
            public_cref = document if document.upper().startswith("CREF") else ""
            if not profile.get("public_directory_enabled") or not username or not bio or not public_cref:
                continue
            public_profiles.append(
                TrainerPublicProfile(
                    id=str(profile["id"]),
                    full_name=profile.get("full_name") or "Treinador",
                    username=username,
                    bio=bio,
                    specialties=profile.get("specialties") or [],
                    public_whatsapp=profile.get("public_whatsapp"),
                    photo_url=profile.get("photo_url") or profile.get("avatar_url"),
                    cref=public_cref,
                )
            )
        return public_profiles[:limit]
    except Exception as e:
        raise HTTPException(status_code=500, detail="Erro ao carregar catálogo público.") from e

@router.get("/trainers/{username}", response_model=TrainerPublicProfile, summary="Obter Perfil Público do Treinador")
async def get_public_trainer_profile(username: str):
    """
    Retorna os dados públicos de um Personal Trainer usando o seu username (slug) ou ID.
    Esta rota não exige autenticação e é usada para renderizar a Landing Page B2B.
    """
    clean_key = username.strip().lower()
    now_ts = time.time()
    if clean_key in _PUBLIC_TRAINER_CACHE:
        cached_ts, cached_prof = _PUBLIC_TRAINER_CACHE[clean_key]
        if now_ts - cached_ts < _PUBLIC_CACHE_TTL:
            return cached_prof

    client = await supabase_service.get_client()
    if not client:
        raise HTTPException(status_code=500, detail="Database connection error")

    clean_user = username.strip()

    try:
        # 1. Tenta buscar pelo username (case-insensitive para máxima usabilidade de URLs)
        response = await client.table("profiles")\
            .select("id, full_name, bio, specialties, public_whatsapp, photo_url, avatar_url, username, role, professional_document, public_directory_enabled")\
            .ilike("username", clean_user)\
            .eq("role", "trainer")\
            .maybe_single()\
            .execute()
        
        # 2. Fallback: Se não achou por username, tenta por ID (apenas se for UUID válido)
        if (not response or not response.data) and is_valid_uuid(clean_user):
            response = await client.table("profiles")\
                .select("id, full_name, bio, specialties, public_whatsapp, photo_url, avatar_url, username, role, professional_document, public_directory_enabled")\
                .eq("id", clean_user)\
                .eq("role", "trainer")\
                .maybe_single()\
                .execute()

        if not response or not response.data:
            raise HTTPException(status_code=404, detail="Treinador não encontrado.")

        data = response.data
        if data.get("role") != "trainer":
            raise HTTPException(status_code=403, detail="Perfil não é de um treinador.")

        if (
            not data.get("public_directory_enabled")
            or not (data.get("username") or "").strip()
            or not (data.get("bio") or "").strip()
        ):
            raise HTTPException(status_code=404, detail="Treinador não encontrado.")

        # Trava de CREF
        doc_val = data.get("professional_document") or ""
        public_cref = str(doc_val).strip() if str(doc_val).strip().upper().startswith("CREF") else ""
        if not public_cref:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Perfil profissional ainda não validado (CREF pendente)"
            )

        # Garantir que specialties seja lista
        specialties = data.get("specialties")
        if not isinstance(specialties, list):
            specialties = []

        # Verifica cota de vagas do treinador
        accepts_new_students = True
        try:
            occupied = await supabase_service.count_trainer_occupied_slots(data["id"])
            sub = await supabase_service.get_trainer_subscription(data["id"])
            accepts_new_students = occupied < sub.max_students
        except Exception as q_err:
            logger.warning(f"[Public] Falha ao checar vagas do treinador {clean_key}: {q_err}")

        prof = TrainerPublicProfile(
            id=data.get("id"),
            full_name=data.get("full_name") or "Treinador",
            bio=data.get("bio"),
            specialties=specialties,
            public_whatsapp=data.get("public_whatsapp"),
            photo_url=data.get("photo_url") or data.get("avatar_url"),
            username=data.get("username"),
            cref=public_cref,
            accepts_new_students=accepts_new_students,
        )
        _PUBLIC_TRAINER_CACHE[clean_key] = (now_ts, prof)
        if prof.id:
            _PUBLIC_TRAINER_CACHE[str(prof.id).lower()] = (now_ts, prof)
        return prof
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")


class AvatarUploadRequest(BaseModel):
    image_base64: str
    user_id: Optional[str] = None
    content_type: Optional[str] = "image/jpeg"


class AvatarUploadResponse(BaseModel):
    avatar_url: str


@router.post("/upload-avatar", response_model=AvatarUploadResponse, summary="Upload de avatar/foto para armazenamento público")
async def upload_avatar_endpoint(payload: AvatarUploadRequest):
    """
    Recebe uma imagem codificada em base64 (câmera ou galeria) e armazena com segurança
    no bucket de avatares do Supabase com URL pública acessível.
    """
    try:
        raw_b64 = payload.image_base64
        if "," in raw_b64:
            raw_b64 = raw_b64.split(",", 1)[1]
        
        image_bytes = base64.b64decode(raw_b64)
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Imagem vazia.")
        if len(image_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="A imagem não pode ultrapassar 10MB.")

        ext = "jpg"
        content_type = payload.content_type or "image/jpeg"
        if "png" in content_type.lower():
            ext = "png"
        elif "webp" in content_type.lower():
            ext = "webp"

        user_prefix = payload.user_id if payload.user_id and is_valid_uuid(payload.user_id) else "user"
        file_name = f"uploads/{user_prefix}_{uuid.uuid4().hex[:12]}.{ext}"

        client = await supabase_service.get_client()
        if not client:
            raise HTTPException(status_code=503, detail="Serviço de armazenamento indisponível.")

        await client.storage.from_("avatars").upload(
            file_name,
            image_bytes,
            {"upsert": "true", "content-type": content_type}
        )

        public_url = f"{settings.SUPABASE_URL}/storage/v1/object/public/avatars/{file_name}"
        return AvatarUploadResponse(avatar_url=public_url)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Falha ao realizar upload da imagem: {str(e)}")



# ==============================================================================
# FASE 6: Planos de Consultoria e Checkout Transparente na Vitrine Pública
# ==============================================================================

from app.schemas.consultancy_plan import (
    ConsultancyPlanResponse,
    PublicCheckoutRequest,
    PublicCheckoutResponse,
)
from app.services.consultancy_plan_service import ConsultancyPlanService


@router.get(
    "/trainers/{username}/plans",
    response_model=List[ConsultancyPlanResponse],
    summary="Listar Planos de Consultoria Ativos do Treinador",
    description="Retorna os planos e preços ativos na Vitrine Pública para contratação por novos alunos.",
)
async def list_public_trainer_plans(username: str):
    clean_user = username.strip().lower()
    now_ts = time.time()
    if clean_user in _PUBLIC_PLANS_CACHE:
        cached_ts, cached_plans = _PUBLIC_PLANS_CACHE[clean_user]
        if now_ts - cached_ts < _PUBLIC_CACHE_TTL:
            return cached_plans
    client = await supabase_service.get_client()
    trainer_id = None

    if client:
        try:
            res = await client.table("profiles").select("id").ilike("username", clean_user).maybe_single().execute()
            if res and res.data:
                trainer_id = res.data["id"]
        except Exception:
            pass

    if not trainer_id and is_valid_uuid(clean_user):
        trainer_id = clean_user

    if not trainer_id:
        if clean_user == "mrcoach":
            trainer_id = "6f645308-f1b2-4d73-ac45-9890c27e20d4"
        else:
            raise HTTPException(status_code=404, detail="Treinador não encontrado.")

    plans = await ConsultancyPlanService.list_trainer_plans(trainer_id, only_active=True)
    _PUBLIC_PLANS_CACHE[clean_user] = (now_ts, plans)
    return plans


@router.post(
    "/trainers/{username}/checkout",
    response_model=PublicCheckoutResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Checkout Transparente do Aluno na Vitrine",
    description="Gera a cobrança (Pix com QR Code ou Cartão via Asaas) para o aluno assinar a consultoria do personal.",
)
async def public_trainer_checkout(username: str, req: PublicCheckoutRequest):
    try:
        return await ConsultancyPlanService.process_public_checkout(username, req)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao processar checkout: {str(e)}")
