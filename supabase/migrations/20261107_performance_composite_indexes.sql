-- Migration 20261107: Índices Compostos de Alta Performance para Cockpit e Vitrine
-- Otimiza consultas frequentes no Supabase eliminando Full Table Scans.

-- 1. Índice para busca de alunos por professor e role (Dashboard, Listagem e Radar)
CREATE INDEX IF NOT EXISTS idx_profiles_trainer_role 
ON public.profiles(trainer_id, role)
WHERE role = 'client';

-- 2. Índice para busca rápida de alertas biomecânicos pendentes por professor
CREATE INDEX IF NOT EXISTS idx_adaptation_logs_trainer_viewed 
ON public.adaptation_logs(trainer_id, viewed_by_trainer);

-- 3. Índice para agregação de treinos concluídos recentes por aluno
CREATE INDEX IF NOT EXISTS idx_workout_sessions_client_completed 
ON public.workout_sessions(client_id, completed_at DESC);

-- 4. Índice para Vitrine Pública: planos ativos ordenados do treinador
CREATE INDEX IF NOT EXISTS idx_consultancy_plans_trainer_active 
ON public.trainer_consultancy_plans(trainer_id, is_active, sort_order);

-- 5. Índice para Faturas e Carteira: faturas do treinador por status
CREATE INDEX IF NOT EXISTS idx_student_invoices_trainer_status 
ON public.student_invoices(trainer_id, status);

-- 6. Índice case-insensitive para busca de username na Vitrine Pública
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower 
ON public.profiles(LOWER(username))
WHERE username IS NOT NULL;

