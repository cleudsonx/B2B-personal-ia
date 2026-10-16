-- Migration: 20261030_trainer_whatsapp_logs.sql
-- Registra telemetria e histórico transparente de interações do robô do WhatsApp e IA

CREATE TABLE IF NOT EXISTS public.trainer_whatsapp_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    student_name TEXT NOT NULL,
    student_phone TEXT,
    channel TEXT NOT NULL DEFAULT 'whatsapp', -- 'whatsapp' ou 'in_app'
    message_in TEXT NOT NULL,
    message_out TEXT NOT NULL,
    tokens_used INTEGER DEFAULT 0,
    cost_type TEXT DEFAULT 'free', -- 'free' ou 'ai_gemini'
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trainer_whatsapp_logs_trainer 
    ON public.trainer_whatsapp_logs(trainer_id, created_at DESC);

ALTER TABLE public.trainer_whatsapp_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trainers read own whatsapp logs" ON public.trainer_whatsapp_logs;
CREATE POLICY "Trainers read own whatsapp logs" 
    ON public.trainer_whatsapp_logs FOR SELECT 
    USING (auth.uid() = trainer_id);

DROP POLICY IF EXISTS "Service role manages whatsapp logs" ON public.trainer_whatsapp_logs;
CREATE POLICY "Service role manages whatsapp logs" 
    ON public.trainer_whatsapp_logs FOR ALL 
    USING (true)
    WITH CHECK (true);

