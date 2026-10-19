"""
Script de Curadoria, Normalização Biomecânica e Sincronização do Catálogo de Exercícios (Mr. Coach).

1. Elimina todos os caracteres corrompidos (mojibake e replacement character '\ufffd').
2. Traduz todos os nomes de arquivos brutos em inglês (ex: 'barbell-curl', 'chest-press-machine', 'cable-cross-over')
   para a nomenclatura cinesiológica e biomecânica formal brasileira (Padrão CREF).
3. Corrige erros de digitação e concordância (ex: 'Crucifico' -> 'Crucifixo', 'Arnol Press Femino' -> 'Desenvolvimento Arnold com Halteres', 'bicleta' -> 'bicicleta').
4. Mapeia os 17 exercícios MP4 antigos para os GIFs de alta resolução correspondentes do acervo definitivo.
5. Salva o catálogo limpo e consistente em backend/app/data/exercise_catalog.json (UTF-8 puro).
6. Sincroniza em lote com a tabela exercise_library do Supabase.
"""

import os
import sys
import re
import json
import asyncio
import logging
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
logger = logging.getLogger("ExerciseCurator")

from app.services.supabase_service import SupabaseService

CATALOG_PATH = BACKEND_DIR / "app" / "data" / "exercise_catalog.json"


# Dicionário de tradução e normalização canônica para nomes em inglês e termos com erros comuns
CANONICAL_NAME_MAP = {
    # Peitoral
    "barbell-decline-bench-press": "Supino Declinado com Barra",
    "barbell-pullover": "Pullover com Barra",
    "bench-press-feet-up": "Supino Reto com Barra (Pés Elevados)",
    "cable-cross-over": "Crossover na Polia Média",
    "cable-fly": "Crucifixo na Polia (Fly)",
    "chest-press-machine": "Supino Reto na Máquina Articulada",
    "cross over 1": "Crossover na Polia Alta",
    "cross over 2": "Crossover na Polia Média",
    "cross over alto": "Crossover na Polia Alta",
    "cross over polia baixa": "Crossover na Polia Baixa",
    "crossover": "Crossover na Polia Tradicional",
    "crucifico com halteres": "Crucifixo Reto com Halteres",
    "crucifixo inclinado com halteres": "Crucifixo Inclinado com Halteres",
    "crucifixo inclinado no cabo 2": "Crucifixo Inclinado na Polia",
    "crucifixo maquina": "Crucifixo na Máquina (Voador / Peck Deck)",
    "crucifixo pegada pronada": "Crucifixo com Pegada Pronada",
    "crucifixo polia baixa": "Crucifixo na Polia Baixa",
    "crucifixo unilateral declinado": "Crucifixo Declinado Unilateral",
    "declinado smith": "Supino Declinado no Smith",
    "decline-cable-fly": "Crucifixo Declinado na Polia",
    "decline-push-up": "Flexão de Braço Declinada",
    "deficit-push-ups": "Flexão de Braço com Déficit",
    "dumbbell-chest-press": "Supino Reto com Halteres",
    "dumbbell-floor-press": "Supino no Solo com Halteres (Floor Press)",
    "dumbbell-one-arm-chest-press": "Supino Unilateral com Halteres",
    "dumbbell-pullover": "Pullover com Haltere",
    "flexao aberta lateral": "Flexão de Braço Aberta Lateral",
    "flexao apoio alto": "Flexão de Braço Inclinada no Banco",
    "flexao apoio alto banco": "Flexão de Braço com Mãos no Banco",
    "flexao assistida": "Flexão de Braço Assistida com Elástico",
    "flexao com apoio dos joelhos": "Flexão de Braço com Apoio dos Joelhos",
    "high-cable-fly": "Crossover na Polia Alta (High Cable Fly)",
    "inclinado no smith": "Supino Inclinado no Smith",
    "incline-barbell-bench-press": "Supino Inclinado com Barra",
    "knee-push-ups": "Flexão de Braço com Apoio de Joelhos",
    "low-cable-chest-flys": "Crossover na Polia Baixa",
    "paralelas graviton": "Mergulho nas Barras Paralelas no Graviton",
    "peck deck": "Peck Deck (Voador Peitoral)",
    "pike-push-up": "Flexão Pike (Foco Deltoide e Superior)",
    "plyometric-push-ups": "Flexão de Braço Pliométrica (com Impulso)",
    "press alto inclinado": "Supino Inclinado com Halteres (Pegada Neutra)",
    "press peitoral": "Press Peitoral com Halteres",
    "press peitoral 3": "Press Peitoral Articulado",
    "press peitoral cabo": "Press Peitoral na Polia",
    "pullover apoio dorsal": "Pullover com Apoio no Banco",
    "pullover com instabilidade": "Pullover no Fitball / Instabilidade",
    "apoio batendo palmas": "Flexão de Braço Pliométrica com Palma",

    # Costas & Trapézio
    "back-extension": "Extensão de Tronco (Banco Romano 45°)",
    "band-assisted-pull-up": "Barra Fixa Assistida com Elástico",
    "banded-wide-grip-row": "Remada Aberta com Elástico",
    "barra fixa nuca": "Barra Fixa com Puxada Atrás da Nuca",
    "barra fixa pegada aberta": "Barra Fixa com Pegada Aberta Pronada",
    "barra no graviton": "Barra Fixa Assistida no Graviton",
    "barra pegada fechada": "Barra Fixa com Pegada Fechada Neutra",
    "barra pegada supinada": "Barra Fixa com Pegada Supinada (Chin-Up)",
    "cable-face-pull": "Face Pull na Polia com Corda",
    "cable-rear-delt-fly": "Crucifixo Invertido na Polia",
    "cable-seated-row": "Remada Baixa Sentada na Polia",
    "cable-wide-grip-row": "Remada Baixa com Barra Pegada Aberta",
    "chin-ups": "Barra Fixa Supinada (Chin-Up)",
    "close-grip-lat-pulldown-standard-bar-attachment": "Puxada Alta com Pegada Fechada",
    "crcifixo inverto maquina": "Crucifixo Invertido na Máquina",
    "crucifixo invertido com halter": "Crucifixo Invertido com Halteres",
    "crucifixo invertido com halteres": "Crucifixo Invertido com Halteres",
    "crucifixo invertido elastico": "Crucifixo Invertido com Elástico",
    "crucifixo invertido polia baixa": "Crucifixo Invertido na Polia Baixa",
    "dumbbell-back-extension": "Extensão Lombar com Haltere",
    "dumbbell-face-pull": "Face Pull com Halteres",
    "dumbbell-jefferson-curl": "Jefferson Curl com Haltere",
    "eccentric-pull-up": "Barra Fixa Fase Excêntrica Lenta",
    "elevacao frontal cabo": "Elevação Frontal na Polia Baixa",
    "encolhimento 3": "Encolhimento de Trapézio com Halteres",
    "encolhimento barra": "Encolhimento de Trapézio com Barra",
    "encolhimento barra atras": "Encolhimento com Barra Atrás (Lee Haney)",
    "encolhimento com halteres": "Encolhimento de Trapézio com Halteres",
    "encolhimento maquina": "Encolhimento de Trapézio na Máquina",
    "facepull": "Face Pull na Polia Alta com Corda",
    "inverted-row": "Remada Invertida (Peso Corporal / Barra)",
    "landmine-row": "Remada Landmine (Remada Cavalinho com Barra)",
    "pull-up": "Barra Fixa Pronada (Pull-Up)",
    "pulldown com corda": "Pulldown na Polia Alta com Corda",
    "pulldown1": "Pulldown na Polia Alta Tradicional",
    "puxada alta com elastico": "Puxada Alta com Elástico",
    "puxada alta fechada": "Puxada Alta com Pegada Fechada Neutra",
    "puxada alta nuca": "Puxada Alta Atrás da Nuca",
    "puxada alta polia": "Puxada Alta na Polia (Lat Pulldown)",
    "puxada alta tradicional": "Puxada Alta Tradicional com Barra",
    "puxada alta triangulo": "Puxada Alta com Triângulo",
    "puxada cruzada": "Puxada Alta Cruzada na Polia",
    "puxada maquina": "Puxada Alta na Máquina Articulada",
    "puxada unilateral 1": "Puxada Unilateral na Polia",
    "puxada unilateral cabo": "Puxada Unilateral no Cabo",
    "remada aberta pronada": "Remada Aberta Pronada",
    "remada ajoelhado": "Remada Unilateral Ajoelhado no Cabo",
    "remada alta": "Remada Alta na Polia",
    "remada alta barra": "Remada Alta com Barra",

    # Bíceps & Antebraço
    "barbell-curl": "Rosca Direta com Barra Reta",
    "bayesian-curl": "Rosca Bayesian na Polia (Extensão de Ombro)",
    "bicep-curl-machine": "Rosca Bíceps na Máquina",
    "cable-bicep-curl": "Rosca Bíceps na Polia Baixa",
    "cable-one-arm-curl": "Rosca Bíceps Unilateral na Polia",
    "cable-preacher-curl": "Rosca Scott na Polia com Barra",
    "cross-body-hammer-curl": "Rosca Martelo Cruzada (Cross Body)",
    "dumbbell-bicep-curl": "Rosca Direta com Halteres",
    "dumbbell-hammer-curl": "Rosca Martelo com Halteres",
    "dumbbell-incline-hammer-curl": "Rosca Martelo no Banco Inclinado",
    "dumbbell-preacher-curl": "Rosca Scott com Halteres",
    "dumbbell-reverse-curl": "Rosca Inversa com Halteres",
    "dumbbell-seated-zottman-curl": "Rosca Zottman Sentada com Halteres",
    "dumbbell-wrist-curl": "Rosca de Punho com Halteres (Flexão de Punho)",
    "rosca agachado": "Rosca Concentrada com Haltere",
    "rosca alta unilateral": "Rosca Bíceps Alta Unilateral na Polia",
    "rosca inversa com halteres": "Rosca Inversa com Halteres",
    "rosca lateral polia alta": "Rosca Dupla Bíceps na Polia Alta",

    # Tríceps
    "bench-tricep-dips": "Tríceps no Banco (Mergulho)",
    "cable-tricep-kickback": "Tríceps Coice na Polia Baixa",
    "cable-tricep-overhead-extensions": "Tríceps Francês na Polia com Corda",
    "close-grip-bench-press-movement": "Supino Fechado com Barra (Foco Tríceps)",
    "dumbbell-tricep-kickback": "Tríceps Coice com Halteres",
    "extensao no elastico": "Extensão de Tríceps com Elástico",
    "extensao unilateral": "Extensão de Tríceps Unilateral",
    "extensao unilateral no cabo": "Extensão de Tríceps Unilateral na Polia",
    "ez-bar-tricep-pushdown": "Tríceps na Polia com Barra W",
    "flexao diamante": "Flexão Diamante (Foco Tríceps)",
    "mergulho banco": "Tríceps no Banco (Mergulho)",
    "overhead-cable-tricep-extension": "Tríceps Francês na Polia Alta com Corda",
    "paralelas no graviton": "Tríceps nas Barras Paralelas no Graviton",
    "sphinx-push-up": "Flexão Sphinx (Extensão de Tríceps no Solo)",
    "tricep-overhead-extensions": "Tríceps Francês Unilateral com Haltere",
    "triceps coice com halteres": "Tríceps Coice com Halteres",
    "triceps coice no cabo": "Tríceps Coice no Cabo",
    "triceps com coice com halteres 2": "Tríceps Coice com Halteres Inclinado",
    "triceps cord": "Tríceps na Polia com Corda",
    "triceps extensao unilateral": "Tríceps Extensão Unilateral",
    "triceps fechado": "Supino Fechado com Halteres",
    "triceps frances": "Tríceps Francês com Haltere",
    "triceps frances barra w": "Tríceps Francês com Barra W",
    "triceps frances com barra": "Tríceps Francês com Barra Reta",
    "triceps frances inclinado com halter": "Tríceps Francês no Banco Inclinado",
    "triceps frances no cabo com corda": "Tríceps Francês na Polia com Corda",
    "triceps frances sentado": "Tríceps Francês Sentado com Haltere",
    "triceps frances unilateral cabo": "Tríceps Francês Unilateral na Polia",
    "triceps frances unilateral sentado": "Tríceps Francês Unilateral Sentado",
    "triceps maquina 01": "Tríceps Extensão na Máquina",
    "triceps maquina 02": "Tríceps na Máquina Articulada",
    "triceps pulley": "Tríceps na Polia com Barra Reta",
    "triceps pulley pronado": "Tríceps Pulley Pronado",
    "triceps pulley supinado": "Tríceps Pulley Supinado (Inverso)",
    "triceps supinado 02": "Tríceps na Polia Pegada Supinada",
    "triceps testa 01": "Tríceps Testa com Barra W",
    "triceps testa com halteres": "Tríceps Testa com Halteres",
    "triceps testa incliando 02": "Tríceps Testa no Banco Inclinado",
    "triceps testa inclinado": "Tríceps Testa no Banco Inclinado com Halteres",
    "triceps testa no cabo": "Tríceps Testa na Polia",
    "triceps testa polia alta": "Tríceps Testa na Polia Alta com Corda",
    "triceps testa supinado": "Tríceps Testa com Pegada Supinada",
    "triceps testa unilateral": "Tríceps Testa Unilateral com Haltere",
    "triceps unilateral cabo ajoelhado": "Tríceps Francês Unilateral Ajoelhado na Polia",
    "v-bar-tricep-pushdown": "Tríceps na Polia com Barra V",

    # Deltóides / Ombros
    "arnol press femino": "Desenvolvimento Arnold com Halteres",
    "arnolda press": "Desenvolvimento Arnold com Halteres",
    "landmine press": "Desenvolvimento Landmine Unilateral",

    # Membros Inferiores & Glúteos
    "agachamento sumo com halter": "Agachamento Sumô com Halter",
    "agachamento sumo com halter 02": "Agachamento Sumô com Halter no Step",
    "agachamento sumo 01": "Agachamento Sumô Tradicional",
    "agachamento sumo barra": "Agachamento Sumô com Barra",
    "agachmento sumo": "Agachamento Sumô",
    "agachmento sumo com halter 02": "Agachamento Sumô com Halter",
    "agchamento smith": "Agachamento no Smith",
    "band-standing-hip-extension": "Extensão de Quadril em Pé com Elástico",
    "barbell-good-morning": "Bom Dia (Good Morning) com Barra",
    "barbell-hip-thrust": "Elevação Pélvica com Barra (Hip Thrust)",
    "barbell-romanian-deadlift-movement": "Levantamento Terra Romeno (RDL) com Barra",
    "benefits-of-farmers-walks": "Caminhada do Fazendeiro (Farmer's Walk)",
    "bodyweight-hip-thrust": "Elevação Pélvica com Peso Corporal",
    "bulgarian-split-spuat": "Agachamento Búlgaro com Halteres",
    "bulgaro com barra": "Agachamento Búlgaro com Barra",
    "bulgaro com halteres": "Agachamento Búlgaro com Halteres",
    "cable-kickback": "Glúteo Coice na Polia Baixa (Kickback)",
    "cable-step-up": "Subida no Step com Cabo",
    "cadeira abdutora": "Cadeira Abdutora",
    "cadeira adutora": "Cadeira Adutora",
    "cadeira extensora": "Cadeira Extensora",
    "cadeira extensora unilateral": "Cadeira Extensora Unilateral",
    "cadeira flexora": "Cadeira Flexora",
    "clean": "Power Clean (Levantamento Olímpico)",
    "dumbbell-good-morning": "Bom Dia com Haltere",
    "elevacao pelvica": "Elevação Pélvica Tradicional",

    # Abdômen & Core
    "abdominal bicleta": "Abdominal Bicicleta",
    "abdominal com rotacao de tronco": "Abdominal com Rotação de Tronco",
    "abdominal declinado": "Abdominal no Banco Declinado",
    "abdominal pegando a bola": "Abdominal Canivete com Bola Suíça",
    "abs rolinho": "Abdominal Rolinho (Ab Wheel)",
    "abdominal rolinho": "Abdominal Rolinho (Ab Wheel)",
    "abs alternado com rotacao": "Abdominal Alternado com Rotação",
    "abs alternando pernas": "Abdominal com Elevação Alternada de Pernas",
    "crunch": "Abdominal Crunch Tradicional",
    "crunch 3": "Abdominal Crunch com Braços Estendidos",
    "crunch 4": "Abdominal Crunch no Banco Declinado",
    "crunch com carga": "Abdominal Crunch com Carga",
    "crunch pernas elevadas": "Abdominal Crunch com Pernas Elevadas a 90°",
    "crunch reverso": "Abdominal Crunch Reverso",
    "crunch-floor": "Abdominal Crunch no Solo",
    "crunch-with-leg-raise": "Abdominal Crunch com Elevação de Pernas",
}

