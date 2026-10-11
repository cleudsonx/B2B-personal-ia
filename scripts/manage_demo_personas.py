"""
Script para Gerenciamento de Personas de Demonstração / Testes
Professor: Cleudson Cavalcante (cleudsonx2021@gmail.com)

Cria 10 personas completas com:
- auth.users (ID único, metadados)
- public.profiles (nome, idade, peso, altura, foto de perfil, restrições clínicas, streak, progresso diário, etc.)
- public.anamnesis (objetivo, nível de treino, dias/semana, restrições e notas)
- public.workouts (ficha estruturada e ativa com splits e exercícios biomecânicos)
- public.workout_sessions (histórico para gamificação e streaks reais)
"""

import os
import sys
import uuid
from datetime import datetime, timezone, timedelta
from dotenv import load_dotenv

# Carrega variáveis de ambiente
load_dotenv(".env")
load_dotenv("backend/.env")

from supabase import create_client

SUPABASE_URL = os.getenv("SUPABASE_URL", "https://rgbyfiulomxpqkuufdtg.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_KEY")

if not SUPABASE_KEY:
    print("ERRO: SUPABASE_SECRET_KEY ou SUPABASE_KEY não encontrada no .env")
    sys.exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

TARGET_TRAINER_EMAIL = "cleudsonx2021@gmail.com"

