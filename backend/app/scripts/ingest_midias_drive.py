"""
Ingestor do Acervo Definitivo de Mídias (GIFs e Vídeos) do Google Drive.

Mapeia a árvore de pastas e subpastas da pasta 'MIDIAS' (12z2gPSsg06-CmXt4TtrhAcXDHMPqd_0m),
limpa os nomes dos exercícios, associa os grupos musculares e equipamentos, e sincroniza
diretamente com backend/app/data/exercise_catalog.json e com a tabela exercise_library do Supabase.
"""

import os
import sys
import re
import json
import asyncio
import logging
import urllib.request
from pathlib import Path
from dotenv import load_dotenv

sys.stdout.reconfigure(encoding='utf-8')

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(BACKEND_DIR))
load_dotenv(BACKEND_DIR / ".env")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("MidiasIngestor")

from app.services.supabase_service import SupabaseService

ROOT_MIDIAS_FOLDER_ID = "12z2gPSsg06-CmXt4TtrhAcXDHMPqd_0m"
CATALOG_DB_PATH = BACKEND_DIR / "app" / "data" / "exercise_catalog.json"


def fix_encoding(text: str) -> str:
    """Corrige caracteres com dupla codificação (mojibake)."""
    try:
        # Tenta reverter UTF-8 interpretado como latin1 ou cp1252
        fixed = text.encode('latin1', errors='ignore').decode('utf-8', errors='ignore')
        if len(fixed) > 0 and not ('Ã' in fixed or 'Â' in fixed):
            return fixed
    except Exception:
        pass
    return text


def clean_exercise_name(filename: str) -> str:
    """Transforma 'Triceps testa supinado (1).gif' em 'Tríceps Testa Supinado'."""
    name = filename.strip()
    # Remove extensão
    name = re.sub(r'\.(gif|mp4|png|jpg|jpeg|webp)$', '', name, flags=re.IGNORECASE)
    # Remove sufixos como (1), _01, etc.
    name = re.sub(r'\s*\(\d+\)$', '', name)
    name = re.sub(r'[\-_]0\d+$', '', name)
    name = re.sub(r'[\-_]\d+$', '', name)
    name = re.sub(r'[-_]', ' ', name)

    name = fix_encoding(name).strip()

    # Correções fonéticas e acentuação comum
    replacements = {
        r'\btriceps\b': 'Tríceps',
        r'\bbiceps\b': 'Bíceps',
        r'\babs\b': 'Abdominal',
        r'\babdominal\b': 'Abdominal',
        r'\belevacao\b': 'Elevação',
        r'\bextensao\b': 'Extensão',
        r'\bflexao\b': 'Flexão',
        r'\bmaquina\b': 'Máquina',
        r'\bpolia\b': 'Polia',
        r'\bpress\b': 'Press',
        r'\bcrunch\b': 'Abdominal Crunch',
        r'\bfacepull\b': 'Face Pull',
        r'\bclean\b': 'Clean (Levantamento Olímpico)',
        r'\bgluteo\b': 'Glúteo',
        r'\bgluteos\b': 'Glúteos',
    }
    lowered = name.lower()
    for pattern, rep in replacements.items():
        lowered = re.sub(pattern, rep, lowered, flags=re.IGNORECASE)

    # Capitaliza primeiras letras de forma elegante
    words = lowered.split()
    capitalized = []
    lowercase_words = {'de', 'da', 'do', 'das', 'dos', 'em', 'no', 'na', 'nos', 'nas', 'com', 'e', 'para'}
    for i, w in enumerate(words):
        if i > 0 and w.lower() in lowercase_words:
            capitalized.append(w.lower())
        else:
            capitalized.append(w.capitalize())

    final_name = " ".join(capitalized)
    return final_name


def normalize_slug(text: str) -> str:
    clean = text.lower().strip()
    clean = re.sub(r"[áàãâä]", "a", clean)
    clean = re.sub(r"[éèêë]", "e", clean)
    clean = re.sub(r"[íìîï]", "i", clean)
    clean = re.sub(r"[óòõôö]", "o", clean)
    clean = re.sub(r"[úùûü]", "u", clean)
    clean = re.sub(r"[ç]", "c", clean)
    clean = re.sub(r"[^a-z0-9\s]", "", clean)
    return "-".join(clean.split())