# Normalização de Grupo Muscular Canônico
MUSCLE_GROUP_CLEAN = {
    "Abdômen & Core": "Abdômen & Core",
    "Abdmen & Core": "Abdômen & Core",
    "Reto do Abdome": "Abdômen & Core",
    "Bíceps & Antebraço": "Bíceps & Antebraço",
    "Bceps & Antebrao": "Bíceps & Antebraço",
    "Bceps Braquial": "Bíceps & Antebraço",
    "Antebrao": "Bíceps & Antebraço",
    "Costas & Trapézio": "Costas & Trapézio",
    "Latssimo do Dorso": "Costas & Trapézio",
    "Eretores da Espinha": "Costas & Trapézio",
    "Deltóides": "Deltoides",
    "Deltoide Lateral": "Deltoides",
    "Deltoides": "Deltoides",
    "Membros Inferiores & Glúteos": "Membros Inferiores & Glúteos",
    "Glteos e Adutores": "Membros Inferiores & Glúteos",
    "Glteo Mximo": "Membros Inferiores & Glúteos",
    "Quadrceps": "Membros Inferiores & Glúteos",
    "Panturrilhas": "Panturrilhas",
    "Trceps Sural (Gastronmio e Sleo)": "Panturrilhas",
    "Peitoral": "Peitoral",
    "Peitoral Maior": "Peitoral",
    "Tríceps": "Tríceps",
    "Trceps Braquial": "Tríceps",
}