# Definição das 10 Personas Ricas e Diversas
STUDENT_PERSONAS = [
    {
        "full_name": "Lucas Andrade",
        "email": "demo.lucas.andrade@shaipados.com",
        "phone": "61991234001",
        "age": 28,
        "weight_kg": 78.5,
        "height_cm": 178,
        "photo_url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80",
        "objective": "Hipertrofia Muscular e Ganho de Força",
        "training_level": "Intermediário",
        "days_per_week": 5,
        "workout_location": "Academia Completa (Musculação)",
        "clinical_restrictions": "Nenhuma",
        "current_streak": 14,
        "daily_goal_progress": 1.0,
        "workout_title": "Ficha ABCDE - Hipertrofia & Força Biomecânica",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Peitoral & Tríceps (Ênfase Clavicular)",
                "estimated_duration_min": 50,
                "exercises": [
                    {"order": 1, "name": "Supino Inclinado com Halteres (30°)", "target_muscle_group": "Peitoral Maior (Porção Clavicular)", "sets": 4, "reps": "8-10", "rest_seconds": 90, "notes": "Escápulas aduzidas e deprimidas; cadência controlada na fase excêntrica.", "substitution_vector": "Empurrar horizontal inclinado"},
                    {"order": 2, "name": "Supino Reto com Barra", "target_muscle_group": "Peitoral Maior (Esternocostal)", "sets": 4, "reps": "8-10", "rest_seconds": 90, "notes": "Pegada ligeiramente maior que a largura dos ombros; toque suave no esterno.", "substitution_vector": "Empurrar horizontal livre"},
                    {"order": 3, "name": "Crucifixo na Polia Média", "target_muscle_group": "Peitoral Maior", "sets": 3, "reps": "12-15", "rest_seconds": 60, "notes": "Pico de contração de 1s no centro de adução.", "substitution_vector": "Adução horizontal na máquina"},
                    {"order": 4, "name": "Tríceps Polia com Barra V", "target_muscle_group": "Tríceps Braquial", "sets": 4, "reps": "10-12", "rest_seconds": 60, "notes": "Cotovelos colados ao tronco; extensão completa sem projetar ombros.", "substitution_vector": "Extensão de cotovelos na polia"},
                ]
            },
            {
                "split_identifier": "B",
                "split_name": "Dorsal & Bíceps (Largura e Densidade)",
                "estimated_duration_min": 50,
                "exercises": [
                    {"order": 1, "name": "Puxada Frontal Aberta", "target_muscle_group": "Latíssimo do Dorso", "sets": 4, "reps": "10-12", "rest_seconds": 90, "notes": "Tração guiada pelos cotovelos; sem retroversão lombar excessiva.", "substitution_vector": "Tracionar vertical"},
                    {"order": 2, "name": "Remada Curvada com Barra", "target_muscle_group": "Rombóides e Latíssimo", "sets": 4, "reps": "8-10", "rest_seconds": 90, "notes": "Coluna neutra a 45°; barra puxada na direção do umbigo.", "substitution_vector": "Remada horizontal livre"},
                    {"order": 3, "name": "Rosca Direta com Barra W", "target_muscle_group": "Bíceps Braquial", "sets": 4, "reps": "10-12", "rest_seconds": 60, "notes": "Sem embalo do tronco; amplitude articular completa.", "substitution_vector": "Flexão de cotovelos livre"},
                ]
            }
        ]
    },
    {
        "full_name": "Mariana Souza",
        "email": "demo.mariana.souza@shaipados.com",
        "phone": "61992345002",
        "age": 32,
        "weight_kg": 62.0,
        "height_cm": 165,
        "photo_url": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80",
        "objective": "Emagrecimento e Definição Muscular",
        "training_level": "Intermediário",
        "days_per_week": 4,
        "workout_location": "Academia Completa (Musculação)",
        "clinical_restrictions": "Condromalácia (Joelho)",
        "current_streak": 8,
        "daily_goal_progress": 0.85,
        "workout_title": "Ficha AB - Densidade Metabólica & Proteção Femoropatelar",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Membros Inferiores (Ênfase Isquiotibiais e Glúteo)",
                "estimated_duration_min": 45,
                "exercises": [
                    {"order": 1, "name": "Elevação Pélvica com Barra", "target_muscle_group": "Glúteo Máximo", "sets": 4, "reps": "10-12", "rest_seconds": 75, "notes": "Isometria de 2s no topo; vetor vertical com proteção patelar.", "substitution_vector": "Extensão de quadril em ponte"},
                    {"order": 2, "name": "Mesa Flexora", "target_muscle_group": "Isquiotibiais", "sets": 4, "reps": "12-15", "rest_seconds": 60, "notes": "Pelve apoiada no banco; cadência 3s excêntrica.", "substitution_vector": "Flexão de joelhos na máquina"},
                    {"order": 3, "name": "Leg Press 45° (Pés Altos)", "target_muscle_group": "Quadríceps e Glúteo", "sets": 4, "reps": "12", "rest_seconds": 75, "notes": "Ângulo do joelho até 90° para não sobrecarregar a patela.", "substitution_vector": "Pressão de pernas com proteção articular"},
                ]
            }
        ]
    },
    {
        "full_name": "Rodrigo Ferreira",
        "email": "demo.rodrigo.ferreira@shaipados.com",
        "phone": "61993456003",
        "age": 45,
        "weight_kg": 86.0,
        "height_cm": 182,
        "photo_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80",
        "objective": "Saúde, Longevidade e Fortalecimento Postural",
        "training_level": "Iniciante",
        "days_per_week": 3,
        "workout_location": "Academia Completa",
        "clinical_restrictions": "Hérnia de Disco",
        "current_streak": 5,
        "daily_goal_progress": 0.75,
        "workout_title": "Ficha Full Body - Descompressão Axial & Estabilidade de Core",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Full Body Funcional e Estabilização Lombar",
                "estimated_duration_min": 45,
                "exercises": [
                    {"order": 1, "name": "Prancha Isométrica com Apoio", "target_muscle_group": "Core / Transverso do Abdômen", "sets": 3, "reps": "30s", "rest_seconds": 45, "notes": "Ativação do abdômen sem hiperextensão lombar.", "substitution_vector": "Estabilidade estática de core"},
                    {"order": 2, "name": "Puxada Alta Articulada", "target_muscle_group": "Dorsal e Cintura Escapular", "sets": 3, "reps": "12-15", "rest_seconds": 60, "notes": "Tronco ereto apoiado no encosto; zero compressão na coluna.", "substitution_vector": "Puxada vertical guiada"},
                    {"order": 3, "name": "Leg Press Horizontal", "target_muscle_group": "Membros Inferiores", "sets": 3, "reps": "12", "rest_seconds": 75, "notes": "Costas 100% estabilizadas no encosto ergonômico.", "substitution_vector": "Pressão de pernas horizontal"},
                ]
            }
        ]
    },
    {
        "full_name": "Camila Ribeiro",
        "email": "demo.camila.ribeiro@shaipados.com",
        "phone": "61994567004",
        "age": 26,
        "weight_kg": 58.5,
        "height_cm": 168,
        "photo_url": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80",
        "objective": "Hipertrofia de Glúteos e Membros Inferiores",
        "training_level": "Avançado",
        "days_per_week": 5,
        "workout_location": "Academia Completa (Musculação)",
        "clinical_restrictions": "Nenhuma",
        "current_streak": 21,
        "daily_goal_progress": 1.0,
        "workout_title": "Ficha Especializada - Glúteos Máximo/Médio & Cadeia Posterior",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Glúteos & Isquiotibiais em Alta Intensidade",
                "estimated_duration_min": 55,
                "exercises": [
                    {"order": 1, "name": "Elevação Pélvica Pesada", "target_muscle_group": "Glúteo Máximo", "sets": 5, "reps": "8-10", "rest_seconds": 90, "notes": "Pausa de 2s no ponto de maior encurtamento muscular.", "substitution_vector": "Extensão de quadril em ponte"},
                    {"order": 2, "name": "Stiff com Halteres", "target_muscle_group": "Cadeia Posterior", "sets": 4, "reps": "10-12", "rest_seconds": 75, "notes": "Joelhos semiflexionados; ênfase no alongamento excêntrico.", "substitution_vector": "Flexão de quadril com barra"},
                    {"order": 3, "name": "Cadeira Abdutora (Tronco Inclinado)", "target_muscle_group": "Glúteo Médio", "sets": 4, "reps": "15-20", "rest_seconds": 45, "notes": "Tronco à frente a 45° para maior recrutamento do feixe superior.", "substitution_vector": "Abdução de quadril na máquina"},
                ]
            }
        ]
    },
    {
        "full_name": "Bruno Mendes",
        "email": "demo.bruno.mendes@shaipados.com",
        "phone": "61995678005",
        "age": 35,
        "weight_kg": 92.0,
        "height_cm": 175,
        "photo_url": "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80",
        "objective": "Recomposição Corporal e Força",
        "training_level": "Intermediário",
        "days_per_week": 4,
        "workout_location": "Academia Completa",
        "clinical_restrictions": "Manguito Rotador (Ombro)",
        "current_streak": 11,
        "daily_goal_progress": 0.9,
        "workout_title": "Ficha Upper/Lower - Adaptação Escapular & Hipertrofia",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Superiores (Pegada Neutra & Proteção Subacromial)",
                "estimated_duration_min": 50,
                "exercises": [
                    {"order": 1, "name": "Supino com Halteres Pegada Neutra", "target_muscle_group": "Peitoral Maior", "sets": 4, "reps": "10-12", "rest_seconds": 75, "notes": "Cotovelos a 45° em relação ao tronco; sem impacto articular.", "substitution_vector": "Empurrar horizontal neutro"},
                    {"order": 2, "name": "Remada Baixa com Triângulo", "target_muscle_group": "Dorsal e Rombóides", "sets": 4, "reps": "10-12", "rest_seconds": 60, "notes": "Depressão escapular ativa; ombros longe das orelhas.", "substitution_vector": "Remada horizontal na polia"},
                ]
            }
        ]
    },
    {
        "full_name": "Juliana Castro",
        "email": "demo.juliana.castro@shaipados.com",
        "phone": "61996789006",
        "age": 29,
        "weight_kg": 54.0,
        "height_cm": 160,
        "photo_url": "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80",
        "objective": "Condicionamento Físico, Postura e Tonificação",
        "training_level": "Intermediário",
        "days_per_week": 4,
        "workout_location": "Academia Completa",
        "clinical_restrictions": "Nenhuma",
        "current_streak": 16,
        "daily_goal_progress": 1.0,
        "workout_title": "Ficha ABC - Tonificação Global & Eficiência Metabólica",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Quadríceps e Abdômen",
                "estimated_duration_min": 45,
                "exercises": [
                    {"order": 1, "name": "Agachamento Búlgaro com Halteres", "target_muscle_group": "Quadríceps e Glúteo", "sets": 4, "reps": "10-12", "rest_seconds": 60, "notes": "Tronco levemente inclinado para frente; controle unilateral.", "substitution_vector": "Afundo unilateral livre"},
                    {"order": 2, "name": "Cadeira Extensora", "target_muscle_group": "Reto Femoral", "sets": 4, "reps": "12-15", "rest_seconds": 45, "notes": "Ponto de contração máxima de 1s no topo.", "substitution_vector": "Extensão de joelhos em máquina"},
                ]
            }
        ]
    },
    {
        "full_name": "Gabriel Tavares",
        "email": "demo.gabriel.tavares@shaipados.com",
        "phone": "61997890107",
        "age": 23,
        "weight_kg": 70.0,
        "height_cm": 176,
        "photo_url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80",
        "objective": "Ganho de Massa Muscular Bruta (Bulking Limpo)",
        "training_level": "Iniciante",
        "days_per_week": 4,
        "workout_location": "Academia Completa (Musculação)",
        "clinical_restrictions": "Nenhuma",
        "current_streak": 6,
        "daily_goal_progress": 0.7,
        "workout_title": "Ficha AB - Aprendizado Motor e Hipertrofia Básica",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Peitoral, Deltoide Anterior e Tríceps",
                "estimated_duration_min": 45,
                "exercises": [
                    {"order": 1, "name": "Supino Reto na Máquina Guiada", "target_muscle_group": "Peitoral Maior", "sets": 4, "reps": "10-12", "rest_seconds": 75, "notes": "Foco na conexão mente-músculo; trajetórias guiadas e seguras.", "substitution_vector": "Empurrar horizontal na máquina"},
                    {"order": 2, "name": "Desenvolvimento com Halteres", "target_muscle_group": "Deltoide Anterior/Médio", "sets": 3, "reps": "10-12", "rest_seconds": 60, "notes": "Banco a 75°; sem projetar a cabeça à frente.", "substitution_vector": "Desenvolvimento de ombros livre"},
                ]
            }
        ]
    },
    {
        "full_name": "Fernanda Lima",
        "email": "demo.fernanda.lima@shaipados.com",
        "phone": "61998901208",
        "age": 38,
        "weight_kg": 67.5,
        "height_cm": 170,
        "photo_url": "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=400&q=80",
        "objective": "Emagrecimento, Fortalecimento Lombar & Saúde",
        "training_level": "Intermediário",
        "days_per_week": 3,
        "workout_location": "Academia Completa",
        "clinical_restrictions": "Dor Lombar",
        "current_streak": 4,
        "daily_goal_progress": 0.6,
        "workout_title": "Ficha Circuito Metabólico - Descompressão e Estabilidade",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Circuito Resistido Metabólico",
                "estimated_duration_min": 40,
                "exercises": [
                    {"order": 1, "name": "Ponte de Glúteo no Solo", "target_muscle_group": "Glúteos e Lombar", "sets": 3, "reps": "15", "rest_seconds": 45, "notes": "Ativação do períneo e transverso do abdômen.", "substitution_vector": "Ponte solo funcional"},
                    {"order": 2, "name": "Puxada Neutra no Pulley", "target_muscle_group": "Dorsal e Bíceps", "sets": 3, "reps": "12", "rest_seconds": 45, "notes": "Manter postura ereta sem balançar o tronco.", "substitution_vector": "Puxada vertical com pegada neutra"},
                ]
            }
        ]
    },
    {
        "full_name": "Thiago Martins",
        "email": "demo.thiago.martins@shaipados.com",
        "phone": "61999012309",
        "age": 41,
        "weight_kg": 81.0,
        "height_cm": 179,
        "photo_url": "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=400&q=80",
        "objective": "Alta Performance, Força e Redução de Estresse",
        "training_level": "Avançado",
        "days_per_week": 5,
        "workout_location": "Academia Completa (Musculação)",
        "clinical_restrictions": "Cotovelo / Tendinopatia",
        "current_streak": 19,
        "daily_goal_progress": 1.0,
        "workout_title": "Ficha Push/Pull/Legs - Eficiência Articular e Alta Carga",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Push (Empurrar com Pegadas Neutras/Articuladas)",
                "estimated_duration_min": 50,
                "exercises": [
                    {"order": 1, "name": "Supino Inclinado na Máquina Articulada", "target_muscle_group": "Peitoral Maior", "sets": 4, "reps": "8-10", "rest_seconds": 90, "notes": "Pegada neutra para alívio dos tendões dos epicôndilos.", "substitution_vector": "Supino inclinado articulado"},
                    {"order": 2, "name": "Elevação Lateral na Polia", "target_muscle_group": "Deltoide Lateral", "sets": 4, "reps": "12-15", "rest_seconds": 45, "notes": "Cabo passando por trás do tronco com tensão contínua.", "substitution_vector": "Abdução de ombro na polia"},
                ]
            }
        ]
    },
    {
        "full_name": "Beatriz Alencar",
        "email": "demo.beatriz.alencar@shaipados.com",
        "phone": "61990123410",
        "age": 27,
        "weight_kg": 60.0,
        "height_cm": 163,
        "photo_url": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80",
        "objective": "Preparação Física Geral, Definição e Mobilidade",
        "training_level": "Intermediário",
        "days_per_week": 4,
        "workout_location": "Academia Completa",
        "clinical_restrictions": "Nenhuma",
        "current_streak": 10,
        "daily_goal_progress": 0.85,
        "workout_title": "Ficha ABC - Definição Estética e Isometrias",
        "splits": [
            {
                "split_identifier": "A",
                "split_name": "Membros Inferiores Global e Panturrilha",
                "estimated_duration_min": 48,
                "exercises": [
                    {"order": 1, "name": "Agachamento Livre com Barra", "target_muscle_group": "Quadríceps e Glúteos", "sets": 4, "reps": "10-12", "rest_seconds": 90, "notes": "Base na largura do quadril; respiração diafragmática para travar core.", "substitution_vector": "Agachamento livre com peso corporal ou carga"},
                    {"order": 2, "name": "Gêmeos Sentado (Cadeira de Sóleo)", "target_muscle_group": "Sóleo / Panturrilha", "sets": 4, "reps": "15-20", "rest_seconds": 45, "notes": "Alongamento completo na fase excêntrica.", "substitution_vector": "Flexão plantar sentado na máquina"},
                ]
            }
        ]
    }
]