def infer_equipment(name: str, group: str) -> str:
    n = name.lower()
    if "polia" in n or "cabo" in n or "cross" in n:
        return "Polia / Cabo"
    if "halter" in n or "dumb" in n:
        return "Halteres"
    if "barra" in n or "smith" in n:
        return "Barra"
    if "maquina" in n or "leg press" in n or "extensora" in n or "flexora" in n:
        return "Máquina Específica"
    if "banco" in n:
        return "Banco"
    if "step" in n:
        return "Step"
    if "calistenia" in group.lower() or "peso corporal" in n:
        return "Peso Corporal"
    return "Livre / Equipamento de Academia"


def fetch_folder_entries(folder_id: str) -> list[tuple[str, str, str]]:
    """Retorna lista de (id, name, mimeType) dos itens de uma pasta pública do Drive."""
    url = f"https://drive.google.com/drive/folders/{folder_id}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read().decode('utf-8', errors='ignore')
        m_ivd = re.search(r"window\['_DRIVE_ivd'\]\s*=\s*'([^']+)'", html)
        if m_ivd:
            raw_ivd = m_ivd.group(1).encode('utf-8').decode('unicode_escape', errors='ignore')
            return re.findall(r'\["([a-zA-Z0-9_\-]{25,40})",\["[a-zA-Z0-9_\-]+"\],"([^"]+)","([^"]+)"', raw_ivd)
    except Exception as e:
        logger.error(f"Erro ao buscar pasta {folder_id}: {e}")
    return []