MP4_CANONICAL_NAMES = {
    "17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa": {
        "name": "Agachamento Sumô no Step com Haltere",
        "muscle_group": "Membros Inferiores & Glúteos",
        "equipment": "Haltere e Steps",
    },
    "1TxSpy72LIriyv-uKTwutAb180t5kRZuh": {
        "name": "Extensão de Tríceps na Polia Alta",
        "muscle_group": "Tríceps",
        "equipment": "Polia Alta com Barra Reta",
    },
    "1T7FiAAqkknQcbFVof8ZVAxJJPaSqSmZc": {
        "name": "Remada Baixa Sentada com Triângulo",
        "muscle_group": "Costas & Trapézio",
        "equipment": "Polia Baixa com Puxador Triângulo",
    },
    "1vxEkKH1rOQ-hox6E4zRZAvtQqzT7D4VQ": {
        "name": "Extensão de Tronco no Banco 45°",
        "muscle_group": "Costas & Trapézio",
        "equipment": "Banco de Hiperextensão 45°",
    },
    "15tu4--Y8TWabaPPwIKuxNLkU4CjK6wcM": {
        "name": "Remada Baixa na Polia com Triângulo",
        "muscle_group": "Costas & Trapézio",
        "equipment": "Polia Baixa com Puxador Triângulo",
    },
    "1AOfqPbhRoQqqhAeCeZW0fYiRMd_fhtW8": {
        "name": "Leg Press 45°",
        "muscle_group": "Membros Inferiores & Glúteos",
        "equipment": "Máquina de Leg Press 45°",
    },
    "1mpb80woL3Tr7WQ2sgW9XHkwN3cr05A8U": {
        "name": "Supino Reto com Barra",
        "muscle_group": "Peitoral",
        "equipment": "Banco Reto e Barra Olímpica",
    },
    "1f-8iD1kyFFU1-kFq8XyppfUz73uyxwtV": {
        "name": "Rosca de Punho com Barra",
        "muscle_group": "Bíceps & Antebraço",
        "equipment": "Barra com Anilhas",
    },
    "1uraJ2DpW1hkXGYrFpSD_sfkhMmeQsBME": {
        "name": "Rosca Bíceps na Polia Baixa",
        "muscle_group": "Bíceps & Antebraço",
        "equipment": "Polia Baixa com Barra Reta",
    },
    "1LZSnbeHLzxuCp60viKD5qWM6hT7gMDqd": {
        "name": "Puxada Alta na Polia (Lat Pulldown)",
        "muscle_group": "Costas & Trapézio",
        "equipment": "Máquina de Puxada Alta (Lat Pulldown)",
    },
    "1CuE_Xbgjh8kQNdO8Of5eHi_AvzUg1g8F": {
        "name": "Elevação Pélvica no Smith",
        "muscle_group": "Membros Inferiores & Glúteos",
        "equipment": "Máquina Smith e Banco",
    },
    "13611i4gmfgOKwL9Etp9umvKzAG8wR5q8": {
        "name": "Elevação Lateral com Halteres",
        "muscle_group": "Deltoides",
        "equipment": "Halteres",
    },
    "1-vyxdrKf1wN9Qf6AbzYRsxySnyty75dl": {
        "name": "Elevação de Panturrilha em Pé no Step",
        "muscle_group": "Panturrilhas",
        "equipment": "Step e Halteres",
    },
    "1LXrZ8VG0Ms6Fyu3anMU7ANY72GJ_GPaW": {
        "name": "Glúteo Coice na Polia Baixa",
        "muscle_group": "Membros Inferiores & Glúteos",
        "equipment": "Polia Baixa e Tornozeleira",
    },
    "1Twx8oILp54O4HZJ5NBhJ7qWcN3E3szp5": {
        "name": "Abdominal Borboleta com Pernas Elevadas",
        "muscle_group": "Abdômen & Core",
        "equipment": "Colchonete / Solo",
    },
    "1I4Wdw8N2LVllRUwtfRYvgQgsakYNGD8a": {
        "name": "Tríceps no Banco (Mergulho)",
        "muscle_group": "Tríceps",
        "equipment": "Banco Reto",
    },
    "1Hl4FgY3GGHEKw5fz9_dpEl9X5dVOOqko": {
        "name": "Crucifixo Reto com Halteres",
        "muscle_group": "Peitoral",
        "equipment": "Banco Reto e Halteres",
    },
}