def find_trainer():
    users = supabase.auth.admin.list_users()
    for u in users:
        email = (u.email or "").lower()
        if "cleudsonx2021" in email:
            print(f"Treinador encontrado: {u.email} (ID: {u.id})")
            return u.id
    # Fallback procurando em profiles
    res = supabase.table("profiles").select("*").ilike("phone", "%82912174%").execute()
    if res.data:
        return res.data[0]["id"]
    raise RuntimeError(f"Treinador {TARGET_TRAINER_EMAIL} não encontrado no Supabase.")

def seed():
    trainer_id = find_trainer()
    
    # 1. Garante que o perfil do professor está completo
    supabase.table("profiles").update({
        "full_name": "Cleudson Cavalcante",
        "role": "trainer",
        "subscription_status": "active",
        "professional_document": "CREF 019284-G/DF",
        "public_directory_enabled": True
    }).eq("id", trainer_id).execute()
    print("Perfil do professor Cleudson Cavalcante verificado e atualizado.")

    created_count = 0
    for p in STUDENT_PERSONAS:
        email = p["email"]
        print(f"\nProcessando persona: {p['full_name']} ({email})...")
        
        # Verifica se já existe em auth.users
        users = supabase.auth.admin.list_users()
        user_id = None
        for u in users:
            if (u.email or "").lower() == email.lower():
                user_id = u.id
                break
        
        if not user_id:
            # Cria em auth.users inicialmente com role trainer para contornar a trava de convite público
            temp_pwd = "DemoPersona2026!"
            new_u = supabase.auth.admin.create_user({
                "email": email,
                "password": temp_pwd,
                "email_confirm": True,
                "user_metadata": {
                    "full_name": p["full_name"],
                    "role": "trainer",
                    "phone": p["phone"],
                    "is_demo_persona": True
                }
            })
            user_id = new_u.user.id
            print(f"  -> Criado no auth.users (ID: {user_id})")

            # Atualiza metadados do auth para 'client' vinculado ao professor
            supabase.auth.admin.update_user_by_id(user_id, {
                "user_metadata": {
                    "full_name": p["full_name"],
                    "role": "client",
                    "trainer_id": trainer_id,
                    "phone": p["phone"],
                    "is_demo_persona": True
                }
            })
        else:
            print(f"  -> Já existente no auth.users (ID: {user_id})")

        # 2. Atualiza tabela profiles
        profile_data = {
            "id": user_id,
            "full_name": p["full_name"],
            "role": "client",
            "roles": ["client"],
            "phone": p["phone"],
            "trainer_id": trainer_id,
            "subscription_status": "active",
            "status": "Ativo",
            "photo_url": p["photo_url"],
            "avatar_url": p["photo_url"],
            "age": p["age"],
            "weight_kg": p["weight_kg"],
            "height_cm": p["height_cm"],
            "clinical_restrictions": p["clinical_restrictions"],
            "timezone": "America/Sao_Paulo",
            "has_completed_anamnesis": True,
            "current_streak": p["current_streak"],
            "daily_goal_progress": p["daily_goal_progress"]
        }
        supabase.table("profiles").upsert(profile_data).execute()
        print(f"  -> Perfil populado com foto, idade, peso e altura.")

        # 3. Anamnese
        anamnesis_data = {
            "client_id": user_id,
            "trainer_id": trainer_id,
            "objective": p["objective"],
            "training_level": p["training_level"],
            "days_per_week": p["days_per_week"],
            "workout_location": p["workout_location"],
            "injuries_or_restrictions": p["clinical_restrictions"],
            "additional_notes": f"Persona de demonstração para o Prof. Cleudson Cavalcante. Objetivo principal: {p['objective']}."
        }
        # Deleta anamnese anterior se houver
        supabase.table("anamnesis").delete().eq("client_id", user_id).execute()
        supabase.table("anamnesis").insert(anamnesis_data).execute()
        print(f"  -> Anamnese cadastrada: {p['objective']}.")

        # 4. Ficha de treino ativa (Workouts)
        plan_json = {
            "workout_plan_title": p["workout_title"],
            "notes_for_trainer": f"Prescrição individualizada para {p['full_name']}. Carga progressiva e atenção biomecânica às restrições.",
            "splits": p["splits"]
        }
        workout_data = {
            "client_id": user_id,
            "trainer_id": trainer_id,
            "title": p["workout_title"],
            "notes_for_trainer": f"Ficha prescrita e ativa pelo Prof. Cleudson Cavalcante.",
            "plan_json": plan_json,
            "is_active": True
        }
        # Desativa treinos anteriores
        supabase.table("workouts").update({"is_active": False}).eq("client_id", user_id).execute()
        supabase.table("workouts").insert(workout_data).execute()
        print(f"  -> Ficha de treino ativa criada: {p['workout_title']}.")

        # 5. Sessões de treino (para gamificação / streak)
        today = datetime.now(timezone.utc)
        for d in range(min(p["current_streak"], 7)):
            session_date = (today - timedelta(days=d)).isoformat()
            try:
                supabase.table("workout_sessions").insert({
                    "client_id": user_id,
                    "trainer_id": trainer_id,
                    "total_exercises": 4,
                    "completed_exercises": 4,
                    "completed_at": session_date
                }).execute()
            except Exception:
                pass

        created_count += 1

    print(f"\n==========================================")
    print(f"SUCESSO! {created_count} personas de demonstração criadas e vinculadas ao Prof. Cleudson Cavalcante.")
    print(f"==========================================")

def cleanup():
    print(f"Iniciando exclusão de todas as personas demo de teste...")
    users = supabase.auth.admin.list_users()
    deleted_count = 0
    for u in users:
        email = (u.email or "").lower()
        if email.startswith("demo.") and email.endswith("@shaipados.com"):
            print(f"Removendo persona: {email} (ID: {u.id})...")
            try:
                # Deleta em cascata através de auth.admin.delete_user
                supabase.auth.admin.delete_user(u.id)
                deleted_count += 1
                print(f"  -> Excluído com sucesso.")
            except Exception as e:
                print(f"  -> Erro ao excluir: {e}")
    print(f"\nExclusão concluída: {deleted_count} personas removidas da base.")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--cleanup":
        cleanup()
    else:
        seed()
