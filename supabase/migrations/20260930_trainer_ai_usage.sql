CREATE TABLE IF NOT EXISTS public.trainer_ai_usage (
    trainer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    generations_used INTEGER NOT NULL DEFAULT 0 CHECK (generations_used >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (trainer_id, period_start)
);

ALTER TABLE public.trainer_ai_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Trainers read their own AI usage" ON public.trainer_ai_usage;
CREATE POLICY "Trainers read their own AI usage"
    ON public.trainer_ai_usage FOR SELECT
    USING (auth.uid() = trainer_id);

CREATE OR REPLACE FUNCTION public.increment_trainer_ai_usage(
    p_trainer_id UUID,
    p_period_start DATE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_generations_used INTEGER;
BEGIN
    INSERT INTO public.trainer_ai_usage (trainer_id, period_start, generations_used)
    VALUES (p_trainer_id, p_period_start, 1)
    ON CONFLICT (trainer_id, period_start)
    DO UPDATE SET
        generations_used = public.trainer_ai_usage.generations_used + 1,
        updated_at = now()
    RETURNING generations_used INTO v_generations_used;

    RETURN v_generations_used;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_trainer_ai_usage(UUID, DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_trainer_ai_usage(UUID, DATE) TO service_role;