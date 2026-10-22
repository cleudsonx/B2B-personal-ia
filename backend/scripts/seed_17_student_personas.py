# backend/scripts/seed_17_student_personas.py
# FASE 6 EXPANDIDA: Injeção de 52 Personas de Alunos Clínicos Reais no Mr. Coach
# - 17 personas originais + 35 novas personas (total 52)
# - Idades variadas de 16 a 78 anos
# - Mesociclos variados (Adaptação, Hipertrofia Miofibrilar, Choque/Sobrecarga, Deload, Pico de Força)
# - Inadimplentes (bloqueados e past_due) e Adimplentes
# - Alunos com mais de 5 a 14 dias sem treinar (Alerta de Churn no Radar de Retenção)
# - Perfis clínicos: Diástase pós-parto, Hérnia L5-S1, Condromalácia, Cardiopatas, Idosos frágeis, Atletas, Ectomorfos, etc.
# - Role 'client' e roles = ['client'] garantidos no Supabase

import asyncio
import uuid
import random
import unicodedata
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass
from datetime import datetime, date, timedelta, timezone
from app.services.supabase_service import supabase_service

TRAINER_ID = "6f645308-f1b2-4d73-ac45-9890c27e20d4"  # Cleudson Cavalcante (mrcoach)

def slugify(text: str) -> str:
    nfkd = unicodedata.normalize('NFKD', text)
    clean = "".join([c for c in nfkd if not unicodedata.combining(c)])
    return "".join(c.lower() if c.isalnum() else "." for c in clean).strip(".")