MP4_TO_GIF_REPLACEMENTS = {
    "17-TsJ2vQ7ivXQCShCynFAr0QODTtgtpa": ("1GbTTXncARd5Bz8dSy35RpLjuxaHE4EOK", "agachamento sumo 01 (1).gif"),
    "1TxSpy72LIriyv-uKTwutAb180t5kRZuh": ("1s66vXg4CMlIcZ97KXbjgmdhE0TJPrFwG", "triceps pulley (1).gif"),
    "1T7FiAAqkknQcbFVof8ZVAxJJPaSqSmZc": ("18gsfPl2ybr7XGngpUEHgMYAsDwzxwLkw", "cable-seated-row (1).gif"),
    "1vxEkKH1rOQ-hox6E4zRZAvtQqzT7D4VQ": ("1PzcETvH6m6GKtouDyRIReiCeAyvj6peR", "back-extension (1).gif"),
    "15tu4--Y8TWabaPPwIKuxNLkU4CjK6wcM": ("18gsfPl2ybr7XGngpUEHgMYAsDwzxwLkw", "cable-seated-row (1).gif"),
    "1AOfqPbhRoQqqhAeCeZW0fYiRMd_fhtW8": ("1mTRWKE_n0WdQl5xjCHbRvPXjzJwjIIxz", "leg-press-calf-raise (1).gif"),
    "1mpb80woL3Tr7WQ2sgW9XHkwN3cr05A8U": ("1UwWzixRB09eM-VF8FTBUsTTiGSF-9Yop", "bench-press-feet-up (1).gif"),
    "1f-8iD1kyFFU1-kFq8XyppfUz73uyxwtV": ("1SsQ-rFyUG8fuW5wPkdgpPZxp5Qc6oWqT", "dumbbell-wrist-curl (1).gif"),
    "1uraJ2DpW1hkXGYrFpSD_sfkhMmeQsBME": ("1QBEOg7UNmeqwSqWbPwmSkbzPVJh0Zj8-", "cable-bicep-curl (1).gif"),
    "1LZSnbeHLzxuCp60viKD5qWM6hT7gMDqd": ("1HVpG7tRZDyuLQ9ck9H8jXIbupRIg5hnw", "puxada alta polia (1).gif"),
    "1CuE_Xbgjh8kQNdO8Of5eHi_AvzUg1g8F": ("15V-daBh8wRpB1ZnG7Qdmk60ETzZMYkhK", "barbell-hip-thrust (1).gif"),
    "13611i4gmfgOKwL9Etp9umvKzAG8wR5q8": ("1n89n1Nct2zbtER6zmO9CmV4YNDPWJpdT", "Elevação lateral 01 (1).gif"),
    "1-vyxdrKf1wN9Qf6AbzYRsxySnyty75dl": ("1hQ14agK4hL8bYblJWUrC-CNBn2h0YMaN", "standing-calf-raise (3).gif"),
    "1LXrZ8VG0Ms6Fyu3anMU7ANY72GJ_GPaW": ("19AohH2sHB9V6ywwqAswhTvvaY-n20QHr", "cable-kickback (1).gif"),
    "1Twx8oILp54O4HZJ5NBhJ7qWcN3E3szp5": ("163PrWJKA0YMcOcPVI0cIwM1RFChoQhli", "crunch 3 (1).gif"),
    "1I4Wdw8N2LVllRUwtfRYvgQgsakYNGD8a": ("1k09WhgxV-UK0yOdTNEBc-svfw_Oq6KsU", "mergulho banco (1).gif"),
    "1Hl4FgY3GGHEKw5fz9_dpEl9X5dVOOqko": ("10juxAPalludUX2OZb2lmoknFQ5CrO6P2", "crucifico com halteres (1).gif"),
}


