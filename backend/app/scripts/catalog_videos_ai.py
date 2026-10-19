"""
Catalogador Inteligente de Exercícios & Vídeos via Gemini Multimodal.

Analisa vídeos de treinos armazenados no Google Drive, extrai o nome canônico do exercício,
músculos primários e secundários, equipamento, padrão motor e dicas de execução biomecânica,
salvando tudo de forma persistente em backend/app/data/exercise_catalog.json.
"""

import os
import sys
import time
import json
import logging
import argparse
import urllib.request
import re
from pathlib import Path
from dotenv import load_dotenv

# Carrega variáveis de ambiente do backend (.env)
BACKEND_DIR = Path(__file__).resolve().parent.parent.parent
load_dotenv(BACKEND_DIR / ".env")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("VideoCataloger")

API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    logger.error("ERRO: GEMINI_API_KEY não encontrada no arquivo .env!")
    sys.exit(1)

from google import genai
from google.genai import types

client = genai.Client(api_key=API_KEY)

CATALOG_DB_PATH = BACKEND_DIR / "app" / "data" / "exercise_catalog.json"
DRIVE_CATALOG_PATH = BACKEND_DIR / "app" / "data" / "drive_catalog.json"
TEMP_VIDEO_DIR = BACKEND_DIR / "app" / "data" / ".tmp_videos"
TEMP_VIDEO_DIR.mkdir(parents=True, exist_ok=True)


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


def load_catalog_db() -> dict:
    if CATALOG_DB_PATH.exists():
        try:
            with open(CATALOG_DB_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Erro ao carregar catálogo existente: {e}")
    return {}


def save_catalog_db(db: dict):
    CATALOG_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CATALOG_DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)


def download_drive_video(file_id: str, dest_path: Path) -> bool:
    """Baixa o vídeo público do Google Drive para arquivo local."""
    url = f"https://drive.google.com/uc?export=download&id={file_id}"
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp, open(dest_path, "wb") as out:
            data = resp.read()
            if len(data) < 1000:
                logger.warning(f"Download do arquivo {file_id} retornou apenas {len(data)} bytes (possível tela de confirmação).")
                return False
            out.write(data)
        return True
    except Exception as e:
        logger.error(f"Falha ao baixar vídeo {file_id}: {e}")
        return False


def analyze_video_with_gemini(video_path: Path) -> dict:
    """Envia o vídeo para o Gemini File API e extrai classificação técnica completa."""
    uploaded_file = client.files.upload(file=str(video_path))
    
    # Aguarda processamento do vídeo
    max_wait = 30
    waited = 0
    while uploaded_file.state == "PROCESSING" and waited < max_wait:
        time.sleep(1)
        waited += 1
        uploaded_file = client.files.get(name=uploaded_file.name)

    if uploaded_file.state != "ACTIVE":
        raise RuntimeError(f"O arquivo de vídeo ficou no estado {uploaded_file.state} no Gemini.")

    prompt = """
Você é um especialista internacional em Cinesiologia, Biomecânica da Musculação e Educação Física.
Analise com extrema precisão o vídeo deste exercício de musculação e retorne OBRIGATORIAMENTE um JSON estrito no seguinte formato:

{
  "nome_exercicio": "Nome oficial e canônico em português (ex: Agachamento Búlgaro com Halteres, Cadeira Extensora, Supino Reto com Barra, Puxada Alta Pronada)",
  "grupo_muscular": "Músculo primário agonista (ex: Quadríceps, Peitoral Maior, Latíssimo do Dorso, Glúteo Máximo, Deltoide Lateral, etc.)",
  "musculos_secundarios": "Músculos sinergistas e estabilizadores separados por vírgula (ex: Isquiotibiais, Glúteos, Core)",
  "equipamento": "Equipamento utilizado (ex: Halteres e Banco, Barra Olímpica, Máquina Específica, Polia com Barra Reta, Peso Corporal)",
  "padrao_motor": "Padrão de movimento biomecânico (ex: Dominante de Joelho Unilateral, Empurrar Horizontal, Puxar Vertical, Isolado Monoarticular)",
  "instrucoes": "Instruções claras de execução, postura das escápulas/lombar, trajetória correta e amplitude segura para evitar lesões."
}
"""

    models = ["gemini-3.8-flash", "gemini-3.5-flash-lite"]
    last_error = None
    response_text = None

    for m in models:
        try:
            response = client.models.generate_content(
                model=m,
                contents=[uploaded_file, prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.2
                )
            )
            response_text = response.text
            break
        except Exception as e:
            last_error = e
            logger.warning(f"Falha ao gerar com modelo {m}: {e}")

    # Limpeza do arquivo no Gemini File API
    try:
        client.files.delete(name=uploaded_file.name)
    except Exception:
        pass

    if not response_text:
        raise RuntimeError(f"Nenhum modelo respondeu. Último erro: {last_error}")

    data = json.loads(response_text)
    return data