PERSONAS = [
    # =========================================================================
    # GRUPO 1: 5 Alunos Adultos Acima do Peso (Emagrecimento / Reeducação)
    # =========================================================================
    {
        "full_name": "Bruno Silveira",
        "gender": "male",
        "age": 38,
        "weight_kg": 108.5,
        "height_cm": 178,
        "group": "adult_overweight",
        "modality": "Funcional & Cardio Metabólico",
        "objective": "Emagrecimento Acelerado & Redução de Gordura Visceral",
        "experience": "Iniciante",
        "restrictions": "Hipertensão arterial estágio 1 controlada. Evitar manobra de Valsalva e isometria prolongada.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 1,
        "mesocycle_name": "Adaptação Metabólica",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
        "amount_cents": 16000,
    },
    {
        "full_name": "Juliana Alencar",
        "gender": "female",
        "age": 42,
        "weight_kg": 94.0,
        "height_cm": 165,
        "group": "adult_overweight",
        "modality": "Hipertrofia & Recomposição Corporal",
        "objective": "Redução de Gordura & Fortalecimento de Membros Inferiores",
        "experience": "Intermediário",
        "restrictions": "Condromalácia patelar bilateral grau 2. Evitar agachamento profundo (>90°) e cadeira extensora pesada.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Miofibrilar",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,  # Vence hoje -> AVISO
        "amount_cents": 18000,
    },
    {
        "full_name": "Rodrigo Maciel",
        "gender": "male",
        "age": 45,
        "weight_kg": 115.0,
        "height_cm": 182,
        "group": "adult_overweight",
        "modality": "Musculação com Máquinas Guiadas",
        "objective": "Emagrecimento & Reabilitação Lombar",
        "experience": "Iniciante",
        "restrictions": "Hérnia de disco protusa em L4-L5. Proibido carga axial na coluna (sem agachamento livre ou terra).",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 2,
        "mesocycle_name": "Estabilização Lombar",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 2,  # Vencida há 2 dias -> BLOQUEADO
        "amount_cents": 20000,
    },
    {
        "full_name": "Fabiana Guimarães",
        "gender": "female",
        "age": 35,
        "weight_kg": 88.5,
        "height_cm": 162,
        "group": "adult_overweight",
        "modality": "Calistenia Leve & Treino Metabólico",
        "objective": "Condicionamento Físico & Perda de Peso",
        "experience": "Iniciante (Sedentária recente)",
        "restrictions": "Sensibilidade patelar em saltos de alto impacto. Preferir exercícios de cadeia cinética fechada sem impacto.",
        "avatar": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 1,
        "mesocycle_name": "Condicionamento Geral",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 0,  # Vence hoje
        "amount_cents": 15000,
    },
    {
        "full_name": "André Vasconcelos",
        "gender": "male",
        "age": 41,
        "weight_kg": 102.0,
        "height_cm": 175,
        "group": "adult_overweight",
        "modality": "Força & Hipertrofia",
        "objective": "Ganho de Massa Magra e Redução da Circunferência Abdominal",
        "experience": "Intermediário",
        "restrictions": "Nenhuma restrição articular ou metabólica relatada. Atestado cardiológico 100% liberado.",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 0,
        "mesocycle_name": "Sobrecarga Progressiva",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
        "amount_cents": 17000,
    },

    # =========================================================================
    # GRUPO 2: 4 Alunos Jovens entre 16 e 30 anos
    # =========================================================================
    {
        "full_name": "Lucas Pinheiro",
        "gender": "male",
        "age": 21,
        "weight_kg": 76.0,
        "height_cm": 180,
        "group": "young",
        "modality": "Calistenia Avançada & Street Workout",
        "objective": "Controle Corporal, Muscle-Up & Hipertrofia Funcional",
        "experience": "Avançado",
        "restrictions": "Nenhuma restrição. Excelente mobilidade de ombros e punhos.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 0,
        "mesocycle_name": "Potência & Calistenia",
        "mesocycle_week": "Semana 4 de 4",
        "days_overdue": 0,
        "amount_cents": 14000,
    },
    {
        "full_name": "Beatriz Fagundes",
        "gender": "female",
        "age": 24,
        "weight_kg": 58.5,
        "height_cm": 168,
        "group": "young",
        "modality": "Hipertrofia & Glúteos de Elite",
        "objective": "Hipertrofia de Quadríceps e Glúteos (Ênfase Inferior)",
        "experience": "Avançada",
        "restrictions": "Nenhuma restrição. Foco em sobrecarga progressiva pesada.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 1,
        "mesocycle_name": "Hipertrofia Glúteos & Pernas",
        "mesocycle_week": "Semana 5 de 8",
        "days_overdue": 2,
        "amount_cents": 19000,
    },
    {
        "full_name": "Gabriel Zanin",
        "gender": "male",
        "age": 19,
        "weight_kg": 72.0,
        "height_cm": 176,
        "group": "young",
        "modality": "Periodização de Força Linear",
        "objective": "Construção de Base Muscular & Postura",
        "experience": "Iniciante",
        "restrictions": "Escoliose torácica postural leve. Monitorar simetria em exercícios unilaterais.",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 0,
        "mesocycle_name": "Base Postural & Força",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 1,
        "amount_cents": 15000,
    },
    {
        "full_name": "Larissa Rocha",
        "gender": "female",
        "age": 27,
        "weight_kg": 61.0,
        "height_cm": 164,
        "group": "young",
        "modality": "Powerlifting & Força Máxima",
        "objective": "Aumento de Cargas em Supino, Agachamento e Terra",
        "experience": "Intermediária",
        "restrictions": "Tendinite esporádica no punho direito. Usar munhequeiras e pegada neutra em empurrar.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 1,
        "mesocycle_name": "Força Máxima 5x5",
        "mesocycle_week": "Semana 6 de 8",
        "days_overdue": 0,
        "amount_cents": 17500,
    },

    # =========================================================================
    # GRUPO 3: 5 Alunos Abaixo do Peso Ideal (Ectomorfos / Bulking / Sarcopenia)
    # =========================================================================
    {
        "full_name": "Matheus Cordeiro",
        "gender": "male",
        "age": 20,
        "weight_kg": 54.0,
        "height_cm": 179,
        "group": "underweight",
        "modality": "Hipertrofia Bulking Limpo",
        "objective": "Ganho Rápido de Massa Muscular e Peso Corporal",
        "experience": "Iniciante",
        "restrictions": "Ectomorfo puro com metabolismo ultra acelerado. Séries curtas e intensas, sem excesso de cardio.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 0,
        "mesocycle_name": "Bulking Hipertrófico",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 1,
        "amount_cents": 16000,
    },
    {
        "full_name": "Camila Prado",
        "gender": "female",
        "age": 29,
        "weight_kg": 44.5,
        "height_cm": 166,
        "group": "underweight",
        "modality": "Hipertrofia & Densidade Óssea",
        "objective": "Ganho de Peso e Curvas Musculares",
        "experience": "Intermediária",
        "restrictions": "Nenhuma lesão. Requer atenção especial aos descansos entre séries para não queimar excesso calórico.",
        "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 1,
        "mesocycle_name": "Ganho Ponderal Limpo",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 15000,
    },
    {
        "full_name": "Thiago Nogueira",
        "gender": "male",
        "age": 34,
        "weight_kg": 56.5,
        "height_cm": 175,
        "group": "underweight",
        "modality": "Força Hipertrófica",
        "objective": "Superação de Platô Ponderal e Aumento de Força",
        "experience": "Intermediário",
        "restrictions": "Desconforto em epicôndilo medial no tríceps testa. Substituir por tríceps corda na polia.",
        "avatar": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 2,
        "mesocycle_name": "Quebra de Platô de Cargas",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 2,
        "amount_cents": 16500,
    },
    {
        "full_name": "Helena Bittencourt",
        "gender": "female",
        "age": 64,
        "weight_kg": 46.0,
        "height_cm": 158,
        "group": "underweight",
        "modality": "Reabilitação & Ganho de Massa Funcional",
        "objective": "Combate à Sarcopenia e Fortalecimento Ósseo",
        "experience": "Iniciante",
        "restrictions": "Osteopenia no fêmur e perda de massa muscular (sarcopenia leve). Exercícios resistidos controlados com cargas moderadas.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 1,
        "mesocycle_name": "Reabilitação Óssea",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 1,
        "amount_cents": 18000,
    },
    {
        "full_name": "Vinícius Salles",
        "gender": "male",
        "age": 26,
        "weight_kg": 52.0,
        "height_cm": 172,
        "group": "underweight",
        "modality": "Calistenia & Musculação Híbrida",
        "objective": "Ganho de Peso Corporal, Peitoral e Dorsais",
        "experience": "Iniciante",
        "restrictions": "Nenhuma restrição articular. Foco em nutrição hipercalórica e exercícios multiarticulares.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Multiarticular",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 0,
        "amount_cents": 14000,
    },

    # =========================================================================
    # GRUPO 4: 3 Alunos Idosos acima de 60 anos
    # =========================================================================
    {
        "full_name": "Walter Guimarães",
        "gender": "male",
        "age": 68,
        "weight_kg": 74.0,
        "height_cm": 171,
        "group": "senior",
        "modality": "Longevidade & Mobilidade Articular",
        "objective": "Manutenção da Autonomia, Equilíbrio e Força de Pegada",
        "experience": "Intermediário",
        "restrictions": "Impacto subacromial no ombro direito. Proibido elevação acima de 90° e desenvolvimento militar livre.",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 2,
        "mesocycle_name": "Longevidade Ativa",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 1,
        "amount_cents": 21000,
    },
    {
        "full_name": "Maria das Graças",
        "gender": "female",
        "age": 72,
        "weight_kg": 63.5,
        "height_cm": 157,
        "group": "senior",
        "modality": "Treinamento Funcional Sênior",
        "objective": "Prevenção de Quedas, Fortalecimento de Quadril e Core",
        "experience": "Iniciante",
        "restrictions": "Episódios de labirintite e osteopenia de coluna. Exercícios sempre com ponto de apoio seguro, sem troca rápida de plano corporal.",
        "avatar": "https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 1,
        "mesocycle_name": "Equilíbrio & Prevenção de Quedas",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
    },
    {
        "full_name": "Dr. Paulo Afonso",
        "gender": "male",
        "age": 63,
        "weight_kg": 79.0,
        "height_cm": 177,
        "group": "senior",
        "modality": "Musculação de Força & Hipertrofia Sênior",
        "objective": "Performance, Longevidade e Preservação de Massa Magra",
        "experience": "Avançado (Ex-atleta master)",
        "restrictions": "Nenhuma restrição articular ativa. Excelente condicionamento cardiovascular.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Master Avançada",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 2,
        "amount_cents": 22000,
    },

    # =========================================================================
    # GRUPO 5: 4 Alunas Pós-parto & Saúde Feminina
    # =========================================================================
    {
        "full_name": "Camila Fontes",
        "gender": "female",
        "age": 28,
        "weight_kg": 62.0,
        "height_cm": 166,
        "group": "postpartum",
        "modality": "Recuperação Pós-Parto & Fechamento de Diástase",
        "objective": "Reabilitação do Assoalho Pélvico e Fortalecimento do Transverso",
        "experience": "Intermediária",
        "restrictions": "Diástase abdominal de 2.5cm supraumbilical. Proibido flexão clássica de tronco (crunches) e prancha frontal estática.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 14,
        "days_inactive": 1,
        "mesocycle_name": "Reabilitação de Core & Diástase",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 19000,
    },
    {
        "full_name": "Renata Vasconcelos",
        "gender": "female",
        "age": 32,
        "weight_kg": 68.0,
        "height_cm": 169,
        "group": "postpartum",
        "modality": "Funcional Pós-Parto & Estabilidade",
        "objective": "Retorno Seguro à Atividade Física após Cesárea",
        "experience": "Iniciante",
        "restrictions": "Cicatriz de cesárea de 5 meses. Evitar impactos repetitivos na pelve.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 3,
        "days_inactive": 6,  # ⚠️ INATIVA HÁ 6 DIAS (Alerta)
        "mesocycle_name": "Reativação Postural",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 3,  # Inadimplente há 3 dias
        "amount_cents": 17000,
    },
    {
        "full_name": "Mariana Toledo Leite",
        "gender": "female",
        "age": 30,
        "weight_kg": 65.0,
        "height_cm": 167,
        "group": "postpartum",
        "modality": "Treinamento Funcional e Pilates Solo",
        "objective": "Fortalecimento Global e Alívio de Lombalgia Pós-Maternidade",
        "experience": "Intermediária",
        "restrictions": "Instabilidade sacroilíaca leve. Foco em ativação de glúteo médio.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 22,
        "days_inactive": 0,
        "mesocycle_name": "Estabilidade Lombopélvica",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 18500,
    },
    {
        "full_name": "Gisele Arantes",
        "gender": "female",
        "age": 36,
        "weight_kg": 58.0,
        "height_cm": 162,
        "group": "postpartum",
        "modality": "Musculação & Densidade Óssea",
        "objective": "Ganho de Massa Muscular e Prevenção de Osteopenia",
        "experience": "Intermediária (Praticava Pilates)",
        "restrictions": "Nenhuma restrição articular. Transição de cargas moderadas para progressivas.",
        "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&fit=crop&crop=face",
        "streak": 16,
        "days_inactive": 1,
        "mesocycle_name": "Sobrecarga Progressiva Linear",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 16000,
    },

    # =========================================================================
    # GRUPO 6: 5 Alunos com Reabilitação Ortopédica Específica
    # =========================================================================
    {
        "full_name": "Marcos Vinícius Terra",
        "gender": "male",
        "age": 35,
        "weight_kg": 88.0,
        "height_cm": 180,
        "group": "orthopedic",
        "modality": "Reabilitação Lombar & Hipertrofia Guiada",
        "objective": "Fortalecimento de Paravertebrais e Glúteos sem Carga Axial",
        "experience": "Intermediário",
        "restrictions": "Hérnia extrusa em L5-S1 assintomática. Proibido agachamento livre, levantamento terra e desenvolvimento militar em pé.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 19,
        "days_inactive": 0,
        "mesocycle_name": "Estabilização Lombar e Core",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
    },
    {
        "full_name": "Patrícia Meirelles",
        "gender": "female",
        "age": 46,
        "weight_kg": 75.0,
        "height_cm": 160,
        "group": "orthopedic",
        "modality": "Fortalecimento de Glúteo Médio & Isquiotibiais",
        "objective": "Tratamento de Dor Patelofemoral no Joelho Esquerdo",
        "experience": "Iniciante",
        "restrictions": "Condromalácia patelar grau 3 no joelho esquerdo. Proibido cadeira extensora aberta e pliometria.",
        "avatar": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=300&fit=crop&crop=face",
        "streak": 2,
        "days_inactive": 8,  # ⚠️ INATIVA HÁ 8 DIAS (Alerta de Churn)
        "mesocycle_name": "Estabilização Patelofemoral",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 5,  # Inadimplente há 5 dias
        "amount_cents": 19500,
    },
    {
        "full_name": "Carlos Eduardo 'Kadu'",
        "gender": "male",
        "age": 22,
        "weight_kg": 78.0,
        "height_cm": 184,
        "group": "orthopedic",
        "modality": "Propriocepção & Força Unilateral",
        "objective": "Fase Final de Reabilitação de LCA (Futebol Amador)",
        "experience": "Avançado",
        "restrictions": "Pós-operatório de LCA há 8 meses. Priorizar exercícios unilaterais e aterrissagem controlada.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 25,
        "days_inactive": 2,
        "mesocycle_name": "Força Unilateral & Retorno ao Esporte",
        "mesocycle_week": "Semana 5 de 8",
        "days_overdue": 0,
        "amount_cents": 22000,
    },
    {
        "full_name": "Dra. Denise Prado",
        "gender": "female",
        "age": 52,
        "weight_kg": 71.0,
        "height_cm": 163,
        "group": "orthopedic",
        "modality": "Mobilidade Escapular & Fortalecimento de Membros Inferiores",
        "objective": "Descompressão Subacromial e Fortalecimento sem Dor",
        "experience": "Intermediária",
        "restrictions": "Tendinopatia crônica de supraespinal no ombro direito. Proibido elevação lateral acima de 80° e supino reto com barra.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 4,
        "days_inactive": 7,  # ⚠️ INATIVA HÁ 7 DIAS
        "mesocycle_name": "Descompressão Subacromial",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 18000,
    },
    {
        "full_name": "Alexandre 'Ale' Fontoura",
        "gender": "male",
        "age": 49,
        "weight_kg": 87.0,
        "height_cm": 174,
        "group": "orthopedic",
        "modality": "Fortalecimento Escapular & Postural",
        "objective": "Tratamento de LER/DORT em Antebraços e Punhos (Engenheiro de Software)",
        "experience": "Iniciante",
        "restrictions": "Sensibilidade em flexores de punho. Utilizar pegadas neutras, munhequeiras e cabos.",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&fit=crop&crop=face",
        "streak": 18,
        "days_inactive": 1,
        "mesocycle_name": "Descompressão de Punhos & Postura",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 17500,
    },

    # =========================================================================
    # GRUPO 7: 4 Alunos Cardiopatas / Metabólicos
    # =========================================================================
    {
        "full_name": "Jorge Tadeu Mendonça",
        "gender": "male",
        "age": 59,
        "weight_kg": 96.0,
        "height_cm": 173,
        "group": "cardio_metabolic",
        "modality": "Cardiorrespiratório Contínuo & Resistência Leve",
        "objective": "Controle Pressórico, Redução de Peso e Melhora da Capacidade Cardíaca",
        "experience": "Iniciante",
        "restrictions": "Hipertensão arterial estágio 2 controlada. Manter FC abaixo de 140 bpm, pausas regulares de hidratação.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 12,
        "days_inactive": 1,
        "mesocycle_name": "Resistência Muscular Geral",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 0,
        "amount_cents": 20000,
    },
    {
        "full_name": "Silvia Helena Ramos",
        "gender": "female",
        "age": 56,
        "weight_kg": 84.0,
        "height_cm": 158,
        "group": "cardio_metabolic",
        "modality": "Controle Glicêmico & Circuito Metabólico",
        "objective": "Aumento de Sensibilidade à Insulina e Perda de Gordura Abdominal",
        "experience": "Iniciante",
        "restrictions": "Diabetes Tipo 2. Medir glicemia pré-treino, ter carboidrato de ação rápida disponível em caso de hipoglicemia.",
        "avatar": "https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=300&fit=crop&crop=face",
        "streak": 27,
        "days_inactive": 0,
        "mesocycle_name": "Sensibilidade Insulínica & Circuito",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
    },
    {
        "full_name": "Nelson Antunes",
        "gender": "male",
        "age": 66,
        "weight_kg": 82.0,
        "height_cm": 175,
        "group": "cardio_metabolic",
        "modality": "Condicionamento Cardioprotetor",
        "objective": "Reabilitação Cardiovascular Pós-Stent",
        "experience": "Iniciante",
        "restrictions": "Cardiopata com stent coronariano há 18 meses. Proibido manobra de Valsalva e testes de 1RM.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 3,
        "days_inactive": 9,  # ⚠️ INATIVO HÁ 9 DIAS (Alerta)
        "mesocycle_name": "Condicionamento Cardioprotetor",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 4,  # Inadimplente há 4 dias
        "amount_cents": 23000,
    },
    {
        "full_name": "Murilo Peixoto",
        "gender": "male",
        "age": 54,
        "weight_kg": 99.0,
        "height_cm": 179,
        "group": "cardio_metabolic",
        "modality": "Circuito Metabólico com Intervalos Curtos",
        "objective": "Reversão de Pré-Diabetes e Redução da Circunferência Abdominal (>108cm)",
        "experience": "Iniciante",
        "restrictions": "Esteatose hepática grau 2 e intolerância inicial à glicose. Exercícios com pausas ativas leves.",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face",
        "streak": 5,
        "days_inactive": 8,  # ⚠️ INATIVO HÁ 8 DIAS
        "mesocycle_name": "Circuito Anti-Esteatose",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 6,  # Inadimplente há 6 dias
        "amount_cents": 18000,
    },

    # =========================================================================
    # GRUPO 8: 5 Atletas e Alunos de Alta Performance
    # =========================================================================
    {
        "full_name": "Felipe 'Spartan' Guedes",
        "gender": "male",
        "age": 28,
        "weight_kg": 85.0,
        "height_cm": 178,
        "group": "athlete",
        "modality": "Cross Training & Pliometria Funcional",
        "objective": "Potência Pliométrica, Resistência de Grip e Performance em OCR",
        "experience": "Avançado",
        "restrictions": "Nenhuma restrição articular. Foco em volume alto e cadência rápida.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 32,
        "days_inactive": 0,
        "mesocycle_name": "Choque & Volume Máximo Pliométrico",
        "mesocycle_week": "Semana 4 de 4",
        "days_overdue": 0,
        "amount_cents": 24000,
    },
    {
        "full_name": "Mariana Becker",
        "gender": "female",
        "age": 25,
        "weight_kg": 64.0,
        "height_cm": 172,
        "group": "athlete",
        "modality": "Bodybuilding Bikini & Densidade",
        "objective": "Ênfase em Deltoide Lateral, Grande Dorsal e Glúteo Máximo",
        "experience": "Avançada",
        "restrictions": "Nenhuma restrição. Atenção a fadiga de SNC com drop-sets e rest-pause programados.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 35,
        "days_inactive": 0,
        "mesocycle_name": "Pico de Volume Miofibrilar",
        "mesocycle_week": "Semana 6 de 8",
        "days_overdue": 0,
        "amount_cents": 25000,
    },
    {
        "full_name": "Diego Hernandes",
        "gender": "male",
        "age": 31,
        "weight_kg": 92.0,
        "height_cm": 185,
        "group": "athlete",
        "modality": "Força Excêntrica para Triatletas",
        "objective": "Prevenção de Lesões em Corrida/Bike e Estabilidade de Quadril",
        "experience": "Avançado",
        "restrictions": "Histórico de síndrome do trato iliotibial tratada. Manter liberação miofascial prévia.",
        "avatar": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&fit=crop&crop=face",
        "streak": 24,
        "days_inactive": 1,
        "mesocycle_name": "Força Máxima Excêntrica",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 23000,
    },
    {
        "full_name": "Priscila Zanetti",
        "gender": "female",
        "age": 29,
        "weight_kg": 55.0,
        "height_cm": 161,
        "group": "athlete",
        "modality": "Economia de Corrida & Força Rápida",
        "objective": "Sub-45min nos 10k e Fortalecimento de Gastrocnêmios/Sóleo",
        "experience": "Intermediária",
        "restrictions": "Canelite prévia sob controle. Evitar saltos verticais com calçado duro.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 21,
        "days_inactive": 2,
        "mesocycle_name": "Economia de Corrida & Força Rápida",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 18000,
    },
    {
        "full_name": "Eduardo 'Dudu' Vasques",
        "gender": "male",
        "age": 27,
        "weight_kg": 81.0,
        "height_cm": 178,
        "group": "athlete",
        "modality": "Força Isométrica & Pegada (Jiu-Jitsu)",
        "objective": "Resistência de Empunhadura, Core Rotacional e Isometria de Quadril",
        "experience": "Avançado (Faixa Roxa)",
        "restrictions": "Instabilidade de clavícula direita grau 1. Sem desenvolvimento com pegada aberta.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 30,
        "days_inactive": 0,
        "mesocycle_name": "Força de Empunhadura & Core Rotacional",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 22000,
    },

    # =========================================================================
    # GRUPO 9: 5 Alunos Inadimplentes e Inativos Críticos (>5 a 14 dias sem treinar)
    # =========================================================================
    {
        "full_name": "Guilherme Albuquerque",
        "gender": "male",
        "age": 39,
        "weight_kg": 112.0,
        "height_cm": 176,
        "group": "churn_risk",
        "modality": "Adaptação Funcional Inicial",
        "objective": "Emagrecimento e Quebra do Sedentarismo",
        "experience": "Iniciante",
        "restrictions": "Sedentário convicto, baixa adesão a rotinas de esforço prolongado.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 1,
        "days_inactive": 12,  # ⚠️ CHURN CRÍTICO: 12 dias sem treinar
        "mesocycle_name": "Adaptação Funcional Inicial",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 14,  # Inadimplente há 14 dias
        "amount_cents": 16000,
    },
    {
        "full_name": "Vanessa Toledo",
        "gender": "female",
        "age": 43,
        "weight_kg": 89.0,
        "height_cm": 167,
        "group": "churn_risk",
        "modality": "Treino Metabólico Leve",
        "objective": "Perda de Gordura e Redução da Compulsão Noturna",
        "experience": "Iniciante",
        "restrictions": "Dores articulares no tornozelo direito pós-entorse antigo.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 3,
        "days_inactive": 6,  # ⚠️ INATIVA HÁ 6 DIAS
        "mesocycle_name": "Metabólico Leve",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 2,  # Inadimplente há 2 dias
        "amount_cents": 17000,
    },
    {
        "full_name": "Rogério Cintra",
        "gender": "male",
        "age": 48,
        "weight_kg": 105.0,
        "height_cm": 181,
        "group": "churn_risk",
        "modality": "Emagrecimento sem Impacto",
        "objective": "Perda de Peso e Alívio de Fascite Plantar Bilateral",
        "experience": "Iniciante",
        "restrictions": "Fascite plantar bilateral intensa. Proibido corrida ou esteira inclinada.",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&fit=crop&crop=face",
        "streak": 0,
        "days_inactive": 14,  # ⚠️ CHURN CRÍTICO: 14 dias sem treinar
        "mesocycle_name": "Emagrecimento sem Impacto",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 20,  # Inadimplente há 20 dias
        "amount_cents": 19000,
    },
    {
        "full_name": "Tatiane 'Tati' Fagundes",
        "gender": "female",
        "age": 34,
        "weight_kg": 79.0,
        "height_cm": 164,
        "group": "churn_risk",
        "modality": "Capacidade Aeróbica Gradativa",
        "objective": "Recuperação do Fôlego e Disposição Geral",
        "experience": "Iniciante",
        "restrictions": "Fadiga rápida ao menor sinal de estresse físico. Intervalos longos.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 2,
        "days_inactive": 10,  # ⚠️ INATIVA HÁ 10 DIAS
        "mesocycle_name": "Capacidade Aeróbica Gradativa",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 8,  # Inadimplente há 8 dias
        "amount_cents": 15000,
    },
    {
        "full_name": "Vitor Hugo Brandão",
        "gender": "male",
        "age": 23,
        "weight_kg": 74.0,
        "height_cm": 182,
        "group": "churn_risk",
        "modality": "Manutenção Rápida",
        "objective": "Evitar Perda de Massa Durante Período de Provas/TCC",
        "experience": "Intermediário",
        "restrictions": "Falta crônica de tempo e horários erráticos.",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face",
        "streak": 1,
        "days_inactive": 11,  # ⚠️ INATIVO HÁ 11 DIAS
        "mesocycle_name": "Manutenção Rápida",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 12,  # Inadimplente há 12 dias
        "amount_cents": 14000,
    },

    # =========================================================================
    # GRUPO 10: 4 Alunos Idosos Frágeis (70 a 78 anos) com Sarcopenia e Marcha
    # =========================================================================
    {
        "full_name": "Seu Agenor Barreto",
        "gender": "male",
        "age": 74,
        "weight_kg": 66.0,
        "height_cm": 168,
        "group": "frail_elderly",
        "modality": "Autonomia & Força Básica para Idosos",
        "objective": "Recuperação do Padrão de Marcha e Confiança pós-queda",
        "experience": "Iniciante",
        "restrictions": "Sarcopenia e medo de novas quedas. Utilizar barras paralelas e apoio constante.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 18,
        "days_inactive": 1,
        "mesocycle_name": "Autonomia & Força Básica",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 23000,
    },
    {
        "full_name": "Dona Irene Albuquerque",
        "gender": "female",
        "age": 76,
        "weight_kg": 54.0,
        "height_cm": 152,
        "group": "frail_elderly",
        "modality": "Densidade Óssea & Postura Axial",
        "objective": "Fortalecimento Muscular sem Compressão de Vértebras",
        "experience": "Iniciante",
        "restrictions": "Osteoporose severa em coluna lombar. Proibido flexões e torções de tronco bruscas.",
        "avatar": "https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=300&fit=crop&crop=face",
        "streak": 20,
        "days_inactive": 2,
        "mesocycle_name": "Densidade Óssea & Postura Axial",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
    },
    {
        "full_name": "Professor Antenor Lins",
        "gender": "male",
        "age": 71,
        "weight_kg": 70.0,
        "height_cm": 172,
        "group": "frail_elderly",
        "modality": "Neuroativação & Mobilidade Rítmica",
        "objective": "Preservação da Destreza Motora e Ritmo de Passadas",
        "experience": "Intermediário",
        "restrictions": "Tremores de repouso em MSE (Parkinson inicial). Exercícios com feedback visual.",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300&fit=crop&crop=face",
        "streak": 26,
        "days_inactive": 0,
        "mesocycle_name": "Neuroativação & Mobilidade Rítmica",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 24000,
    },
    {
        "full_name": "Dona Nair de Camargo",
        "gender": "female",
        "age": 78,
        "weight_kg": 58.0,
        "height_cm": 155,
        "group": "frail_elderly",
        "modality": "Mobilidade e Fortalecimento Articular",
        "objective": "Manutenção da Marcha Independente e Alívio da Coxartrose",
        "experience": "Iniciante",
        "restrictions": "Artrose severa de quadril bilateral. Carga sempre suave com amplitude confortável.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 15,
        "days_inactive": 3,
        "mesocycle_name": "Mobilidade e Fortalecimento Articular",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 22000,
    },

    # =========================================================================
    # GRUPO 11: 4 Alunos Adolescentes / Jovens Atletas (16 a 18 anos)
    # =========================================================================
    {
        "full_name": "Enzo Gabriel Nogueira",
        "gender": "male",
        "age": 16,
        "weight_kg": 62.0,
        "height_cm": 179,
        "group": "teenager",
        "modality": "Alinhamento Postural & Hipertrofia de Base",
        "objective": "Correção de Postura Hipercifótica e Construção de Base Muscular",
        "experience": "Iniciante",
        "restrictions": "Fase final de estirão de crescimento. Carga progressiva sem impacto exagerado em fêmur/tíbia.",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face",
        "streak": 17,
        "days_inactive": 0,
        "mesocycle_name": "Alinhamento Postural & Hipertrofia de Base",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 0,
        "amount_cents": 15000,
    },
    {
        "full_name": "Sofia Castanho",
        "gender": "female",
        "age": 17,
        "weight_kg": 53.0,
        "height_cm": 163,
        "group": "teenager",
        "modality": "Potência de Membros Superiores (Natação)",
        "objective": "Melhora de Força Explosiva de Saída e Virada de Nado",
        "experience": "Avançada",
        "restrictions": "Sensibilidade em manguito rotador nos estilos borboleta/crawl. Fortalecimento de romboides.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 23,
        "days_inactive": 1,
        "mesocycle_name": "Potência de Membros Superiores",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 17000,
    },
    {
        "full_name": "Arthur 'Tutu' Bernardes",
        "gender": "male",
        "age": 18,
        "weight_kg": 69.0,
        "height_cm": 175,
        "group": "teenager",
        "modality": "Hipertrofia Miofibrilar Iniciante",
        "objective": "Ganho de Massa Muscular para Peitoral, Costas e Braços",
        "experience": "Iniciante",
        "restrictions": "Nenhuma restrição articular relatada. Treino com foco em técnica estrita.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 20,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Miofibrilar Iniciante",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 14000,
    },
    {
        "full_name": "Larissa Miyake",
        "gender": "female",
        "age": 17,
        "weight_kg": 51.0,
        "height_cm": 160,
        "group": "teenager",
        "modality": "Estabilidade Central e Força Isométrica",
        "objective": "Controle Articular e Fortalecimento para Ginástica",
        "experience": "Avançada",
        "restrictions": "Hipermobilidade articular congênita. Foco em força isométrica para travar articulações.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 22,
        "days_inactive": 2,
        "mesocycle_name": "Estabilidade Central e Força Isométrica",
        "mesocycle_week": "Semana 4 de 4",
        "days_overdue": 0,
        "amount_cents": 16500,
    },

    # =========================================================================
    # GRUPO 12: 4 Executivos Sedentários com Rotina de Alta Viagem e Estresse
    # =========================================================================
    {
        "full_name": "Roberto 'Beto' Salgado",
        "gender": "male",
        "age": 44,
        "weight_kg": 91.0,
        "height_cm": 177,
        "group": "executive",
        "modality": "Manutenção Express para Viagens",
        "objective": "Sessões Rápidas de 30 minutos em Hotéis e Aeroportos",
        "experience": "Intermediário",
        "restrictions": "Rotina caótica de viagens, dor cervical tensional.",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face",
        "streak": 5,
        "days_inactive": 7,  # ⚠️ INATIVO HÁ 7 DIAS
        "mesocycle_name": "Manutenção Express para Viagens",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 21000,
    },
    {
        "full_name": "Fernanda Queiroz",
        "gender": "female",
        "age": 38,
        "weight_kg": 65.0,
        "height_cm": 168,
        "group": "executive",
        "modality": "Descompressão Cervical & Glúteos",
        "objective": "Combate aos Efeitos de 12 Horas Diárias Sentada (Advocacia)",
        "experience": "Iniciante",
        "restrictions": "Encurtamento severo de psoas e dor ciática leve. Alongamento diário de flexores.",
        "avatar": "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=300&fit=crop&crop=face",
        "streak": 6,
        "days_inactive": 5,  # ⚠️ INATIVA HÁ 5 DIAS
        "mesocycle_name": "Descompressão Cervical & Glúteos",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 3,  # Inadimplente há 3 dias
        "amount_cents": 18000,
    },
    {
        "full_name": "Cláudia Mello",
        "gender": "female",
        "age": 40,
        "weight_kg": 70.0,
        "height_cm": 165,
        "group": "executive",
        "modality": "Circuito Neuromuscular Revitalizante",
        "objective": "Gestão de Estresse e Sono em Rotina de Plantão Médico",
        "experience": "Intermediária",
        "restrictions": "Insônia crônica pós-plantão noturno. Treino de média intensidade sem estresse adrenal.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 8,
        "days_inactive": 6,  # ⚠️ INATIVA HÁ 6 DIAS
        "mesocycle_name": "Circuito Neuromuscular Revitalizante",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 0,
        "amount_cents": 19500,
    },
    {
        "full_name": "Bárbara Dantas",
        "gender": "female",
        "age": 31,
        "weight_kg": 63.0,
        "height_cm": 167,
        "group": "executive",
        "modality": "Pico de Definição & Densidade",
        "objective": "Condicionamento Geral e Definição Muscular",
        "experience": "Avançada",
        "restrictions": "Nenhuma restrição articular relatada.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 0,
        "mesocycle_name": "Pico de Definição & Densidade",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
    },
]