def sanitize_text(text: str) -> str:
    """Substitui caracteres quebrados por acentos ortográficos corretos."""
    if not text:
        return ""
    t = text
    # Dicionário de correções sem afetar letras isoladas
    fixes = [
        (r'Tr[íi\ufffd]?ceps', 'Tríceps'),
        (r'B[íi\ufffd]?ceps', 'Bíceps'),
        (r'Extens[ãa\ufffd]?o', 'Extensão'),
        (r'Eleva[çc\ufffd]?[ãa\ufffd]?o', 'Elevação'),
        (r'Flex[ãa\ufffd]?o', 'Flexão'),
        (r'Rota[çc\ufffd]?[ãa\ufffd]?o', 'Rotação'),
        (r'Plvica', 'Pélvica'),
        (r'P[ée\ufffd]lvica', 'Pélvica'),
        (r'P[ée\ufffd]lvico', 'Pélvico'),
        (r'Tri[ãa\ufffd]?ngulo', 'Triângulo'),
        (r'Tringulo', 'Triângulo'),
        (r'Gl[úu\ufffd]?teo', 'Glúteo'),
        (r'Gl[úu\ufffd]?teos', 'Glúteos'),
        (r'Glteo', 'Glúteo'),
        (r'Glteos', 'Glúteos'),
        (r'Quadr[íi\ufffd]?ceps', 'Quadríceps'),
        (r'Quadrceps', 'Quadríceps'),
        (r'Antebra[çc\ufffd]?o', 'Antebraço'),
        (r'Antebrao', 'Antebraço'),
        (r'Lat[íi\ufffd]?ssimo', 'Latíssimo'),
        (r'Latssimo', 'Latíssimo'),
        (r'M[áa\ufffd]?quina', 'Máquina'),
        (r'Mquina', 'Máquina'),
        (r'\bsum[ôo\ufffd]?\b', 'sumô'),
        (r'\bSum[ôo\ufffd]?\b', 'Sumô'),
        (r'45°?', '45°'),
        (r'\bem p[ée\ufffd]?\b', 'em pé'),
        (r'\bem P[ée\ufffd]?\b', 'em Pé'),
        (r'Abd[ôo\ufffd]?men', 'Abdômen'),
        (r'Abdmen', 'Abdômen'),
        (r'Gastrocn[êe\ufffd]?mio', 'Gastrocnêmio'),
        (r'Gastronmio', 'Gastrocnêmio'),
        (r'S[óo\ufffd]?leo', 'Sóleo'),
        (r'Sleo', 'Sóleo'),
        (r'M[áa\ufffd]?ximo', 'Máximo'),
        (r'Mximo', 'Máximo'),
        (r'Ol[íi\ufffd]?mpico', 'Olímpico'),
        (r'Ol[íi\ufffd]?mpica', 'Olímpica'),
        (r'Exerc[íi\ufffd]?cio', 'Exercício'),
    ]
    for pattern, replacement in fixes:
        t = re.sub(pattern, replacement, t)

    t = t.replace('\ufffd', '')
    t = re.sub(r'\s+', ' ', t)
    return t.strip()


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