def run_cataloger(limit: int = 5, start_index: int = 1, delay: float = 2.0):
    if not DRIVE_CATALOG_PATH.exists():
        logger.error(f"Arquivo de catálogo {DRIVE_CATALOG_PATH} não encontrado!")
        return

    with open(DRIVE_CATALOG_PATH, "r", encoding="utf-8") as f:
        drive_files = json.load(f)

    # Ordena por índice de vídeo
    drive_files.sort(key=lambda x: x.get("video_index", 9999))

    # Filtra a partir do start_index
    drive_files = [f for f in drive_files if f.get("video_index", 0) >= start_index]

    catalog_db = load_catalog_db()
    cataloged_file_ids = {item.get("drive_file_id") for item in catalog_db.values()}

    logger.info(f"=== INICIANDO CATALOGADOR DE VÍDEOS VIA IA ===")
    logger.info(f"Total de vídeos mapeados: {len(drive_files)}")
    logger.info(f"Já catalogados no banco: {len(catalog_db)}")
    logger.info(f"Meta desta rodada: processar até {limit} novos vídeos (a partir do vídeo #{start_index})\n")

    processed = 0
    success = 0

    for item in drive_files:
        if processed >= limit:
            break

        file_id = item["file_id"]
        filename = item["filename"]
        idx = item.get("video_index", "?")

        if file_id in cataloged_file_ids:
            logger.info(f"⏭️  Vídeo #{idx} ({filename}) já catalogado anteriormente. Pulando...")
            continue

        processed += 1
        logger.info(f"▶️  [{processed}/{limit}] Processando Vídeo #{idx}: {filename} (ID: {file_id})...")

        temp_path = TEMP_VIDEO_DIR / f"temp_{file_id}.mp4"

        try:
            # 1. Download
            logger.info("   📥 Baixando vídeo...")
            ok = download_drive_video(file_id, temp_path)
            if not ok:
                logger.error(f"   ❌ Falha no download do vídeo #{idx}. Pulando.")
                continue

            file_size_kb = temp_path.stat().st_size / 1024
            logger.info(f"   ✓ Baixado com sucesso ({file_size_kb:.1f} KB).")

            # 2. IA Multimodal
            logger.info("   🧠 Analisando biomecânica via Gemini...")
            start_t = time.time()
            analysis = analyze_video_with_gemini(temp_path)
            elapsed = time.time() - start_t
            logger.info(f"   ✓ Análise concluída em {elapsed:.1f}s!")

            # 3. Consolidação no Catálogo
            nome = analysis.get("nome_exercicio", f"Exercício #{idx}")
            slug = analysis.get("slug") or normalize_slug(nome)
            key_name = normalize_slug(nome).replace("-", " ")

            record = {
                "name": nome,
                "slug": slug,
                "muscle_group": analysis.get("grupo_muscular", "Geral"),
                "secondary_muscles": analysis.get("musculos_secundarios", ""),
                "equipment": analysis.get("equipamento", "Livre / Máquina"),
                "motor_pattern": analysis.get("padrao_motor", "Composto"),
                "execution_cues": analysis.get("instrucoes", ""),
                "media_source": "gdrive_initial",
                "media_url": f"https://drive.google.com/uc?export=download&id={file_id}",
                "thumbnail_url": "",
                "drive_file_id": file_id,
                "source_filename": filename,
                "video_index": idx
            }

            catalog_db[key_name] = record
            save_catalog_db(catalog_db)
            cataloged_file_ids.add(file_id)

            success += 1
            logger.info(f"   ✅ SALVO: '{nome}' | Foco: {record['muscle_group']} | Equip: {record['equipment']}")

        except Exception as e:
            logger.error(f"   ❌ Erro ao processar #{idx} ({filename}): {e}")

        finally:
            # Remove arquivo temporário local
            if temp_path.exists():
                try:
                    temp_path.unlink()
                except Exception:
                    pass

        # Intervalo anti-rate-limit
        if delay > 0 and processed < limit:
            time.sleep(delay)

    logger.info(f"\n=== SESSÃO DE CATALOGAÇÃO FINALIZADA ===")
    logger.info(f"Processados nesta rodada: {processed}")
    logger.info(f"Sucessos adicionados: {success}")
    logger.info(f"Total agora no catálogo oficial: {len(catalog_db)} exercícios cadastrados.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Catalogador de Vídeos de Treino via Gemini")
    parser.add_argument("--limit", type=int, default=5, help="Quantidade de vídeos a processar nesta rodada")
    parser.add_argument("--start", type=int, default=1, help="Número do vídeo para iniciar")
    parser.add_argument("--delay", type=float, default=2.0, help="Segundos de espera entre análises")
    args = parser.parse_args()

    run_cataloger(limit=args.limit, start_index=args.start, delay=args.delay)
