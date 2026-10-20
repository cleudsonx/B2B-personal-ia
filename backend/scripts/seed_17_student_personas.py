# backend/scripts/seed_17_student_personas.py
# FASE 6: Injeção de 17 Personas de Alunos com perfis clínicos completos,
# streaks de 28-29 dias, simulação de vencimento de mensalidade e bloqueio.

import asyncio
import uuid
import random
import unicodedata
from datetime import datetime, date, timedelta, timezone
from app.services.supabase_service import supabase_service

TRAINER_ID = "6f645308-f1b2-4d73-ac45-9890c27e20d4"  # Cleudson Cavalcante (mrcoach)

def slugify(text: str) -> str:
    nfkd = unicodedata.normalize('NFKD', text)
    clean = "".join([c for c in nfkd if not unicodedata.combining(c)])
    return "".join(c.lower() if c.isalnum() else "." for c in clean).strip(".")

PERSONAS = [
    # GRUPO 1: 5 Alunos Adultos Acima do Peso (Emagrecimento / Reeducação)
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
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
        "amount_cents": 17000,
    },

    # GRUPO 2: 4 Alunos Jovens entre 16 e 30 anos
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
        "days_overdue": 0,  # Vence hoje
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
        "days_overdue": 2,  # Vencida há 2 dias -> BLOQUEADO
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
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
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
        "days_overdue": 0,  # Vence hoje
        "amount_cents": 17500,
    },

    # GRUPO 3: 5 Alunos Abaixo do Peso Ideal (Ectomorfos / Bulking / Sarcopenia)
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
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
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
        "days_overdue": 0,  # Vence hoje
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
        "days_overdue": 2,  # Vencida há 2 dias -> BLOQUEADO
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
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
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
        "days_overdue": 0,  # Vence hoje
        "amount_cents": 14000,
    },

    # GRUPO 4: 3 Alunos Idosos acima de 60 anos
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
        "days_overdue": 1,  # Vencida ontem -> BLOQUEADO
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
        "days_overdue": 0,  # Vence hoje
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
        "days_overdue": 2,  # Vencida há 2 dias -> BLOQUEADO
        "amount_cents": 22000,
    },
]


