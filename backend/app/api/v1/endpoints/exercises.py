import re
import json
import logging
from pathlib import Path
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from app.services.supabase_service import SupabaseService

logger = logging.getLogger(__name__)
router = APIRouter()
supabase_service = SupabaseService()

# Catálogo em memória para resiliência (funciona mesmo antes da migration ser executada no Supabase)
INITIAL_EXERCISE_MEDIA: Dict[str, Dict[str, Any]] = {
    "agachamento sumo no step com haltere": {
        "name": "Agachamento sumô no step com haltere",
        "slug": "agachamento-sumo-step-haltere",
        "muscle_group": "Glúteos e Adutores",
        "secondary_muscles": "Quadríceps, Isquiotibiais",
        "equipment": "Haltere e Steps",
        "motor_pattern": "Agachamento profundo com base alargada",
        "execution_cues": "Em pé sobre dois steps com afastamento maior que os ombros e pontas dos pés para fora, segure o haltere com as duas mãos e desça agachando profundamente mantendo o tronco alinhado para máxima ativação de glúteos.",
        "media_source": "gdrive_initial",
        "media_url": "https://drive.google.com/uc?export=download&id=17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa",
        "thumbnail_url": "",
    },
    "agachamento bulgaro": {
        "name": "Agachamento Búlgaro",
        "slug": "agachamento-bulgaro",
        "muscle_group": "Quadríceps & Glúteo Máximo",
        "secondary_muscles": "Isquiotibiais, Adutores",
        "equipment": "Halteres e Banco",
        "motor_pattern": "Agachamento unilateral em cadeia cinética fechada",
        "execution_cues": "Apoie o peito de um pé no banco atrás de você. Desça na vertical com o joelho da frente a 90°, mantendo o tronco ligeiramente inclinado para transferir a tensão para o glúteo.",
        "media_source": "gdrive_initial",
        "media_url": "https://drive.google.com/uc?export=download&id=17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa",
        "thumbnail_url": "",
    },
    "supino reto com barra": {
        "name": "Supino Reto com Barra",
        "slug": "supino-reto-barra",
        "muscle_group": "Peitoral Maior",
        "secondary_muscles": "Tríceps Braquial, Deltoide Anterior",
        "equipment": "Barra Olímpica e Banco Reto",
        "motor_pattern": "Empurrar horizontal bipodal",
        "execution_cues": "Pés firmes no chão, escápulas retraídas e deprimidas. Desça a barra controladamente até encostar na linha média do peito e empurre com máxima intenção concêntrica.",
        "media_source": "gdrive_initial",
        "media_url": "",
        "thumbnail_url": "",
    },
    "puxada alta": {
        "name": "Puxada Alta (Lat Pulldown)",
        "slug": "puxada-alta-pulley",
        "muscle_group": "Latíssimo do Dorso",
        "secondary_muscles": "Bíceps, Romboides, Trapézio Médio",
        "equipment": "Polia / Puxador Alto",
        "motor_pattern": "Puxar vertical convergente",
        "execution_cues": "Inicie o movimento puxando os cotovelos para baixo em direção aos bolsos da calça, deprimindo as escápulas antes de flexionar os cotovelos.",
        "media_source": "gdrive_initial",
        "media_url": "",
        "thumbnail_url": "",
    },
    "leg press 45": {
        "name": "Leg Press 45°",
        "slug": "leg-press-45",
        "muscle_group": "Quadríceps & Glúteos",
        "secondary_muscles": "Adutores",
        "equipment": "Máquina Leg Press 45°",
        "motor_pattern": "Extensão de quadril e joelho",
        "execution_cues": "Mantenha a lombar e o sacro colados no assento durante toda a descida. Desça até 90° de joelhos e empurre pela base do calcanhar sem hiperestender as articulações no topo.",
        "media_source": "gdrive_initial",
        "media_url": "",
        "thumbnail_url": "",
    }
}


def _get_combined_catalog() -> Dict[str, Dict[str, Any]]:
    catalog = dict(INITIAL_EXERCISE_MEDIA)
    catalog_path = Path(__file__).resolve().parent.parent.parent.parent / "data" / "exercise_catalog.json"
    if catalog_path.exists():
        try:
            with open(catalog_path, "r", encoding="utf-8") as f:
                extra = json.load(f)
                if isinstance(extra, dict):
                    catalog.update(extra)
        except Exception as e:
            logger.warning(f"[ExerciseLibrary] Erro ao ler exercise_catalog.json: {e}")
    return catalog


def _normalize(text: str) -> str:
    if not text:
        return ""
    clean = text.lower().strip()
    clean = re.sub(r"[áàãâä]", "a", clean)
    clean = re.sub(r"[éèêë]", "e", clean)
    clean = re.sub(r"[íìîï]", "i", clean)
    clean = re.sub(r"[óòõôö]", "o", clean)
    clean = re.sub(r"[úùûü]", "u", clean)
    clean = re.sub(r"[ç]", "c", clean)
    clean = re.sub(r"[^a-z0-9\s]", "", clean)
    return " ".join(clean.split())