async def seed():
    print(f"Iniciando injeção e sincronização de {len(PERSONAS)} Personas de Alunos no Mr. Coach...")
    client = await supabase_service.get_client()
    if not client:
        print("Erro: Não foi possível obter o cliente Supabase.")
        return

    # 1. Garante que o treinador tem plano STUDIO e cota de 200 alunos para não bater no limite
    try:
        await client.table("subscriptions").update({
            "plan_id": "studio",
            "status": "active"
        }).eq("trainer_id", TRAINER_ID).execute()
        await client.table("profiles").update({
            "current_plan": "Studio Scale",
            "max_students": 200
        }).eq("id", TRAINER_ID).execute()
        print("✓ Plano do treinador garantido como STUDIO (Cota: 200 alunos).")
    except Exception as e:
        print(f"Aviso ao atualizar assinatura do treinador: {e}")

    now = datetime.now(timezone.utc)
    today = date.today()

    inserted_count = 0
    blocked_count = 0
    warning_count = 0
    inactive_5plus_count = 0

    for idx, p in enumerate(PERSONAS, start=1):
        email = f"{slugify(p['full_name'])}@shaipados.com"
        clean_phone = f"551198{random.randint(1000000, 9999999)}"
        is_blocked = p["days_overdue"] > 0
        subscription_status = "past_due" if is_blocked else "active"

        if is_blocked:
            blocked_count += 1
            due_date = today - timedelta(days=p["days_overdue"])
            valid_until = datetime(due_date.year, due_date.month, due_date.day, 23, 59, 59, tzinfo=timezone.utc).isoformat()
        else:
            warning_count += 1
            due_date = today + timedelta(days=25)
            valid_until = (now + timedelta(days=30)).isoformat()

        days_inactive = p.get("days_inactive", 0)
        if days_inactive >= 5:
            inactive_5plus_count += 1
            alert_msg = f"⚠️ ALERTA DE CHURN: Aluno sem treinar há {days_inactive} dias ({p['mesocycle_name']})"
        else:
            alert_msg = f"✅ Treino em dia ({p['mesocycle_name']} - {p['mesocycle_week']})"

        # 1. Cria usuário no Auth do Supabase com role 'client'
        student_id = None
        try:
            auth_user = None
            try:
                auth_user = await client.auth.admin.create_user({
                    "email": email,
                    "password": "AlunoMrCoach2026!",
                    "email_confirm": True,
                    "user_metadata": {
                        "full_name": p["full_name"],
                        "role": "client",
                        "roles": ["client"],
                        "phone": clean_phone
                    }
                })
            except Exception as e:
                # Se já existir no auth, continua
                pass

            student_id = auth_user.user.id if (auth_user and auth_user.user) else None
            if not student_id:
                # Tenta buscar pelo email existente no profiles
                exist = await client.table("profiles").select("id").eq("email", email).maybe_single().execute()
                student_id = (exist.data or {}).get("id") if exist else None
                if not student_id:
                    exist_phone = await client.table("profiles").select("id").eq("phone", clean_phone).maybe_single().execute()
                    student_id = (exist_phone.data or {}).get("id") if exist_phone else None

            if not student_id:
                print(f"[{idx}/{len(PERSONAS)}] Pulando {p['full_name']} (sem student_id)")
                continue

            # 2. Atualiza o Profile para role 'client', vinculado ao treinador
            profile_update = {
                "role": "client",
                "roles": ["client"],
                "full_name": p["full_name"],
                "email": email,
                "phone": clean_phone,
                "trainer_id": TRAINER_ID,
                "subscription_status": subscription_status,
                "subscription_valid_until": valid_until,
                "avatar_url": p["avatar"],
                "photo_url": p["avatar"],
                "current_streak": p["streak"],
                "daily_goal_progress": 0.3 if days_inactive >= 5 else 0.95,
                "age": p["age"],
                "weight_kg": p["weight_kg"],
                "height_cm": p["height_cm"],
                "clinical_restrictions": p["restrictions"],
                "has_completed_anamnesis": True,
                "status_message": f"Mesociclo: {p['mesocycle_name']} ({p['mesocycle_week']}) | Inativo há {days_inactive} dias",
                "alert_message": alert_msg,
            }
            await client.table("profiles").update(profile_update).eq("id", student_id).execute()

            # 3. Anamnese
            anamnesis_record = {
                "client_id": student_id,
                "trainer_id": TRAINER_ID,
                "objective": p["objective"],
                "training_level": p["experience"],
                "days_per_week": random.choice([3, 4, 5]),
                "workout_location": "Academia Convencional",
                "injuries_or_restrictions": p["restrictions"],
                "training_style": p["modality"],
                "biological_sex": p["gender"],
                "age": p["age"],
                "weight": p["weight_kg"],
                "height": p["height_cm"],
                "daily_activity": "Sedentária" if days_inactive >= 5 else "Moderada",
                "sleep_hours": "6 a 7 horas" if p["group"] == "executive" else "7 a 8 horas",
                "stress_level": "Alto" if p["group"] in ("executive", "churn_risk") else "Médio",
                "training_history": f"{p['experience']} em musculação/treino físico.",
                "available_equipment": "Halteres, Máquinas, Barras e Polias",
                "details": f"Aluno do ecossistema Mr. Coach. Mesociclo: {p['mesocycle_name']} ({p['mesocycle_week']})."
            }
            try:
                await client.table("anamnesis").upsert(anamnesis_record, on_conflict="client_id").execute()
            except Exception:
                try:
                    await client.table("anamnesis").insert(anamnesis_record).execute()
                except Exception:
                    pass

            # 4. Ficha de Treino Personalizada em WORKOUTS
            workout_record = {
                "client_id": student_id,
                "trainer_id": TRAINER_ID,
                "title": f"Ficha {p['mesocycle_name']} ({p['mesocycle_week']}) — {p['modality']}",
                "notes_for_trainer": f"Mesociclo: {p['mesocycle_name']} ({p['mesocycle_week']}). Restrições clínicas: {p['restrictions']}",
                "is_active": True,
                "plan_json": {
                    "splits": [
                        {
                            "split_identifier": "A",
                            "split_name": f"{p['modality']} Split A",
                            "exercises": [
                                {"name": "Aquecimento e Mobilidade Articular", "sets": 2, "reps": "15", "rest_seconds": 45},
                                {"name": "Supino com Halteres (Pegada Neutra)", "sets": 3, "reps": "10-12", "rest_seconds": 60},
                                {"name": "Puxada Frontal na Polia", "sets": 3, "reps": "12", "rest_seconds": 60},
                                {"name": "Leg Press 45 Guiado", "sets": 3, "reps": "12", "rest_seconds": 90},
                            ]
                        },
                        {
                            "split_identifier": "B",
                            "split_name": f"{p['modality']} Split B",
                            "exercises": [
                                {"name": "Elevação Pélvica com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
                                {"name": "Remada Baixa Sentada", "sets": 3, "reps": "10", "rest_seconds": 60},
                                {"name": "Prancha Isométrica Adaptada", "sets": 3, "reps": "30s", "rest_seconds": 45},
                            ]
                        }
                    ]
                }
            }
            inserted_workout = None
            try:
                res_w = await client.table("workouts").insert(workout_record).execute()
                if res_w and res_w.data:
                    inserted_workout = res_w.data[0]
            except Exception:
                pass

            # 5. Sessão de Treino em WORKOUT_SESSIONS correspondente à inatividade
            session_date = now - timedelta(days=days_inactive)
            session_record = {
                "client_id": student_id,
                "trainer_id": TRAINER_ID,
                "workout_id": (inserted_workout or {}).get("id"),
                "split_identifier": "A",
                "split_name": f"{p['modality']} Split A",
                "total_exercises": 4,
                "completed_exercises": 4,
                "started_at": (session_date - timedelta(minutes=50)).isoformat(),
                "completed_at": session_date.isoformat(),
                "duration_seconds": 3000,
            }
            try:
                await client.table("workout_sessions").insert(session_record).execute()
            except Exception:
                pass

            # 6. Fatura / Cobrança na tabela STUDENT_INVOICES
            inv_id = str(uuid.uuid4())
            fee_cents = int(p["amount_cents"] * 0.05)
            net_cents = p["amount_cents"] - fee_cents
            payment_link = f"https://shaipados.com/pay/{inv_id}"
            simulated_pix = (
                f"00020126580014br.gov.bcb.pix0136{inv_id}520400005303986"
                f"540{p['amount_cents']/100:.2f}5802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304"
            )

            invoice_record = {
                "id": inv_id,
                "trainer_id": TRAINER_ID,
                "student_id": student_id,
                "student_name": p["full_name"],
                "student_phone": clean_phone,
                "student_email": email,
                "title": f"Consultoria Mensal: {p['modality']}",
                "description": f"Ciclo de 30 dias individualizado. Mesociclo: {p['mesocycle_name']} ({p['mesocycle_week']})",
                "amount_cents": p["amount_cents"],
                "platform_fee_cents": fee_cents,
                "net_amount_cents": net_cents,
                "status": "pending" if is_blocked else "paid",
                "due_date": due_date.strftime("%Y-%m-%d"),
                "paid_at": None if is_blocked else (now - timedelta(days=5)).isoformat(),
                "payment_method": "pix",
                "payment_link": payment_link,
                "pix_copy_paste": simulated_pix,
            }
            try:
                await client.table("student_invoices").insert(invoice_record).execute()
            except Exception:
                pass

            inserted_count += 1
            status_tag = f"BLOQUEADO (Vencida há {p['days_overdue']}d)" if is_blocked else "ADIMPLENTE"
            inact_tag = f"[ALERTA INATIVO {days_inactive} DIAS]" if days_inactive >= 5 else f"Ativo ({days_inactive}d)"
            print(f"[{idx}/{len(PERSONAS)}] OK -> {p['full_name']} ({p['age']}a, {p['gender']}, {p['mesocycle_name']} - {p['mesocycle_week']}) -> {status_tag} | {inact_tag}")

        except Exception as e:
            print(f"Erro em {p['full_name']}: {e}")

    print("\n" + "="*80)
    print("Injeção de Personas Clínicas Finalizada com Sucesso!")
    print(f"Total de alunos sincronizados: {inserted_count}/{len(PERSONAS)}")
    print(f"Alunos com acesso BLOQUEADO / Inadimplentes (past_due): {blocked_count}")
    print(f"Alunos com mais de 5 dias sem treinar (Alerta de Churn): {inactive_5plus_count}")
    print("="*80)

if __name__ == "__main__":
    asyncio.run(seed())
