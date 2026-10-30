# backend/scripts/generate_50_personas_sql.py
"""
Gerador de 50 personas enriquecidas e diversificadas para o treinador Mr. Coach (cleudsonx2021@gmail.com).
Gera o arquivo SQL 'seed_50_new_personas.sql' pronto para execução direta no banco do Supabase.
"""

import uuid
import json
import random
from datetime import datetime, date, timedelta, timezone

TRAINER_ID = "6f645308-f1b2-4d73-ac45-9890c27e20d4"

RAW_PERSONAS = [
    # --- 1 a 10: Jovens & Universitários (16 a 22 anos) ---
    {
        "full_name": "Gabriel Meneses",
        "gender": "male",
        "age": 17,
        "weight_kg": 64.0,
        "height_cm": 176,
        "modality": "Calistenia & Musculação Juvenil",
        "objective": "Ganho de Massa Muscular (Hipertrofia Ectomorfo) & Postura",
        "experience": "Iniciante",
        "restrictions": "Escoliose postural leve em 'C'. Foco em fortalecimento do core e simetria escapular.",
        "avatar": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face",
        "streak": 14,
        "days_inactive": 1,
        "mesocycle_name": "Adaptação Anatômica",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 15000,
        "split_a": [
            {"name": "Puxada Frontal Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10-12", "rest_seconds": 60},
            {"name": "Prancha Isométrica", "sets": 3, "reps": "30s", "rest_seconds": 45},
            {"name": "Remada Baixa Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Leg Press 45°", "sets": 3, "reps": "12-15", "rest_seconds": 75},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Panturrilha Sentado", "sets": 4, "reps": "15", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Sofia Bittencourt",
        "gender": "female",
        "age": 19,
        "weight_kg": 53.5,
        "height_cm": 164,
        "modality": "Condicionamento & Força para Vôlei",
        "objective": "Potência de Salto Vertical & Prevenção de Lesões",
        "experience": "Intermediário",
        "restrictions": "Histórico de entorse de tornozelo grau 1. Exercícios com base instável controlada.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 22,
        "days_inactive": 0,
        "mesocycle_name": "Potência & Pliometria",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Saltos em Caixa com Aterrissagem Suave", "sets": 4, "reps": "6", "rest_seconds": 90},
            {"name": "Agachamento Búlgaro", "sets": 3, "reps": "8-10", "rest_seconds": 75},
            {"name": "Hip Thrust com Barra", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Flexão Nórdica Reversa", "sets": 3, "reps": "8", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Desenvolvimento Militar com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Face Pull na Polia", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Rotação Externa de Ombro (Manguito)", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Remada Curvada com Apoio", "sets": 3, "reps": "10", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Lucas Evangelista",
        "gender": "male",
        "age": 21,
        "weight_kg": 73.0,
        "height_cm": 180,
        "modality": "Preparação TAF & Resistência Física",
        "objective": "Aprovação no TAF (Barra Fixa, Corrida 2400m e Abdominal Remador)",
        "experience": "Intermediário",
        "restrictions": "Sem restrições articulares. Foco em cadência e resistência cardiorrespiratória.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 35,
        "days_inactive": 0,
        "mesocycle_name": "Sobrecarga Específica TAF",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 22000,
        "split_a": [
            {"name": "Barra Fixa Pronada (Padrão TAF)", "sets": 5, "reps": "Falha - 1", "rest_seconds": 90},
            {"name": "Abdominal Remador Militar", "sets": 4, "reps": "25-30", "rest_seconds": 60},
            {"name": "Flexão de Braço no Solo", "sets": 4, "reps": "20", "rest_seconds": 60},
            {"name": "Tiro Intervalado na Esteira (400m)", "sets": 5, "reps": "1m30s", "rest_seconds": 90}
        ],
        "split_b": [
            {"name": "Agachamento Frontal com Barra", "sets": 4, "reps": "10", "rest_seconds": 90},
            {"name": "Passada Caminhando", "sets": 3, "reps": "20 passos", "rest_seconds": 60},
            {"name": "Puxada Neutra Fechada", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Farmer's Walk com Halteres Pesados", "sets": 4, "reps": "40m", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Beatriz Dornelles",
        "gender": "female",
        "age": 22,
        "weight_kg": 58.0,
        "height_cm": 168,
        "modality": "Hipertrofia Funcional & Glúteos",
        "objective": "Hipertrofia de Quadríceps e Glúteos com Cintura Fina",
        "experience": "Avançado",
        "restrictions": "Condromalácia patelar grau 1 no joelho esquerdo. Sem agachamento livre até o chão.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 42,
        "days_inactive": 1,
        "mesocycle_name": "Hipertrofia Miofibrilar",
        "mesocycle_week": "Semana 5 de 8",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Elevação Pélvica com Barra e Pausa 2s", "sets": 4, "reps": "10", "rest_seconds": 90},
            {"name": "Búlgaro com Halteres e Tronco Inclinado", "sets": 3, "reps": "10-12", "rest_seconds": 75},
            {"name": "Cadeira Abdutora Inclinada", "sets": 4, "reps": "15+drop", "rest_seconds": 60},
            {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75}
        ],
        "split_b": [
            {"name": "Puxador Articulado Aberto", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Lateral na Polia", "sets": 4, "reps": "12-15", "rest_seconds": 45},
            {"name": "Tríceps Corda", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Prancha Lateral com Abdução", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Caio Marcondes",
        "gender": "male",
        "age": 20,
        "weight_kg": 85.0,
        "height_cm": 184,
        "modality": "Powerbuilding & Força Bruta",
        "objective": "Quebra de PR no Supino e Terra com Hipertrofia",
        "experience": "Avançado",
        "restrictions": "Sem restrições. Sobrecarga progressiva monitorada por RPE.",
        "avatar": "https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face",
        "streak": 50,
        "days_inactive": 0,
        "mesocycle_name": "Choque / Sobrecarga de Força",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 0,
        "amount_cents": 25000,
        "split_a": [
            {"name": "Supino Reto com Barra (Pausa 1s no Peito)", "sets": 5, "reps": "5", "rest_seconds": 120},
            {"name": "Supino Inclinado com Halteres", "sets": 4, "reps": "8", "rest_seconds": 90},
            {"name": "Paralelas com Sobrecarga", "sets": 3, "reps": "8", "rest_seconds": 90},
            {"name": "Tríceps Francês na Polia", "sets": 4, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Levantamento Terra Convencional", "sets": 5, "reps": "3-5", "rest_seconds": 150},
            {"name": "Barra Fixa com Peso Adicional", "sets": 4, "reps": "6", "rest_seconds": 90},
            {"name": "Remada Curvada com Barra", "sets": 4, "reps": "8", "rest_seconds": 90},
            {"name": "Rosca Direta Barra W", "sets": 3, "reps": "10", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Camila Furtado",
        "gender": "female",
        "age": 21,
        "weight_kg": 62.0,
        "height_cm": 169,
        "modality": "Treino Funcional Híbrido",
        "objective": "Tonificação Muscular & Ganho de Fôlego",
        "experience": "Iniciante",
        "restrictions": "Tendinite patelar no joelho direito. Uso de cargas moderadas e cadência controlada.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 8,
        "days_inactive": 7,  # Risco de Churn!
        "mesocycle_name": "Adaptação Funcional",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 2,  # Bloqueada
        "amount_cents": 16000,
        "split_a": [
            {"name": "Leg Press Horizontal Unilateral", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Glúteo no Cabo com Caneleira", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Puxada Articulada Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Prancha Isométrica com Apoio de Joelhos", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino com Halteres Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Barra Romana", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Passada Curta com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60},
            {"name": "Abdominal Supra na Bola Suíça", "sets": 3, "reps": "15", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Henrique Toledo",
        "gender": "male",
        "age": 18,
        "weight_kg": 60.5,
        "height_cm": 179,
        "modality": "Musculação para Ganho de Peso",
        "objective": "Superávit Calórico & Hipertrofia Global (+8kg)",
        "experience": "Iniciante",
        "restrictions": "Magreza constitucional acentuada. Evitar treinos exaustivos acima de 50 minutos.",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face",
        "streak": 19,
        "days_inactive": 2,
        "mesocycle_name": "Hipertrofia Básica",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 17000,
        "split_a": [
            {"name": "Supino Reto na Barra Guiada", "sets": 4, "reps": "8-10", "rest_seconds": 75},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Tríceps Testa com Barra W", "sets": 3, "reps": "10-12", "rest_seconds": 60},
            {"name": "Agachamento no Hack Machine", "sets": 4, "reps": "10", "rest_seconds": 90}
        ],
        "split_b": [
            {"name": "Puxada Frente na Polia", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Remada Serrote com Halter", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Rosca Scott na Máquina", "sets": 3, "reps": "10-12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 4, "reps": "12", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Mariana Castelo",
        "gender": "female",
        "age": 22,
        "weight_kg": 67.0,
        "height_cm": 166,
        "modality": "Musculação & Emagrecimento",
        "objective": "Recomposição Corporal & Redução de Gordura Abdominal",
        "experience": "Intermediário",
        "restrictions": "Lombalgia mecânica ocasional. Manter postura neutra sem hiperextensão.",
        "avatar": "https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face",
        "streak": 27,
        "days_inactive": 0,
        "mesocycle_name": "Metabólico & Densidade",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Agachamento Goblet com Halter Pesado", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Leg Press 45° com Pés no Topo", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica com Miniband", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Panturrilha em Pé", "sets": 4, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Curvada Pegada Supinada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Desenvolvimento Arnold", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Cardio HIIT em Escada Ergométrica", "sets": 1, "reps": "15 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Felipe Diniz",
        "gender": "male",
        "age": 16,
        "weight_kg": 59.0,
        "height_cm": 174,
        "modality": "Iniciação Esportiva & Basquete",
        "objective": "Fortalecimento Muscular para Atletas Jovens & Agilidade",
        "experience": "Iniciante",
        "restrictions": "Adolescente em fase de crescimento. Proibidas cargas máximas (1RM).",
        "avatar": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&fit=crop&crop=face",
        "streak": 11,
        "days_inactive": 1,
        "mesocycle_name": "Coordenação & Base Neuromuscular",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 15000,
        "split_a": [
            {"name": "Agachamento Livre sem Carga (Técnica)", "sets": 3, "reps": "15", "rest_seconds": 60},
            {"name": "Puxada Alta com Elástico", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Flexão de Braço com Mãos Elevadas", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Bird-Dog", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Salto Lateral sobre Linha", "sets": 4, "reps": "20s", "rest_seconds": 60},
            {"name": "Arremesso de Medicine Ball no Solo", "sets": 3, "reps": "10", "rest_seconds": 45},
            {"name": "Afundo com Peso Corporal", "sets": 3, "reps": "10 cada perna", "rest_seconds": 60},
            {"name": "Caminhada do Fazendeiro Leve", "sets": 3, "reps": "30m", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Larissa Nogueira",
        "gender": "female",
        "age": 20,
        "weight_kg": 55.0,
        "height_cm": 163,
        "modality": "Musculação Estética & Pilates",
        "objective": "Definição Abdominal e Glúteos Firmes",
        "experience": "Intermediário",
        "restrictions": "Hipermobilidade articular. Manter controle excêntrico rígido sem hiperextender joelhos e cotovelos.",
        "avatar": "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face",
        "streak": 31,
        "days_inactive": 0,
        "mesocycle_name": "Tonificação & Controle Motor",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Stiff Unilateral com Apoio", "sets": 3, "reps": "12 cada lado", "rest_seconds": 60},
            {"name": "Agachamento Sumô com Kettlebell", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Extensora com Isometria 2s", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Abdominal Infra no Banco Declinado", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Puxada Triângulo no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa Supinada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Tríceps Mergulho no Banco", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Prancha Frontal com Toque no Ombro", "sets": 3, "reps": "20 toques", "rest_seconds": 45}
        ]
    },

    # --- 11 a 25: Adultos em Carreira & Vida Ativa (23 a 39 anos) ---
    {
        "full_name": "Leandro Pimentel",
        "gender": "male",
        "age": 31,
        "weight_kg": 92.0,
        "height_cm": 181,
        "modality": "Musculação Hipertrofia & Força",
        "objective": "Ganho de Braços e Peitoral (+42cm de braço)",
        "experience": "Avançado",
        "restrictions": "Epicondilite medial no cotovelo esquerdo. Pegada neutra em puxadas e roscas.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 45,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia de Braços & Peitoral",
        "mesocycle_week": "Semana 4 de 8",
        "days_overdue": 0,
        "amount_cents": 24000,
        "split_a": [
            {"name": "Supino Reto com Halteres Pesados", "sets": 4, "reps": "8-10", "rest_seconds": 90},
            {"name": "Crucifixo Inclinado na Polia", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Tríceps Corda com Abertura", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Tríceps Francês Unilateral", "sets": 3, "reps": "10", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Puxada Alta Pegada Neutra Fechada", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Remada Cavalinho com Barra", "sets": 4, "reps": "8-10", "rest_seconds": 90},
            {"name": "Rosca Martelo com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Rosca Inversa com Barra W", "sets": 3, "reps": "12", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Débora Medeiros",
        "gender": "female",
        "age": 34,
        "weight_kg": 71.0,
        "height_cm": 165,
        "modality": "Pós-Parto & Reabilitação Abdominal",
        "objective": "Fechamento de Diástase (3cm) & Reativação Pélvica",
        "experience": "Iniciante",
        "restrictions": "Diástase abdominal pós-parto (6 meses). Proibidos abdominais crunch tradicionais e prancha frontal sem apoio.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 16,
        "days_inactive": 1,
        "mesocycle_name": "Reabilitação de Core & Transverso",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
        "split_a": [
            {"name": "Ativação de Transverso com Respiração (Belly Vacuum)", "sets": 4, "reps": "10 expirações", "rest_seconds": 45},
            {"name": "Ponte de Glúteos com Bloqueio de Joelhos", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Deadbug Adaptado com Pés no Solo", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60},
            {"name": "Puxada Alta Sentada na Máquina", "sets": 3, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Agachamento na Cadeira com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Elástico", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Clamshell (Ostra) com Miniband", "sets": 3, "reps": "15 cada lado", "rest_seconds": 45},
            {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Danilo Paixão",
        "gender": "male",
        "age": 28,
        "weight_kg": 98.0,
        "height_cm": 186,
        "modality": "Emagrecimento Acelerado & Cross-Training",
        "objective": "Perder 15kg de Gordura & Aumentar VO2 Máximo",
        "experience": "Intermediário",
        "restrictions": "Condromalácia patelar grau 2 no joelho direito. Evitar impacto de salto no asfalto.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 5,
        "days_inactive": 9,  # Alerta Churn!
        "mesocycle_name": "Metabólico de Alta Densidade",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 3,  # Bloqueado
        "amount_cents": 18000,
        "split_a": [
            {"name": "Remo Ergométrico (Cardio Zero Impacto)", "sets": 4, "reps": "500m", "rest_seconds": 60},
            {"name": "Kettlebell Swing com Encaixe de Quadril", "sets": 4, "reps": "15", "rest_seconds": 60},
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Slam Ball no Chão", "sets": 4, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Air Bike Intervalada (Tabata)", "sets": 8, "reps": "20s/10s", "rest_seconds": 60},
            {"name": "Puxada Frente com Triângulo", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Leg Press 45° com Cadência 3030", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Prancha Frontal Estática", "sets": 3, "reps": "45s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Renata Vasconcelos",
        "gender": "female",
        "age": 36,
        "weight_kg": 63.5,
        "height_cm": 167,
        "modality": "Corrida de Rua & Fortalecimento de Base",
        "objective": "Completar Meia Maratona (21km) Sub-2h sem Lesões",
        "experience": "Avançado",
        "restrictions": "Fascite plantar no pé esquerdo em remissão. Mobilidade de tornozelo e liberação miofascial obrigatória.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 58,
        "days_inactive": 0,
        "mesocycle_name": "Força Resistente para Corredores",
        "mesocycle_week": "Semana 6 de 8",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Agachamento Unilateral no Step", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60},
            {"name": "Gêmeos em Pé no Degrau (Fase Excêntrica Lenta)", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Elevação Pélvica Unilateral", "sets": 3, "reps": "12 cada lado", "rest_seconds": 60},
            {"name": "Ponte Isométrica para Posteriores", "sets": 3, "reps": "40s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Remada Baixa com Pegada Aberta", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Pallof Press no Cabo (Anti-Rotação)", "sets": 3, "reps": "12 cada lado", "rest_seconds": 45},
            {"name": "Farmer's Walk Unilateral", "sets": 3, "reps": "30m cada braço", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Marcelo Bastos",
        "gender": "male",
        "age": 33,
        "weight_kg": 88.0,
        "height_cm": 178,
        "modality": "Musculação ABC Clássica",
        "objective": "Ganho de Densidade Muscular & Recomposição",
        "experience": "Intermediário",
        "restrictions": "Ombro direito com leve impacto subacromial. Sem elevação lateral acima de 90°.",
        "avatar": "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face",
        "streak": 24,
        "days_inactive": 2,
        "mesocycle_name": "Hipertrofia Sarcoplasmática",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Supino Inclinado com Halteres (Plano Escapular)", "sets": 4, "reps": "10-12", "rest_seconds": 75},
            {"name": "Crossover na Polia Média", "sets": 3, "reps": "12-15", "rest_seconds": 60},
            {"name": "Elevação Lateral no Cabo a 30°", "sets": 4, "reps": "12", "rest_seconds": 45},
            {"name": "Tríceps Pulley com Barra Reta", "sets": 3, "reps": "12", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Puxada Frontal com Barra Pegada Neutra", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Remada Baixa no Triângulo", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Crucifixo Invertido na Máquina", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Rosca Martelo na Polia com Corda", "sets": 3, "reps": "12", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Cláudia Peixoto",
        "gender": "female",
        "age": 39,
        "weight_kg": 68.0,
        "height_cm": 162,
        "modality": "Musculação Funcional & Core",
        "objective": "Emagrecimento & Alívio de Dores Cervicais de Home Office",
        "experience": "Intermediário",
        "restrictions": "Cervicalgia tensional e retificação cervical. Evitar trapézio elevado e encolhimentos.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 38,
        "days_inactive": 1,
        "mesocycle_name": "Reabilitação Postural & Tônus",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
        "split_a": [
            {"name": "Puxada Frente com Apoio no Peito", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Face Pull no Cabo com Foco em Romboides", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Agachamento Búlgaro com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica na Máquina", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Abdução de Quadril na Polia", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Prancha Frontal com Respiração Controlada", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Diego Brant",
        "gender": "male",
        "age": 35,
        "weight_kg": 105.0,
        "height_cm": 183,
        "modality": "Musculação & Cardio Não-Impactante",
        "objective": "Combate ao Sedentarismo & Redução de Esteatose Hepática",
        "experience": "Iniciante",
        "restrictions": "Hipertensão moderada controlada. Descansos mínimos de 60s entre séries.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 18,
        "days_inactive": 0,
        "mesocycle_name": "Adaptação Metabólica",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Leg Press 45°", "sets": 3, "reps": "12", "rest_seconds": 75},
            {"name": "Cadeira Extensora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino Máquina Sentado", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Bike Ergométrica Contínua", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ],
        "split_b": [
            {"name": "Puxada Alta na Máquina", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa Sentada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Patrícia Fagundes",
        "gender": "female",
        "age": 27,
        "weight_kg": 59.0,
        "height_cm": 163,
        "modality": "Preparação para Casamento & Estética",
        "objective": "Definição de Costas e Braços para Vestido & Glúteos Firmes",
        "experience": "Intermediário",
        "restrictions": "Sem restrições articulares. Foco em estética e densidade corporal.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 40,
        "days_inactive": 0,
        "mesocycle_name": "Polimento Estético",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 22000,
        "split_a": [
            {"name": "Puxada Supinada Fechada", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Curvada com Halteres", "sets": 4, "reps": "10-12", "rest_seconds": 60},
            {"name": "Elevação Lateral com Halteres", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Tríceps Banco com Pés Elevados", "sets": 3, "reps": "12", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Elevação Pélvica com Barra 60kg", "sets": 4, "reps": "10-12", "rest_seconds": 75},
            {"name": "Agachamento Sumô no Smith", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Cadeira Flexora Unilateral", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Abdominal Infra Suspenso", "sets": 3, "reps": "15", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Arthur Mansur",
        "gender": "male",
        "age": 29,
        "weight_kg": 77.0,
        "height_cm": 177,
        "modality": "Jiu-Jitsu & Preparação Física Complementar",
        "objective": "Pegada Poderosa (Grip Strength), Força Isométrica & Prevenção de Lesões",
        "experience": "Avançado",
        "restrictions": "Histórico de luxação de clavícula grau 1. Sem desenvolvimento militar pesado com barra.",
        "avatar": "https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face",
        "streak": 33,
        "days_inactive": 1,
        "mesocycle_name": "Força Isométrica & Grip",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Barra Fixa com Pano de Kimono", "sets": 4, "reps": "6-8", "rest_seconds": 90},
            {"name": "Levantamento Terra com Trap Bar", "sets": 4, "reps": "6", "rest_seconds": 120},
            {"name": "Farmer's Walk com Pegada em Pinça", "sets": 4, "reps": "30m", "rest_seconds": 60},
            {"name": "Rotação de Tronco no Cabo (Landmine)", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres Pegada Neutra", "sets": 4, "reps": "8", "rest_seconds": 90},
            {"name": "Agachamento Frontal com Halteres nos Ombros", "sets": 4, "reps": "8", "rest_seconds": 90},
            {"name": "Remada Unilateral com Halter Pesado", "sets": 3, "reps": "8 cada lado", "rest_seconds": 75},
            {"name": "Ponte de Glúteo Isométrica com Carga", "sets": 3, "reps": "45s", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Letícia Sampaio",
        "gender": "female",
        "age": 30,
        "weight_kg": 64.0,
        "height_cm": 170,
        "modality": "Hipertrofia Funcional & Corrida",
        "objective": "Ganho de Massa Magra em Membros Inferiores & Resistência",
        "experience": "Intermediário",
        "restrictions": "Sem restrições clínicas.",
        "avatar": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face",
        "streak": 48,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Miofibrilar",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Agachamento Livre com Barra", "sets": 4, "reps": "10", "rest_seconds": 90},
            {"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Cadeira Extensora", "sets": 3, "reps": "12-15", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Puxada Frontal Aberta", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Supino Inclinado com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Lateral na Polia", "sets": 4, "reps": "12", "rest_seconds": 45},
            {"name": "Prancha Lateral", "sets": 3, "reps": "40s cada lado", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Otávio Siqueira",
        "gender": "male",
        "age": 37,
        "weight_kg": 81.0,
        "height_cm": 175,
        "modality": "Musculação para Postura & Saúde",
        "objective": "Eliminação de Dores Lombares & Fortalecimento de Glúteos",
        "experience": "Iniciante",
        "restrictions": "Protrusão discal em L5-S1 assintomática. Proibida carga axial livre na coluna.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 6,
        "days_inactive": 11,  # Alerta Churn!
        "mesocycle_name": "Estabilização Lombopélvica",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 4,  # Bloqueado
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press Horizontal", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Alta com Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Chão", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Prancha Bird-Dog", "sets": 3, "reps": "12 cada lado", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa Apoiada no Peito", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Lateral Sentado", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Alongamento de Isquiotibiais com Fita", "sets": 3, "reps": "30s", "rest_seconds": 30}
        ]
    },
    {
        "full_name": "Rafaela Barreto",
        "gender": "female",
        "age": 26,
        "weight_kg": 57.0,
        "height_cm": 161,
        "modality": "Hipertrofia & Definição",
        "objective": "Massa Magra em Pernas & Costas Esculpidas",
        "experience": "Intermediário",
        "restrictions": "Sem restrições clínicas.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 29,
        "days_inactive": 0,
        "mesocycle_name": "Hipertrofia Muscular",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Hip Thrust na Máquina", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Agachamento no Hack", "sets": 3, "reps": "10", "rest_seconds": 75},
            {"name": "Cadeira Abdutora", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Mesa Flexora com Rest-Pause", "sets": 3, "reps": "10+4+4", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Remada Curvada com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Aberta na Polia", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Tríceps Corda", "sets": 3, "reps": "15", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Bernardo Krieger",
        "gender": "male",
        "age": 32,
        "weight_kg": 86.5,
        "height_cm": 182,
        "modality": "Treino Funcional & Triathlon Sprint",
        "objective": "Condicionamento Físico & Transição para Ciclismo/Corrida",
        "experience": "Avançado",
        "restrictions": "Histórico de tendinopatia no tendão de Aquiles direito. Carga progressiva em panturrilhas.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 62,
        "days_inactive": 0,
        "mesocycle_name": "Potência & Resistência Láctica",
        "mesocycle_week": "Semana 6 de 8",
        "days_overdue": 0,
        "amount_cents": 23000,
        "split_a": [
            {"name": "Trap Bar Deadlift com Velocidade", "sets": 4, "reps": "5", "rest_seconds": 90},
            {"name": "Salto sobre Barreira Baixa", "sets": 4, "reps": "6", "rest_seconds": 60},
            {"name": "Passada com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60},
            {"name": "Panturrilha Unilateral no Degrau", "sets": 4, "reps": "12", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Puxada Alta Fechada", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Rollout na Bola Suíça", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Tiro no Remo Indoor (500m)", "sets": 3, "reps": "1m35s", "rest_seconds": 90}
        ]
    },
    {
        "full_name": "Helena Prado",
        "gender": "female",
        "age": 28,
        "weight_kg": 54.0,
        "height_cm": 160,
        "modality": "Musculação & Yoga Híbrida",
        "objective": "Tonificação Corporal & Controle de Ansiedade",
        "experience": "Intermediário",
        "restrictions": "Asma induzida pelo exercício. Aquecimento respiratório obrigatório de 10 minutos.",
        "avatar": "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face",
        "streak": 25,
        "days_inactive": 1,
        "mesocycle_name": "Resistência Muscular Localizada",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Avanço Estático", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60},
            {"name": "Elevação Pélvica com Miniband", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Panturrilha Sentado", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Puxada Alta no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino com Halteres Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Desenvolvimento Arnold", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Frontal com Respiração Diafragmática", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Gustavo Mendonça",
        "gender": "male",
        "age": 38,
        "weight_kg": 94.0,
        "height_cm": 180,
        "modality": "Musculação & HIIT Metabólico",
        "objective": "Emagrecimento com Preservação de Massa Magra",
        "experience": "Intermediário",
        "restrictions": "Tendinite no tendão quadricipital direito. Sem agachamento profundo além de 90°.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 3,
        "days_inactive": 14,  # Alerta Churn Crítico!
        "mesocycle_name": "Reativação & Perda de Gordura",
        "mesocycle_week": "Semana 1 de 4",
        "days_overdue": 5,  # Bloqueado há 5 dias
        "amount_cents": 20000,
        "split_a": [
            {"name": "Leg Press 45° com Amplitude Limitada", "sets": 3, "reps": "12", "rest_seconds": 75},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino na Máquina Guiada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Transport (Elíptico) Contínuo", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ],
        "split_b": [
            {"name": "Puxada Alta com Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Articulada Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica com Apoio no Banco", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Prancha com Joelhos Apoiados", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ]
    },

    # --- 26 a 40: Meia Idade, Gestão de Estresse & Reabilitação (40 a 59 anos) ---
    {
        "full_name": "Tatiana Rocha",
        "gender": "female",
        "age": 44,
        "weight_kg": 72.0,
        "height_cm": 164,
        "modality": "Musculação & Prevenção Metabólica",
        "objective": "Ganho de Massa Óssea (Osteopenia) & Tonificação",
        "experience": "Intermediário",
        "restrictions": "Osteopenia na coluna lombar. Cargas axiais moderadas com foco em tração e empurrar.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 34,
        "days_inactive": 1,
        "mesocycle_name": "Estimulação Osteogênica",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press Horizontal Pesado", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Elevação Pélvica com Halter no Quadril", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Frontal Estática", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Puxada Alta Pegada Supinada", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Remada Baixa no Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Caminhada Rápida com Inclinação", "sets": 1, "reps": "25 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Rodrigo Valente",
        "gender": "male",
        "age": 47,
        "weight_kg": 90.0,
        "height_cm": 179,
        "modality": "Musculação & Estabilização de Coluna",
        "objective": "Alívio de Hérnia de Disco L4-L5 & Recomposição",
        "experience": "Intermediário",
        "restrictions": "Hérnia discal L4-L5 com pinçamento ciático prévio. Proibido levantamento terra e agachamento livre.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 41,
        "days_inactive": 0,
        "mesocycle_name": "Estabilização do Core & Descompressão",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Leg Press 45° com Costas Bem Apoiadas", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Puxada Frontal com Pegada Neutra Aberta", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Solo", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Prancha Bird-Dog com Isometria 3s", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino Máquina Sentado", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Articulada com Apoio Peitoral", "sets": 4, "reps": "10-12", "rest_seconds": 60},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Alongamento de Piriforme e Mobilidade de Quadril", "sets": 3, "reps": "40s", "rest_seconds": 30}
        ]
    },
    {
        "full_name": "Vanessa Brandão",
        "gender": "female",
        "age": 49,
        "weight_kg": 66.0,
        "height_cm": 160,
        "modality": "Treino Funcional & Climatério",
        "objective": "Preservação Muscular na Menopausa & Metabolismo Ativo",
        "experience": "Iniciante",
        "restrictions": "Dores articulares migratórias e fogachos. Treinos com ventilação adequada e hidratação constante.",
        "avatar": "https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face",
        "streak": 15,
        "days_inactive": 2,
        "mesocycle_name": "Adaptação Metabólica no Climatério",
        "mesocycle_week": "Semana 3 de 4",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Agachamento com Bola nas Costas (Parede)", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Alta com Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Extensora Leve", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Elevação Pélvica com Miniband", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Bike Reclinada Suave", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "André Linhares",
        "gender": "male",
        "age": 52,
        "weight_kg": 84.0,
        "height_cm": 173,
        "modality": "Musculação para Saúde Cardíaca",
        "objective": "Condicionamento Cardiovascular & Redução de Triglicerídeos",
        "experience": "Intermediário",
        "restrictions": "Pós-angioplastia (stent colocado há 2 anos). Acompanhamento cardiológico em dia. FC máx limitada a 135 bpm.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 46,
        "days_inactive": 1,
        "mesocycle_name": "Resistência Cardiovascular & Tônus",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 23000,
        "split_a": [
            {"name": "Caminhada Contínua com Monitor de FC", "sets": 1, "reps": "20 min", "rest_seconds": 0},
            {"name": "Leg Press Horizontal", "sets": 3, "reps": "15", "rest_seconds": 75},
            {"name": "Supino Máquina Guiada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica sem Carga", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Bicicleta Ergométrica com Carga Leve", "sets": 1, "reps": "20 min", "rest_seconds": 0},
            {"name": "Puxada Frontal Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Natália Guimarães",
        "gender": "female",
        "age": 41,
        "weight_kg": 65.0,
        "height_cm": 168,
        "modality": "Musculação & Mobilidade",
        "objective": "Fortalecimento para Combate à Fibromialgia",
        "experience": "Iniciante",
        "restrictions": "Fibromialgia com pontos dolorosos em ombros e quadris. Treinos curtos e sem fadiga excessiva.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 12,
        "days_inactive": 3,
        "mesocycle_name": "Adaptação Neuromuscular Suave",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press 45° com Peso Leve", "sets": 3, "reps": "10", "rest_seconds": 75},
            {"name": "Puxada Alta com Elástico", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Mobilidade Torácica no Colchonete", "sets": 3, "reps": "8 cada lado", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino com Halteres Leves", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Remada Baixa Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Extensora Suave", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Alongamento Global e Respiração Guiada", "sets": 1, "reps": "10 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Samuel Peçanha",
        "gender": "male",
        "age": 46,
        "weight_kg": 110.0,
        "height_cm": 185,
        "modality": "Emagrecimento com Máquinas Guiadas",
        "objective": "Perder 20kg & Reverter Pré-Diabetes",
        "experience": "Iniciante",
        "restrictions": "Obesidade grau 1 e sobrecarga nos joelhos. Zero corrida no solo, apenas elíptico e remo.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 20,
        "days_inactive": 0,
        "mesocycle_name": "Metabólico Não-Impactante",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Leg Press 45° Guiado", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Supino na Máquina com Pegada Neutra", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Elíptico com Resistência Moderada", "sets": 1, "reps": "25 min", "rest_seconds": 0}
        ],
        "split_b": [
            {"name": "Puxada Frontal Aberta na Máquina", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Apoio", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica com Apoio", "sets": 3, "reps": "15", "rest_seconds": 60},
            {"name": "Bicicleta Reclinada", "sets": 1, "reps": "25 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Gabriela Silveira",
        "gender": "female",
        "age": 42,
        "weight_kg": 61.0,
        "height_cm": 166,
        "modality": "Musculação Estética & Funcional",
        "objective": "Tonificação de Membros Inferiores & Cintura",
        "experience": "Intermediário",
        "restrictions": "Sem restrições.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 37,
        "days_inactive": 1,
        "mesocycle_name": "Hipertrofia Miofibrilar",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Elevação Pélvica com Barra", "sets": 4, "reps": "10-12", "rest_seconds": 75},
            {"name": "Agachamento Sumô com Halter", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Cadeira Abdutora", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Puxada Alta Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Elevação Lateral", "sets": 4, "reps": "12", "rest_seconds": 45},
            {"name": "Prancha Isométrica", "sets": 3, "reps": "45s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Thiago Cordeiro",
        "gender": "male",
        "age": 45,
        "weight_kg": 87.0,
        "height_cm": 176,
        "modality": "Musculação & Corrida Moderada",
        "objective": "Qualidade de Vida, Força & Fôlego",
        "experience": "Intermediário",
        "restrictions": "Condromalácia patelar grau 2 no joelho esquerdo.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 21,
        "days_inactive": 8,  # Alerta Churn!
        "mesocycle_name": "Força Resistente",
        "mesocycle_week": "Semana 2 de 6",
        "days_overdue": 1,  # Bloqueado há 1 dia
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Supino Reto com Barra", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Puxada Frontal", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Abdominal", "sets": 3, "reps": "45s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Remada Baixa no Triângulo", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Mesa Flexora", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Esteira Inclinada Caminhada", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Luciana Antunes",
        "gender": "female",
        "age": 48,
        "weight_kg": 69.5,
        "height_cm": 165,
        "modality": "Musculação & Saúde Metabólica",
        "objective": "Fortalecimento Muscular & Controle de Glicemia",
        "experience": "Iniciante",
        "restrictions": "Diabetes tipo 2 controlado por dieta e medicação. Cuidado com sinais de hipoglicemia.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 1,
        "mesocycle_name": "Adaptação de Força",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Leg Press Horizontal", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Extensora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino Máquina", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Puxada Alta Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Sentada no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Bike Ergométrica", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Murilo Farias",
        "gender": "male",
        "age": 55,
        "weight_kg": 91.0,
        "height_cm": 178,
        "modality": "Musculação & Mobilidade Articular",
        "objective": "Combate à Rigidez Matinal & Fortalecimento Geral",
        "experience": "Intermediário",
        "restrictions": "Artrose incipiente no quadril direito. Evitar abduções extremas com carga pesada.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 30,
        "days_inactive": 0,
        "mesocycle_name": "Mobilidade & Força Funcional",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
        "split_a": [
            {"name": "Leg Press 45° com Pés Afastados", "sets": 3, "reps": "12", "rest_seconds": 75},
            {"name": "Puxada Frente com Barra Romana", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Elevação Pélvica com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Prancha Bird-Dog", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Remada Articulada Fechada", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Mobilidade de Tornozelo e Quadril", "sets": 3, "reps": "40s", "rest_seconds": 30}
        ]
    },
    {
        "full_name": "Elisângela Costa",
        "gender": "female",
        "age": 53,
        "weight_kg": 73.0,
        "height_cm": 162,
        "modality": "Musculação Terapêutica",
        "objective": "Reabilitação de Tendinite no Ombro & Emagrecimento",
        "experience": "Iniciante",
        "restrictions": "Tendinopatia do supraespinhal direito. Proibidos movimentos acima da linha dos ombros.",
        "avatar": "https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face",
        "streak": 17,
        "days_inactive": 2,
        "mesocycle_name": "Estabilização Escapular",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press Horizontal", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Apoio de Peito", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Solo", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino com Halteres Leves (Amplitude 70°)", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Alta Fechada na Polia", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Wagner Assumpção",
        "gender": "male",
        "age": 51,
        "weight_kg": 96.0,
        "height_cm": 181,
        "modality": "Musculação & Ciclismo de Estrada",
        "objective": "Fortalecimento para Ciclismo & Perda de Peso",
        "experience": "Avançado",
        "restrictions": "Sem restrições graves.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 52,
        "days_inactive": 0,
        "mesocycle_name": "Potência & Força para Ciclismo",
        "mesocycle_week": "Semana 5 de 8",
        "days_overdue": 0,
        "amount_cents": 23000,
        "split_a": [
            {"name": "Agachamento Livre com Barra", "sets": 4, "reps": "8", "rest_seconds": 90},
            {"name": "Leg Press 45° com Cadência 4020", "sets": 4, "reps": "10", "rest_seconds": 90},
            {"name": "Stiff com Barra", "sets": 4, "reps": "8", "rest_seconds": 75},
            {"name": "Panturrilha em Pé com Carga", "sets": 4, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Supino Reto com Barra", "sets": 4, "reps": "8", "rest_seconds": 75},
            {"name": "Remada Curvada com Barra", "sets": 4, "reps": "8", "rest_seconds": 75},
            {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Frontal Estática", "sets": 4, "reps": "45s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Fernando Esteves",
        "gender": "male",
        "age": 43,
        "weight_kg": 83.0,
        "height_cm": 177,
        "modality": "Musculação Executiva (Express)",
        "objective": "Manutenção de Massa Magra & Alívio de Estresse (45 min)",
        "experience": "Intermediário",
        "restrictions": "Rotina intensa com viagens constantes. Treinos curtos de alta densidade.",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 28,
        "days_inactive": 1,
        "mesocycle_name": "Densidade & Circuito Força",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 22000,
        "split_a": [
            {"name": "Supino Reto com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Puxada Frontal Pegada Neutra", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75},
            {"name": "Prancha Isométrica", "sets": 3, "reps": "45s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Desenvolvimento Militar com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Remada Baixa no Triângulo", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}
        ]
    },

    # --- 41 a 50: Master, Terceira Idade & Perfis Especiais (56 a 82 anos e diversos) ---
    {
        "full_name": "Roberto Valadão",
        "gender": "male",
        "age": 63,
        "weight_kg": 79.0,
        "height_cm": 172,
        "modality": "Musculação para Longevidade",
        "objective": "Prevenção de Sarcopenia & Manutenção de Massa Magra",
        "experience": "Intermediário",
        "restrictions": "Artrose leve nos dois joelhos. Evitar flexão profunda (>90°) sob carga.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 44,
        "days_inactive": 0,
        "mesocycle_name": "Força Funcional & Densidade Óssea",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Leg Press Horizontal com Apoio Total", "sets": 3, "reps": "12", "rest_seconds": 75},
            {"name": "Puxada Alta Fechada na Polia", "sets": 3, "reps": "10-12", "rest_seconds": 60},
            {"name": "Supino na Máquina com Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Colchonete", "sets": 3, "reps": "12", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Remada Sentada no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Lateral com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Caminhada em Esteira (Velocidade 5.0 km/h)", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Teresa Viana",
        "gender": "female",
        "age": 67,
        "weight_kg": 63.0,
        "height_cm": 158,
        "modality": "Fortalecimento & Equilíbrio Master",
        "objective": "Prevenção de Quedas & Autonomia para Subir Escadas",
        "experience": "Iniciante",
        "restrictions": "Osteoporose no fêmur direito. Proibidos saltos e impactos bruscos.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 26,
        "days_inactive": 1,
        "mesocycle_name": "Equilíbrio & Força Básica",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
        "split_a": [
            {"name": "Sentar e Levantar da Caixa (com Apoio)", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Puxada Frontal com Elástico Resistente", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Equilíbrio Unipodal com Apoio de Barra", "sets": 3, "reps": "20s cada perna", "rest_seconds": 45},
            {"name": "Panturrilha com Apoio na Parede", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Remada Articulada com Apoio Peitoral", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica no Solo com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Passada Curta com Apoio de Mão", "sets": 3, "reps": "10 passos", "rest_seconds": 60},
            {"name": "Alongamento de Cadeia Posterior Suave", "sets": 3, "reps": "30s", "rest_seconds": 30}
        ]
    },
    {
        "full_name": "Vicente Morais",
        "gender": "male",
        "age": 72,
        "weight_kg": 76.0,
        "height_cm": 170,
        "modality": "Musculação Terapêutica Geriátrica",
        "objective": "Preservação da Capacidade Funcional & Vitalidade",
        "experience": "Intermediário",
        "restrictions": "Artrose de quadril bilateral e hipotensão postural. Evitar mudanças bruscas de decúbito.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 35,
        "days_inactive": 0,
        "mesocycle_name": "Autonomia & Estabilidade",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 22000,
        "split_a": [
            {"name": "Leg Press Horizontal com Amplitude Confortável", "sets": 3, "reps": "10", "rest_seconds": 75},
            {"name": "Puxada Alta Sentada na Máquina", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Supino Sentado na Máquina", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Caminhada no Espaldar", "sets": 3, "reps": "20m", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Remada Baixa Sentada no Cabo", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Cadeira Extensora com Peso Leve", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Flexora Suave", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Bicicleta Reclinada Confortável", "sets": 1, "reps": "15 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Maria Luísa Paiva",
        "gender": "female",
        "age": 78,
        "weight_kg": 56.0,
        "height_cm": 155,
        "modality": "Mobilidade & Independência Física",
        "objective": "Manter Independência em Atividades da Vida Diária (AVDs)",
        "experience": "Iniciante",
        "restrictions": "Fragilidade senil e prótese total de quadril esquerdo (colocada há 5 anos).",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 19,
        "days_inactive": 1,
        "mesocycle_name": "Coordenação & Autonomia Geriátrica",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 24000,
        "split_a": [
            {"name": "Levantar da Cadeira com Apoio de Braços", "sets": 3, "reps": "8", "rest_seconds": 75},
            {"name": "Puxada Frontal com Elástico", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Abertura de Braços com Elástico Leve", "sets": 3, "reps": "10", "rest_seconds": 45},
            {"name": "Marcha Estacionária com Apoio de Barra", "sets": 3, "reps": "30s", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Extensão de Joelhos Sentada com Tornozeleira 1kg", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Flexão de Joelhos em Pé com Apoio de Parede", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Elevação de Calcanhares com Apoio", "sets": 3, "reps": "12", "rest_seconds": 45},
            {"name": "Alongamento Cervical e Respiração", "sets": 1, "reps": "10 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Sérgio Botelho",
        "gender": "male",
        "age": 60,
        "weight_kg": 85.0,
        "height_cm": 175,
        "modality": "Musculação & Saúde Metabólica",
        "objective": "Controle de Hipertensão & Ganho de Força nos Braços",
        "experience": "Intermediário",
        "restrictions": "Hipertensão arterial estágio 1. Manter expiração ativa na fase concêntrica (sem Valsalva).",
        "avatar": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face",
        "streak": 25,
        "days_inactive": 2,
        "mesocycle_name": "Adaptação de Força",
        "mesocycle_week": "Semana 4 de 6",
        "days_overdue": 0,
        "amount_cents": 20000,
        "split_a": [
            {"name": "Leg Press 45°", "sets": 3, "reps": "12", "rest_seconds": 75},
            {"name": "Supino Máquina", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Puxada Aberta", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Remada Sentada com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Desenvolvimento com Halteres Leves", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Esteira Caminhada Contínua", "sets": 1, "reps": "20 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Alex Drummond",
        "gender": "non_binary",
        "age": 25,
        "weight_kg": 62.0,
        "height_cm": 171,
        "modality": "Calistenia & Musculação Neutra",
        "objective": "Força Relativa, Equilíbrio Postural & Definição",
        "experience": "Intermediário",
        "restrictions": "Sem restrições.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face",
        "streak": 32,
        "days_inactive": 0,
        "mesocycle_name": "Força Funcional & Core",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Barra Fixa com Apoio de Elástico", "sets": 4, "reps": "8", "rest_seconds": 75},
            {"name": "Flexão de Braço no Solo com Pausa", "sets": 4, "reps": "12", "rest_seconds": 60},
            {"name": "Pistol Squat Adaptado no TRX", "sets": 3, "reps": "8 cada perna", "rest_seconds": 60},
            {"name": "L-Sit Suspenso", "sets": 3, "reps": "15s", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Agachamento com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Remada Invertida na Barra", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Handstand Hold na Parede", "sets": 3, "reps": "30s", "rest_seconds": 60},
            {"name": "Hollow Body Hold (Canoa)", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Morgan Toledo",
        "gender": "non_binary",
        "age": 28,
        "weight_kg": 68.0,
        "height_cm": 173,
        "modality": "Treino Funcional & Mobilidade",
        "objective": "Condicionamento Geral & Alívio de Tensão",
        "experience": "Iniciante",
        "restrictions": "Sem restrições clínicas.",
        "avatar": "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face",
        "streak": 14,
        "days_inactive": 1,
        "mesocycle_name": "Adaptação Anatômica",
        "mesocycle_week": "Semana 2 de 4",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Alta Neutra", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Supino com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Prancha Frontal", "sets": 3, "reps": "30s", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Passada com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60},
            {"name": "Remada Curvada com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Mobilidade Global", "sets": 1, "reps": "15 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Ingrid Becker",
        "gender": "female",
        "age": 37,
        "weight_kg": 60.0,
        "height_cm": 169,
        "modality": "Musculação Estética & Natação",
        "objective": "Definição de Costas e Ombros & Resistência no Nado",
        "experience": "Avançado",
        "restrictions": "Histórico de tendinite no bíceps braquial direito.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 54,
        "days_inactive": 0,
        "mesocycle_name": "Potência & Hipertrofia Miofibrilar",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Puxada Frontal com Barra Pegada Média", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Remada Cavalinho com Apoio", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Face Pull no Cabo", "sets": 4, "reps": "15", "rest_seconds": 45},
            {"name": "Elevação Pélvica com Barra", "sets": 4, "reps": "10-12", "rest_seconds": 75}
        ],
        "split_b": [
            {"name": "Agachamento Frontal no Smith", "sets": 4, "reps": "10", "rest_seconds": 75},
            {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60},
            {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Prancha Lateral com Elevação de Perna", "sets": 3, "reps": "30s cada lado", "rest_seconds": 45}
        ]
    },
    {
        "full_name": "Valéria Dorneles",
        "gender": "female",
        "age": 58,
        "weight_kg": 68.0,
        "height_cm": 161,
        "modality": "Musculação Funcional & Mobilidade",
        "objective": "Fortalecimento para Artrose e Bem-Estar",
        "experience": "Iniciante",
        "restrictions": "Artrose patelofemoral nos joelhos. Movimentos sempre guiados e sem impacto.",
        "avatar": "https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face",
        "streak": 22,
        "days_inactive": 2,
        "mesocycle_name": "Adaptação Funcional",
        "mesocycle_week": "Semana 3 de 6",
        "days_overdue": 0,
        "amount_cents": 19000,
        "split_a": [
            {"name": "Leg Press Horizontal Leve", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Extensora (Últimos 30° apenas)", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Puxada Frontal Fechada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "15", "rest_seconds": 45}
        ],
        "split_b": [
            {"name": "Supino com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Remada Baixa com Barra Romana", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Alongamento Suave de Coluna e Quadris", "sets": 1, "reps": "15 min", "rest_seconds": 0}
        ]
    },
    {
        "full_name": "Cristiano Lourenço",
        "gender": "male",
        "age": 40,
        "weight_kg": 95.0,
        "height_cm": 182,
        "modality": "Powerbuilding & Treino de Força",
        "objective": "Força Máxima & Volume Muscular de Peitoral e Dorsal",
        "experience": "Avançado",
        "restrictions": "Sem restrições.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face",
        "streak": 49,
        "days_inactive": 0,
        "mesocycle_name": "Sobrecarga de Força & Densidade",
        "mesocycle_week": "Semana 5 de 6",
        "days_overdue": 0,
        "amount_cents": 25000,
        "split_a": [
            {"name": "Supino Reto com Barra (Pirâmide)", "sets": 5, "reps": "12-10-8-6-4", "rest_seconds": 120},
            {"name": "Supino Inclinado com Halteres Pesados", "sets": 4, "reps": "8-10", "rest_seconds": 90},
            {"name": "Crucifixo na Polia", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Tríceps Paralelas", "sets": 3, "reps": "10", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Levantamento Terra com Barra", "sets": 4, "reps": "6", "rest_seconds": 120},
            {"name": "Puxada Alta com Triângulo", "sets": 4, "reps": "8-10", "rest_seconds": 75},
            {"name": "Remada Curvada com Barra Pegada Supinada", "sets": 4, "reps": "8", "rest_seconds": 75},
            {"name": "Rosca Direta com Barra Reta", "sets": 3, "reps": "10", "rest_seconds": 60}
        ]
    },
    {
        "full_name": "Gisele Farias",
        "gender": "female",
        "age": 36,
        "weight_kg": 64.0,
        "height_cm": 167,
        "modality": "Pilates Clínico & Força para Hipermobilidade",
        "objective": "Estabilidade Articular & Controle Postural",
        "experience": "Intermediário",
        "restrictions": "Hipermobilidade articular nos ombros e tornozelos. Evitar hiperextensão articular e priorizar ativação isométrica.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face",
        "streak": 15,
        "days_inactive": 1,
        "mesocycle_name": "Estabilização Escapular e Pélvica",
        "mesocycle_week": "Semana 4 de 8",
        "days_overdue": 0,
        "amount_cents": 21000,
        "split_a": [
            {"name": "Fortalecimento de Manguito com Elástico", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Prancha Lateral com Joelho no Solo", "sets": 3, "reps": "30s", "rest_seconds": 45},
            {"name": "Agachamento Isométrico na Parede (Wall Sit)", "sets": 3, "reps": "40s", "rest_seconds": 60},
            {"name": "Remada Neutra com Halteres Controlada", "sets": 3, "reps": "12", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Ponte Unipodal com Estabilização de Pelve", "sets": 3, "reps": "10/lado", "rest_seconds": 45},
            {"name": "Deadbug com Foco em Respiração Diafragmática", "sets": 3, "reps": "10/lado", "rest_seconds": 45},
            {"name": "Farmer Walk com Carga Moderada (Postura Ativa)", "sets": 3, "reps": "30s", "rest_seconds": 60},
            {"name": "Mobilidade Ativa de Tornozelo sem Carga Excessiva", "sets": 2, "reps": "10", "rest_seconds": 30}
        ]
    },
    {
        "full_name": "Otávio Fontes",
        "gender": "male",
        "age": 71,
        "weight_kg": 74.0,
        "height_cm": 173,
        "modality": "Musculação para Terceira Idade & Autonomia",
        "objective": "Preservação de Massa Muscular (Anti-Sarcopenia) e Equilíbrio",
        "experience": "Iniciante",
        "restrictions": "Artrose de quadril leve e histórico de vertigem postural. Evitar movimentos bruscos de cabeça e exercícios livres instáveis.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face",
        "streak": 26,
        "days_inactive": 1,
        "mesocycle_name": "Força e Equilíbrio Sênior",
        "mesocycle_week": "Semana 2 de 6",
        "days_overdue": 0,
        "amount_cents": 18000,
        "split_a": [
            {"name": "Sentar e Levantar da Cadeira com Apoio", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Puxada Baixa Articulada", "sets": 3, "reps": "12", "rest_seconds": 60},
            {"name": "Elevação de Panturrilha no Chão com Apoio", "sets": 3, "reps": "15", "rest_seconds": 45},
            {"name": "Rosca com Halter Sentado", "sets": 3, "reps": "10", "rest_seconds": 60}
        ],
        "split_b": [
            {"name": "Leg Press Horizontal Guiado (Carga Leve)", "sets": 3, "reps": "10", "rest_seconds": 75},
            {"name": "Supino Vertical na Máquina Guiada", "sets": 3, "reps": "10", "rest_seconds": 60},
            {"name": "Caminhada em Linha Reta com Apoio Unipodal Guiado", "sets": 3, "reps": "10 passos", "rest_seconds": 45},
            {"name": "Alongamento Suave de Isquiotibiais Sentado", "sets": 2, "reps": "30s", "rest_seconds": 30}
        ]
    }
]

def main():
    print(f"Total de personas a gerar: {len(RAW_PERSONAS)}")
    assert len(RAW_PERSONAS) == 50, f"Esperado 50 personas, mas tem {len(RAW_PERSONAS)}"

    now = datetime.now(timezone.utc)
    today = date.today()

    sql_statements = []
    sql_statements.append("-- ============================================================================")
    sql_statements.append("-- SEED 50 NOVAS PERSONAS CLÍNICAS E DIVERSAS PARA O MR. COACH")
    sql_statements.append(f"-- Data de Geração: {now.isoformat()}")
    sql_statements.append(f"-- Professor Alvo: {TRAINER_ID} (Mr. Coach / cleudsonx2021@gmail.com)")
    sql_statements.append("-- ============================================================================\n")
    sql_statements.append("BEGIN;\n")

    for i, p in enumerate(RAW_PERSONAS, start=1):
        # Gera IDs determinísticos ou aleatórios
        student_id = str(uuid.uuid4())
        workout_id = str(uuid.uuid4())
        invoice_id = str(uuid.uuid4())
        
        # Telefone único garantido (5511971000001 a 5511971000050)
        phone = f"5511971000{i:03d}"
        
        # Email único padronizado
        clean_name = p["full_name"].lower().replace(" ", ".").replace("ã", "a").replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ç", "c")
        email = f"aluno.{clean_name}.{i}@shaipados.com"

        is_blocked = p["days_overdue"] > 0
        subscription_status = "past_due" if is_blocked else "active"

        if is_blocked:
            due_date = today - timedelta(days=p["days_overdue"])
            valid_until = (now - timedelta(days=p["days_overdue"])).isoformat()
            invoice_status = "pending"
            paid_at = "NULL"
        else:
            due_date = today + timedelta(days=25)
            valid_until = (now + timedelta(days=30)).isoformat()
            invoice_status = "paid"
            paid_at = f"'{ (now - timedelta(days=5)).isoformat() }'"

        days_inactive = p["days_inactive"]
        if days_inactive >= 5:
            alert_msg = f"⚠️ ALERTA DE CHURN: Aluno sem treinar há {days_inactive} dias ({p['mesocycle_name']})"
            daily_prog = 0.25
        else:
            alert_msg = f"✅ Treino em dia ({p['mesocycle_name']} - {p['mesocycle_week']})"
            daily_prog = 0.95

        status_msg = f"Mesociclo: {p['mesocycle_name']} ({p['mesocycle_week']}) | Inativo há {days_inactive} dias"

        plan_json = {
            "splits": [
                {
                    "split_identifier": "A",
                    "split_name": f"{p['modality']} Split A",
                    "exercises": p["split_a"]
                },
                {
                    "split_identifier": "B",
                    "split_name": f"{p['modality']} Split B",
                    "exercises": p["split_b"]
                }
            ]
        }
        plan_json_str = json.dumps(plan_json, ensure_ascii=False).replace("'", "''")

        app_meta = json.dumps({"provider": "email", "providers": ["email"]}).replace("'", "''")
        user_meta = json.dumps({
            "full_name": p["full_name"],
            "role": "client",
            "roles": ["client"],
            "phone": phone
        }, ensure_ascii=False).replace("'", "''")

        full_name_escaped = p["full_name"].replace("'", "''")
        objective_escaped = p["objective"].replace("'", "''")
        restrictions_escaped = p["restrictions"].replace("'", "''")
        modality_escaped = p["modality"].replace("'", "''")
        mesocycle_escaped = p["mesocycle_name"].replace("'", "''")
        status_msg_escaped = status_msg.replace("'", "''")
        alert_msg_escaped = alert_msg.replace("'", "''")

        # 1. Inserção em auth.users
        sql_statements.append(f"""
-- [{i}/50] {p['full_name']}
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '{student_id}', 'authenticated', 'authenticated', '{email}',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{app_meta}'::jsonb, '{user_meta}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;
""")

        # 2. Inserção / Upsert em profiles
        sql_statements.append(f"""
INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '{student_id}', 'client', ARRAY['client'], '{full_name_escaped}', '{email}', '{phone}', '{TRAINER_ID}',
    '{subscription_status}', '{valid_until}'::timestamptz, '{p['avatar']}', '{p['avatar']}',
    {p['streak']}, {daily_prog}, {p['age']}, {p['weight_kg']}, {p['height_cm']},
    '{restrictions_escaped}', true, '{status_msg_escaped}', '{alert_msg_escaped}',
    false, false, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    role = 'client',
    roles = ARRAY['client'],
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    trainer_id = EXCLUDED.trainer_id,
    subscription_status = EXCLUDED.subscription_status,
    subscription_valid_until = EXCLUDED.subscription_valid_until,
    avatar_url = EXCLUDED.avatar_url,
    photo_url = EXCLUDED.photo_url,
    current_streak = EXCLUDED.current_streak,
    daily_goal_progress = EXCLUDED.daily_goal_progress,
    age = EXCLUDED.age,
    weight_kg = EXCLUDED.weight_kg,
    height_cm = EXCLUDED.height_cm,
    clinical_restrictions = EXCLUDED.clinical_restrictions,
    has_completed_anamnesis = true,
    status_message = EXCLUDED.status_message,
    alert_message = EXCLUDED.alert_message,
    updated_at = now();
""")

        # 3. Anamnese
        anamnesis_id = str(uuid.uuid4())
        sql_statements.append(f"""
INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '{anamnesis_id}', '{student_id}', '{TRAINER_ID}', '{objective_escaped}', '{p['experience']}', 4,
    'Academia Convencional', '{restrictions_escaped}', '{modality_escaped}', '{p['gender']}',
    {p['age']}, {p['weight_kg']}, {p['height_cm']}, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    '{p['experience']} em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();
""")

        # 4. Ficha de Treino em workouts
        workout_title = f"Ficha {p['mesocycle_name']} ({p['mesocycle_week']}) — {p['modality']}".replace("'", "''")
        sql_statements.append(f"""
INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '{workout_id}', '{student_id}', '{TRAINER_ID}', '{workout_title}',
    'Mesociclo: {mesocycle_escaped} ({p['mesocycle_week']}). Restrições: {restrictions_escaped}',
    '{plan_json_str}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();
""")

        # 5. Sessão de Treino Concluída correspondente à inatividade
        session_date = now - timedelta(days=days_inactive)
        session_id = str(uuid.uuid4())
        sql_statements.append(f"""
INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '{session_id}', '{student_id}', '{TRAINER_ID}', '{workout_id}',
    'A', '{modality_escaped} Split A', 4, 4,
    '{ (session_date - timedelta(minutes=50)).isoformat() }'::timestamptz,
    '{ session_date.isoformat() }'::timestamptz,
    3000, '{ session_date.isoformat() }'::timestamptz
) ON CONFLICT (id) DO NOTHING;
""")

        # 6. Fatura / Mensalidade em student_invoices
        fee_cents = int(p["amount_cents"] * 0.05)
        net_cents = p["amount_cents"] - fee_cents
        payment_link = f"https://shaipados.com/pay/{invoice_id}"
        simulated_pix = (
            f"00020126580014br.gov.bcb.pix0136{invoice_id}520400005303986"
            f"540{p['amount_cents']/100:.2f}5802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304"
        )
        sql_statements.append(f"""
INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '{invoice_id}', '{TRAINER_ID}', '{student_id}', '{full_name_escaped}', '{phone}', '{email}',
    'Consultoria Mensal: {modality_escaped}', 'Ciclo individualizado 30 dias. Mesociclo: {mesocycle_escaped} ({p['mesocycle_week']})',
    {p['amount_cents']}, {fee_cents}, {net_cents},
    '{invoice_status}', '{due_date.strftime("%Y-%m-%d")}', {paid_at}, 'pix',
    '{payment_link}', '{simulated_pix}', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;
""")

    sql_statements.append("COMMIT;\n")

    sql_file = "backend/scripts/seed_50_new_personas.sql"
    with open(sql_file, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_statements))

    print(f"Sucesso! Arquivo '{sql_file}' gerado com {len(RAW_PERSONAS)} personas prontas para inserção.")

if __name__ == "__main__":
    main()