async def run_ingestion():
    logger.info("=== INICIANDO INGESTÃO DO ACERVO DEFINITIVO DE MÍDIAS ===")

    # 1. Carrega catálogo existente para preservar enriquecimentos anteriores
    catalog_db = {}
    if CATALOG_DB_PATH.exists():
        try:
            with open(CATALOG_DB_PATH, "r", encoding="utf-8") as f:
                catalog_db = json.load(f)
            logger.info(f"Catálogo prévio carregado com {len(catalog_db)} exercícios.")
        except Exception as e:
            logger.warning(f"Erro ao carregar catálogo prévio: {e}")

    # Subpastas de Musculação
    muscle_folders = [
        ("1AyIUKylYpo4goHep3P4oAdbVVgz0Itan", "Abdômen & Core"),
        ("1nqFU1rhG-55RqOHNEM6T532MZRyEADHb", "Bíceps & Antebraço"),
        ("1BpUDWSt_LGJofiM12JtfEFJHkZUDo1nk", "Costas & Trapézio"),
        ("1oN8Z4UYaGL8HAjJjfChZ2MtPps8R0Bl7", "Deltóides"),
        ("18kU2i-zZDxOjPV-19TBTgS0vD8FvGhwZ", "Membros Inferiores & Glúteos"),
        ("1vkbhKZznkme7dezyt7jIAXRueoxSSttQ", "Panturrilhas"),
        ("1M-vppInNeqgP9jcdG3sR6W4hFJhWmMND", "Peitoral"),
        ("1GbiThHkuTJ9PftpREU8d0tEB9U5MdWT2", "Tríceps"),
    ]

    total_added = 0
    all_rows_for_supabase = []

    # Processa Musculação
    for fid, group_name in muscle_folders:
        entries = fetch_folder_entries(fid)
        files = [e for e in entries if 'folder' not in e[2]]
        logger.info(f"Processando '{group_name}': {len(files)} arquivos...")

        for file_id, raw_filename, mime in files:
            clean_name = clean_exercise_name(raw_filename)
            slug = normalize_slug(clean_name)
            key = normalize_slug(clean_name).replace("-", " ")

            equipment = infer_equipment(clean_name, group_name)

            record = {
                "name": clean_name,
                "slug": slug,
                "muscle_group": group_name,
                "secondary_muscles": "",
                "equipment": equipment,
                "motor_pattern": "Biomecânica e Cinesiologia Guiada",
                "execution_cues": f"Execução com foco primário em {group_name}. Mantenha cadência controlada e amplitude segura.",
                "media_source": "gdrive_midias",
                "media_url": f"https://drive.google.com/uc?export=download&id={file_id}",
                "thumbnail_url": f"https://lh3.googleusercontent.com/d/{file_id}",
                "drive_file_id": file_id,
                "source_filename": raw_filename,
                "media_type": "gif"
            }

            # Se já existia um exercício com esse nome enriquecido pelo Gemini, preserva os detalhes biomecânicos
            if key in catalog_db:
                existing = catalog_db[key]
                record["execution_cues"] = existing.get("execution_cues") or record["execution_cues"]
                record["motor_pattern"] = existing.get("motor_pattern") or record["motor_pattern"]
                record["secondary_muscles"] = existing.get("secondary_muscles") or record["secondary_muscles"]

            catalog_db[key] = record
            total_added += 1

            all_rows_for_supabase.append({
                "name": clean_name,
                "normalized_slug": slug,
                "muscle_group": group_name,
                "secondary_muscles": record.get("secondary_muscles", ""),
                "equipment": equipment,
                "motor_pattern": record.get("motor_pattern"),
                "execution_cues": record.get("execution_cues"),
                "media_source": "gdrive_midias",
                "media_url": record["media_url"],
                "thumbnail_url": record["thumbnail_url"],
                "metadata": {"type": "gif", "drive_file_id": file_id, "source_filename": raw_filename}
            })

    # Processa Calistenia
    calisthenics_entries = fetch_folder_entries("1v0Jr3NbtbLVlsiQ423OrmFeUj8i-nxPz")
    calisthenics_files = [e for e in calisthenics_entries if 'folder' not in e[2]]
    logger.info(f"Processando 'Calistenia': {len(calisthenics_files)} arquivos...")

    for file_id, raw_filename, mime in calisthenics_files:
        clean_name = clean_exercise_name(raw_filename)
        slug = normalize_slug(clean_name)
        key = normalize_slug(clean_name).replace("-", " ")

        record = {
            "name": clean_name,
            "slug": slug,
            "muscle_group": "Calistenia & Peso Corporal",
            "secondary_muscles": "Core, Estabilizadores",
            "equipment": "Peso Corporal",
            "motor_pattern": "Movimento Calistênico Multiarticular",
            "execution_cues": "Domínio do peso corporal com foco em controle articular e ativação do core.",
            "media_source": "gdrive_midias",
            "media_url": f"https://drive.google.com/uc?export=download&id={file_id}",
            "thumbnail_url": f"https://lh3.googleusercontent.com/d/{file_id}",
            "drive_file_id": file_id,
            "source_filename": raw_filename,
            "media_type": "gif"
        }

        if key in catalog_db:
            existing = catalog_db[key]
            record["execution_cues"] = existing.get("execution_cues") or record["execution_cues"]
            record["motor_pattern"] = existing.get("motor_pattern") or record["motor_pattern"]

        catalog_db[key] = record
        total_added += 1

        all_rows_for_supabase.append({
            "name": clean_name,
            "normalized_slug": slug,
            "muscle_group": "Calistenia & Peso Corporal",
            "secondary_muscles": record.get("secondary_muscles", ""),
            "equipment": "Peso Corporal",
            "motor_pattern": record.get("motor_pattern"),
            "execution_cues": record.get("execution_cues"),
            "media_source": "gdrive_midias",
            "media_url": record["media_url"],
            "thumbnail_url": record["thumbnail_url"],
            "metadata": {"type": "gif", "drive_file_id": file_id, "source_filename": raw_filename}
        })

    # Salva no JSON local
    with open(CATALOG_DB_PATH, "w", encoding="utf-8") as f:
        json.dump(catalog_db, f, indent=2, ensure_ascii=False)
    logger.info(f"✓ Base local atualizada com sucesso: {len(catalog_db)} exercícios cadastrados!")

    # Deduplica antes de sincronizar com o Supabase
    deduped_rows_dict = {}
    for r in all_rows_for_supabase:
        slug = r["normalized_slug"]
        if slug in deduped_rows_dict:
            # Garante slug único se houver variações do mesmo exercício
            i = 2
            while f"{slug}-{i}" in deduped_rows_dict:
                i += 1
            r["normalized_slug"] = f"{slug}-{i}"
        deduped_rows_dict[r["normalized_slug"]] = r
    
    unique_rows = list(deduped_rows_dict.values())
    logger.info(f"Sincronizando {len(unique_rows)} itens únicos com o Supabase...")
    try:
        svc = SupabaseService()
        client = await svc.get_client()
        batch_size = 50
        for i in range(0, len(unique_rows), batch_size):
            batch = unique_rows[i:i + batch_size]
            await client.table("exercise_library").upsert(batch, on_conflict="normalized_slug").execute()
            logger.info(f"   ✓ Lote {i // batch_size + 1}/{(len(unique_rows) - 1) // batch_size + 1} sincronizado.")
        logger.info("🎉 SINCRONIZAÇÃO COMPLETA COM O SUPABASE FINALIZADA!")
    except Exception as e:
        logger.error(f"Erro na sincronização com Supabase: {e}")

    logger.info("=== PROCESSO DE INGESTÃO FINALIZADO ===")


if __name__ == "__main__":
    asyncio.run(run_ingestion())