async def seed():
    print("Iniciando injecao de 17 Personas de Alunos no Mr. Coach...")
    client = await supabase_service.get_client()
    if not client:
        print("Erro: Nao foi possivel obter o cliente Supabase.")
        return

    # 1. Garante que o treinador tem plano STUDIO (cota de 100 alunos) para não bater no limite
    try:
        await client.table("subscriptions").update({
            "plan_id": "studio",
            "status": "active"
        }).eq("trainer_id", TRAINER_ID).execute()
        print("Plano do treinador garantido como STUDIO (Cota: 100 alunos).")
    except Exception as e:
        print(f"Aviso ao atualizar assinatura do treinador: {e}")

    now = datetime.now(timezone.utc)
    today = date.today()

    inserted_count = 0
    blocked_count = 0
    warning_count = 0

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
            due_date = today  # Vence hoje!
            valid_until = (now + timedelta(hours=12)).isoformat()

        # 1. Cria usuário no Auth do Supabase com bypass seguro via role trainer temporário
        try:
            # Primeiro verifica se o usuário já existe
            auth_user = None
            try:
                auth_user = await client.auth.admin.create_user({
                    "email": email,
                    "password": "AlunoMrCoach2026!",
                    "email_confirm": True,
                    "user_metadata": {
                        "full_name": p["full_name"],
                        "role": "trainer",
                        "phone": clean_phone
                    }
                })
            except Exception as e:
                # Se já existir, busca usuário
                print(f"Aviso ao criar auth user {email}: {e}")

            student_id = auth_user.user.id if (auth_user and auth_user.user) else None
            if not student_id:
                # Tenta buscar pelo email existente no profiles
                exist = await client.table("profiles").select("id").eq("phone", clean_phone).maybe_single().execute()
                student_id = (exist.data or {}).get("id") if exist else None

            if not student_id:
                print(f"Pula {p['full_name']} (sem student_id)")
                continue

            # 2. Atualiza o Profile para role 'client', vinculado ao treinador
            profile_update = {
                "role": "client",
                "full_name": p["full_name"],
                "phone": clean_phone,
                "trainer_id": TRAINER_ID,
                "subscription_status": subscription_status,
                "subscription_valid_until": valid_until,
                "avatar_url": p["avatar"],
                "photo_url": p["avatar"],
                "current_streak": p["streak"],
                "daily_goal_progress": 0.95,
                "age": p["age"],
                "weight_kg": p["weight_kg"],
                "height_cm": p["height_cm"],
                "clinical_restrictions": p["restrictions"],
                "has_completed_anamnesis": True,
                "status_message": f"Treino ativo: {p['modality']} | Streak: {p['streak']} dias",
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
                "daily_activity": "Moderada",
                "sleep_hours": "7 a 8 horas",
                "stress_level": "Medio",
                "training_history": f"{p['experience']} em musculacao/treino fisico.",
                "available_equipment": "Halteres, Maquinas, Barras e Polias",
                "details": f"Aluno cadastrado na simulacao do ecossistema. Modalidade foco: {p['modality']}."
            }
            try:
                await client.table("anamnesis").upsert(anamnesis_record, on_conflict="client_id").execute()
            except Exception as e:
                # Se não der upsert direto, tenta insert simples
                try:
                    await client.table("anamnesis").insert(anamnesis_record).execute()
                except Exception:
                    pass

            # 4. Ficha de Treino Personalizada em WORKOUTS
            workout_record = {
                "client_id": student_id,
                "trainer_id": TRAINER_ID,
                "title": f"Ficha {p['modality']} — {p['objective'].split('&')[0].strip()}",
                "notes_for_trainer": f"Restricoes clinicas: {p['restrictions']}",
                "is_active": True,
                "plan_json": {
                    "splits": [
                        {
                            "split_identifier": "A",
                            "split_name": f"{p['modality']} Split A (Principal)",
                            "exercises": [
                                {"name": "Aquecimento e Mobilidade Articular", "sets": 2, "reps": "15", "rest_seconds": 45},
                                {"name": "Supino com Halteres (Pegada Neutra)", "sets": 3, "reps": "10-12", "rest_seconds": 60},
                                {"name": "Puxada Frontal na Polia", "sets": 3, "reps": "12", "rest_seconds": 60},
                                {"name": "Leg Press 45 Guiado", "sets": 3, "reps": "12", "rest_seconds": 90},
                            ]
                        },
                        {
                            "split_identifier": "B",
                            "split_name": f"{p['modality']} Split B (Secundario)",
                            "exercises": [
                                {"name": "Elevacao Pelvica com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60},
                                {"name": "Remada Baixa Sentada", "sets": 3, "reps": "10", "rest_seconds": 60},
                                {"name": "Prancha Isometrica Adaptada", "sets": 3, "reps": "30s", "rest_seconds": 45},
                            ]
                        }
                    ]
                }
            }
            try:
                await client.table("workouts").insert(workout_record).execute()
            except Exception as e:
                pass

            # 5. Fatura / Cobrança na tabela STUDENT_INVOICES
            inv_id = str(uuid.uuid4())
            fee_cents = int(p["amount_cents"] * 0.05)
            net_cents = p["amount_cents"] - fee_cents
            payment_link = f"https://shaipados-labs.web.app/pay/{inv_id}"
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
                "description": f"Ciclo de 30 dias de acompanhamento individualizado. Foco: {p['objective']}",
                "amount_cents": p["amount_cents"],
                "platform_fee_cents": fee_cents,
                "net_amount_cents": net_cents,
                "status": "pending",
                "due_date": due_date.strftime("%Y-%m-%d"),
                "paid_at": None,
                "payment_method": "pix",
                "payment_link": payment_link,
                "pix_copy_paste": simulated_pix,
            }
            try:
                await client.table("student_invoices").insert(invoice_record).execute()
            except Exception as e:
                print(f"Aviso fatura {p['full_name']}: {e}")

            inserted_count += 1
            status_tag = "BLOQUEADO (Vencida)" if is_blocked else "VENCE HOJE (Aviso)"
            print(f"[{idx}/17] OK -> {p['full_name']} ({p['group']}, {p['age']}a, {p['weight_kg']}kg, {p['streak']} dias) -> {status_tag}")

        except Exception as e:
            print(f"Erro em {p['full_name']}: {e}")

    print("\n" + "="*70)
    print("Finalizado com Sucesso!")
    print(f"Total de alunos inseridos: {inserted_count}/17")
    print(f"Alunos com acesso BLOQUEADO (past_due): {blocked_count}")
    print(f"Alunos com fatura VENCENDO HOJE: {warning_count}")
    print("="*70)


if __name__ == "__main__":
    asyncio.run(seed())
