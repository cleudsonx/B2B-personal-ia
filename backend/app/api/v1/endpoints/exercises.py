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


STOPWORDS = {
    'de', 'da', 'do', 'das', 'dos', 'em', 'no', 'na', 'nos', 'nas', 
    'com', 'e', 'para', 'o', 'a', 'os', 'as', 'um', 'uma', 'ao', 'aos'
}


def _tokenize(text: str) -> List[str]:
    clean = _normalize(text)
    return [w for w in clean.split() if len(w) > 1 and w not in STOPWORDS]


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
    Busca mídia (vídeo/animação) do exercício por busca inteligente de correspondência.
    Resiliente: Consulta o Supabase e usa fallback local caso o banco esteja sincronizando.
    """
    norm = _normalize(name)
    if not norm:
        raise HTTPException(status_code=400, detail="Nome de exercício inválido")

    tokens = _tokenize(name)

    # 1. Tenta buscar no Supabase com busca inteligente por tokens
    try:
        client = await supabase_service.get_client()
        if client:
            candidates = []
            if tokens:
                # Busca pelo primeiro token principal (ex: desenvolvimento, agachamento, supino, puxada)
                res = await client.table("exercise_library").select("*").ilike("name", f"%{tokens[0]}%").limit(25).execute()
                candidates = res.data or []
            
            # Se não encontrou, tenta buscar por qualquer outro token
            if not candidates and len(tokens) > 1:
                for t in tokens[1:]:
                    res = await client.table("exercise_library").select("*").ilike("name", f"%{t}%").limit(25).execute()
                    if res.data:
                        candidates.extend(res.data)
                        break

            # Se ainda não encontrou, tenta busca ilike direta no nome completo
            if not candidates:
                res = await client.table("exercise_library").select("*").ilike("name", f"%{name}%").limit(10).execute()
                candidates = res.data or []

            if candidates:
                # Pontua cada candidato por correspondência e proximidade semântica
                best_row = None
                best_score = -1
                for row in candidates:
                    row_tokens = set(_tokenize(row["name"]))
                    score = sum(2 if t in row_tokens else 0 for t in tokens)
                    if tokens and tokens[0] in row_tokens:
                        score += 3
                    row_norm = _normalize(row["name"])
                    if row_norm in norm or norm in row_norm:
                        score += 5
                    if score > best_score:
                        best_score = score
                        best_row = row

                if best_row:
                    return ExerciseMediaResponse(
                        name=best_row["name"],
                        slug=best_row.get("normalized_slug") or _normalize(best_row["name"]).replace(" ", "-"),
                        muscle_group=best_row["muscle_group"],
                        secondary_muscles=best_row.get("secondary_muscles"),
                        equipment=best_row["equipment"],
                        motor_pattern=best_row.get("motor_pattern"),
                        execution_cues=best_row.get("execution_cues"),
                        media_source=best_row.get("media_source", "custom"),
                        media_url=best_row["media_url"],
                        thumbnail_url=best_row.get("thumbnail_url"),
                    )
    except Exception as e:
        logger.warning(f"[ExerciseLibrary] Supabase fallback: {e}")

    # 2. Fallback de memória resiliente com pontuação de tokens (estático + catalog.json)
    combined = _get_combined_catalog()
    best_data = None
    best_score = -1
    for data in combined.values():
        data_tokens = set(_tokenize(data["name"]))
        score = sum(2 if t in data_tokens else 0 for t in tokens)
        if tokens and tokens[0] in data_tokens:
            score += 3
        key = _normalize(data["name"])
        if key in norm or norm in key:
            score += 5
        if score > best_score and score >= 3:
            best_score = score
            best_data = data

    if best_data:
        return ExerciseMediaResponse(
            name=best_data["name"],
            slug=best_data["slug"],
            muscle_group=best_data["muscle_group"],
            secondary_muscles=best_data.get("secondary_muscles"),
            equipment=best_data["equipment"],
            motor_pattern=best_data.get("motor_pattern"),
            execution_cues=best_data.get("execution_cues"),
            media_source=best_data["media_source"],
            media_url=best_data["media_url"],
            thumbnail_url=best_data.get("thumbnail_url"),
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

