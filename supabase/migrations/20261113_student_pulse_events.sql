-- ==============================================================================
-- 20261113_student_pulse_events.sql
-- Barramento de Eventos de Alunos (Mr. Coach AI 3.0 - Live Student Pulse)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.student_pulse_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL, -- 'pain_alert', 'exercise_adapted', 'workout_completed', 'ai_doubt', 'streak_milestone', 'inactivity_risk'
    severity TEXT NOT NULL DEFAULT 'info', -- 'critical', 'warning', 'info', 'success'
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    viewed_by_trainer BOOLEAN DEFAULT FALSE,
    action_taken TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices otimizados para busca do painel do treinador e filtros por aluno
CREATE INDEX IF NOT EXISTS idx_student_pulse_trainer_viewed 
    ON public.student_pulse_events(trainer_id, viewed_by_trainer, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_student_pulse_student 
    ON public.student_pulse_events(student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_student_pulse_type 
    ON public.student_pulse_events(event_type, severity);

-- Habilita RLS
ALTER TABLE public.student_pulse_events ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
DROP POLICY IF EXISTS "Trainers can view own students pulse events" ON public.student_pulse_events;
CREATE POLICY "Trainers can view own students pulse events"
    ON public.student_pulse_events FOR SELECT
    USING (trainer_id = auth.uid() OR public.current_user_has_role('trainer'));

DROP POLICY IF EXISTS "Trainers can update own students pulse events" ON public.student_pulse_events;
CREATE POLICY "Trainers can update own students pulse events"
    ON public.student_pulse_events FOR UPDATE
    USING (trainer_id = auth.uid());

DROP POLICY IF EXISTS "Clients can insert own pulse events" ON public.student_pulse_events;
CREATE POLICY "Clients can insert own pulse events"
    ON public.student_pulse_events FOR INSERT
    WITH CHECK (student_id = auth.uid() OR public.current_user_has_role('client'));

DROP POLICY IF EXISTS "Clients can view own pulse events" ON public.student_pulse_events;
CREATE POLICY "Clients can view own pulse events"
    ON public.student_pulse_events FOR SELECT
    USING (student_id = auth.uid());