async def curate_catalog():
    logger.info("=== INICIANDO CURADORIA BIOMECÂNICA DO CATÁLOGO DE EXERCÍCIOS ===")

    with open(CATALOG_PATH, "r", encoding="utf-8", errors="replace") as f:
        catalog = json.load(f)

    logger.info(f"Total de registros lidos: {len(catalog)}")

    curated_catalog = {}
    supabase_rows = []

    # Mapa de chave simplificada para achar GIFs de alta qualidade
    gif_by_slug = {}
    for k, v in catalog.items():
        src = str(v.get("source_filename", "")).lower()
        if src.endswith(".gif"):
            slug = normalize_slug(v.get("name", k))
            gif_by_slug[slug] = v

    for key, item in catalog.items():
        raw_name = item.get("name", key)
        src = str(item.get("source_filename", ""))
        src_clean = re.sub(r'\.(gif|mp4|png|jpg|jpeg|webp)$', '', src, flags=re.IGNORECASE)
        src_clean = re.sub(r'\s*\(\d+\)$', '', src_clean)
        src_clean = re.sub(r'[\-_]0\d+$', '', src_clean)
        src_clean = re.sub(r'[\-_]\d+$', '', src_clean)
        src_key = normalize_slug(src_clean).replace("-", " ")

        # Extrai ID do arquivo e URL da mídia
        media_url = item.get("media_url", "")
        file_id = item.get("drive_file_id", "")
        if not file_id and media_url:
            m = re.search(r'(?:id=|\/d\/|file\/d\/)([a-zA-Z0-9_\-]+)', media_url)
            if m:
                file_id = m.group(1)

        # 1. Identifica o Nome Canônico
        canonical_name = None
        if file_id in MP4_CANONICAL_NAMES:
            canonical_name = MP4_CANONICAL_NAMES[file_id]["name"]
            muscle_group = MP4_CANONICAL_NAMES[file_id]["muscle_group"]
            equipment = MP4_CANONICAL_NAMES[file_id]["equipment"]
        elif src_key in CANONICAL_NAME_MAP:
            canonical_name = CANONICAL_NAME_MAP[src_key]
        elif normalize_slug(raw_name).replace("-", " ") in CANONICAL_NAME_MAP:
            canonical_name = CANONICAL_NAME_MAP[normalize_slug(raw_name).replace("-", " ")]
        else:
            canonical_name = sanitize_text(raw_name)

        # 2. Higieniza Grupo Muscular e Equipamento se não for do MP4
        if file_id not in MP4_CANONICAL_NAMES:
            raw_group = item.get("muscle_group", "Geral")
            muscle_group = MUSCLE_GROUP_CLEAN.get(raw_group, sanitize_text(raw_group))
            if not muscle_group or muscle_group == "Geral":
                muscle_group = "Musculação Geral"
            equipment = sanitize_text(item.get("equipment", "Equipamento de Academia"))

        motor_pattern = sanitize_text(item.get("motor_pattern", "Biomecânica e Cinesiologia Guiada"))
        cues = sanitize_text(item.get("execution_cues", ""))
        if not cues:
            cues = f"Execução com foco primário em {muscle_group}. Mantenha cadência controlada, estabilização escapular e amplitude articular segura."

        # 4. Mídia (GIF / MP4 / Thumbnail)
        media_type = item.get("media_type", "gif")
        if file_id in MP4_TO_GIF_REPLACEMENTS:
            gif_id, gif_src = MP4_TO_GIF_REPLACEMENTS[file_id]
            file_id = gif_id
            src = gif_src
            media_type = "gif"
            media_url = f"https://drive.google.com/uc?export=download&id={file_id}"
            thumbnail_url = f"https://lh3.googleusercontent.com/d/{file_id}"
        elif src.lower().endswith(".mp4"):
            media_type = "mp4"
            thumbnail_url = f"https://lh3.googleusercontent.com/d/{file_id}" if file_id else item.get("thumbnail_url", "")
        else:
            thumbnail_url = f"https://lh3.googleusercontent.com/d/{file_id}" if file_id else item.get("thumbnail_url", "")

        new_slug = normalize_slug(canonical_name)
        new_key = new_slug.replace("-", " ")

        record = {
            "name": canonical_name,
            "slug": new_slug,
            "muscle_group": muscle_group,
            "secondary_muscles": sanitize_text(item.get("secondary_muscles", "")),
            "equipment": equipment,
            "motor_pattern": motor_pattern,
            "execution_cues": cues,
            "media_source": "gdrive_midias",
            "media_url": media_url,
            "thumbnail_url": thumbnail_url,
            "drive_file_id": file_id,
            "source_filename": src,
            "media_type": media_type,
        }

        curated_catalog[new_key] = record
        supabase_rows.append(record)

    logger.info(f"Curadoria concluída: {len(curated_catalog)} exercícios refinados!")

    # 5. Salva catálogo em formato UTF-8 puro
    with open(CATALOG_PATH, "w", encoding="utf-8") as f:
        json.dump(curated_catalog, f, indent=2, ensure_ascii=False)
    logger.info(f"Arquivo salvo com sucesso em: {CATALOG_PATH}")

    # 6. Sincroniza com o Supabase
    try:
        svc = SupabaseService()
        client = await svc.get_client()
        logger.info(f"Sincronizando {len(supabase_rows)} exercícios com a tabela 'exercise_library' no Supabase...")

        # Deduplica por normalized_slug
        deduped = {}
        for r in supabase_rows:
            slug = r["slug"]
            if slug in deduped:
                idx = 2
                while f"{slug}-{idx}" in deduped:
                    idx += 1
                slug = f"{slug}-{idx}"
            deduped[slug] = {
                "name": r["name"],
                "normalized_slug": slug,
                "muscle_group": r["muscle_group"],
                "secondary_muscles": r["secondary_muscles"],
                "equipment": r["equipment"],
                "motor_pattern": r["motor_pattern"],
                "execution_cues": r["execution_cues"],
                "media_source": r["media_source"],
                "media_url": r["media_url"],
                "thumbnail_url": r["thumbnail_url"],
                "metadata": {
                    "type": r["media_type"],
                    "drive_file_id": r["drive_file_id"],
                    "source_filename": r["source_filename"]
                }
            }

        unique_rows = list(deduped.values())
        batch_size = 50
        for i in range(0, len(unique_rows), batch_size):
            batch = unique_rows[i:i + batch_size]
            await client.table("exercise_library").upsert(batch, on_conflict="normalized_slug").execute()
            logger.info(f"Lote {i // batch_size + 1}/{(len(unique_rows) + batch_size - 1) // batch_size} sincronizado.")

        logger.info("✅ Todos os exercícios foram atualizados e sincronizados com sucesso no Supabase!")
    except Exception as e:
        logger.error(f"Erro ao sincronizar com Supabase: {e}")


if __name__ == "__main__":
    asyncio.run(curate_catalog())