class ExerciseMediaResponse(BaseModel):
    name: str
    slug: str
    muscle_group: str
    secondary_muscles: Optional[str] = None
    equipment: str
    motor_pattern: Optional[str] = None
    execution_cues: Optional[str] = None
    media_source: str
    media_url: str
    thumbnail_url: Optional[str] = None


@router.get("/media", response_model=Optional[ExerciseMediaResponse])
async def get_exercise_media(name: str = Query(..., description="Nome do exercício para buscar mídia")):
    """
    Busca mídia (vídeo/animação) do exercício por nome aproximado ou slug.
    Resiliente: Consulta o Supabase e usa fallback local caso o banco esteja sincronizando.
    """
    norm = _normalize(name)
    if not norm:
        raise HTTPException(status_code=400, detail="Nome de exercício inválido")

    # 1. Tenta buscar no Supabase
    try:
        client = await supabase_service.get_client()
        if client:
            res = await client.table("exercise_library").select("*").ilike("name", f"%{name}%").limit(1).execute()
            if res.data and len(res.data) > 0:
                row = res.data[0]
                return ExerciseMediaResponse(
                    name=row["name"],
                    slug=row.get("normalized_slug") or _normalize(row["name"]).replace(" ", "-"),
                    muscle_group=row["muscle_group"],
                    secondary_muscles=row.get("secondary_muscles"),
                    equipment=row["equipment"],
                    motor_pattern=row.get("motor_pattern"),
                    execution_cues=row.get("execution_cues"),
                    media_source=row.get("media_source", "custom"),
                    media_url=row["media_url"],
                    thumbnail_url=row.get("thumbnail_url"),
                )
    except Exception as e:
        logger.warning(f"[ExerciseLibrary] Supabase fallback: {e}")

    # 2. Fallback de memória resiliente (estático + catalog.json)
    combined = _get_combined_catalog()
    for key, data in combined.items():
        if key in norm or norm in key:
            return ExerciseMediaResponse(
                name=data["name"],
                slug=data["slug"],
                muscle_group=data["muscle_group"],
                secondary_muscles=data.get("secondary_muscles"),
                equipment=data["equipment"],
                motor_pattern=data.get("motor_pattern"),
                execution_cues=data.get("execution_cues"),
                media_source=data["media_source"],
                media_url=data["media_url"],
                thumbnail_url=data.get("thumbnail_url"),
            )

    return None


@router.get("/library", response_model=List[ExerciseMediaResponse])
async def list_exercise_library(
    q: Optional[str] = Query(None, description="Termo de busca"),
    muscle: Optional[str] = Query(None, description="Filtro por grupo muscular")
):
    """
    Lista todos os exercícios com suporte multimídia disponíveis.
    """
    results: List[ExerciseMediaResponse] = []

    # 1. Consulta Supabase
    try:
        client = await supabase_service.get_client()
        if client:
            query = client.table("exercise_library").select("*").eq("is_active", True)
            if q:
                query = query.ilike("name", f"%{q}%")
            if muscle:
                query = query.ilike("muscle_group", f"%{muscle}%")
            res = await query.limit(50).execute()
            if res.data:
                for row in res.data:
                    results.append(
                        ExerciseMediaResponse(
                            name=row["name"],
                            slug=row.get("normalized_slug") or _normalize(row["name"]).replace(" ", "-"),
                            muscle_group=row["muscle_group"],
                            secondary_muscles=row.get("secondary_muscles"),
                            equipment=row["equipment"],
                            motor_pattern=row.get("motor_pattern"),
                            execution_cues=row.get("execution_cues"),
                            media_source=row.get("media_source", "custom"),
                            media_url=row["media_url"],
                            thumbnail_url=row.get("thumbnail_url"),
                        )
                    )
                return results
    except Exception as e:
        logger.warning(f"[ExerciseLibrary] Falha ao listar do banco, usando catálogo base: {e}")

    # 2. Fallback
    combined = _get_combined_catalog()
    for data in combined.values():
        if q and _normalize(q) not in _normalize(data["name"]):
            continue
        if muscle and _normalize(muscle) not in _normalize(data["muscle_group"]):
            continue
        results.append(
            ExerciseMediaResponse(
                name=data["name"],
                slug=data["slug"],
                muscle_group=data["muscle_group"],
                secondary_muscles=data.get("secondary_muscles"),
                equipment=data["equipment"],
                motor_pattern=data.get("motor_pattern"),
                execution_cues=data.get("execution_cues"),
                media_source=data["media_source"],
                media_url=data["media_url"],
                thumbnail_url=data.get("thumbnail_url"),
            )
        )

    return results

