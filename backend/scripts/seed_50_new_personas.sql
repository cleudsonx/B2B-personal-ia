-- ============================================================================
-- SEED 50 NOVAS PERSONAS CLÍNICAS E DIVERSAS PARA O MR. COACH
-- Data de Geração: 2026-10-30T15:23:19.946496+00:00
-- Professor Alvo: 6f645308-f1b2-4d73-ac45-9890c27e20d4 (Mr. Coach / cleudsonx2021@gmail.com)
-- ============================================================================

BEGIN;


-- [1/50] Gabriel Meneses
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '98cd9db9-f39a-4e8b-85a6-54f257b6c871', 'authenticated', 'authenticated', 'aluno.gabriel.meneses.1@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Gabriel Meneses", "role": "client", "roles": ["client"], "phone": "5511971000001"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '98cd9db9-f39a-4e8b-85a6-54f257b6c871', 'client', ARRAY['client'], 'Gabriel Meneses', 'aluno.gabriel.meneses.1@shaipados.com', '5511971000001', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=300&fit=crop&crop=face',
    14, 0.95, 17, 64.0, 176,
    'Escoliose postural leve em ''C''. Foco em fortalecimento do core e simetria escapular.', true, 'Mesociclo: Adaptação Anatômica (Semana 2 de 4) | Inativo há 1 dias', '✅ Treino em dia (Adaptação Anatômica - Semana 2 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'aa7a32c9-2e22-410c-89b8-16652fc4c3cb', '98cd9db9-f39a-4e8b-85a6-54f257b6c871', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ganho de Massa Muscular (Hipertrofia Ectomorfo) & Postura', 'Iniciante', 4,
    'Academia Convencional', 'Escoliose postural leve em ''C''. Foco em fortalecimento do core e simetria escapular.', 'Calistenia & Musculação Juvenil', 'male',
    17, 64.0, 176, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '6a228c71-1814-4e0b-a334-e0ccc3768674', '98cd9db9-f39a-4e8b-85a6-54f257b6c871', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Anatômica (Semana 2 de 4) — Calistenia & Musculação Juvenil',
    'Mesociclo: Adaptação Anatômica (Semana 2 de 4). Restrições: Escoliose postural leve em ''C''. Foco em fortalecimento do core e simetria escapular.',
    '{"splits": [{"split_identifier": "A", "split_name": "Calistenia & Musculação Juvenil Split A", "exercises": [{"name": "Puxada Frontal Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10-12", "rest_seconds": 60}, {"name": "Prancha Isométrica", "sets": 3, "reps": "30s", "rest_seconds": 45}, {"name": "Remada Baixa Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Calistenia & Musculação Juvenil Split B", "exercises": [{"name": "Leg Press 45°", "sets": 3, "reps": "12-15", "rest_seconds": 75}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Panturrilha Sentado", "sets": 4, "reps": "15", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '46d9b42f-e542-46f9-9f50-f177b37e66de', '98cd9db9-f39a-4e8b-85a6-54f257b6c871', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '6a228c71-1814-4e0b-a334-e0ccc3768674',
    'A', 'Calistenia & Musculação Juvenil Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '4f6dbef0-8820-48ea-ae29-846dac7cdd9c', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '98cd9db9-f39a-4e8b-85a6-54f257b6c871', 'Gabriel Meneses', '5511971000001', 'aluno.gabriel.meneses.1@shaipados.com',
    'Consultoria Mensal: Calistenia & Musculação Juvenil', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Anatômica (Semana 2 de 4)',
    15000, 750, 14250,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/4f6dbef0-8820-48ea-ae29-846dac7cdd9c', '00020126580014br.gov.bcb.pix01364f6dbef0-8820-48ea-ae29-846dac7cdd9c520400005303986540150.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [2/50] Sofia Bittencourt
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '91d8b7a7-886c-4768-bc37-3c2a492c21ca', 'authenticated', 'authenticated', 'aluno.sofia.bittencourt.2@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Sofia Bittencourt", "role": "client", "roles": ["client"], "phone": "5511971000002"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '91d8b7a7-886c-4768-bc37-3c2a492c21ca', 'client', ARRAY['client'], 'Sofia Bittencourt', 'aluno.sofia.bittencourt.2@shaipados.com', '5511971000002', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face',
    22, 0.95, 19, 53.5, 164,
    'Histórico de entorse de tornozelo grau 1. Exercícios com base instável controlada.', true, 'Mesociclo: Potência & Pliometria (Semana 3 de 6) | Inativo há 0 dias', '✅ Treino em dia (Potência & Pliometria - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'ddd15ee0-8b09-4ada-a536-34f97aad2f64', '91d8b7a7-886c-4768-bc37-3c2a492c21ca', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Potência de Salto Vertical & Prevenção de Lesões', 'Intermediário', 4,
    'Academia Convencional', 'Histórico de entorse de tornozelo grau 1. Exercícios com base instável controlada.', 'Condicionamento & Força para Vôlei', 'female',
    19, 53.5, 164, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '2c2c01e4-f3af-4ea6-a585-f3bb7834b1a2', '91d8b7a7-886c-4768-bc37-3c2a492c21ca', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Potência & Pliometria (Semana 3 de 6) — Condicionamento & Força para Vôlei',
    'Mesociclo: Potência & Pliometria (Semana 3 de 6). Restrições: Histórico de entorse de tornozelo grau 1. Exercícios com base instável controlada.',
    '{"splits": [{"split_identifier": "A", "split_name": "Condicionamento & Força para Vôlei Split A", "exercises": [{"name": "Saltos em Caixa com Aterrissagem Suave", "sets": 4, "reps": "6", "rest_seconds": 90}, {"name": "Agachamento Búlgaro", "sets": 3, "reps": "8-10", "rest_seconds": 75}, {"name": "Hip Thrust com Barra", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Flexão Nórdica Reversa", "sets": 3, "reps": "8", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Condicionamento & Força para Vôlei Split B", "exercises": [{"name": "Desenvolvimento Militar com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Face Pull na Polia", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Rotação Externa de Ombro (Manguito)", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Remada Curvada com Apoio", "sets": 3, "reps": "10", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'f04a97bc-8b2f-4f52-afb0-353724746da2', '91d8b7a7-886c-4768-bc37-3c2a492c21ca', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '2c2c01e4-f3af-4ea6-a585-f3bb7834b1a2',
    'A', 'Condicionamento & Força para Vôlei Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '8ee8f047-fe5a-433d-accc-e105456e1f7f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '91d8b7a7-886c-4768-bc37-3c2a492c21ca', 'Sofia Bittencourt', '5511971000002', 'aluno.sofia.bittencourt.2@shaipados.com',
    'Consultoria Mensal: Condicionamento & Força para Vôlei', 'Ciclo individualizado 30 dias. Mesociclo: Potência & Pliometria (Semana 3 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/8ee8f047-fe5a-433d-accc-e105456e1f7f', '00020126580014br.gov.bcb.pix01368ee8f047-fe5a-433d-accc-e105456e1f7f520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [3/50] Lucas Evangelista
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '849913c0-5724-4ed5-a832-ed093182df95', 'authenticated', 'authenticated', 'aluno.lucas.evangelista.3@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Lucas Evangelista", "role": "client", "roles": ["client"], "phone": "5511971000003"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '849913c0-5724-4ed5-a832-ed093182df95', 'client', ARRAY['client'], 'Lucas Evangelista', 'aluno.lucas.evangelista.3@shaipados.com', '5511971000003', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    35, 0.95, 21, 73.0, 180,
    'Sem restrições articulares. Foco em cadência e resistência cardiorrespiratória.', true, 'Mesociclo: Sobrecarga Específica TAF (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Sobrecarga Específica TAF - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'f1e1eef1-a6d6-44c6-a8fc-4847e342913e', '849913c0-5724-4ed5-a832-ed093182df95', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Aprovação no TAF (Barra Fixa, Corrida 2400m e Abdominal Remador)', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições articulares. Foco em cadência e resistência cardiorrespiratória.', 'Preparação TAF & Resistência Física', 'male',
    21, 73.0, 180, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '444c36fb-2199-485b-a092-c3280f116ca2', '849913c0-5724-4ed5-a832-ed093182df95', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Sobrecarga Específica TAF (Semana 4 de 6) — Preparação TAF & Resistência Física',
    'Mesociclo: Sobrecarga Específica TAF (Semana 4 de 6). Restrições: Sem restrições articulares. Foco em cadência e resistência cardiorrespiratória.',
    '{"splits": [{"split_identifier": "A", "split_name": "Preparação TAF & Resistência Física Split A", "exercises": [{"name": "Barra Fixa Pronada (Padrão TAF)", "sets": 5, "reps": "Falha - 1", "rest_seconds": 90}, {"name": "Abdominal Remador Militar", "sets": 4, "reps": "25-30", "rest_seconds": 60}, {"name": "Flexão de Braço no Solo", "sets": 4, "reps": "20", "rest_seconds": 60}, {"name": "Tiro Intervalado na Esteira (400m)", "sets": 5, "reps": "1m30s", "rest_seconds": 90}]}, {"split_identifier": "B", "split_name": "Preparação TAF & Resistência Física Split B", "exercises": [{"name": "Agachamento Frontal com Barra", "sets": 4, "reps": "10", "rest_seconds": 90}, {"name": "Passada Caminhando", "sets": 3, "reps": "20 passos", "rest_seconds": 60}, {"name": "Puxada Neutra Fechada", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Farmer''s Walk com Halteres Pesados", "sets": 4, "reps": "40m", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'b9d4a959-d8bb-4f27-9c3f-41163878c154', '849913c0-5724-4ed5-a832-ed093182df95', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '444c36fb-2199-485b-a092-c3280f116ca2',
    'A', 'Preparação TAF & Resistência Física Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '919e66a5-d3b7-469b-bdc3-eccd088f0651', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '849913c0-5724-4ed5-a832-ed093182df95', 'Lucas Evangelista', '5511971000003', 'aluno.lucas.evangelista.3@shaipados.com',
    'Consultoria Mensal: Preparação TAF & Resistência Física', 'Ciclo individualizado 30 dias. Mesociclo: Sobrecarga Específica TAF (Semana 4 de 6)',
    22000, 1100, 20900,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/919e66a5-d3b7-469b-bdc3-eccd088f0651', '00020126580014br.gov.bcb.pix0136919e66a5-d3b7-469b-bdc3-eccd088f0651520400005303986540220.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [4/50] Beatriz Dornelles
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '67c03c5f-0dae-43f8-8681-312701dfa080', 'authenticated', 'authenticated', 'aluno.beatriz.dornelles.4@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Beatriz Dornelles", "role": "client", "roles": ["client"], "phone": "5511971000004"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '67c03c5f-0dae-43f8-8681-312701dfa080', 'client', ARRAY['client'], 'Beatriz Dornelles', 'aluno.beatriz.dornelles.4@shaipados.com', '5511971000004', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face',
    42, 0.95, 22, 58.0, 168,
    'Condromalácia patelar grau 1 no joelho esquerdo. Sem agachamento livre até o chão.', true, 'Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 8) | Inativo há 1 dias', '✅ Treino em dia (Hipertrofia Miofibrilar - Semana 5 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '5657df7d-3b42-4323-95df-e89607f8b8d5', '67c03c5f-0dae-43f8-8681-312701dfa080', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Hipertrofia de Quadríceps e Glúteos com Cintura Fina', 'Avançado', 4,
    'Academia Convencional', 'Condromalácia patelar grau 1 no joelho esquerdo. Sem agachamento livre até o chão.', 'Hipertrofia Funcional & Glúteos', 'female',
    22, 58.0, 168, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'fc3d431a-78d8-41d9-a5a4-53a7ab586058', '67c03c5f-0dae-43f8-8681-312701dfa080', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Miofibrilar (Semana 5 de 8) — Hipertrofia Funcional & Glúteos',
    'Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 8). Restrições: Condromalácia patelar grau 1 no joelho esquerdo. Sem agachamento livre até o chão.',
    '{"splits": [{"split_identifier": "A", "split_name": "Hipertrofia Funcional & Glúteos Split A", "exercises": [{"name": "Elevação Pélvica com Barra e Pausa 2s", "sets": 4, "reps": "10", "rest_seconds": 90}, {"name": "Búlgaro com Halteres e Tronco Inclinado", "sets": 3, "reps": "10-12", "rest_seconds": 75}, {"name": "Cadeira Abdutora Inclinada", "sets": 4, "reps": "15+drop", "rest_seconds": 60}, {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75}]}, {"split_identifier": "B", "split_name": "Hipertrofia Funcional & Glúteos Split B", "exercises": [{"name": "Puxador Articulado Aberto", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Lateral na Polia", "sets": 4, "reps": "12-15", "rest_seconds": 45}, {"name": "Tríceps Corda", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Prancha Lateral com Abdução", "sets": 3, "reps": "30s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'ee0d5f33-d2ad-41c8-89ee-d7584ffaefdb', '67c03c5f-0dae-43f8-8681-312701dfa080', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'fc3d431a-78d8-41d9-a5a4-53a7ab586058',
    'A', 'Hipertrofia Funcional & Glúteos Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '73497338-6c8d-485f-a042-b9c053c29a99', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '67c03c5f-0dae-43f8-8681-312701dfa080', 'Beatriz Dornelles', '5511971000004', 'aluno.beatriz.dornelles.4@shaipados.com',
    'Consultoria Mensal: Hipertrofia Funcional & Glúteos', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 8)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/73497338-6c8d-485f-a042-b9c053c29a99', '00020126580014br.gov.bcb.pix013673497338-6c8d-485f-a042-b9c053c29a99520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [5/50] Caio Marcondes
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '4a4db965-5477-46f8-88d3-03556289c7bd', 'authenticated', 'authenticated', 'aluno.caio.marcondes.5@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Caio Marcondes", "role": "client", "roles": ["client"], "phone": "5511971000005"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '4a4db965-5477-46f8-88d3-03556289c7bd', 'client', ARRAY['client'], 'Caio Marcondes', 'aluno.caio.marcondes.5@shaipados.com', '5511971000005', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face',
    50, 0.95, 20, 85.0, 184,
    'Sem restrições. Sobrecarga progressiva monitorada por RPE.', true, 'Mesociclo: Choque / Sobrecarga de Força (Semana 3 de 4) | Inativo há 0 dias', '✅ Treino em dia (Choque / Sobrecarga de Força - Semana 3 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '34c9f59a-befe-4bf9-86b6-c199f963d1af', '4a4db965-5477-46f8-88d3-03556289c7bd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Quebra de PR no Supino e Terra com Hipertrofia', 'Avançado', 4,
    'Academia Convencional', 'Sem restrições. Sobrecarga progressiva monitorada por RPE.', 'Powerbuilding & Força Bruta', 'male',
    20, 85.0, 184, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '4020c3dc-bd75-43d1-9e94-57f4d209e6a5', '4a4db965-5477-46f8-88d3-03556289c7bd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Choque / Sobrecarga de Força (Semana 3 de 4) — Powerbuilding & Força Bruta',
    'Mesociclo: Choque / Sobrecarga de Força (Semana 3 de 4). Restrições: Sem restrições. Sobrecarga progressiva monitorada por RPE.',
    '{"splits": [{"split_identifier": "A", "split_name": "Powerbuilding & Força Bruta Split A", "exercises": [{"name": "Supino Reto com Barra (Pausa 1s no Peito)", "sets": 5, "reps": "5", "rest_seconds": 120}, {"name": "Supino Inclinado com Halteres", "sets": 4, "reps": "8", "rest_seconds": 90}, {"name": "Paralelas com Sobrecarga", "sets": 3, "reps": "8", "rest_seconds": 90}, {"name": "Tríceps Francês na Polia", "sets": 4, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Powerbuilding & Força Bruta Split B", "exercises": [{"name": "Levantamento Terra Convencional", "sets": 5, "reps": "3-5", "rest_seconds": 150}, {"name": "Barra Fixa com Peso Adicional", "sets": 4, "reps": "6", "rest_seconds": 90}, {"name": "Remada Curvada com Barra", "sets": 4, "reps": "8", "rest_seconds": 90}, {"name": "Rosca Direta Barra W", "sets": 3, "reps": "10", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '82e57767-68e0-41c3-9734-f8447a4bbdb2', '4a4db965-5477-46f8-88d3-03556289c7bd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '4020c3dc-bd75-43d1-9e94-57f4d209e6a5',
    'A', 'Powerbuilding & Força Bruta Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '2eb9ddb2-3ce9-40f6-bf7e-4a6f36604ce0', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '4a4db965-5477-46f8-88d3-03556289c7bd', 'Caio Marcondes', '5511971000005', 'aluno.caio.marcondes.5@shaipados.com',
    'Consultoria Mensal: Powerbuilding & Força Bruta', 'Ciclo individualizado 30 dias. Mesociclo: Choque / Sobrecarga de Força (Semana 3 de 4)',
    25000, 1250, 23750,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/2eb9ddb2-3ce9-40f6-bf7e-4a6f36604ce0', '00020126580014br.gov.bcb.pix01362eb9ddb2-3ce9-40f6-bf7e-4a6f36604ce0520400005303986540250.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [6/50] Camila Furtado
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', 'authenticated', 'authenticated', 'aluno.camila.furtado.6@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Camila Furtado", "role": "client", "roles": ["client"], "phone": "5511971000006"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', 'client', ARRAY['client'], 'Camila Furtado', 'aluno.camila.furtado.6@shaipados.com', '5511971000006', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'past_due', '2026-10-28T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face',
    8, 0.25, 21, 62.0, 169,
    'Tendinite patelar no joelho direito. Uso de cargas moderadas e cadência controlada.', true, 'Mesociclo: Adaptação Funcional (Semana 2 de 4) | Inativo há 7 dias', '⚠️ ALERTA DE CHURN: Aluno sem treinar há 7 dias (Adaptação Funcional)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'fe2039d8-ca59-4552-ad20-b8f75e51c748', '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Tonificação Muscular & Ganho de Fôlego', 'Iniciante', 4,
    'Academia Convencional', 'Tendinite patelar no joelho direito. Uso de cargas moderadas e cadência controlada.', 'Treino Funcional Híbrido', 'female',
    21, 62.0, 169, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '1547a4d6-722a-4ca8-9ba9-2051d82e8762', '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Funcional (Semana 2 de 4) — Treino Funcional Híbrido',
    'Mesociclo: Adaptação Funcional (Semana 2 de 4). Restrições: Tendinite patelar no joelho direito. Uso de cargas moderadas e cadência controlada.',
    '{"splits": [{"split_identifier": "A", "split_name": "Treino Funcional Híbrido Split A", "exercises": [{"name": "Leg Press Horizontal Unilateral", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Glúteo no Cabo com Caneleira", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Puxada Articulada Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Prancha Isométrica com Apoio de Joelhos", "sets": 3, "reps": "30s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Treino Funcional Híbrido Split B", "exercises": [{"name": "Supino com Halteres Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Barra Romana", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Passada Curta com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60}, {"name": "Abdominal Supra na Bola Suíça", "sets": 3, "reps": "15", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '5e1c5add-5ea9-4f4a-8376-dabbd3d14bc9', '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '1547a4d6-722a-4ca8-9ba9-2051d82e8762',
    'A', 'Treino Funcional Híbrido Split A', 4, 4,
    '2026-10-23T14:33:19.946496+00:00'::timestamptz,
    '2026-10-23T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-23T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'f72e5e75-a213-4d0b-8876-6f987bfda4ad', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '7f86e75e-f35c-4a2a-a728-141acc6ffb5f', 'Camila Furtado', '5511971000006', 'aluno.camila.furtado.6@shaipados.com',
    'Consultoria Mensal: Treino Funcional Híbrido', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Funcional (Semana 2 de 4)',
    16000, 800, 15200,
    'pending', '2026-10-28', NULL, 'pix',
    'https://shaipados.com/pay/f72e5e75-a213-4d0b-8876-6f987bfda4ad', '00020126580014br.gov.bcb.pix0136f72e5e75-a213-4d0b-8876-6f987bfda4ad520400005303986540160.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [7/50] Henrique Toledo
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a6772d2b-833d-41b5-8c70-3ce44d705894', 'authenticated', 'authenticated', 'aluno.henrique.toledo.7@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Henrique Toledo", "role": "client", "roles": ["client"], "phone": "5511971000007"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'a6772d2b-833d-41b5-8c70-3ce44d705894', 'client', ARRAY['client'], 'Henrique Toledo', 'aluno.henrique.toledo.7@shaipados.com', '5511971000007', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face',
    19, 0.95, 18, 60.5, 179,
    'Magreza constitucional acentuada. Evitar treinos exaustivos acima de 50 minutos.', true, 'Mesociclo: Hipertrofia Básica (Semana 3 de 6) | Inativo há 2 dias', '✅ Treino em dia (Hipertrofia Básica - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'cec61f9e-3c89-49d0-95a8-6b7194516d76', 'a6772d2b-833d-41b5-8c70-3ce44d705894', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Superávit Calórico & Hipertrofia Global (+8kg)', 'Iniciante', 4,
    'Academia Convencional', 'Magreza constitucional acentuada. Evitar treinos exaustivos acima de 50 minutos.', 'Musculação para Ganho de Peso', 'male',
    18, 60.5, 179, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'aa07ba48-5fbe-41ec-8c3f-073c198f50d0', 'a6772d2b-833d-41b5-8c70-3ce44d705894', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Básica (Semana 3 de 6) — Musculação para Ganho de Peso',
    'Mesociclo: Hipertrofia Básica (Semana 3 de 6). Restrições: Magreza constitucional acentuada. Evitar treinos exaustivos acima de 50 minutos.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação para Ganho de Peso Split A", "exercises": [{"name": "Supino Reto na Barra Guiada", "sets": 4, "reps": "8-10", "rest_seconds": 75}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Tríceps Testa com Barra W", "sets": 3, "reps": "10-12", "rest_seconds": 60}, {"name": "Agachamento no Hack Machine", "sets": 4, "reps": "10", "rest_seconds": 90}]}, {"split_identifier": "B", "split_name": "Musculação para Ganho de Peso Split B", "exercises": [{"name": "Puxada Frente na Polia", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Remada Serrote com Halter", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Rosca Scott na Máquina", "sets": 3, "reps": "10-12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 4, "reps": "12", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'ffbf9a8e-f1d6-4262-98a9-ade6bcaf34ef', 'a6772d2b-833d-41b5-8c70-3ce44d705894', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'aa07ba48-5fbe-41ec-8c3f-073c198f50d0',
    'A', 'Musculação para Ganho de Peso Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'c5d5491a-dba9-4a1e-9e2c-137b265d9a30', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'a6772d2b-833d-41b5-8c70-3ce44d705894', 'Henrique Toledo', '5511971000007', 'aluno.henrique.toledo.7@shaipados.com',
    'Consultoria Mensal: Musculação para Ganho de Peso', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Básica (Semana 3 de 6)',
    17000, 850, 16150,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/c5d5491a-dba9-4a1e-9e2c-137b265d9a30', '00020126580014br.gov.bcb.pix0136c5d5491a-dba9-4a1e-9e2c-137b265d9a30520400005303986540170.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [8/50] Mariana Castelo
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'f07bc08d-3585-4621-be29-3b81f21175b7', 'authenticated', 'authenticated', 'aluno.mariana.castelo.8@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Mariana Castelo", "role": "client", "roles": ["client"], "phone": "5511971000008"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'f07bc08d-3585-4621-be29-3b81f21175b7', 'client', ARRAY['client'], 'Mariana Castelo', 'aluno.mariana.castelo.8@shaipados.com', '5511971000008', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face',
    27, 0.95, 22, 67.0, 166,
    'Lombalgia mecânica ocasional. Manter postura neutra sem hiperextensão.', true, 'Mesociclo: Metabólico & Densidade (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Metabólico & Densidade - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '8a6a348b-88b5-4ce8-9027-f02cd1ced7da', 'f07bc08d-3585-4621-be29-3b81f21175b7', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Recomposição Corporal & Redução de Gordura Abdominal', 'Intermediário', 4,
    'Academia Convencional', 'Lombalgia mecânica ocasional. Manter postura neutra sem hiperextensão.', 'Musculação & Emagrecimento', 'female',
    22, 67.0, 166, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '7d1930b2-efd1-4dfd-a7a5-1774efe04e8e', 'f07bc08d-3585-4621-be29-3b81f21175b7', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Metabólico & Densidade (Semana 4 de 6) — Musculação & Emagrecimento',
    'Mesociclo: Metabólico & Densidade (Semana 4 de 6). Restrições: Lombalgia mecânica ocasional. Manter postura neutra sem hiperextensão.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Emagrecimento Split A", "exercises": [{"name": "Agachamento Goblet com Halter Pesado", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Leg Press 45° com Pés no Topo", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica com Miniband", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Panturrilha em Pé", "sets": 4, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Emagrecimento Split B", "exercises": [{"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Curvada Pegada Supinada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Desenvolvimento Arnold", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Cardio HIIT em Escada Ergométrica", "sets": 1, "reps": "15 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '6faa1275-2394-4a72-a405-8d282937c376', 'f07bc08d-3585-4621-be29-3b81f21175b7', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '7d1930b2-efd1-4dfd-a7a5-1774efe04e8e',
    'A', 'Musculação & Emagrecimento Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'd5ad2ebd-72c6-4248-8aac-52e81c76c670', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f07bc08d-3585-4621-be29-3b81f21175b7', 'Mariana Castelo', '5511971000008', 'aluno.mariana.castelo.8@shaipados.com',
    'Consultoria Mensal: Musculação & Emagrecimento', 'Ciclo individualizado 30 dias. Mesociclo: Metabólico & Densidade (Semana 4 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/d5ad2ebd-72c6-4248-8aac-52e81c76c670', '00020126580014br.gov.bcb.pix0136d5ad2ebd-72c6-4248-8aac-52e81c76c670520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [9/50] Felipe Diniz
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '1300176c-7a70-467e-98fc-8d954e9d52cd', 'authenticated', 'authenticated', 'aluno.felipe.diniz.9@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Felipe Diniz", "role": "client", "roles": ["client"], "phone": "5511971000009"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '1300176c-7a70-467e-98fc-8d954e9d52cd', 'client', ARRAY['client'], 'Felipe Diniz', 'aluno.felipe.diniz.9@shaipados.com', '5511971000009', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=300&fit=crop&crop=face',
    11, 0.95, 16, 59.0, 174,
    'Adolescente em fase de crescimento. Proibidas cargas máximas (1RM).', true, 'Mesociclo: Coordenação & Base Neuromuscular (Semana 2 de 4) | Inativo há 1 dias', '✅ Treino em dia (Coordenação & Base Neuromuscular - Semana 2 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '740876be-e01f-476e-8f37-346ac4191f33', '1300176c-7a70-467e-98fc-8d954e9d52cd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fortalecimento Muscular para Atletas Jovens & Agilidade', 'Iniciante', 4,
    'Academia Convencional', 'Adolescente em fase de crescimento. Proibidas cargas máximas (1RM).', 'Iniciação Esportiva & Basquete', 'male',
    16, 59.0, 174, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '40daf131-254a-4a76-b210-d61ede3697f0', '1300176c-7a70-467e-98fc-8d954e9d52cd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Coordenação & Base Neuromuscular (Semana 2 de 4) — Iniciação Esportiva & Basquete',
    'Mesociclo: Coordenação & Base Neuromuscular (Semana 2 de 4). Restrições: Adolescente em fase de crescimento. Proibidas cargas máximas (1RM).',
    '{"splits": [{"split_identifier": "A", "split_name": "Iniciação Esportiva & Basquete Split A", "exercises": [{"name": "Agachamento Livre sem Carga (Técnica)", "sets": 3, "reps": "15", "rest_seconds": 60}, {"name": "Puxada Alta com Elástico", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Flexão de Braço com Mãos Elevadas", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Bird-Dog", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Iniciação Esportiva & Basquete Split B", "exercises": [{"name": "Salto Lateral sobre Linha", "sets": 4, "reps": "20s", "rest_seconds": 60}, {"name": "Arremesso de Medicine Ball no Solo", "sets": 3, "reps": "10", "rest_seconds": 45}, {"name": "Afundo com Peso Corporal", "sets": 3, "reps": "10 cada perna", "rest_seconds": 60}, {"name": "Caminhada do Fazendeiro Leve", "sets": 3, "reps": "30m", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '4b0291ae-21e8-4aff-acbd-7e49b1a5b984', '1300176c-7a70-467e-98fc-8d954e9d52cd', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '40daf131-254a-4a76-b210-d61ede3697f0',
    'A', 'Iniciação Esportiva & Basquete Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '979b946a-cf23-4e19-8e44-3bab2005bc5c', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '1300176c-7a70-467e-98fc-8d954e9d52cd', 'Felipe Diniz', '5511971000009', 'aluno.felipe.diniz.9@shaipados.com',
    'Consultoria Mensal: Iniciação Esportiva & Basquete', 'Ciclo individualizado 30 dias. Mesociclo: Coordenação & Base Neuromuscular (Semana 2 de 4)',
    15000, 750, 14250,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/979b946a-cf23-4e19-8e44-3bab2005bc5c', '00020126580014br.gov.bcb.pix0136979b946a-cf23-4e19-8e44-3bab2005bc5c520400005303986540150.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [10/50] Larissa Nogueira
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '4ee327fa-021b-4a13-8e5b-921e2d80245b', 'authenticated', 'authenticated', 'aluno.larissa.nogueira.10@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Larissa Nogueira", "role": "client", "roles": ["client"], "phone": "5511971000010"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '4ee327fa-021b-4a13-8e5b-921e2d80245b', 'client', ARRAY['client'], 'Larissa Nogueira', 'aluno.larissa.nogueira.10@shaipados.com', '5511971000010', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face',
    31, 0.95, 20, 55.0, 163,
    'Hipermobilidade articular. Manter controle excêntrico rígido sem hiperextender joelhos e cotovelos.', true, 'Mesociclo: Tonificação & Controle Motor (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Tonificação & Controle Motor - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '3988f7bb-57da-479f-8999-25fb0619a955', '4ee327fa-021b-4a13-8e5b-921e2d80245b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Definição Abdominal e Glúteos Firmes', 'Intermediário', 4,
    'Academia Convencional', 'Hipermobilidade articular. Manter controle excêntrico rígido sem hiperextender joelhos e cotovelos.', 'Musculação Estética & Pilates', 'female',
    20, 55.0, 163, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '067ea0fd-3b7d-41ab-9976-5e38bdb7b58b', '4ee327fa-021b-4a13-8e5b-921e2d80245b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Tonificação & Controle Motor (Semana 4 de 6) — Musculação Estética & Pilates',
    'Mesociclo: Tonificação & Controle Motor (Semana 4 de 6). Restrições: Hipermobilidade articular. Manter controle excêntrico rígido sem hiperextender joelhos e cotovelos.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Estética & Pilates Split A", "exercises": [{"name": "Stiff Unilateral com Apoio", "sets": 3, "reps": "12 cada lado", "rest_seconds": 60}, {"name": "Agachamento Sumô com Kettlebell", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Extensora com Isometria 2s", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Abdominal Infra no Banco Declinado", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação Estética & Pilates Split B", "exercises": [{"name": "Puxada Triângulo no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa Supinada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Tríceps Mergulho no Banco", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Prancha Frontal com Toque no Ombro", "sets": 3, "reps": "20 toques", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '4d4813a5-f786-4c77-8660-985bb8082d60', '4ee327fa-021b-4a13-8e5b-921e2d80245b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '067ea0fd-3b7d-41ab-9976-5e38bdb7b58b',
    'A', 'Musculação Estética & Pilates Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'c2bb0214-adea-4114-803a-a06e269f69b0', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '4ee327fa-021b-4a13-8e5b-921e2d80245b', 'Larissa Nogueira', '5511971000010', 'aluno.larissa.nogueira.10@shaipados.com',
    'Consultoria Mensal: Musculação Estética & Pilates', 'Ciclo individualizado 30 dias. Mesociclo: Tonificação & Controle Motor (Semana 4 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/c2bb0214-adea-4114-803a-a06e269f69b0', '00020126580014br.gov.bcb.pix0136c2bb0214-adea-4114-803a-a06e269f69b0520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [11/50] Leandro Pimentel
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '0a240ada-2f62-47fe-9312-d4dff37f0833', 'authenticated', 'authenticated', 'aluno.leandro.pimentel.11@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Leandro Pimentel", "role": "client", "roles": ["client"], "phone": "5511971000011"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '0a240ada-2f62-47fe-9312-d4dff37f0833', 'client', ARRAY['client'], 'Leandro Pimentel', 'aluno.leandro.pimentel.11@shaipados.com', '5511971000011', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    45, 0.95, 31, 92.0, 181,
    'Epicondilite medial no cotovelo esquerdo. Pegada neutra em puxadas e roscas.', true, 'Mesociclo: Hipertrofia de Braços & Peitoral (Semana 4 de 8) | Inativo há 0 dias', '✅ Treino em dia (Hipertrofia de Braços & Peitoral - Semana 4 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '2a02c413-2259-4953-ae22-75343bb61fa1', '0a240ada-2f62-47fe-9312-d4dff37f0833', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ganho de Braços e Peitoral (+42cm de braço)', 'Avançado', 4,
    'Academia Convencional', 'Epicondilite medial no cotovelo esquerdo. Pegada neutra em puxadas e roscas.', 'Musculação Hipertrofia & Força', 'male',
    31, 92.0, 181, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '201d610f-260e-4e1b-be70-6b8580c202b6', '0a240ada-2f62-47fe-9312-d4dff37f0833', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia de Braços & Peitoral (Semana 4 de 8) — Musculação Hipertrofia & Força',
    'Mesociclo: Hipertrofia de Braços & Peitoral (Semana 4 de 8). Restrições: Epicondilite medial no cotovelo esquerdo. Pegada neutra em puxadas e roscas.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Hipertrofia & Força Split A", "exercises": [{"name": "Supino Reto com Halteres Pesados", "sets": 4, "reps": "8-10", "rest_seconds": 90}, {"name": "Crucifixo Inclinado na Polia", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Tríceps Corda com Abertura", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Tríceps Francês Unilateral", "sets": 3, "reps": "10", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação Hipertrofia & Força Split B", "exercises": [{"name": "Puxada Alta Pegada Neutra Fechada", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Remada Cavalinho com Barra", "sets": 4, "reps": "8-10", "rest_seconds": 90}, {"name": "Rosca Martelo com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Rosca Inversa com Barra W", "sets": 3, "reps": "12", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '6da700f1-82d1-45a0-8822-f5c1f4bab989', '0a240ada-2f62-47fe-9312-d4dff37f0833', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '201d610f-260e-4e1b-be70-6b8580c202b6',
    'A', 'Musculação Hipertrofia & Força Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '0d52a942-23c8-4c8d-ae2b-1f267df5d265', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0a240ada-2f62-47fe-9312-d4dff37f0833', 'Leandro Pimentel', '5511971000011', 'aluno.leandro.pimentel.11@shaipados.com',
    'Consultoria Mensal: Musculação Hipertrofia & Força', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia de Braços & Peitoral (Semana 4 de 8)',
    24000, 1200, 22800,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/0d52a942-23c8-4c8d-ae2b-1f267df5d265', '00020126580014br.gov.bcb.pix01360d52a942-23c8-4c8d-ae2b-1f267df5d265520400005303986540240.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [12/50] Débora Medeiros
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', 'authenticated', 'authenticated', 'aluno.debora.medeiros.12@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Débora Medeiros", "role": "client", "roles": ["client"], "phone": "5511971000012"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', 'client', ARRAY['client'], 'Débora Medeiros', 'aluno.debora.medeiros.12@shaipados.com', '5511971000012', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    16, 0.95, 34, 71.0, 165,
    'Diástase abdominal pós-parto (6 meses). Proibidos abdominais crunch tradicionais e prancha frontal sem apoio.', true, 'Mesociclo: Reabilitação de Core & Transverso (Semana 3 de 6) | Inativo há 1 dias', '✅ Treino em dia (Reabilitação de Core & Transverso - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '5abaab37-f190-48ce-a56b-27ef8f9cbf65', 'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fechamento de Diástase (3cm) & Reativação Pélvica', 'Iniciante', 4,
    'Academia Convencional', 'Diástase abdominal pós-parto (6 meses). Proibidos abdominais crunch tradicionais e prancha frontal sem apoio.', 'Pós-Parto & Reabilitação Abdominal', 'female',
    34, 71.0, 165, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '85cc0130-8cc9-4931-b320-1922c65a6889', 'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Reabilitação de Core & Transverso (Semana 3 de 6) — Pós-Parto & Reabilitação Abdominal',
    'Mesociclo: Reabilitação de Core & Transverso (Semana 3 de 6). Restrições: Diástase abdominal pós-parto (6 meses). Proibidos abdominais crunch tradicionais e prancha frontal sem apoio.',
    '{"splits": [{"split_identifier": "A", "split_name": "Pós-Parto & Reabilitação Abdominal Split A", "exercises": [{"name": "Ativação de Transverso com Respiração (Belly Vacuum)", "sets": 4, "reps": "10 expirações", "rest_seconds": 45}, {"name": "Ponte de Glúteos com Bloqueio de Joelhos", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Deadbug Adaptado com Pés no Solo", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60}, {"name": "Puxada Alta Sentada na Máquina", "sets": 3, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Pós-Parto & Reabilitação Abdominal Split B", "exercises": [{"name": "Agachamento na Cadeira com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Elástico", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Clamshell (Ostra) com Miniband", "sets": 3, "reps": "15 cada lado", "rest_seconds": 45}, {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '4733ce99-be1c-4b5f-8501-b930154d83ef', 'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '85cc0130-8cc9-4931-b320-1922c65a6889',
    'A', 'Pós-Parto & Reabilitação Abdominal Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '31f8bf74-990a-4398-b7d4-e3070a9516c4', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'bf4942bb-5552-4dbf-9fc8-9a5f2dd90c89', 'Débora Medeiros', '5511971000012', 'aluno.debora.medeiros.12@shaipados.com',
    'Consultoria Mensal: Pós-Parto & Reabilitação Abdominal', 'Ciclo individualizado 30 dias. Mesociclo: Reabilitação de Core & Transverso (Semana 3 de 6)',
    20000, 1000, 19000,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/31f8bf74-990a-4398-b7d4-e3070a9516c4', '00020126580014br.gov.bcb.pix013631f8bf74-990a-4398-b7d4-e3070a9516c4520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [13/50] Danilo Paixão
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', 'authenticated', 'authenticated', 'aluno.danilo.paixao.13@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Danilo Paixão", "role": "client", "roles": ["client"], "phone": "5511971000013"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', 'client', ARRAY['client'], 'Danilo Paixão', 'aluno.danilo.paixao.13@shaipados.com', '5511971000013', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'past_due', '2026-10-27T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    5, 0.25, 28, 98.0, 186,
    'Condromalácia patelar grau 2 no joelho direito. Evitar impacto de salto no asfalto.', true, 'Mesociclo: Metabólico de Alta Densidade (Semana 1 de 4) | Inativo há 9 dias', '⚠️ ALERTA DE CHURN: Aluno sem treinar há 9 dias (Metabólico de Alta Densidade)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '1160b063-e916-448f-8a2c-6e9d4b5c0050', '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Perder 15kg de Gordura & Aumentar VO2 Máximo', 'Intermediário', 4,
    'Academia Convencional', 'Condromalácia patelar grau 2 no joelho direito. Evitar impacto de salto no asfalto.', 'Emagrecimento Acelerado & Cross-Training', 'male',
    28, 98.0, 186, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '44c62f94-b6ac-4fa8-97aa-46bacb9f8fe4', '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Metabólico de Alta Densidade (Semana 1 de 4) — Emagrecimento Acelerado & Cross-Training',
    'Mesociclo: Metabólico de Alta Densidade (Semana 1 de 4). Restrições: Condromalácia patelar grau 2 no joelho direito. Evitar impacto de salto no asfalto.',
    '{"splits": [{"split_identifier": "A", "split_name": "Emagrecimento Acelerado & Cross-Training Split A", "exercises": [{"name": "Remo Ergométrico (Cardio Zero Impacto)", "sets": 4, "reps": "500m", "rest_seconds": 60}, {"name": "Kettlebell Swing com Encaixe de Quadril", "sets": 4, "reps": "15", "rest_seconds": 60}, {"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Slam Ball no Chão", "sets": 4, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Emagrecimento Acelerado & Cross-Training Split B", "exercises": [{"name": "Air Bike Intervalada (Tabata)", "sets": 8, "reps": "20s/10s", "rest_seconds": 60}, {"name": "Puxada Frente com Triângulo", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Leg Press 45° com Cadência 3030", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Prancha Frontal Estática", "sets": 3, "reps": "45s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'e2efc11a-d420-4e12-ba16-4df926f7e55d', '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '44c62f94-b6ac-4fa8-97aa-46bacb9f8fe4',
    'A', 'Emagrecimento Acelerado & Cross-Training Split A', 4, 4,
    '2026-10-21T14:33:19.946496+00:00'::timestamptz,
    '2026-10-21T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-21T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'a5a3ecc9-54fb-42fa-a0bd-9ca2edd19685', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '36f55fd1-4884-4c7d-b501-c5f0f0ba80c9', 'Danilo Paixão', '5511971000013', 'aluno.danilo.paixao.13@shaipados.com',
    'Consultoria Mensal: Emagrecimento Acelerado & Cross-Training', 'Ciclo individualizado 30 dias. Mesociclo: Metabólico de Alta Densidade (Semana 1 de 4)',
    18000, 900, 17100,
    'pending', '2026-10-27', NULL, 'pix',
    'https://shaipados.com/pay/a5a3ecc9-54fb-42fa-a0bd-9ca2edd19685', '00020126580014br.gov.bcb.pix0136a5a3ecc9-54fb-42fa-a0bd-9ca2edd19685520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [14/50] Renata Vasconcelos
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '14974d30-ad31-4a3e-8aeb-9f78890d0880', 'authenticated', 'authenticated', 'aluno.renata.vasconcelos.14@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Renata Vasconcelos", "role": "client", "roles": ["client"], "phone": "5511971000014"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '14974d30-ad31-4a3e-8aeb-9f78890d0880', 'client', ARRAY['client'], 'Renata Vasconcelos', 'aluno.renata.vasconcelos.14@shaipados.com', '5511971000014', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face',
    58, 0.95, 36, 63.5, 167,
    'Fascite plantar no pé esquerdo em remissão. Mobilidade de tornozelo e liberação miofascial obrigatória.', true, 'Mesociclo: Força Resistente para Corredores (Semana 6 de 8) | Inativo há 0 dias', '✅ Treino em dia (Força Resistente para Corredores - Semana 6 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '4bb034e5-1b2e-4ced-bb15-710a9a80acb0', '14974d30-ad31-4a3e-8aeb-9f78890d0880', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Completar Meia Maratona (21km) Sub-2h sem Lesões', 'Avançado', 4,
    'Academia Convencional', 'Fascite plantar no pé esquerdo em remissão. Mobilidade de tornozelo e liberação miofascial obrigatória.', 'Corrida de Rua & Fortalecimento de Base', 'female',
    36, 63.5, 167, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'edcd87e6-52d0-48c9-9e16-4698d370f55f', '14974d30-ad31-4a3e-8aeb-9f78890d0880', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força Resistente para Corredores (Semana 6 de 8) — Corrida de Rua & Fortalecimento de Base',
    'Mesociclo: Força Resistente para Corredores (Semana 6 de 8). Restrições: Fascite plantar no pé esquerdo em remissão. Mobilidade de tornozelo e liberação miofascial obrigatória.',
    '{"splits": [{"split_identifier": "A", "split_name": "Corrida de Rua & Fortalecimento de Base Split A", "exercises": [{"name": "Agachamento Unilateral no Step", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60}, {"name": "Gêmeos em Pé no Degrau (Fase Excêntrica Lenta)", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Elevação Pélvica Unilateral", "sets": 3, "reps": "12 cada lado", "rest_seconds": 60}, {"name": "Ponte Isométrica para Posteriores", "sets": 3, "reps": "40s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Corrida de Rua & Fortalecimento de Base Split B", "exercises": [{"name": "Remada Baixa com Pegada Aberta", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Pallof Press no Cabo (Anti-Rotação)", "sets": 3, "reps": "12 cada lado", "rest_seconds": 45}, {"name": "Farmer''s Walk Unilateral", "sets": 3, "reps": "30m cada braço", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'b3eb8c2e-79f5-4262-947c-a1821617baa4', '14974d30-ad31-4a3e-8aeb-9f78890d0880', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'edcd87e6-52d0-48c9-9e16-4698d370f55f',
    'A', 'Corrida de Rua & Fortalecimento de Base Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '1e27c73a-db09-4302-8b5d-ffe211bb4cab', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '14974d30-ad31-4a3e-8aeb-9f78890d0880', 'Renata Vasconcelos', '5511971000014', 'aluno.renata.vasconcelos.14@shaipados.com',
    'Consultoria Mensal: Corrida de Rua & Fortalecimento de Base', 'Ciclo individualizado 30 dias. Mesociclo: Força Resistente para Corredores (Semana 6 de 8)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/1e27c73a-db09-4302-8b5d-ffe211bb4cab', '00020126580014br.gov.bcb.pix01361e27c73a-db09-4302-8b5d-ffe211bb4cab520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [15/50] Marcelo Bastos
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '94f6fa55-9759-4944-bb4f-ab3937028734', 'authenticated', 'authenticated', 'aluno.marcelo.bastos.15@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Marcelo Bastos", "role": "client", "roles": ["client"], "phone": "5511971000015"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '94f6fa55-9759-4944-bb4f-ab3937028734', 'client', ARRAY['client'], 'Marcelo Bastos', 'aluno.marcelo.bastos.15@shaipados.com', '5511971000015', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=300&fit=crop&crop=face',
    24, 0.95, 33, 88.0, 178,
    'Ombro direito com leve impacto subacromial. Sem elevação lateral acima de 90°.', true, 'Mesociclo: Hipertrofia Sarcoplasmática (Semana 3 de 6) | Inativo há 2 dias', '✅ Treino em dia (Hipertrofia Sarcoplasmática - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'b27c5cfd-5108-417e-aeb3-dea91f255c2f', '94f6fa55-9759-4944-bb4f-ab3937028734', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ganho de Densidade Muscular & Recomposição', 'Intermediário', 4,
    'Academia Convencional', 'Ombro direito com leve impacto subacromial. Sem elevação lateral acima de 90°.', 'Musculação ABC Clássica', 'male',
    33, 88.0, 178, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'fa5c3989-210f-4290-a181-a050c02d12e7', '94f6fa55-9759-4944-bb4f-ab3937028734', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Sarcoplasmática (Semana 3 de 6) — Musculação ABC Clássica',
    'Mesociclo: Hipertrofia Sarcoplasmática (Semana 3 de 6). Restrições: Ombro direito com leve impacto subacromial. Sem elevação lateral acima de 90°.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação ABC Clássica Split A", "exercises": [{"name": "Supino Inclinado com Halteres (Plano Escapular)", "sets": 4, "reps": "10-12", "rest_seconds": 75}, {"name": "Crossover na Polia Média", "sets": 3, "reps": "12-15", "rest_seconds": 60}, {"name": "Elevação Lateral no Cabo a 30°", "sets": 4, "reps": "12", "rest_seconds": 45}, {"name": "Tríceps Pulley com Barra Reta", "sets": 3, "reps": "12", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação ABC Clássica Split B", "exercises": [{"name": "Puxada Frontal com Barra Pegada Neutra", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Remada Baixa no Triângulo", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Crucifixo Invertido na Máquina", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Rosca Martelo na Polia com Corda", "sets": 3, "reps": "12", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '49f6a9ff-7433-43ac-8d0c-065c300ecaa6', '94f6fa55-9759-4944-bb4f-ab3937028734', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'fa5c3989-210f-4290-a181-a050c02d12e7',
    'A', 'Musculação ABC Clássica Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'b83f3c30-301e-4b8f-9893-4e4d12a514f6', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '94f6fa55-9759-4944-bb4f-ab3937028734', 'Marcelo Bastos', '5511971000015', 'aluno.marcelo.bastos.15@shaipados.com',
    'Consultoria Mensal: Musculação ABC Clássica', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Sarcoplasmática (Semana 3 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/b83f3c30-301e-4b8f-9893-4e4d12a514f6', '00020126580014br.gov.bcb.pix0136b83f3c30-301e-4b8f-9893-4e4d12a514f6520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [16/50] Cláudia Peixoto
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'a8d9fc70-040d-485b-8042-dace4162fab1', 'authenticated', 'authenticated', 'aluno.claudia.peixoto.16@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Cláudia Peixoto", "role": "client", "roles": ["client"], "phone": "5511971000016"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'a8d9fc70-040d-485b-8042-dace4162fab1', 'client', ARRAY['client'], 'Cláudia Peixoto', 'aluno.claudia.peixoto.16@shaipados.com', '5511971000016', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    38, 0.95, 39, 68.0, 162,
    'Cervicalgia tensional e retificação cervical. Evitar trapézio elevado e encolhimentos.', true, 'Mesociclo: Reabilitação Postural & Tônus (Semana 4 de 6) | Inativo há 1 dias', '✅ Treino em dia (Reabilitação Postural & Tônus - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'c33ef16a-5ec1-4d84-bb52-9e78953d8bdf', 'a8d9fc70-040d-485b-8042-dace4162fab1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Emagrecimento & Alívio de Dores Cervicais de Home Office', 'Intermediário', 4,
    'Academia Convencional', 'Cervicalgia tensional e retificação cervical. Evitar trapézio elevado e encolhimentos.', 'Musculação Funcional & Core', 'female',
    39, 68.0, 162, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'ee28746f-b32d-42e8-9cbd-ba9976d0e97f', 'a8d9fc70-040d-485b-8042-dace4162fab1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Reabilitação Postural & Tônus (Semana 4 de 6) — Musculação Funcional & Core',
    'Mesociclo: Reabilitação Postural & Tônus (Semana 4 de 6). Restrições: Cervicalgia tensional e retificação cervical. Evitar trapézio elevado e encolhimentos.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Funcional & Core Split A", "exercises": [{"name": "Puxada Frente com Apoio no Peito", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Face Pull no Cabo com Foco em Romboides", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Agachamento Búlgaro com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação Funcional & Core Split B", "exercises": [{"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica na Máquina", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Abdução de Quadril na Polia", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Prancha Frontal com Respiração Controlada", "sets": 3, "reps": "30s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'dbbf9bc8-2aac-417f-b8f0-85a28aa8bc43', 'a8d9fc70-040d-485b-8042-dace4162fab1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'ee28746f-b32d-42e8-9cbd-ba9976d0e97f',
    'A', 'Musculação Funcional & Core Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '7b24e61c-b282-436c-abc0-8387670c0aa3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'a8d9fc70-040d-485b-8042-dace4162fab1', 'Cláudia Peixoto', '5511971000016', 'aluno.claudia.peixoto.16@shaipados.com',
    'Consultoria Mensal: Musculação Funcional & Core', 'Ciclo individualizado 30 dias. Mesociclo: Reabilitação Postural & Tônus (Semana 4 de 6)',
    20000, 1000, 19000,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/7b24e61c-b282-436c-abc0-8387670c0aa3', '00020126580014br.gov.bcb.pix01367b24e61c-b282-436c-abc0-8387670c0aa3520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [17/50] Diego Brant
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'f0cf88f0-9826-4b10-801d-0a316abd8eeb', 'authenticated', 'authenticated', 'aluno.diego.brant.17@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Diego Brant", "role": "client", "roles": ["client"], "phone": "5511971000017"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'f0cf88f0-9826-4b10-801d-0a316abd8eeb', 'client', ARRAY['client'], 'Diego Brant', 'aluno.diego.brant.17@shaipados.com', '5511971000017', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    18, 0.95, 35, 105.0, 183,
    'Hipertensão moderada controlada. Descansos mínimos de 60s entre séries.', true, 'Mesociclo: Adaptação Metabólica (Semana 3 de 4) | Inativo há 0 dias', '✅ Treino em dia (Adaptação Metabólica - Semana 3 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'b0546761-ab9e-4303-8eec-c828c90f2689', 'f0cf88f0-9826-4b10-801d-0a316abd8eeb', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Combate ao Sedentarismo & Redução de Esteatose Hepática', 'Iniciante', 4,
    'Academia Convencional', 'Hipertensão moderada controlada. Descansos mínimos de 60s entre séries.', 'Musculação & Cardio Não-Impactante', 'male',
    35, 105.0, 183, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '36f614c7-9ba3-4265-b656-6438e9f5420d', 'f0cf88f0-9826-4b10-801d-0a316abd8eeb', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Metabólica (Semana 3 de 4) — Musculação & Cardio Não-Impactante',
    'Mesociclo: Adaptação Metabólica (Semana 3 de 4). Restrições: Hipertensão moderada controlada. Descansos mínimos de 60s entre séries.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Cardio Não-Impactante Split A", "exercises": [{"name": "Leg Press 45°", "sets": 3, "reps": "12", "rest_seconds": 75}, {"name": "Cadeira Extensora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino Máquina Sentado", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Bike Ergométrica Contínua", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}, {"split_identifier": "B", "split_name": "Musculação & Cardio Não-Impactante Split B", "exercises": [{"name": "Puxada Alta na Máquina", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa Sentada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '72c19fb9-1080-4649-a959-ae3052bb0e3f', 'f0cf88f0-9826-4b10-801d-0a316abd8eeb', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '36f614c7-9ba3-4265-b656-6438e9f5420d',
    'A', 'Musculação & Cardio Não-Impactante Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '7f9227da-9da4-4e73-861b-274c8cc206bb', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f0cf88f0-9826-4b10-801d-0a316abd8eeb', 'Diego Brant', '5511971000017', 'aluno.diego.brant.17@shaipados.com',
    'Consultoria Mensal: Musculação & Cardio Não-Impactante', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Metabólica (Semana 3 de 4)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/7f9227da-9da4-4e73-861b-274c8cc206bb', '00020126580014br.gov.bcb.pix01367f9227da-9da4-4e73-861b-274c8cc206bb520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [18/50] Patrícia Fagundes
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '66cf37e3-5658-45e4-a206-bdf9c51012c2', 'authenticated', 'authenticated', 'aluno.patricia.fagundes.18@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Patrícia Fagundes", "role": "client", "roles": ["client"], "phone": "5511971000018"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '66cf37e3-5658-45e4-a206-bdf9c51012c2', 'client', ARRAY['client'], 'Patrícia Fagundes', 'aluno.patricia.fagundes.18@shaipados.com', '5511971000018', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face',
    40, 0.95, 27, 59.0, 163,
    'Sem restrições articulares. Foco em estética e densidade corporal.', true, 'Mesociclo: Polimento Estético (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Polimento Estético - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'be5825b3-302e-4a82-9f11-b2df3aac52ee', '66cf37e3-5658-45e4-a206-bdf9c51012c2', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Definição de Costas e Braços para Vestido & Glúteos Firmes', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições articulares. Foco em estética e densidade corporal.', 'Preparação para Casamento & Estética', 'female',
    27, 59.0, 163, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '788c7c79-b787-4678-8a0c-a8986e9ec761', '66cf37e3-5658-45e4-a206-bdf9c51012c2', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Polimento Estético (Semana 4 de 6) — Preparação para Casamento & Estética',
    'Mesociclo: Polimento Estético (Semana 4 de 6). Restrições: Sem restrições articulares. Foco em estética e densidade corporal.',
    '{"splits": [{"split_identifier": "A", "split_name": "Preparação para Casamento & Estética Split A", "exercises": [{"name": "Puxada Supinada Fechada", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Remada Curvada com Halteres", "sets": 4, "reps": "10-12", "rest_seconds": 60}, {"name": "Elevação Lateral com Halteres", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Tríceps Banco com Pés Elevados", "sets": 3, "reps": "12", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Preparação para Casamento & Estética Split B", "exercises": [{"name": "Elevação Pélvica com Barra 60kg", "sets": 4, "reps": "10-12", "rest_seconds": 75}, {"name": "Agachamento Sumô no Smith", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Cadeira Flexora Unilateral", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Abdominal Infra Suspenso", "sets": 3, "reps": "15", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '49ec80fe-2518-4473-804a-4fea3a937afd', '66cf37e3-5658-45e4-a206-bdf9c51012c2', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '788c7c79-b787-4678-8a0c-a8986e9ec761',
    'A', 'Preparação para Casamento & Estética Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '4bb92e99-9bbb-470b-b6cf-61c4d325764b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '66cf37e3-5658-45e4-a206-bdf9c51012c2', 'Patrícia Fagundes', '5511971000018', 'aluno.patricia.fagundes.18@shaipados.com',
    'Consultoria Mensal: Preparação para Casamento & Estética', 'Ciclo individualizado 30 dias. Mesociclo: Polimento Estético (Semana 4 de 6)',
    22000, 1100, 20900,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/4bb92e99-9bbb-470b-b6cf-61c4d325764b', '00020126580014br.gov.bcb.pix01364bb92e99-9bbb-470b-b6cf-61c4d325764b520400005303986540220.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [19/50] Arthur Mansur
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '6f11ae01-1fe0-4765-9be1-218f726dad87', 'authenticated', 'authenticated', 'aluno.arthur.mansur.19@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Arthur Mansur", "role": "client", "roles": ["client"], "phone": "5511971000019"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '6f11ae01-1fe0-4765-9be1-218f726dad87', 'client', ARRAY['client'], 'Arthur Mansur', 'aluno.arthur.mansur.19@shaipados.com', '5511971000019', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=300&fit=crop&crop=face',
    33, 0.95, 29, 77.0, 177,
    'Histórico de luxação de clavícula grau 1. Sem desenvolvimento militar pesado com barra.', true, 'Mesociclo: Força Isométrica & Grip (Semana 3 de 4) | Inativo há 1 dias', '✅ Treino em dia (Força Isométrica & Grip - Semana 3 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'b7ad5b99-d8e6-4b1c-83fd-0544e19cea0c', '6f11ae01-1fe0-4765-9be1-218f726dad87', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Pegada Poderosa (Grip Strength), Força Isométrica & Prevenção de Lesões', 'Avançado', 4,
    'Academia Convencional', 'Histórico de luxação de clavícula grau 1. Sem desenvolvimento militar pesado com barra.', 'Jiu-Jitsu & Preparação Física Complementar', 'male',
    29, 77.0, 177, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'e37ca4a6-c54a-4836-a010-b10c28b6d830', '6f11ae01-1fe0-4765-9be1-218f726dad87', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força Isométrica & Grip (Semana 3 de 4) — Jiu-Jitsu & Preparação Física Complementar',
    'Mesociclo: Força Isométrica & Grip (Semana 3 de 4). Restrições: Histórico de luxação de clavícula grau 1. Sem desenvolvimento militar pesado com barra.',
    '{"splits": [{"split_identifier": "A", "split_name": "Jiu-Jitsu & Preparação Física Complementar Split A", "exercises": [{"name": "Barra Fixa com Pano de Kimono", "sets": 4, "reps": "6-8", "rest_seconds": 90}, {"name": "Levantamento Terra com Trap Bar", "sets": 4, "reps": "6", "rest_seconds": 120}, {"name": "Farmer''s Walk com Pegada em Pinça", "sets": 4, "reps": "30m", "rest_seconds": 60}, {"name": "Rotação de Tronco no Cabo (Landmine)", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Jiu-Jitsu & Preparação Física Complementar Split B", "exercises": [{"name": "Supino Reto com Halteres Pegada Neutra", "sets": 4, "reps": "8", "rest_seconds": 90}, {"name": "Agachamento Frontal com Halteres nos Ombros", "sets": 4, "reps": "8", "rest_seconds": 90}, {"name": "Remada Unilateral com Halter Pesado", "sets": 3, "reps": "8 cada lado", "rest_seconds": 75}, {"name": "Ponte de Glúteo Isométrica com Carga", "sets": 3, "reps": "45s", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '64f1204d-4c05-4e68-bfae-3f7cc279d4d8', '6f11ae01-1fe0-4765-9be1-218f726dad87', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'e37ca4a6-c54a-4836-a010-b10c28b6d830',
    'A', 'Jiu-Jitsu & Preparação Física Complementar Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '6119123e-c72a-449b-b0f0-1ab4c2f565d3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '6f11ae01-1fe0-4765-9be1-218f726dad87', 'Arthur Mansur', '5511971000019', 'aluno.arthur.mansur.19@shaipados.com',
    'Consultoria Mensal: Jiu-Jitsu & Preparação Física Complementar', 'Ciclo individualizado 30 dias. Mesociclo: Força Isométrica & Grip (Semana 3 de 4)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/6119123e-c72a-449b-b0f0-1ab4c2f565d3', '00020126580014br.gov.bcb.pix01366119123e-c72a-449b-b0f0-1ab4c2f565d3520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [20/50] Letícia Sampaio
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '59995aa4-9799-417e-800e-230abf7eb0cc', 'authenticated', 'authenticated', 'aluno.leticia.sampaio.20@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Letícia Sampaio", "role": "client", "roles": ["client"], "phone": "5511971000020"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '59995aa4-9799-417e-800e-230abf7eb0cc', 'client', ARRAY['client'], 'Letícia Sampaio', 'aluno.leticia.sampaio.20@shaipados.com', '5511971000020', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=300&fit=crop&crop=face',
    48, 0.95, 30, 64.0, 170,
    'Sem restrições clínicas.', true, 'Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 6) | Inativo há 0 dias', '✅ Treino em dia (Hipertrofia Miofibrilar - Semana 5 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '1b0d1c56-72a1-47b4-9fd0-3b0fb7ed5019', '59995aa4-9799-417e-800e-230abf7eb0cc', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ganho de Massa Magra em Membros Inferiores & Resistência', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições clínicas.', 'Hipertrofia Funcional & Corrida', 'female',
    30, 64.0, 170, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'ac725680-87ae-489d-a82d-da23b58064df', '59995aa4-9799-417e-800e-230abf7eb0cc', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Miofibrilar (Semana 5 de 6) — Hipertrofia Funcional & Corrida',
    'Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 6). Restrições: Sem restrições clínicas.',
    '{"splits": [{"split_identifier": "A", "split_name": "Hipertrofia Funcional & Corrida Split A", "exercises": [{"name": "Agachamento Livre com Barra", "sets": 4, "reps": "10", "rest_seconds": 90}, {"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Cadeira Extensora", "sets": 3, "reps": "12-15", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Hipertrofia Funcional & Corrida Split B", "exercises": [{"name": "Puxada Frontal Aberta", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Supino Inclinado com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Lateral na Polia", "sets": 4, "reps": "12", "rest_seconds": 45}, {"name": "Prancha Lateral", "sets": 3, "reps": "40s cada lado", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '30ae48c2-02e6-46af-9a8c-a0da27f29765', '59995aa4-9799-417e-800e-230abf7eb0cc', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'ac725680-87ae-489d-a82d-da23b58064df',
    'A', 'Hipertrofia Funcional & Corrida Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'f7fdb12b-4c15-4f70-97ab-97f5b3770961', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '59995aa4-9799-417e-800e-230abf7eb0cc', 'Letícia Sampaio', '5511971000020', 'aluno.leticia.sampaio.20@shaipados.com',
    'Consultoria Mensal: Hipertrofia Funcional & Corrida', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Miofibrilar (Semana 5 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/f7fdb12b-4c15-4f70-97ab-97f5b3770961', '00020126580014br.gov.bcb.pix0136f7fdb12b-4c15-4f70-97ab-97f5b3770961520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [21/50] Otávio Siqueira
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', 'authenticated', 'authenticated', 'aluno.otavio.siqueira.21@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Otávio Siqueira", "role": "client", "roles": ["client"], "phone": "5511971000021"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', 'client', ARRAY['client'], 'Otávio Siqueira', 'aluno.otavio.siqueira.21@shaipados.com', '5511971000021', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'past_due', '2026-10-26T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    6, 0.25, 37, 81.0, 175,
    'Protrusão discal em L5-S1 assintomática. Proibida carga axial livre na coluna.', true, 'Mesociclo: Estabilização Lombopélvica (Semana 1 de 4) | Inativo há 11 dias', '⚠️ ALERTA DE CHURN: Aluno sem treinar há 11 dias (Estabilização Lombopélvica)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'f1e14d60-0e65-4e7e-908b-d38d76f966b5', 'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Eliminação de Dores Lombares & Fortalecimento de Glúteos', 'Iniciante', 4,
    'Academia Convencional', 'Protrusão discal em L5-S1 assintomática. Proibida carga axial livre na coluna.', 'Musculação para Postura & Saúde', 'male',
    37, 81.0, 175, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '503452ce-3a86-4354-8332-5918686ddfa4', 'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Estabilização Lombopélvica (Semana 1 de 4) — Musculação para Postura & Saúde',
    'Mesociclo: Estabilização Lombopélvica (Semana 1 de 4). Restrições: Protrusão discal em L5-S1 assintomática. Proibida carga axial livre na coluna.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação para Postura & Saúde Split A", "exercises": [{"name": "Leg Press Horizontal", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Alta com Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Chão", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Prancha Bird-Dog", "sets": 3, "reps": "12 cada lado", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação para Postura & Saúde Split B", "exercises": [{"name": "Supino Reto com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa Apoiada no Peito", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Lateral Sentado", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Alongamento de Isquiotibiais com Fita", "sets": 3, "reps": "30s", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '48caadda-eabb-4469-9d47-47526e9f4464', 'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '503452ce-3a86-4354-8332-5918686ddfa4',
    'A', 'Musculação para Postura & Saúde Split A', 4, 4,
    '2026-10-19T14:33:19.946496+00:00'::timestamptz,
    '2026-10-19T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-19T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '780557af-bf90-4f27-82cc-8e00698f5177', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'd05f8af9-46c8-4f57-9e0d-eac3b0fc01e3', 'Otávio Siqueira', '5511971000021', 'aluno.otavio.siqueira.21@shaipados.com',
    'Consultoria Mensal: Musculação para Postura & Saúde', 'Ciclo individualizado 30 dias. Mesociclo: Estabilização Lombopélvica (Semana 1 de 4)',
    19000, 950, 18050,
    'pending', '2026-10-26', NULL, 'pix',
    'https://shaipados.com/pay/780557af-bf90-4f27-82cc-8e00698f5177', '00020126580014br.gov.bcb.pix0136780557af-bf90-4f27-82cc-8e00698f5177520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [22/50] Rafaela Barreto
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '34d48ede-bffc-47b8-bf64-6733dfcac28e', 'authenticated', 'authenticated', 'aluno.rafaela.barreto.22@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Rafaela Barreto", "role": "client", "roles": ["client"], "phone": "5511971000022"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '34d48ede-bffc-47b8-bf64-6733dfcac28e', 'client', ARRAY['client'], 'Rafaela Barreto', 'aluno.rafaela.barreto.22@shaipados.com', '5511971000022', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face',
    29, 0.95, 26, 57.0, 161,
    'Sem restrições clínicas.', true, 'Mesociclo: Hipertrofia Muscular (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Hipertrofia Muscular - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '42f63069-75f1-4286-9427-3807dd24cd4f', '34d48ede-bffc-47b8-bf64-6733dfcac28e', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Massa Magra em Pernas & Costas Esculpidas', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições clínicas.', 'Hipertrofia & Definição', 'female',
    26, 57.0, 161, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'b621c25b-3221-451a-be7c-b140514e2183', '34d48ede-bffc-47b8-bf64-6733dfcac28e', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Muscular (Semana 4 de 6) — Hipertrofia & Definição',
    'Mesociclo: Hipertrofia Muscular (Semana 4 de 6). Restrições: Sem restrições clínicas.',
    '{"splits": [{"split_identifier": "A", "split_name": "Hipertrofia & Definição Split A", "exercises": [{"name": "Hip Thrust na Máquina", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Agachamento no Hack", "sets": 3, "reps": "10", "rest_seconds": 75}, {"name": "Cadeira Abdutora", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Mesa Flexora com Rest-Pause", "sets": 3, "reps": "10+4+4", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Hipertrofia & Definição Split B", "exercises": [{"name": "Remada Curvada com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Aberta na Polia", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Tríceps Corda", "sets": 3, "reps": "15", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'b316e95f-a80c-46cc-a335-6857367a6406', '34d48ede-bffc-47b8-bf64-6733dfcac28e', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'b621c25b-3221-451a-be7c-b140514e2183',
    'A', 'Hipertrofia & Definição Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'c3dadc45-2738-4ff2-9a0a-e570c1200d50', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '34d48ede-bffc-47b8-bf64-6733dfcac28e', 'Rafaela Barreto', '5511971000022', 'aluno.rafaela.barreto.22@shaipados.com',
    'Consultoria Mensal: Hipertrofia & Definição', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Muscular (Semana 4 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/c3dadc45-2738-4ff2-9a0a-e570c1200d50', '00020126580014br.gov.bcb.pix0136c3dadc45-2738-4ff2-9a0a-e570c1200d50520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [23/50] Bernardo Krieger
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', 'authenticated', 'authenticated', 'aluno.bernardo.krieger.23@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Bernardo Krieger", "role": "client", "roles": ["client"], "phone": "5511971000023"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', 'client', ARRAY['client'], 'Bernardo Krieger', 'aluno.bernardo.krieger.23@shaipados.com', '5511971000023', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    62, 0.95, 32, 86.5, 182,
    'Histórico de tendinopatia no tendão de Aquiles direito. Carga progressiva em panturrilhas.', true, 'Mesociclo: Potência & Resistência Láctica (Semana 6 de 8) | Inativo há 0 dias', '✅ Treino em dia (Potência & Resistência Láctica - Semana 6 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'a071b2bf-ba5d-4834-9453-55fa70f0b878', '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Condicionamento Físico & Transição para Ciclismo/Corrida', 'Avançado', 4,
    'Academia Convencional', 'Histórico de tendinopatia no tendão de Aquiles direito. Carga progressiva em panturrilhas.', 'Treino Funcional & Triathlon Sprint', 'male',
    32, 86.5, 182, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '6703a991-4671-4c47-baef-e449e48e99d5', '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Potência & Resistência Láctica (Semana 6 de 8) — Treino Funcional & Triathlon Sprint',
    'Mesociclo: Potência & Resistência Láctica (Semana 6 de 8). Restrições: Histórico de tendinopatia no tendão de Aquiles direito. Carga progressiva em panturrilhas.',
    '{"splits": [{"split_identifier": "A", "split_name": "Treino Funcional & Triathlon Sprint Split A", "exercises": [{"name": "Trap Bar Deadlift com Velocidade", "sets": 4, "reps": "5", "rest_seconds": 90}, {"name": "Salto sobre Barreira Baixa", "sets": 4, "reps": "6", "rest_seconds": 60}, {"name": "Passada com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60}, {"name": "Panturrilha Unilateral no Degrau", "sets": 4, "reps": "12", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Treino Funcional & Triathlon Sprint Split B", "exercises": [{"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Puxada Alta Fechada", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Rollout na Bola Suíça", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Tiro no Remo Indoor (500m)", "sets": 3, "reps": "1m35s", "rest_seconds": 90}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'c403ed0a-f0e7-4391-a528-a680de12340f', '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '6703a991-4671-4c47-baef-e449e48e99d5',
    'A', 'Treino Funcional & Triathlon Sprint Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '23d96c96-2531-4e9b-9673-ffff6da3c4a4', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '53c04a75-ced2-4ca9-8d2d-ea664c29da4f', 'Bernardo Krieger', '5511971000023', 'aluno.bernardo.krieger.23@shaipados.com',
    'Consultoria Mensal: Treino Funcional & Triathlon Sprint', 'Ciclo individualizado 30 dias. Mesociclo: Potência & Resistência Láctica (Semana 6 de 8)',
    23000, 1150, 21850,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/23d96c96-2531-4e9b-9673-ffff6da3c4a4', '00020126580014br.gov.bcb.pix013623d96c96-2531-4e9b-9673-ffff6da3c4a4520400005303986540230.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [24/50] Helena Prado
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', 'authenticated', 'authenticated', 'aluno.helena.prado.24@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Helena Prado", "role": "client", "roles": ["client"], "phone": "5511971000024"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', 'client', ARRAY['client'], 'Helena Prado', 'aluno.helena.prado.24@shaipados.com', '5511971000024', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&fit=crop&crop=face',
    25, 0.95, 28, 54.0, 160,
    'Asma induzida pelo exercício. Aquecimento respiratório obrigatório de 10 minutos.', true, 'Mesociclo: Resistência Muscular Localizada (Semana 3 de 6) | Inativo há 1 dias', '✅ Treino em dia (Resistência Muscular Localizada - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '44988663-655e-4f1a-a3d6-2165026dfd96', '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Tonificação Corporal & Controle de Ansiedade', 'Intermediário', 4,
    'Academia Convencional', 'Asma induzida pelo exercício. Aquecimento respiratório obrigatório de 10 minutos.', 'Musculação & Yoga Híbrida', 'female',
    28, 54.0, 160, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'e8c577a0-01cb-452c-b1e3-448a70c49602', '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Resistência Muscular Localizada (Semana 3 de 6) — Musculação & Yoga Híbrida',
    'Mesociclo: Resistência Muscular Localizada (Semana 3 de 6). Restrições: Asma induzida pelo exercício. Aquecimento respiratório obrigatório de 10 minutos.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Yoga Híbrida Split A", "exercises": [{"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Avanço Estático", "sets": 3, "reps": "10 cada lado", "rest_seconds": 60}, {"name": "Elevação Pélvica com Miniband", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Panturrilha Sentado", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Yoga Híbrida Split B", "exercises": [{"name": "Puxada Alta no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino com Halteres Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Desenvolvimento Arnold", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Frontal com Respiração Diafragmática", "sets": 3, "reps": "30s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '7592c194-099e-49f5-a660-2ee63a84f67d', '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'e8c577a0-01cb-452c-b1e3-448a70c49602',
    'A', 'Musculação & Yoga Híbrida Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '10a7eb3f-0022-480e-b0d8-a09a164590a4', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0c8363cf-8e12-4227-91bc-53a7e72f1fd8', 'Helena Prado', '5511971000024', 'aluno.helena.prado.24@shaipados.com',
    'Consultoria Mensal: Musculação & Yoga Híbrida', 'Ciclo individualizado 30 dias. Mesociclo: Resistência Muscular Localizada (Semana 3 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/10a7eb3f-0022-480e-b0d8-a09a164590a4', '00020126580014br.gov.bcb.pix013610a7eb3f-0022-480e-b0d8-a09a164590a4520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [25/50] Gustavo Mendonça
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '3601d88a-7611-4489-98df-eca425780996', 'authenticated', 'authenticated', 'aluno.gustavo.mendonca.25@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Gustavo Mendonça", "role": "client", "roles": ["client"], "phone": "5511971000025"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '3601d88a-7611-4489-98df-eca425780996', 'client', ARRAY['client'], 'Gustavo Mendonça', 'aluno.gustavo.mendonca.25@shaipados.com', '5511971000025', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'past_due', '2026-10-25T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    3, 0.25, 38, 94.0, 180,
    'Tendinite no tendão quadricipital direito. Sem agachamento profundo além de 90°.', true, 'Mesociclo: Reativação & Perda de Gordura (Semana 1 de 4) | Inativo há 14 dias', '⚠️ ALERTA DE CHURN: Aluno sem treinar há 14 dias (Reativação & Perda de Gordura)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '2ebb6acc-beb7-4d10-ab27-996176718551', '3601d88a-7611-4489-98df-eca425780996', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Emagrecimento com Preservação de Massa Magra', 'Intermediário', 4,
    'Academia Convencional', 'Tendinite no tendão quadricipital direito. Sem agachamento profundo além de 90°.', 'Musculação & HIIT Metabólico', 'male',
    38, 94.0, 180, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'e72ade03-e5c2-47f2-b3e3-1ce5dab805ae', '3601d88a-7611-4489-98df-eca425780996', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Reativação & Perda de Gordura (Semana 1 de 4) — Musculação & HIIT Metabólico',
    'Mesociclo: Reativação & Perda de Gordura (Semana 1 de 4). Restrições: Tendinite no tendão quadricipital direito. Sem agachamento profundo além de 90°.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & HIIT Metabólico Split A", "exercises": [{"name": "Leg Press 45° com Amplitude Limitada", "sets": 3, "reps": "12", "rest_seconds": 75}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino na Máquina Guiada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Transport (Elíptico) Contínuo", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}, {"split_identifier": "B", "split_name": "Musculação & HIIT Metabólico Split B", "exercises": [{"name": "Puxada Alta com Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Articulada Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica com Apoio no Banco", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Prancha com Joelhos Apoiados", "sets": 3, "reps": "30s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '1dc9e07f-98e7-460f-af3e-71ebef2c3a72', '3601d88a-7611-4489-98df-eca425780996', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'e72ade03-e5c2-47f2-b3e3-1ce5dab805ae',
    'A', 'Musculação & HIIT Metabólico Split A', 4, 4,
    '2026-10-16T14:33:19.946496+00:00'::timestamptz,
    '2026-10-16T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-16T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'cba4b710-1ab9-45fb-8d1b-3e025a85e962', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '3601d88a-7611-4489-98df-eca425780996', 'Gustavo Mendonça', '5511971000025', 'aluno.gustavo.mendonca.25@shaipados.com',
    'Consultoria Mensal: Musculação & HIIT Metabólico', 'Ciclo individualizado 30 dias. Mesociclo: Reativação & Perda de Gordura (Semana 1 de 4)',
    20000, 1000, 19000,
    'pending', '2026-10-25', NULL, 'pix',
    'https://shaipados.com/pay/cba4b710-1ab9-45fb-8d1b-3e025a85e962', '00020126580014br.gov.bcb.pix0136cba4b710-1ab9-45fb-8d1b-3e025a85e962520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [26/50] Tatiana Rocha
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '77db1f19-0585-4ad9-a217-00ca250e5e10', 'authenticated', 'authenticated', 'aluno.tatiana.rocha.26@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Tatiana Rocha", "role": "client", "roles": ["client"], "phone": "5511971000026"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '77db1f19-0585-4ad9-a217-00ca250e5e10', 'client', ARRAY['client'], 'Tatiana Rocha', 'aluno.tatiana.rocha.26@shaipados.com', '5511971000026', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    34, 0.95, 44, 72.0, 164,
    'Osteopenia na coluna lombar. Cargas axiais moderadas com foco em tração e empurrar.', true, 'Mesociclo: Estimulação Osteogênica (Semana 3 de 6) | Inativo há 1 dias', '✅ Treino em dia (Estimulação Osteogênica - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '4634d680-90de-4206-83ca-7b7487cb09fc', '77db1f19-0585-4ad9-a217-00ca250e5e10', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ganho de Massa Óssea (Osteopenia) & Tonificação', 'Intermediário', 4,
    'Academia Convencional', 'Osteopenia na coluna lombar. Cargas axiais moderadas com foco em tração e empurrar.', 'Musculação & Prevenção Metabólica', 'female',
    44, 72.0, 164, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '17488cfe-c876-4e23-a41f-254623086ba7', '77db1f19-0585-4ad9-a217-00ca250e5e10', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Estimulação Osteogênica (Semana 3 de 6) — Musculação & Prevenção Metabólica',
    'Mesociclo: Estimulação Osteogênica (Semana 3 de 6). Restrições: Osteopenia na coluna lombar. Cargas axiais moderadas com foco em tração e empurrar.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Prevenção Metabólica Split A", "exercises": [{"name": "Leg Press Horizontal Pesado", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Elevação Pélvica com Halter no Quadril", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Frontal Estática", "sets": 3, "reps": "30s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Prevenção Metabólica Split B", "exercises": [{"name": "Puxada Alta Pegada Supinada", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Remada Baixa no Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Caminhada Rápida com Inclinação", "sets": 1, "reps": "25 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'f51a1247-9af0-4c68-8a7f-96236bd87a6f', '77db1f19-0585-4ad9-a217-00ca250e5e10', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '17488cfe-c876-4e23-a41f-254623086ba7',
    'A', 'Musculação & Prevenção Metabólica Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'fb5dddb9-ffeb-4f32-8166-b154c4bdbc06', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '77db1f19-0585-4ad9-a217-00ca250e5e10', 'Tatiana Rocha', '5511971000026', 'aluno.tatiana.rocha.26@shaipados.com',
    'Consultoria Mensal: Musculação & Prevenção Metabólica', 'Ciclo individualizado 30 dias. Mesociclo: Estimulação Osteogênica (Semana 3 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/fb5dddb9-ffeb-4f32-8166-b154c4bdbc06', '00020126580014br.gov.bcb.pix0136fb5dddb9-ffeb-4f32-8166-b154c4bdbc06520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [27/50] Rodrigo Valente
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '6956dee2-f454-4b5f-8ccc-da56aaa0094f', 'authenticated', 'authenticated', 'aluno.rodrigo.valente.27@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Rodrigo Valente", "role": "client", "roles": ["client"], "phone": "5511971000027"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '6956dee2-f454-4b5f-8ccc-da56aaa0094f', 'client', ARRAY['client'], 'Rodrigo Valente', 'aluno.rodrigo.valente.27@shaipados.com', '5511971000027', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    41, 0.95, 47, 90.0, 179,
    'Hérnia discal L4-L5 com pinçamento ciático prévio. Proibido levantamento terra e agachamento livre.', true, 'Mesociclo: Estabilização do Core & Descompressão (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Estabilização do Core & Descompressão - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'e8ee5356-fb7e-490e-a587-ac8d243c074c', '6956dee2-f454-4b5f-8ccc-da56aaa0094f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Alívio de Hérnia de Disco L4-L5 & Recomposição', 'Intermediário', 4,
    'Academia Convencional', 'Hérnia discal L4-L5 com pinçamento ciático prévio. Proibido levantamento terra e agachamento livre.', 'Musculação & Estabilização de Coluna', 'male',
    47, 90.0, 179, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'e3297772-1580-430d-a6d1-097c1973cec4', '6956dee2-f454-4b5f-8ccc-da56aaa0094f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Estabilização do Core & Descompressão (Semana 4 de 6) — Musculação & Estabilização de Coluna',
    'Mesociclo: Estabilização do Core & Descompressão (Semana 4 de 6). Restrições: Hérnia discal L4-L5 com pinçamento ciático prévio. Proibido levantamento terra e agachamento livre.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Estabilização de Coluna Split A", "exercises": [{"name": "Leg Press 45° com Costas Bem Apoiadas", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Puxada Frontal com Pegada Neutra Aberta", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Solo", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Prancha Bird-Dog com Isometria 3s", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Estabilização de Coluna Split B", "exercises": [{"name": "Supino Máquina Sentado", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Articulada com Apoio Peitoral", "sets": 4, "reps": "10-12", "rest_seconds": 60}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Alongamento de Piriforme e Mobilidade de Quadril", "sets": 3, "reps": "40s", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '36c7e4f7-5584-40b1-b721-a7ea7182e370', '6956dee2-f454-4b5f-8ccc-da56aaa0094f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'e3297772-1580-430d-a6d1-097c1973cec4',
    'A', 'Musculação & Estabilização de Coluna Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'c10684d6-e603-4138-a667-e8ca05f835a3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '6956dee2-f454-4b5f-8ccc-da56aaa0094f', 'Rodrigo Valente', '5511971000027', 'aluno.rodrigo.valente.27@shaipados.com',
    'Consultoria Mensal: Musculação & Estabilização de Coluna', 'Ciclo individualizado 30 dias. Mesociclo: Estabilização do Core & Descompressão (Semana 4 de 6)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/c10684d6-e603-4138-a667-e8ca05f835a3', '00020126580014br.gov.bcb.pix0136c10684d6-e603-4138-a667-e8ca05f835a3520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [28/50] Vanessa Brandão
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '19891ca1-a46a-4462-8124-c9513bdbc939', 'authenticated', 'authenticated', 'aluno.vanessa.brandao.28@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Vanessa Brandão", "role": "client", "roles": ["client"], "phone": "5511971000028"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '19891ca1-a46a-4462-8124-c9513bdbc939', 'client', ARRAY['client'], 'Vanessa Brandão', 'aluno.vanessa.brandao.28@shaipados.com', '5511971000028', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face',
    15, 0.95, 49, 66.0, 160,
    'Dores articulares migratórias e fogachos. Treinos com ventilação adequada e hidratação constante.', true, 'Mesociclo: Adaptação Metabólica no Climatério (Semana 3 de 4) | Inativo há 2 dias', '✅ Treino em dia (Adaptação Metabólica no Climatério - Semana 3 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'eab599a2-3cb9-4c47-9e55-8b87c21f3295', '19891ca1-a46a-4462-8124-c9513bdbc939', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Preservação Muscular na Menopausa & Metabolismo Ativo', 'Iniciante', 4,
    'Academia Convencional', 'Dores articulares migratórias e fogachos. Treinos com ventilação adequada e hidratação constante.', 'Treino Funcional & Climatério', 'female',
    49, 66.0, 160, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '0e686181-a765-456f-adff-537ccc45f670', '19891ca1-a46a-4462-8124-c9513bdbc939', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Metabólica no Climatério (Semana 3 de 4) — Treino Funcional & Climatério',
    'Mesociclo: Adaptação Metabólica no Climatério (Semana 3 de 4). Restrições: Dores articulares migratórias e fogachos. Treinos com ventilação adequada e hidratação constante.',
    '{"splits": [{"split_identifier": "A", "split_name": "Treino Funcional & Climatério Split A", "exercises": [{"name": "Agachamento com Bola nas Costas (Parede)", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Alta com Triângulo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Extensora Leve", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Elevação Pélvica com Miniband", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Treino Funcional & Climatério Split B", "exercises": [{"name": "Supino com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Bike Reclinada Suave", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '30597580-9146-4da0-8aa7-ec9c4b500b64', '19891ca1-a46a-4462-8124-c9513bdbc939', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0e686181-a765-456f-adff-537ccc45f670',
    'A', 'Treino Funcional & Climatério Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '45b2456e-390d-433b-8b5f-64781ce5d2f1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '19891ca1-a46a-4462-8124-c9513bdbc939', 'Vanessa Brandão', '5511971000028', 'aluno.vanessa.brandao.28@shaipados.com',
    'Consultoria Mensal: Treino Funcional & Climatério', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Metabólica no Climatério (Semana 3 de 4)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/45b2456e-390d-433b-8b5f-64781ce5d2f1', '00020126580014br.gov.bcb.pix013645b2456e-390d-433b-8b5f-64781ce5d2f1520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [29/50] André Linhares
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', 'authenticated', 'authenticated', 'aluno.andre.linhares.29@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "André Linhares", "role": "client", "roles": ["client"], "phone": "5511971000029"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', 'client', ARRAY['client'], 'André Linhares', 'aluno.andre.linhares.29@shaipados.com', '5511971000029', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    46, 0.95, 52, 84.0, 173,
    'Pós-angioplastia (stent colocado há 2 anos). Acompanhamento cardiológico em dia. FC máx limitada a 135 bpm.', true, 'Mesociclo: Resistência Cardiovascular & Tônus (Semana 4 de 6) | Inativo há 1 dias', '✅ Treino em dia (Resistência Cardiovascular & Tônus - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'e646525c-7164-4b93-ae1f-aecff7b25c0c', '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Condicionamento Cardiovascular & Redução de Triglicerídeos', 'Intermediário', 4,
    'Academia Convencional', 'Pós-angioplastia (stent colocado há 2 anos). Acompanhamento cardiológico em dia. FC máx limitada a 135 bpm.', 'Musculação para Saúde Cardíaca', 'male',
    52, 84.0, 173, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'b118eb0e-4f55-4c2f-882f-0f7f59b54ad0', '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Resistência Cardiovascular & Tônus (Semana 4 de 6) — Musculação para Saúde Cardíaca',
    'Mesociclo: Resistência Cardiovascular & Tônus (Semana 4 de 6). Restrições: Pós-angioplastia (stent colocado há 2 anos). Acompanhamento cardiológico em dia. FC máx limitada a 135 bpm.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação para Saúde Cardíaca Split A", "exercises": [{"name": "Caminhada Contínua com Monitor de FC", "sets": 1, "reps": "20 min", "rest_seconds": 0}, {"name": "Leg Press Horizontal", "sets": 3, "reps": "15", "rest_seconds": 75}, {"name": "Supino Máquina Guiada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica sem Carga", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação para Saúde Cardíaca Split B", "exercises": [{"name": "Bicicleta Ergométrica com Carga Leve", "sets": 1, "reps": "20 min", "rest_seconds": 0}, {"name": "Puxada Frontal Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'adfd2fa8-d363-4398-bf76-721832e20a49', '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'b118eb0e-4f55-4c2f-882f-0f7f59b54ad0',
    'A', 'Musculação para Saúde Cardíaca Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '4b025441-d233-4c9e-b935-7e6e2be86c9d', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0ec668d7-6a61-4eb6-b4b4-c86646faf58c', 'André Linhares', '5511971000029', 'aluno.andre.linhares.29@shaipados.com',
    'Consultoria Mensal: Musculação para Saúde Cardíaca', 'Ciclo individualizado 30 dias. Mesociclo: Resistência Cardiovascular & Tônus (Semana 4 de 6)',
    23000, 1150, 21850,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/4b025441-d233-4c9e-b935-7e6e2be86c9d', '00020126580014br.gov.bcb.pix01364b025441-d233-4c9e-b935-7e6e2be86c9d520400005303986540230.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [30/50] Natália Guimarães
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '682e5531-049a-441a-9532-df20ee854129', 'authenticated', 'authenticated', 'aluno.natalia.guimaraes.30@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Natália Guimarães", "role": "client", "roles": ["client"], "phone": "5511971000030"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '682e5531-049a-441a-9532-df20ee854129', 'client', ARRAY['client'], 'Natália Guimarães', 'aluno.natalia.guimaraes.30@shaipados.com', '5511971000030', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face',
    12, 0.95, 41, 65.0, 168,
    'Fibromialgia com pontos dolorosos em ombros e quadris. Treinos curtos e sem fadiga excessiva.', true, 'Mesociclo: Adaptação Neuromuscular Suave (Semana 2 de 4) | Inativo há 3 dias', '✅ Treino em dia (Adaptação Neuromuscular Suave - Semana 2 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'ba2be42e-2639-4407-a817-c399c56f0a66', '682e5531-049a-441a-9532-df20ee854129', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fortalecimento para Combate à Fibromialgia', 'Iniciante', 4,
    'Academia Convencional', 'Fibromialgia com pontos dolorosos em ombros e quadris. Treinos curtos e sem fadiga excessiva.', 'Musculação & Mobilidade', 'female',
    41, 65.0, 168, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '22fd255a-b6c9-4235-8151-b81ef09150ac', '682e5531-049a-441a-9532-df20ee854129', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Neuromuscular Suave (Semana 2 de 4) — Musculação & Mobilidade',
    'Mesociclo: Adaptação Neuromuscular Suave (Semana 2 de 4). Restrições: Fibromialgia com pontos dolorosos em ombros e quadris. Treinos curtos e sem fadiga excessiva.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Mobilidade Split A", "exercises": [{"name": "Leg Press 45° com Peso Leve", "sets": 3, "reps": "10", "rest_seconds": 75}, {"name": "Puxada Alta com Elástico", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Mobilidade Torácica no Colchonete", "sets": 3, "reps": "8 cada lado", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Mobilidade Split B", "exercises": [{"name": "Supino com Halteres Leves", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Remada Baixa Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Extensora Suave", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Alongamento Global e Respiração Guiada", "sets": 1, "reps": "10 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '57c3ab00-8186-4ca4-a84c-16b930595e46', '682e5531-049a-441a-9532-df20ee854129', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '22fd255a-b6c9-4235-8151-b81ef09150ac',
    'A', 'Musculação & Mobilidade Split A', 4, 4,
    '2026-10-27T14:33:19.946496+00:00'::timestamptz,
    '2026-10-27T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-27T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'd944a5dd-7b3d-45af-b3fe-f057dfdf95c6', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '682e5531-049a-441a-9532-df20ee854129', 'Natália Guimarães', '5511971000030', 'aluno.natalia.guimaraes.30@shaipados.com',
    'Consultoria Mensal: Musculação & Mobilidade', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Neuromuscular Suave (Semana 2 de 4)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/d944a5dd-7b3d-45af-b3fe-f057dfdf95c6', '00020126580014br.gov.bcb.pix0136d944a5dd-7b3d-45af-b3fe-f057dfdf95c6520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [31/50] Samuel Peçanha
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'bc14f61b-a1f7-47bc-b10b-61fb672b4298', 'authenticated', 'authenticated', 'aluno.samuel.pecanha.31@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Samuel Peçanha", "role": "client", "roles": ["client"], "phone": "5511971000031"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'bc14f61b-a1f7-47bc-b10b-61fb672b4298', 'client', ARRAY['client'], 'Samuel Peçanha', 'aluno.samuel.pecanha.31@shaipados.com', '5511971000031', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    20, 0.95, 46, 110.0, 185,
    'Obesidade grau 1 e sobrecarga nos joelhos. Zero corrida no solo, apenas elíptico e remo.', true, 'Mesociclo: Metabólico Não-Impactante (Semana 3 de 6) | Inativo há 0 dias', '✅ Treino em dia (Metabólico Não-Impactante - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'abae1d47-26bc-4da5-aae4-1ecf04f75032', 'bc14f61b-a1f7-47bc-b10b-61fb672b4298', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Perder 20kg & Reverter Pré-Diabetes', 'Iniciante', 4,
    'Academia Convencional', 'Obesidade grau 1 e sobrecarga nos joelhos. Zero corrida no solo, apenas elíptico e remo.', 'Emagrecimento com Máquinas Guiadas', 'male',
    46, 110.0, 185, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '2271464f-359d-4239-948c-b54607ffb52a', 'bc14f61b-a1f7-47bc-b10b-61fb672b4298', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Metabólico Não-Impactante (Semana 3 de 6) — Emagrecimento com Máquinas Guiadas',
    'Mesociclo: Metabólico Não-Impactante (Semana 3 de 6). Restrições: Obesidade grau 1 e sobrecarga nos joelhos. Zero corrida no solo, apenas elíptico e remo.',
    '{"splits": [{"split_identifier": "A", "split_name": "Emagrecimento com Máquinas Guiadas Split A", "exercises": [{"name": "Leg Press 45° Guiado", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Supino na Máquina com Pegada Neutra", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Elíptico com Resistência Moderada", "sets": 1, "reps": "25 min", "rest_seconds": 0}]}, {"split_identifier": "B", "split_name": "Emagrecimento com Máquinas Guiadas Split B", "exercises": [{"name": "Puxada Frontal Aberta na Máquina", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Apoio", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica com Apoio", "sets": 3, "reps": "15", "rest_seconds": 60}, {"name": "Bicicleta Reclinada", "sets": 1, "reps": "25 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'dd29a784-58fc-4439-a5e2-1197c7a6a2eb', 'bc14f61b-a1f7-47bc-b10b-61fb672b4298', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '2271464f-359d-4239-948c-b54607ffb52a',
    'A', 'Emagrecimento com Máquinas Guiadas Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '513ae6fa-71dd-469a-8e6b-33a481e570f5', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'bc14f61b-a1f7-47bc-b10b-61fb672b4298', 'Samuel Peçanha', '5511971000031', 'aluno.samuel.pecanha.31@shaipados.com',
    'Consultoria Mensal: Emagrecimento com Máquinas Guiadas', 'Ciclo individualizado 30 dias. Mesociclo: Metabólico Não-Impactante (Semana 3 de 6)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/513ae6fa-71dd-469a-8e6b-33a481e570f5', '00020126580014br.gov.bcb.pix0136513ae6fa-71dd-469a-8e6b-33a481e570f5520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [32/50] Gabriela Silveira
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '0fc6f07e-9f56-42b7-b2ce-04b942343757', 'authenticated', 'authenticated', 'aluno.gabriela.silveira.32@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Gabriela Silveira", "role": "client", "roles": ["client"], "phone": "5511971000032"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '0fc6f07e-9f56-42b7-b2ce-04b942343757', 'client', ARRAY['client'], 'Gabriela Silveira', 'aluno.gabriela.silveira.32@shaipados.com', '5511971000032', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face',
    37, 0.95, 42, 61.0, 166,
    'Sem restrições.', true, 'Mesociclo: Hipertrofia Miofibrilar (Semana 4 de 6) | Inativo há 1 dias', '✅ Treino em dia (Hipertrofia Miofibrilar - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '127640c9-b254-45b5-8577-ed4df3ccf640', '0fc6f07e-9f56-42b7-b2ce-04b942343757', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Tonificação de Membros Inferiores & Cintura', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições.', 'Musculação Estética & Funcional', 'female',
    42, 61.0, 166, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '718abff3-2365-4a41-b66d-532b1cf9cf12', '0fc6f07e-9f56-42b7-b2ce-04b942343757', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Hipertrofia Miofibrilar (Semana 4 de 6) — Musculação Estética & Funcional',
    'Mesociclo: Hipertrofia Miofibrilar (Semana 4 de 6). Restrições: Sem restrições.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Estética & Funcional Split A", "exercises": [{"name": "Elevação Pélvica com Barra", "sets": 4, "reps": "10-12", "rest_seconds": 75}, {"name": "Agachamento Sumô com Halter", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Cadeira Abdutora", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação Estética & Funcional Split B", "exercises": [{"name": "Puxada Alta Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Elevação Lateral", "sets": 4, "reps": "12", "rest_seconds": 45}, {"name": "Prancha Isométrica", "sets": 3, "reps": "45s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '1dde616f-a1c7-406f-bb64-5fd9e904925c', '0fc6f07e-9f56-42b7-b2ce-04b942343757', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '718abff3-2365-4a41-b66d-532b1cf9cf12',
    'A', 'Musculação Estética & Funcional Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'aa058637-0584-42fb-a685-082afa2847a8', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0fc6f07e-9f56-42b7-b2ce-04b942343757', 'Gabriela Silveira', '5511971000032', 'aluno.gabriela.silveira.32@shaipados.com',
    'Consultoria Mensal: Musculação Estética & Funcional', 'Ciclo individualizado 30 dias. Mesociclo: Hipertrofia Miofibrilar (Semana 4 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/aa058637-0584-42fb-a685-082afa2847a8', '00020126580014br.gov.bcb.pix0136aa058637-0584-42fb-a685-082afa2847a8520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [33/50] Thiago Cordeiro
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '7ea30a3a-30e9-487e-87b4-d18736e6ee12', 'authenticated', 'authenticated', 'aluno.thiago.cordeiro.33@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Thiago Cordeiro", "role": "client", "roles": ["client"], "phone": "5511971000033"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '7ea30a3a-30e9-487e-87b4-d18736e6ee12', 'client', ARRAY['client'], 'Thiago Cordeiro', 'aluno.thiago.cordeiro.33@shaipados.com', '5511971000033', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'past_due', '2026-10-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    21, 0.25, 45, 87.0, 176,
    'Condromalácia patelar grau 2 no joelho esquerdo.', true, 'Mesociclo: Força Resistente (Semana 2 de 6) | Inativo há 8 dias', '⚠️ ALERTA DE CHURN: Aluno sem treinar há 8 dias (Força Resistente)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '361fecae-4227-43ef-9384-2f70afa8196a', '7ea30a3a-30e9-487e-87b4-d18736e6ee12', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Qualidade de Vida, Força & Fôlego', 'Intermediário', 4,
    'Academia Convencional', 'Condromalácia patelar grau 2 no joelho esquerdo.', 'Musculação & Corrida Moderada', 'male',
    45, 87.0, 176, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'fbc745d6-8202-4fc0-ad36-b2fbecdebf35', '7ea30a3a-30e9-487e-87b4-d18736e6ee12', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força Resistente (Semana 2 de 6) — Musculação & Corrida Moderada',
    'Mesociclo: Força Resistente (Semana 2 de 6). Restrições: Condromalácia patelar grau 2 no joelho esquerdo.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Corrida Moderada Split A", "exercises": [{"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Supino Reto com Barra", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Puxada Frontal", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Abdominal", "sets": 3, "reps": "45s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Corrida Moderada Split B", "exercises": [{"name": "Remada Baixa no Triângulo", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Mesa Flexora", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Esteira Inclinada Caminhada", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'a80d0316-729b-467d-9389-68a8746b3651', '7ea30a3a-30e9-487e-87b4-d18736e6ee12', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'fbc745d6-8202-4fc0-ad36-b2fbecdebf35',
    'A', 'Musculação & Corrida Moderada Split A', 4, 4,
    '2026-10-22T14:33:19.946496+00:00'::timestamptz,
    '2026-10-22T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-22T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '972c6740-8258-4179-9110-43be9ced2565', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '7ea30a3a-30e9-487e-87b4-d18736e6ee12', 'Thiago Cordeiro', '5511971000033', 'aluno.thiago.cordeiro.33@shaipados.com',
    'Consultoria Mensal: Musculação & Corrida Moderada', 'Ciclo individualizado 30 dias. Mesociclo: Força Resistente (Semana 2 de 6)',
    19000, 950, 18050,
    'pending', '2026-10-29', NULL, 'pix',
    'https://shaipados.com/pay/972c6740-8258-4179-9110-43be9ced2565', '00020126580014br.gov.bcb.pix0136972c6740-8258-4179-9110-43be9ced2565520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [34/50] Luciana Antunes
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'b7e4941d-0d92-43dd-b692-0dc9014996d1', 'authenticated', 'authenticated', 'aluno.luciana.antunes.34@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Luciana Antunes", "role": "client", "roles": ["client"], "phone": "5511971000034"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'b7e4941d-0d92-43dd-b692-0dc9014996d1', 'client', ARRAY['client'], 'Luciana Antunes', 'aluno.luciana.antunes.34@shaipados.com', '5511971000034', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    28, 0.95, 48, 69.5, 165,
    'Diabetes tipo 2 controlado por dieta e medicação. Cuidado com sinais de hipoglicemia.', true, 'Mesociclo: Adaptação de Força (Semana 3 de 6) | Inativo há 1 dias', '✅ Treino em dia (Adaptação de Força - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '9203cc6b-e282-4374-a43e-095219f7dd8d', 'b7e4941d-0d92-43dd-b692-0dc9014996d1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fortalecimento Muscular & Controle de Glicemia', 'Iniciante', 4,
    'Academia Convencional', 'Diabetes tipo 2 controlado por dieta e medicação. Cuidado com sinais de hipoglicemia.', 'Musculação & Saúde Metabólica', 'female',
    48, 69.5, 165, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '94c5e7ee-4b14-4494-8df8-07c80fcc5cb5', 'b7e4941d-0d92-43dd-b692-0dc9014996d1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação de Força (Semana 3 de 6) — Musculação & Saúde Metabólica',
    'Mesociclo: Adaptação de Força (Semana 3 de 6). Restrições: Diabetes tipo 2 controlado por dieta e medicação. Cuidado com sinais de hipoglicemia.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Saúde Metabólica Split A", "exercises": [{"name": "Leg Press Horizontal", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Extensora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino Máquina", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Saúde Metabólica Split B", "exercises": [{"name": "Puxada Alta Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Sentada no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Bike Ergométrica", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '42b14295-fde4-4f3d-9807-7852494d5615', 'b7e4941d-0d92-43dd-b692-0dc9014996d1', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '94c5e7ee-4b14-4494-8df8-07c80fcc5cb5',
    'A', 'Musculação & Saúde Metabólica Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '8fee3b04-f44c-48ab-ab3a-f9a288bccc58', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'b7e4941d-0d92-43dd-b692-0dc9014996d1', 'Luciana Antunes', '5511971000034', 'aluno.luciana.antunes.34@shaipados.com',
    'Consultoria Mensal: Musculação & Saúde Metabólica', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação de Força (Semana 3 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/8fee3b04-f44c-48ab-ab3a-f9a288bccc58', '00020126580014br.gov.bcb.pix01368fee3b04-f44c-48ab-ab3a-f9a288bccc58520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [35/50] Murilo Farias
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '4b34522b-af5b-4061-ae0c-f558ebacd122', 'authenticated', 'authenticated', 'aluno.murilo.farias.35@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Murilo Farias", "role": "client", "roles": ["client"], "phone": "5511971000035"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '4b34522b-af5b-4061-ae0c-f558ebacd122', 'client', ARRAY['client'], 'Murilo Farias', 'aluno.murilo.farias.35@shaipados.com', '5511971000035', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    30, 0.95, 55, 91.0, 178,
    'Artrose incipiente no quadril direito. Evitar abduções extremas com carga pesada.', true, 'Mesociclo: Mobilidade & Força Funcional (Semana 4 de 6) | Inativo há 0 dias', '✅ Treino em dia (Mobilidade & Força Funcional - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'ec4ba6cb-405c-4107-a7c0-8e61e6ad9e72', '4b34522b-af5b-4061-ae0c-f558ebacd122', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Combate à Rigidez Matinal & Fortalecimento Geral', 'Intermediário', 4,
    'Academia Convencional', 'Artrose incipiente no quadril direito. Evitar abduções extremas com carga pesada.', 'Musculação & Mobilidade Articular', 'male',
    55, 91.0, 178, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '77841933-b616-4829-903b-a4b200ebb726', '4b34522b-af5b-4061-ae0c-f558ebacd122', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Mobilidade & Força Funcional (Semana 4 de 6) — Musculação & Mobilidade Articular',
    'Mesociclo: Mobilidade & Força Funcional (Semana 4 de 6). Restrições: Artrose incipiente no quadril direito. Evitar abduções extremas com carga pesada.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Mobilidade Articular Split A", "exercises": [{"name": "Leg Press 45° com Pés Afastados", "sets": 3, "reps": "12", "rest_seconds": 75}, {"name": "Puxada Frente com Barra Romana", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Elevação Pélvica com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Prancha Bird-Dog", "sets": 3, "reps": "10 cada lado", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação & Mobilidade Articular Split B", "exercises": [{"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Remada Articulada Fechada", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Mobilidade de Tornozelo e Quadril", "sets": 3, "reps": "40s", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'fde74301-d5e2-4cba-a7d0-b53cc2688161', '4b34522b-af5b-4061-ae0c-f558ebacd122', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '77841933-b616-4829-903b-a4b200ebb726',
    'A', 'Musculação & Mobilidade Articular Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '6b6b70f0-89fe-44c3-ba3d-bd8cb99d7fe3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '4b34522b-af5b-4061-ae0c-f558ebacd122', 'Murilo Farias', '5511971000035', 'aluno.murilo.farias.35@shaipados.com',
    'Consultoria Mensal: Musculação & Mobilidade Articular', 'Ciclo individualizado 30 dias. Mesociclo: Mobilidade & Força Funcional (Semana 4 de 6)',
    20000, 1000, 19000,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/6b6b70f0-89fe-44c3-ba3d-bd8cb99d7fe3', '00020126580014br.gov.bcb.pix01366b6b70f0-89fe-44c3-ba3d-bd8cb99d7fe3520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [36/50] Elisângela Costa
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', 'authenticated', 'authenticated', 'aluno.elisângela.costa.36@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Elisângela Costa", "role": "client", "roles": ["client"], "phone": "5511971000036"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', 'client', ARRAY['client'], 'Elisângela Costa', 'aluno.elisângela.costa.36@shaipados.com', '5511971000036', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face',
    17, 0.95, 53, 73.0, 162,
    'Tendinopatia do supraespinhal direito. Proibidos movimentos acima da linha dos ombros.', true, 'Mesociclo: Estabilização Escapular (Semana 3 de 6) | Inativo há 2 dias', '✅ Treino em dia (Estabilização Escapular - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '7547d3e9-8275-4756-b873-aa9f44729bc9', 'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Reabilitação de Tendinite no Ombro & Emagrecimento', 'Iniciante', 4,
    'Academia Convencional', 'Tendinopatia do supraespinhal direito. Proibidos movimentos acima da linha dos ombros.', 'Musculação Terapêutica', 'female',
    53, 73.0, 162, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '8f3a0f70-32f0-40df-bf70-82cb52ba6d3e', 'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Estabilização Escapular (Semana 3 de 6) — Musculação Terapêutica',
    'Mesociclo: Estabilização Escapular (Semana 3 de 6). Restrições: Tendinopatia do supraespinhal direito. Proibidos movimentos acima da linha dos ombros.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Terapêutica Split A", "exercises": [{"name": "Leg Press Horizontal", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Apoio de Peito", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Solo", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação Terapêutica Split B", "exercises": [{"name": "Supino com Halteres Leves (Amplitude 70°)", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Alta Fechada na Polia", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Caminhada Inclinada na Esteira", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '4540b637-2bcf-4d0e-b08f-032f8696d3db', 'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '8f3a0f70-32f0-40df-bf70-82cb52ba6d3e',
    'A', 'Musculação Terapêutica Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'c2982ac9-238e-46ef-921b-f14069a6acbc', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'cd5ae44c-7fd1-49ba-8642-641eb5c36cf3', 'Elisângela Costa', '5511971000036', 'aluno.elisângela.costa.36@shaipados.com',
    'Consultoria Mensal: Musculação Terapêutica', 'Ciclo individualizado 30 dias. Mesociclo: Estabilização Escapular (Semana 3 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/c2982ac9-238e-46ef-921b-f14069a6acbc', '00020126580014br.gov.bcb.pix0136c2982ac9-238e-46ef-921b-f14069a6acbc520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [37/50] Wagner Assumpção
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'f8171401-40ff-407c-9fde-e4f564b9e958', 'authenticated', 'authenticated', 'aluno.wagner.assumpcao.37@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Wagner Assumpção", "role": "client", "roles": ["client"], "phone": "5511971000037"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'f8171401-40ff-407c-9fde-e4f564b9e958', 'client', ARRAY['client'], 'Wagner Assumpção', 'aluno.wagner.assumpcao.37@shaipados.com', '5511971000037', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    52, 0.95, 51, 96.0, 181,
    'Sem restrições graves.', true, 'Mesociclo: Potência & Força para Ciclismo (Semana 5 de 8) | Inativo há 0 dias', '✅ Treino em dia (Potência & Força para Ciclismo - Semana 5 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '116ac594-aa83-4305-95b1-6efc0f82c5d4', 'f8171401-40ff-407c-9fde-e4f564b9e958', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fortalecimento para Ciclismo & Perda de Peso', 'Avançado', 4,
    'Academia Convencional', 'Sem restrições graves.', 'Musculação & Ciclismo de Estrada', 'male',
    51, 96.0, 181, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'f66dbfc2-2eb7-440e-916c-dfb914d90ecf', 'f8171401-40ff-407c-9fde-e4f564b9e958', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Potência & Força para Ciclismo (Semana 5 de 8) — Musculação & Ciclismo de Estrada',
    'Mesociclo: Potência & Força para Ciclismo (Semana 5 de 8). Restrições: Sem restrições graves.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Ciclismo de Estrada Split A", "exercises": [{"name": "Agachamento Livre com Barra", "sets": 4, "reps": "8", "rest_seconds": 90}, {"name": "Leg Press 45° com Cadência 4020", "sets": 4, "reps": "10", "rest_seconds": 90}, {"name": "Stiff com Barra", "sets": 4, "reps": "8", "rest_seconds": 75}, {"name": "Panturrilha em Pé com Carga", "sets": 4, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação & Ciclismo de Estrada Split B", "exercises": [{"name": "Supino Reto com Barra", "sets": 4, "reps": "8", "rest_seconds": 75}, {"name": "Remada Curvada com Barra", "sets": 4, "reps": "8", "rest_seconds": 75}, {"name": "Desenvolvimento com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Frontal Estática", "sets": 4, "reps": "45s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '2152382a-54a9-445c-90e3-5758f801815b', 'f8171401-40ff-407c-9fde-e4f564b9e958', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f66dbfc2-2eb7-440e-916c-dfb914d90ecf',
    'A', 'Musculação & Ciclismo de Estrada Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '4b215770-ec63-4192-a52a-26f360cc970e', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f8171401-40ff-407c-9fde-e4f564b9e958', 'Wagner Assumpção', '5511971000037', 'aluno.wagner.assumpcao.37@shaipados.com',
    'Consultoria Mensal: Musculação & Ciclismo de Estrada', 'Ciclo individualizado 30 dias. Mesociclo: Potência & Força para Ciclismo (Semana 5 de 8)',
    23000, 1150, 21850,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/4b215770-ec63-4192-a52a-26f360cc970e', '00020126580014br.gov.bcb.pix01364b215770-ec63-4192-a52a-26f360cc970e520400005303986540230.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [38/50] Fernando Esteves
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'eb90afe7-b416-4bf8-9413-580ffcc7f048', 'authenticated', 'authenticated', 'aluno.fernando.esteves.38@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Fernando Esteves", "role": "client", "roles": ["client"], "phone": "5511971000038"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'eb90afe7-b416-4bf8-9413-580ffcc7f048', 'client', ARRAY['client'], 'Fernando Esteves', 'aluno.fernando.esteves.38@shaipados.com', '5511971000038', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    28, 0.95, 43, 83.0, 177,
    'Rotina intensa com viagens constantes. Treinos curtos de alta densidade.', true, 'Mesociclo: Densidade & Circuito Força (Semana 3 de 6) | Inativo há 1 dias', '✅ Treino em dia (Densidade & Circuito Força - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '01e3a317-5d93-4037-ae1a-fb1ccefaaccd', 'eb90afe7-b416-4bf8-9413-580ffcc7f048', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Manutenção de Massa Magra & Alívio de Estresse (45 min)', 'Intermediário', 4,
    'Academia Convencional', 'Rotina intensa com viagens constantes. Treinos curtos de alta densidade.', 'Musculação Executiva (Express)', 'male',
    43, 83.0, 177, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'b070c92b-006c-48f8-ba11-d40facc1e5fd', 'eb90afe7-b416-4bf8-9413-580ffcc7f048', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Densidade & Circuito Força (Semana 3 de 6) — Musculação Executiva (Express)',
    'Mesociclo: Densidade & Circuito Força (Semana 3 de 6). Restrições: Rotina intensa com viagens constantes. Treinos curtos de alta densidade.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Executiva (Express) Split A", "exercises": [{"name": "Supino Reto com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Puxada Frontal Pegada Neutra", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Leg Press 45°", "sets": 4, "reps": "12", "rest_seconds": 75}, {"name": "Prancha Isométrica", "sets": 3, "reps": "45s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação Executiva (Express) Split B", "exercises": [{"name": "Desenvolvimento Militar com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Remada Baixa no Triângulo", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'be0a6ae3-26ac-4e02-b075-9bf70f43c024', 'eb90afe7-b416-4bf8-9413-580ffcc7f048', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'b070c92b-006c-48f8-ba11-d40facc1e5fd',
    'A', 'Musculação Executiva (Express) Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'fc6b019f-9eb9-40a9-94c5-2294962e05d0', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'eb90afe7-b416-4bf8-9413-580ffcc7f048', 'Fernando Esteves', '5511971000038', 'aluno.fernando.esteves.38@shaipados.com',
    'Consultoria Mensal: Musculação Executiva (Express)', 'Ciclo individualizado 30 dias. Mesociclo: Densidade & Circuito Força (Semana 3 de 6)',
    22000, 1100, 20900,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/fc6b019f-9eb9-40a9-94c5-2294962e05d0', '00020126580014br.gov.bcb.pix0136fc6b019f-9eb9-40a9-94c5-2294962e05d0520400005303986540220.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [39/50] Roberto Valadão
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '453cb75d-b6db-4ce1-a6b4-836003a6733f', 'authenticated', 'authenticated', 'aluno.roberto.valadao.39@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Roberto Valadão", "role": "client", "roles": ["client"], "phone": "5511971000039"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '453cb75d-b6db-4ce1-a6b4-836003a6733f', 'client', ARRAY['client'], 'Roberto Valadão', 'aluno.roberto.valadao.39@shaipados.com', '5511971000039', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    44, 0.95, 63, 79.0, 172,
    'Artrose leve nos dois joelhos. Evitar flexão profunda (>90°) sob carga.', true, 'Mesociclo: Força Funcional & Densidade Óssea (Semana 5 de 6) | Inativo há 0 dias', '✅ Treino em dia (Força Funcional & Densidade Óssea - Semana 5 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '981e487f-834b-4290-81c0-305b1b41e837', '453cb75d-b6db-4ce1-a6b4-836003a6733f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Prevenção de Sarcopenia & Manutenção de Massa Magra', 'Intermediário', 4,
    'Academia Convencional', 'Artrose leve nos dois joelhos. Evitar flexão profunda (>90°) sob carga.', 'Musculação para Longevidade', 'male',
    63, 79.0, 172, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '3874356d-511a-4010-ab42-33a54ef2e8db', '453cb75d-b6db-4ce1-a6b4-836003a6733f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força Funcional & Densidade Óssea (Semana 5 de 6) — Musculação para Longevidade',
    'Mesociclo: Força Funcional & Densidade Óssea (Semana 5 de 6). Restrições: Artrose leve nos dois joelhos. Evitar flexão profunda (>90°) sob carga.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação para Longevidade Split A", "exercises": [{"name": "Leg Press Horizontal com Apoio Total", "sets": 3, "reps": "12", "rest_seconds": 75}, {"name": "Puxada Alta Fechada na Polia", "sets": 3, "reps": "10-12", "rest_seconds": 60}, {"name": "Supino na Máquina com Pegada Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Colchonete", "sets": 3, "reps": "12", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação para Longevidade Split B", "exercises": [{"name": "Remada Sentada no Cabo", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Lateral com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Caminhada em Esteira (Velocidade 5.0 km/h)", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'a833aba6-f122-416e-aff9-09fb977f1f2d', '453cb75d-b6db-4ce1-a6b4-836003a6733f', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '3874356d-511a-4010-ab42-33a54ef2e8db',
    'A', 'Musculação para Longevidade Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'fbf8e411-a3b9-4da3-9c33-0ed4fe7916b2', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '453cb75d-b6db-4ce1-a6b4-836003a6733f', 'Roberto Valadão', '5511971000039', 'aluno.roberto.valadao.39@shaipados.com',
    'Consultoria Mensal: Musculação para Longevidade', 'Ciclo individualizado 30 dias. Mesociclo: Força Funcional & Densidade Óssea (Semana 5 de 6)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/fbf8e411-a3b9-4da3-9c33-0ed4fe7916b2', '00020126580014br.gov.bcb.pix0136fbf8e411-a3b9-4da3-9c33-0ed4fe7916b2520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [40/50] Teresa Viana
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', 'authenticated', 'authenticated', 'aluno.teresa.viana.40@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Teresa Viana", "role": "client", "roles": ["client"], "phone": "5511971000040"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', 'client', ARRAY['client'], 'Teresa Viana', 'aluno.teresa.viana.40@shaipados.com', '5511971000040', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    26, 0.95, 67, 63.0, 158,
    'Osteoporose no fêmur direito. Proibidos saltos e impactos bruscos.', true, 'Mesociclo: Equilíbrio & Força Básica (Semana 4 de 6) | Inativo há 1 dias', '✅ Treino em dia (Equilíbrio & Força Básica - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'c2a2edd8-bae5-4626-a92f-ce4049497da6', '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Prevenção de Quedas & Autonomia para Subir Escadas', 'Iniciante', 4,
    'Academia Convencional', 'Osteoporose no fêmur direito. Proibidos saltos e impactos bruscos.', 'Fortalecimento & Equilíbrio Master', 'female',
    67, 63.0, 158, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '15bd1340-47df-43de-9fe8-b019a54cb3aa', '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Equilíbrio & Força Básica (Semana 4 de 6) — Fortalecimento & Equilíbrio Master',
    'Mesociclo: Equilíbrio & Força Básica (Semana 4 de 6). Restrições: Osteoporose no fêmur direito. Proibidos saltos e impactos bruscos.',
    '{"splits": [{"split_identifier": "A", "split_name": "Fortalecimento & Equilíbrio Master Split A", "exercises": [{"name": "Sentar e Levantar da Caixa (com Apoio)", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Puxada Frontal com Elástico Resistente", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Equilíbrio Unipodal com Apoio de Barra", "sets": 3, "reps": "20s cada perna", "rest_seconds": 45}, {"name": "Panturrilha com Apoio na Parede", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Fortalecimento & Equilíbrio Master Split B", "exercises": [{"name": "Remada Articulada com Apoio Peitoral", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica no Solo com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Passada Curta com Apoio de Mão", "sets": 3, "reps": "10 passos", "rest_seconds": 60}, {"name": "Alongamento de Cadeia Posterior Suave", "sets": 3, "reps": "30s", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '0f4c17b4-bc97-434f-bf5e-41669e436698', '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '15bd1340-47df-43de-9fe8-b019a54cb3aa',
    'A', 'Fortalecimento & Equilíbrio Master Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '86b2ad63-29b4-473c-9392-793281d491db', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '3befdbe1-4b88-4a44-837b-3b7b1df01e4d', 'Teresa Viana', '5511971000040', 'aluno.teresa.viana.40@shaipados.com',
    'Consultoria Mensal: Fortalecimento & Equilíbrio Master', 'Ciclo individualizado 30 dias. Mesociclo: Equilíbrio & Força Básica (Semana 4 de 6)',
    20000, 1000, 19000,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/86b2ad63-29b4-473c-9392-793281d491db', '00020126580014br.gov.bcb.pix013686b2ad63-29b4-473c-9392-793281d491db520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [41/50] Vicente Morais
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'fb3b895f-b93e-4010-a008-bedfdfc0fbee', 'authenticated', 'authenticated', 'aluno.vicente.morais.41@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Vicente Morais", "role": "client", "roles": ["client"], "phone": "5511971000041"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'fb3b895f-b93e-4010-a008-bedfdfc0fbee', 'client', ARRAY['client'], 'Vicente Morais', 'aluno.vicente.morais.41@shaipados.com', '5511971000041', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    35, 0.95, 72, 76.0, 170,
    'Artrose de quadril bilateral e hipotensão postural. Evitar mudanças bruscas de decúbito.', true, 'Mesociclo: Autonomia & Estabilidade (Semana 3 de 6) | Inativo há 0 dias', '✅ Treino em dia (Autonomia & Estabilidade - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'd4185996-3b03-4762-a6a4-f0ac0de2f53b', 'fb3b895f-b93e-4010-a008-bedfdfc0fbee', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Preservação da Capacidade Funcional & Vitalidade', 'Intermediário', 4,
    'Academia Convencional', 'Artrose de quadril bilateral e hipotensão postural. Evitar mudanças bruscas de decúbito.', 'Musculação Terapêutica Geriátrica', 'male',
    72, 76.0, 170, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '0b337ceb-1cd3-49d8-88c6-c5d281480e4c', 'fb3b895f-b93e-4010-a008-bedfdfc0fbee', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Autonomia & Estabilidade (Semana 3 de 6) — Musculação Terapêutica Geriátrica',
    'Mesociclo: Autonomia & Estabilidade (Semana 3 de 6). Restrições: Artrose de quadril bilateral e hipotensão postural. Evitar mudanças bruscas de decúbito.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Terapêutica Geriátrica Split A", "exercises": [{"name": "Leg Press Horizontal com Amplitude Confortável", "sets": 3, "reps": "10", "rest_seconds": 75}, {"name": "Puxada Alta Sentada na Máquina", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Supino Sentado na Máquina", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Caminhada no Espaldar", "sets": 3, "reps": "20m", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação Terapêutica Geriátrica Split B", "exercises": [{"name": "Remada Baixa Sentada no Cabo", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Cadeira Extensora com Peso Leve", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Flexora Suave", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Bicicleta Reclinada Confortável", "sets": 1, "reps": "15 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '7d9ecb08-587b-479d-9c54-4fe01ab914f3', 'fb3b895f-b93e-4010-a008-bedfdfc0fbee', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0b337ceb-1cd3-49d8-88c6-c5d281480e4c',
    'A', 'Musculação Terapêutica Geriátrica Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '5516ba60-459b-44df-9fd7-7404b0d51309', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'fb3b895f-b93e-4010-a008-bedfdfc0fbee', 'Vicente Morais', '5511971000041', 'aluno.vicente.morais.41@shaipados.com',
    'Consultoria Mensal: Musculação Terapêutica Geriátrica', 'Ciclo individualizado 30 dias. Mesociclo: Autonomia & Estabilidade (Semana 3 de 6)',
    22000, 1100, 20900,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/5516ba60-459b-44df-9fd7-7404b0d51309', '00020126580014br.gov.bcb.pix01365516ba60-459b-44df-9fd7-7404b0d51309520400005303986540220.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [42/50] Maria Luísa Paiva
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '809e5d3a-b486-4543-b1ed-e20ba4a17193', 'authenticated', 'authenticated', 'aluno.maria.luisa.paiva.42@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Maria Luísa Paiva", "role": "client", "roles": ["client"], "phone": "5511971000042"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '809e5d3a-b486-4543-b1ed-e20ba4a17193', 'client', ARRAY['client'], 'Maria Luísa Paiva', 'aluno.maria.luisa.paiva.42@shaipados.com', '5511971000042', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    19, 0.95, 78, 56.0, 155,
    'Fragilidade senil e prótese total de quadril esquerdo (colocada há 5 anos).', true, 'Mesociclo: Coordenação & Autonomia Geriátrica (Semana 2 de 4) | Inativo há 1 dias', '✅ Treino em dia (Coordenação & Autonomia Geriátrica - Semana 2 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '0a7e6581-013b-40b5-8990-8b4d4d578ffd', '809e5d3a-b486-4543-b1ed-e20ba4a17193', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Manter Independência em Atividades da Vida Diária (AVDs)', 'Iniciante', 4,
    'Academia Convencional', 'Fragilidade senil e prótese total de quadril esquerdo (colocada há 5 anos).', 'Mobilidade & Independência Física', 'female',
    78, 56.0, 155, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '5072a7a3-bebb-4b83-a195-4f49f018e2b1', '809e5d3a-b486-4543-b1ed-e20ba4a17193', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Coordenação & Autonomia Geriátrica (Semana 2 de 4) — Mobilidade & Independência Física',
    'Mesociclo: Coordenação & Autonomia Geriátrica (Semana 2 de 4). Restrições: Fragilidade senil e prótese total de quadril esquerdo (colocada há 5 anos).',
    '{"splits": [{"split_identifier": "A", "split_name": "Mobilidade & Independência Física Split A", "exercises": [{"name": "Levantar da Cadeira com Apoio de Braços", "sets": 3, "reps": "8", "rest_seconds": 75}, {"name": "Puxada Frontal com Elástico", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Abertura de Braços com Elástico Leve", "sets": 3, "reps": "10", "rest_seconds": 45}, {"name": "Marcha Estacionária com Apoio de Barra", "sets": 3, "reps": "30s", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Mobilidade & Independência Física Split B", "exercises": [{"name": "Extensão de Joelhos Sentada com Tornozeleira 1kg", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Flexão de Joelhos em Pé com Apoio de Parede", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Elevação de Calcanhares com Apoio", "sets": 3, "reps": "12", "rest_seconds": 45}, {"name": "Alongamento Cervical e Respiração", "sets": 1, "reps": "10 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'bbefee05-50bf-4d3f-b7dc-0edc6ab94b7c', '809e5d3a-b486-4543-b1ed-e20ba4a17193', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '5072a7a3-bebb-4b83-a195-4f49f018e2b1',
    'A', 'Mobilidade & Independência Física Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'df1d00bc-1b32-4dc1-9117-9e66a968ae6b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '809e5d3a-b486-4543-b1ed-e20ba4a17193', 'Maria Luísa Paiva', '5511971000042', 'aluno.maria.luisa.paiva.42@shaipados.com',
    'Consultoria Mensal: Mobilidade & Independência Física', 'Ciclo individualizado 30 dias. Mesociclo: Coordenação & Autonomia Geriátrica (Semana 2 de 4)',
    24000, 1200, 22800,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/df1d00bc-1b32-4dc1-9117-9e66a968ae6b', '00020126580014br.gov.bcb.pix0136df1d00bc-1b32-4dc1-9117-9e66a968ae6b520400005303986540240.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [43/50] Sérgio Botelho
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'cb735072-1762-4838-a5cc-3ad6504fa0bf', 'authenticated', 'authenticated', 'aluno.sergio.botelho.43@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Sérgio Botelho", "role": "client", "roles": ["client"], "phone": "5511971000043"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'cb735072-1762-4838-a5cc-3ad6504fa0bf', 'client', ARRAY['client'], 'Sérgio Botelho', 'aluno.sergio.botelho.43@shaipados.com', '5511971000043', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&fit=crop&crop=face',
    25, 0.95, 60, 85.0, 175,
    'Hipertensão arterial estágio 1. Manter expiração ativa na fase concêntrica (sem Valsalva).', true, 'Mesociclo: Adaptação de Força (Semana 4 de 6) | Inativo há 2 dias', '✅ Treino em dia (Adaptação de Força - Semana 4 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'f89fa5fd-3891-45fb-ad02-b26c75992558', 'cb735072-1762-4838-a5cc-3ad6504fa0bf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Controle de Hipertensão & Ganho de Força nos Braços', 'Intermediário', 4,
    'Academia Convencional', 'Hipertensão arterial estágio 1. Manter expiração ativa na fase concêntrica (sem Valsalva).', 'Musculação & Saúde Metabólica', 'male',
    60, 85.0, 175, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'dffcc0fb-e55a-4496-b642-a9aef9e49422', 'cb735072-1762-4838-a5cc-3ad6504fa0bf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação de Força (Semana 4 de 6) — Musculação & Saúde Metabólica',
    'Mesociclo: Adaptação de Força (Semana 4 de 6). Restrições: Hipertensão arterial estágio 1. Manter expiração ativa na fase concêntrica (sem Valsalva).',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação & Saúde Metabólica Split A", "exercises": [{"name": "Leg Press 45°", "sets": 3, "reps": "12", "rest_seconds": 75}, {"name": "Supino Máquina", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Puxada Aberta", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação & Saúde Metabólica Split B", "exercises": [{"name": "Remada Sentada com Apoio", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Desenvolvimento com Halteres Leves", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Mesa Flexora", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Esteira Caminhada Contínua", "sets": 1, "reps": "20 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'f6ceeeef-3abe-40e4-93f0-64126688437f', 'cb735072-1762-4838-a5cc-3ad6504fa0bf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'dffcc0fb-e55a-4496-b642-a9aef9e49422',
    'A', 'Musculação & Saúde Metabólica Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '300368e9-8d1f-4c80-8b34-664d439548dc', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'cb735072-1762-4838-a5cc-3ad6504fa0bf', 'Sérgio Botelho', '5511971000043', 'aluno.sergio.botelho.43@shaipados.com',
    'Consultoria Mensal: Musculação & Saúde Metabólica', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação de Força (Semana 4 de 6)',
    20000, 1000, 19000,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/300368e9-8d1f-4c80-8b34-664d439548dc', '00020126580014br.gov.bcb.pix0136300368e9-8d1f-4c80-8b34-664d439548dc520400005303986540200.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [44/50] Alex Drummond
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '577a7ab0-8728-4f73-9996-133d9f489c80', 'authenticated', 'authenticated', 'aluno.alex.drummond.44@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Alex Drummond", "role": "client", "roles": ["client"], "phone": "5511971000044"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '577a7ab0-8728-4f73-9996-133d9f489c80', 'client', ARRAY['client'], 'Alex Drummond', 'aluno.alex.drummond.44@shaipados.com', '5511971000044', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&fit=crop&crop=face',
    32, 0.95, 25, 62.0, 171,
    'Sem restrições.', true, 'Mesociclo: Força Funcional & Core (Semana 3 de 6) | Inativo há 0 dias', '✅ Treino em dia (Força Funcional & Core - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '039a4293-9b38-4653-9a65-c718de82070f', '577a7ab0-8728-4f73-9996-133d9f489c80', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Força Relativa, Equilíbrio Postural & Definição', 'Intermediário', 4,
    'Academia Convencional', 'Sem restrições.', 'Calistenia & Musculação Neutra', 'non_binary',
    25, 62.0, 171, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'a05e618a-d446-460e-b5ef-585e6de5c6eb', '577a7ab0-8728-4f73-9996-133d9f489c80', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força Funcional & Core (Semana 3 de 6) — Calistenia & Musculação Neutra',
    'Mesociclo: Força Funcional & Core (Semana 3 de 6). Restrições: Sem restrições.',
    '{"splits": [{"split_identifier": "A", "split_name": "Calistenia & Musculação Neutra Split A", "exercises": [{"name": "Barra Fixa com Apoio de Elástico", "sets": 4, "reps": "8", "rest_seconds": 75}, {"name": "Flexão de Braço no Solo com Pausa", "sets": 4, "reps": "12", "rest_seconds": 60}, {"name": "Pistol Squat Adaptado no TRX", "sets": 3, "reps": "8 cada perna", "rest_seconds": 60}, {"name": "L-Sit Suspenso", "sets": 3, "reps": "15s", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Calistenia & Musculação Neutra Split B", "exercises": [{"name": "Agachamento com Halteres", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Remada Invertida na Barra", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Handstand Hold na Parede", "sets": 3, "reps": "30s", "rest_seconds": 60}, {"name": "Hollow Body Hold (Canoa)", "sets": 3, "reps": "30s", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '5538b120-deb6-45e7-84c6-7bb35b439256', '577a7ab0-8728-4f73-9996-133d9f489c80', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'a05e618a-d446-460e-b5ef-585e6de5c6eb',
    'A', 'Calistenia & Musculação Neutra Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '8ac0dd26-811b-45f8-8afa-15299cce02a2', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '577a7ab0-8728-4f73-9996-133d9f489c80', 'Alex Drummond', '5511971000044', 'aluno.alex.drummond.44@shaipados.com',
    'Consultoria Mensal: Calistenia & Musculação Neutra', 'Ciclo individualizado 30 dias. Mesociclo: Força Funcional & Core (Semana 3 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/8ac0dd26-811b-45f8-8afa-15299cce02a2', '00020126580014br.gov.bcb.pix01368ac0dd26-811b-45f8-8afa-15299cce02a2520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [45/50] Morgan Toledo
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', 'authenticated', 'authenticated', 'aluno.morgan.toledo.45@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Morgan Toledo", "role": "client", "roles": ["client"], "phone": "5511971000045"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', 'client', ARRAY['client'], 'Morgan Toledo', 'aluno.morgan.toledo.45@shaipados.com', '5511971000045', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&fit=crop&crop=face',
    14, 0.95, 28, 68.0, 173,
    'Sem restrições clínicas.', true, 'Mesociclo: Adaptação Anatômica (Semana 2 de 4) | Inativo há 1 dias', '✅ Treino em dia (Adaptação Anatômica - Semana 2 de 4)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '05752bb0-9490-4de5-9bd2-a4430cdd1833', 'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Condicionamento Geral & Alívio de Tensão', 'Iniciante', 4,
    'Academia Convencional', 'Sem restrições clínicas.', 'Treino Funcional & Mobilidade', 'non_binary',
    28, 68.0, 173, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'f6bd0845-d7bd-4132-b39c-e93151fdb0ba', 'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Anatômica (Semana 2 de 4) — Treino Funcional & Mobilidade',
    'Mesociclo: Adaptação Anatômica (Semana 2 de 4). Restrições: Sem restrições clínicas.',
    '{"splits": [{"split_identifier": "A", "split_name": "Treino Funcional & Mobilidade Split A", "exercises": [{"name": "Agachamento Goblet", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Alta Neutra", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Supino com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Prancha Frontal", "sets": 3, "reps": "30s", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Treino Funcional & Mobilidade Split B", "exercises": [{"name": "Passada com Halteres", "sets": 3, "reps": "16 passos", "rest_seconds": 60}, {"name": "Remada Curvada com Halteres", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação Pélvica", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Mobilidade Global", "sets": 1, "reps": "15 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'a79bb9e0-965c-481d-9678-a4649acf7a1d', 'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f6bd0845-d7bd-4132-b39c-e93151fdb0ba',
    'A', 'Treino Funcional & Mobilidade Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '1ac0e181-84c4-4e46-ae2f-b0661a65466d', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'cb2d5bdf-134b-48cf-b227-10d95ce47d0a', 'Morgan Toledo', '5511971000045', 'aluno.morgan.toledo.45@shaipados.com',
    'Consultoria Mensal: Treino Funcional & Mobilidade', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Anatômica (Semana 2 de 4)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/1ac0e181-84c4-4e46-ae2f-b0661a65466d', '00020126580014br.gov.bcb.pix01361ac0e181-84c4-4e46-ae2f-b0661a65466d520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [46/50] Ingrid Becker
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'be652a59-f8ed-4d13-ba69-9b708c708498', 'authenticated', 'authenticated', 'aluno.ingrid.becker.46@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Ingrid Becker", "role": "client", "roles": ["client"], "phone": "5511971000046"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'be652a59-f8ed-4d13-ba69-9b708c708498', 'client', ARRAY['client'], 'Ingrid Becker', 'aluno.ingrid.becker.46@shaipados.com', '5511971000046', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    54, 0.95, 37, 60.0, 169,
    'Histórico de tendinite no bíceps braquial direito.', true, 'Mesociclo: Potência & Hipertrofia Miofibrilar (Semana 5 de 6) | Inativo há 0 dias', '✅ Treino em dia (Potência & Hipertrofia Miofibrilar - Semana 5 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '98befd3c-fd67-499d-bc3e-7e93ba619845', 'be652a59-f8ed-4d13-ba69-9b708c708498', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Definição de Costas e Ombros & Resistência no Nado', 'Avançado', 4,
    'Academia Convencional', 'Histórico de tendinite no bíceps braquial direito.', 'Musculação Estética & Natação', 'female',
    37, 60.0, 169, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '0994e931-0782-46d5-845b-48351d7f345a', 'be652a59-f8ed-4d13-ba69-9b708c708498', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Potência & Hipertrofia Miofibrilar (Semana 5 de 6) — Musculação Estética & Natação',
    'Mesociclo: Potência & Hipertrofia Miofibrilar (Semana 5 de 6). Restrições: Histórico de tendinite no bíceps braquial direito.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Estética & Natação Split A", "exercises": [{"name": "Puxada Frontal com Barra Pegada Média", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Remada Cavalinho com Apoio", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Face Pull no Cabo", "sets": 4, "reps": "15", "rest_seconds": 45}, {"name": "Elevação Pélvica com Barra", "sets": 4, "reps": "10-12", "rest_seconds": 75}]}, {"split_identifier": "B", "split_name": "Musculação Estética & Natação Split B", "exercises": [{"name": "Agachamento Frontal no Smith", "sets": 4, "reps": "10", "rest_seconds": 75}, {"name": "Stiff com Halteres", "sets": 4, "reps": "10", "rest_seconds": 60}, {"name": "Supino Reto com Halteres", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Prancha Lateral com Elevação de Perna", "sets": 3, "reps": "30s cada lado", "rest_seconds": 45}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'c5d1d7dc-7908-4ab8-a987-77b9dbabdaa8', 'be652a59-f8ed-4d13-ba69-9b708c708498', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '0994e931-0782-46d5-845b-48351d7f345a',
    'A', 'Musculação Estética & Natação Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '9cacd420-e9f7-4b3b-a219-0d25bb4b7e19', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'be652a59-f8ed-4d13-ba69-9b708c708498', 'Ingrid Becker', '5511971000046', 'aluno.ingrid.becker.46@shaipados.com',
    'Consultoria Mensal: Musculação Estética & Natação', 'Ciclo individualizado 30 dias. Mesociclo: Potência & Hipertrofia Miofibrilar (Semana 5 de 6)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/9cacd420-e9f7-4b3b-a219-0d25bb4b7e19', '00020126580014br.gov.bcb.pix01369cacd420-e9f7-4b3b-a219-0d25bb4b7e19520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [47/50] Valéria Dorneles
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '26a6ba34-9a80-4c5f-9abf-898ab7757acf', 'authenticated', 'authenticated', 'aluno.valeria.dorneles.47@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Valéria Dorneles", "role": "client", "roles": ["client"], "phone": "5511971000047"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '26a6ba34-9a80-4c5f-9abf-898ab7757acf', 'client', ARRAY['client'], 'Valéria Dorneles', 'aluno.valeria.dorneles.47@shaipados.com', '5511971000047', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=300&fit=crop&crop=face',
    22, 0.95, 58, 68.0, 161,
    'Artrose patelofemoral nos joelhos. Movimentos sempre guiados e sem impacto.', true, 'Mesociclo: Adaptação Funcional (Semana 3 de 6) | Inativo há 2 dias', '✅ Treino em dia (Adaptação Funcional - Semana 3 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '584aadab-c0b1-4109-ae27-159842a224d6', '26a6ba34-9a80-4c5f-9abf-898ab7757acf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Fortalecimento para Artrose e Bem-Estar', 'Iniciante', 4,
    'Academia Convencional', 'Artrose patelofemoral nos joelhos. Movimentos sempre guiados e sem impacto.', 'Musculação Funcional & Mobilidade', 'female',
    58, 68.0, 161, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '78e25ea5-a6a9-4382-a84f-e5be2d39c5eb', '26a6ba34-9a80-4c5f-9abf-898ab7757acf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Adaptação Funcional (Semana 3 de 6) — Musculação Funcional & Mobilidade',
    'Mesociclo: Adaptação Funcional (Semana 3 de 6). Restrições: Artrose patelofemoral nos joelhos. Movimentos sempre guiados e sem impacto.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação Funcional & Mobilidade Split A", "exercises": [{"name": "Leg Press Horizontal Leve", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Extensora (Últimos 30° apenas)", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Puxada Frontal Fechada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Ponte de Glúteo no Chão", "sets": 3, "reps": "15", "rest_seconds": 45}]}, {"split_identifier": "B", "split_name": "Musculação Funcional & Mobilidade Split B", "exercises": [{"name": "Supino com Halteres Leves", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Remada Baixa com Barra Romana", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Cadeira Abdutora", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Alongamento Suave de Coluna e Quadris", "sets": 1, "reps": "15 min", "rest_seconds": 0}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'df6211ea-3001-4334-a7f8-90f06e4204bf', '26a6ba34-9a80-4c5f-9abf-898ab7757acf', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '78e25ea5-a6a9-4382-a84f-e5be2d39c5eb',
    'A', 'Musculação Funcional & Mobilidade Split A', 4, 4,
    '2026-10-28T14:33:19.946496+00:00'::timestamptz,
    '2026-10-28T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-28T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '06ab7261-bbf1-4f29-9007-94ae2ca4cb98', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '26a6ba34-9a80-4c5f-9abf-898ab7757acf', 'Valéria Dorneles', '5511971000047', 'aluno.valeria.dorneles.47@shaipados.com',
    'Consultoria Mensal: Musculação Funcional & Mobilidade', 'Ciclo individualizado 30 dias. Mesociclo: Adaptação Funcional (Semana 3 de 6)',
    19000, 950, 18050,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/06ab7261-bbf1-4f29-9007-94ae2ca4cb98', '00020126580014br.gov.bcb.pix013606ab7261-bbf1-4f29-9007-94ae2ca4cb98520400005303986540190.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [48/50] Cristiano Lourenço
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', 'authenticated', 'authenticated', 'aluno.cristiano.lourenco.48@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Cristiano Lourenço", "role": "client", "roles": ["client"], "phone": "5511971000048"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', 'client', ARRAY['client'], 'Cristiano Lourenço', 'aluno.cristiano.lourenco.48@shaipados.com', '5511971000048', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&fit=crop&crop=face',
    49, 0.95, 40, 95.0, 182,
    'Sem restrições.', true, 'Mesociclo: Sobrecarga de Força & Densidade (Semana 5 de 6) | Inativo há 0 dias', '✅ Treino em dia (Sobrecarga de Força & Densidade - Semana 5 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '4858ad16-e577-4493-b6af-e43cf69f4e23', '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Força Máxima & Volume Muscular de Peitoral e Dorsal', 'Avançado', 4,
    'Academia Convencional', 'Sem restrições.', 'Powerbuilding & Treino de Força', 'male',
    40, 95.0, 182, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Avançado em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '21729724-333a-4f9e-840e-a6eacdc595a1', '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Sobrecarga de Força & Densidade (Semana 5 de 6) — Powerbuilding & Treino de Força',
    'Mesociclo: Sobrecarga de Força & Densidade (Semana 5 de 6). Restrições: Sem restrições.',
    '{"splits": [{"split_identifier": "A", "split_name": "Powerbuilding & Treino de Força Split A", "exercises": [{"name": "Supino Reto com Barra (Pirâmide)", "sets": 5, "reps": "12-10-8-6-4", "rest_seconds": 120}, {"name": "Supino Inclinado com Halteres Pesados", "sets": 4, "reps": "8-10", "rest_seconds": 90}, {"name": "Crucifixo na Polia", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Tríceps Paralelas", "sets": 3, "reps": "10", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Powerbuilding & Treino de Força Split B", "exercises": [{"name": "Levantamento Terra com Barra", "sets": 4, "reps": "6", "rest_seconds": 120}, {"name": "Puxada Alta com Triângulo", "sets": 4, "reps": "8-10", "rest_seconds": 75}, {"name": "Remada Curvada com Barra Pegada Supinada", "sets": 4, "reps": "8", "rest_seconds": 75}, {"name": "Rosca Direta com Barra Reta", "sets": 3, "reps": "10", "rest_seconds": 60}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    'ddd57297-95e0-45ba-9c8a-2c8c812b4808', '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '21729724-333a-4f9e-840e-a6eacdc595a1',
    'A', 'Powerbuilding & Treino de Força Split A', 4, 4,
    '2026-10-30T14:33:19.946496+00:00'::timestamptz,
    '2026-10-30T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-30T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    'ef05d003-e511-4341-a690-c7f249c8560b', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '1b8b988d-0a91-4bc6-abe8-a9863fbf0cda', 'Cristiano Lourenço', '5511971000048', 'aluno.cristiano.lourenco.48@shaipados.com',
    'Consultoria Mensal: Powerbuilding & Treino de Força', 'Ciclo individualizado 30 dias. Mesociclo: Sobrecarga de Força & Densidade (Semana 5 de 6)',
    25000, 1250, 23750,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/ef05d003-e511-4341-a690-c7f249c8560b', '00020126580014br.gov.bcb.pix0136ef05d003-e511-4341-a690-c7f249c8560b520400005303986540250.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [49/50] Gisele Farias
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    'f905b849-6bd8-454a-9ab6-fe2729319501', 'authenticated', 'authenticated', 'aluno.gisele.farias.49@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Gisele Farias", "role": "client", "roles": ["client"], "phone": "5511971000049"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    'f905b849-6bd8-454a-9ab6-fe2729319501', 'client', ARRAY['client'], 'Gisele Farias', 'aluno.gisele.farias.49@shaipados.com', '5511971000049', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=300&fit=crop&crop=face',
    15, 0.95, 36, 64.0, 167,
    'Hipermobilidade articular nos ombros e tornozelos. Evitar hiperextensão articular e priorizar ativação isométrica.', true, 'Mesociclo: Estabilização Escapular e Pélvica (Semana 4 de 8) | Inativo há 1 dias', '✅ Treino em dia (Estabilização Escapular e Pélvica - Semana 4 de 8)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    'b5b8b77c-d066-4dbe-805c-10c108a9284a', 'f905b849-6bd8-454a-9ab6-fe2729319501', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Estabilidade Articular & Controle Postural', 'Intermediário', 4,
    'Academia Convencional', 'Hipermobilidade articular nos ombros e tornozelos. Evitar hiperextensão articular e priorizar ativação isométrica.', 'Pilates Clínico & Força para Hipermobilidade', 'female',
    36, 64.0, 167, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Intermediário em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    'be335bb7-9e1b-41b9-96b9-a56d16a3aaac', 'f905b849-6bd8-454a-9ab6-fe2729319501', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Estabilização Escapular e Pélvica (Semana 4 de 8) — Pilates Clínico & Força para Hipermobilidade',
    'Mesociclo: Estabilização Escapular e Pélvica (Semana 4 de 8). Restrições: Hipermobilidade articular nos ombros e tornozelos. Evitar hiperextensão articular e priorizar ativação isométrica.',
    '{"splits": [{"split_identifier": "A", "split_name": "Pilates Clínico & Força para Hipermobilidade Split A", "exercises": [{"name": "Fortalecimento de Manguito com Elástico", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Prancha Lateral com Joelho no Solo", "sets": 3, "reps": "30s", "rest_seconds": 45}, {"name": "Agachamento Isométrico na Parede (Wall Sit)", "sets": 3, "reps": "40s", "rest_seconds": 60}, {"name": "Remada Neutra com Halteres Controlada", "sets": 3, "reps": "12", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Pilates Clínico & Força para Hipermobilidade Split B", "exercises": [{"name": "Ponte Unipodal com Estabilização de Pelve", "sets": 3, "reps": "10/lado", "rest_seconds": 45}, {"name": "Deadbug com Foco em Respiração Diafragmática", "sets": 3, "reps": "10/lado", "rest_seconds": 45}, {"name": "Farmer Walk com Carga Moderada (Postura Ativa)", "sets": 3, "reps": "30s", "rest_seconds": 60}, {"name": "Mobilidade Ativa de Tornozelo sem Carga Excessiva", "sets": 2, "reps": "10", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '86cdaf88-9ee7-4b91-aa50-d13129f0f7a3', 'f905b849-6bd8-454a-9ab6-fe2729319501', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'be335bb7-9e1b-41b9-96b9-a56d16a3aaac',
    'A', 'Pilates Clínico & Força para Hipermobilidade Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '83b460b8-c32b-4bf8-ab43-6e489721fcc9', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'f905b849-6bd8-454a-9ab6-fe2729319501', 'Gisele Farias', '5511971000049', 'aluno.gisele.farias.49@shaipados.com',
    'Consultoria Mensal: Pilates Clínico & Força para Hipermobilidade', 'Ciclo individualizado 30 dias. Mesociclo: Estabilização Escapular e Pélvica (Semana 4 de 8)',
    21000, 1050, 19950,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/83b460b8-c32b-4bf8-ab43-6e489721fcc9', '00020126580014br.gov.bcb.pix013683b460b8-c32b-4bf8-ab43-6e489721fcc9520400005303986540210.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;


-- [50/50] Otávio Fontes
INSERT INTO auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES (
    '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', 'authenticated', 'authenticated', 'aluno.otavio.fontes.50@shaipados.com',
    '$2a$10$wK1m.9UqjB5yE.jD5uD2OuGz7xH9yQ2r1jA0zE6yA1mC1mY1pC0q2', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, '{"full_name": "Otávio Fontes", "role": "client", "roles": ["client"], "phone": "5511971000050"}'::jsonb, now(), now()
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.profiles (
    id, role, roles, full_name, email, phone, trainer_id,
    subscription_status, subscription_valid_until, avatar_url, photo_url,
    current_streak, daily_goal_progress, age, weight_kg, height_cm,
    clinical_restrictions, has_completed_anamnesis, status_message, alert_message,
    is_admin, is_vip, created_at, updated_at
) VALUES (
    '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', 'client', ARRAY['client'], 'Otávio Fontes', 'aluno.otavio.fontes.50@shaipados.com', '5511971000050', '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    'active', '2026-11-29T15:23:19.946496+00:00'::timestamptz, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300&fit=crop&crop=face',
    26, 0.95, 71, 74.0, 173,
    'Artrose de quadril leve e histórico de vertigem postural. Evitar movimentos bruscos de cabeça e exercícios livres instáveis.', true, 'Mesociclo: Força e Equilíbrio Sênior (Semana 2 de 6) | Inativo há 1 dias', '✅ Treino em dia (Força e Equilíbrio Sênior - Semana 2 de 6)',
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


INSERT INTO public.anamnesis (
    id, client_id, trainer_id, objective, training_level, days_per_week,
    workout_location, injuries_or_restrictions, training_style, biological_sex,
    age, weight, height, daily_activity, sleep_hours, stress_level,
    training_history, available_equipment, created_at, updated_at
) VALUES (
    '39eae8c3-08d1-469e-be0c-29cc55fc33c6', '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Preservação de Massa Muscular (Anti-Sarcopenia) e Equilíbrio', 'Iniciante', 4,
    'Academia Convencional', 'Artrose de quadril leve e histórico de vertigem postural. Evitar movimentos bruscos de cabeça e exercícios livres instáveis.', 'Musculação para Terceira Idade & Autonomia', 'male',
    71, 74.0, 173, 'Atividade Moderada', '7 a 8 horas', 'Médio',
    'Iniciante em musculação e preparação física.', '["Halteres", "Barras", "Polias", "Máquinas Guiadas"]'::jsonb,
    now(), now()
) ON CONFLICT (id) DO UPDATE SET
    objective = EXCLUDED.objective,
    injuries_or_restrictions = EXCLUDED.injuries_or_restrictions,
    updated_at = now();


INSERT INTO public.workouts (
    id, client_id, trainer_id, title, notes_for_trainer, plan_json, is_active, created_at, updated_at
) VALUES (
    '71695a8c-32f4-4ba3-a693-d60498b89c00', '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', '6f645308-f1b2-4d73-ac45-9890c27e20d4', 'Ficha Força e Equilíbrio Sênior (Semana 2 de 6) — Musculação para Terceira Idade & Autonomia',
    'Mesociclo: Força e Equilíbrio Sênior (Semana 2 de 6). Restrições: Artrose de quadril leve e histórico de vertigem postural. Evitar movimentos bruscos de cabeça e exercícios livres instáveis.',
    '{"splits": [{"split_identifier": "A", "split_name": "Musculação para Terceira Idade & Autonomia Split A", "exercises": [{"name": "Sentar e Levantar da Cadeira com Apoio", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Puxada Baixa Articulada", "sets": 3, "reps": "12", "rest_seconds": 60}, {"name": "Elevação de Panturrilha no Chão com Apoio", "sets": 3, "reps": "15", "rest_seconds": 45}, {"name": "Rosca com Halter Sentado", "sets": 3, "reps": "10", "rest_seconds": 60}]}, {"split_identifier": "B", "split_name": "Musculação para Terceira Idade & Autonomia Split B", "exercises": [{"name": "Leg Press Horizontal Guiado (Carga Leve)", "sets": 3, "reps": "10", "rest_seconds": 75}, {"name": "Supino Vertical na Máquina Guiada", "sets": 3, "reps": "10", "rest_seconds": 60}, {"name": "Caminhada em Linha Reta com Apoio Unipodal Guiado", "sets": 3, "reps": "10 passos", "rest_seconds": 45}, {"name": "Alongamento Suave de Isquiotibiais Sentado", "sets": 2, "reps": "30s", "rest_seconds": 30}]}]}'::jsonb, true, now(), now()
) ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    notes_for_trainer = EXCLUDED.notes_for_trainer,
    plan_json = EXCLUDED.plan_json,
    is_active = EXCLUDED.is_active,
    updated_at = now();


INSERT INTO public.workout_sessions (
    id, client_id, trainer_id, workout_id, split_identifier, split_name,
    total_exercises, completed_exercises, started_at, completed_at, duration_seconds, created_at
) VALUES (
    '88e6c349-f0f9-42b4-aef6-87da0de32472', '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '71695a8c-32f4-4ba3-a693-d60498b89c00',
    'A', 'Musculação para Terceira Idade & Autonomia Split A', 4, 4,
    '2026-10-29T14:33:19.946496+00:00'::timestamptz,
    '2026-10-29T15:23:19.946496+00:00'::timestamptz,
    3000, '2026-10-29T15:23:19.946496+00:00'::timestamptz
) ON CONFLICT (id) DO NOTHING;


INSERT INTO public.student_invoices (
    id, trainer_id, student_id, student_name, student_phone, student_email,
    title, description, amount_cents, platform_fee_cents, net_amount_cents,
    status, due_date, paid_at, payment_method, payment_link, pix_copy_paste, created_at
) VALUES (
    '2e083d4b-510f-4fda-9b78-7f361c1adf62', '6f645308-f1b2-4d73-ac45-9890c27e20d4', '23bfa6b9-66f1-48e0-b11a-c33e489c7c18', 'Otávio Fontes', '5511971000050', 'aluno.otavio.fontes.50@shaipados.com',
    'Consultoria Mensal: Musculação para Terceira Idade & Autonomia', 'Ciclo individualizado 30 dias. Mesociclo: Força e Equilíbrio Sênior (Semana 2 de 6)',
    18000, 900, 17100,
    'paid', '2026-11-24', '2026-10-25T15:23:19.946496+00:00', 'pix',
    'https://shaipados.com/pay/2e083d4b-510f-4fda-9b78-7f361c1adf62', '00020126580014br.gov.bcb.pix01362e083d4b-510f-4fda-9b78-7f361c1adf62520400005303986540180.005802BR5916MRCOACHPLATAFORMA6009SAOPAULO62070503***6304', now()
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    due_date = EXCLUDED.due_date,
    paid_at = EXCLUDED.paid_at,
    amount_cents = EXCLUDED.amount_cents;

COMMIT;
