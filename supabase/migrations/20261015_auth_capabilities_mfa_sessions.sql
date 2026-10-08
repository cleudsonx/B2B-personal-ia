BEGIN;

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS roles TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS session_revoked_at TIMESTAMPTZ;

UPDATE public.profiles
SET roles = ARRAY[role]
WHERE cardinality(roles) = 0;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_role TEXT := COALESCE(NEW.raw_user_meta_data->>'role', 'client');
BEGIN
    INSERT INTO public.profiles (
        id, full_name, role, roles, phone, trainer_id, username, bio, specialties,
        public_whatsapp, photo_url, avatar_url, professional_document
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
        v_role,
        ARRAY[v_role],
        NEW.raw_user_meta_data->>'phone',
        NULLIF(NEW.raw_user_meta_data->>'trainer_id', '')::UUID,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'bio',
        COALESCE(
            ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'specialties')),
            '{}'::TEXT[]
        ),
        NEW.raw_user_meta_data->>'public_whatsapp',
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
        COALESCE(NEW.raw_user_meta_data->>'photo_url', NEW.raw_user_meta_data->>'avatar_url'),
        NEW.raw_user_meta_data->>'professional_document'
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        username = COALESCE(EXCLUDED.username, public.profiles.username),
        bio = COALESCE(EXCLUDED.bio, public.profiles.bio),
        specialties = CASE
            WHEN cardinality(EXCLUDED.specialties) > 0 THEN EXCLUDED.specialties
            ELSE public.profiles.specialties
        END,
        public_whatsapp = COALESCE(EXCLUDED.public_whatsapp, public.profiles.public_whatsapp),
        photo_url = COALESCE(EXCLUDED.photo_url, public.profiles.photo_url),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.profiles.avatar_url),
        professional_document = COALESCE(EXCLUDED.professional_document, public.profiles.professional_document),
        updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_current_session_valid()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_revoked_at TIMESTAMPTZ;
    v_issued_at NUMERIC;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT p.session_revoked_at INTO v_revoked_at
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF v_revoked_at IS NULL THEN
        RETURN TRUE;
    END IF;

    v_issued_at := NULLIF(auth.jwt()->>'iat', '')::NUMERIC;
    RETURN v_issued_at IS NOT NULL
       AND to_timestamp(v_issued_at::DOUBLE PRECISION) > v_revoked_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_user_has_role(p_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_has_role BOOLEAN;
BEGIN
    IF NOT public.is_current_session_valid() THEN
        RETURN FALSE;
    END IF;

    SELECT (p.role = p_role OR p_role = ANY(p.roles))
    INTO v_has_role
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF NOT COALESCE(v_has_role, FALSE) THEN
        RETURN FALSE;
    END IF;

    RETURN p_role <> 'trainer' OR auth.jwt()->>'aal' = 'aal2';
END;
$$;

REVOKE ALL ON FUNCTION public.is_current_session_valid() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_session_valid() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.current_user_has_role(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_has_role(TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.protect_profile_privilege_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.role() = 'authenticated' THEN
        IF NEW.role IS DISTINCT FROM OLD.role OR NEW.roles IS DISTINCT FROM OLD.roles THEN
            RAISE EXCEPTION 'Os papéis do perfil só podem ser alterados por operações autorizadas.';
        END IF;
        IF NEW.session_revoked_at IS DISTINCT FROM OLD.session_revoked_at THEN
            RAISE EXCEPTION 'A revogação de sessões só pode ser realizada pelo backend.';
        END IF;
        IF NEW.trainer_id IS DISTINCT FROM OLD.trainer_id THEN
            RAISE EXCEPTION 'O vínculo de treinador só pode ser alterado por convite autorizado.';
        END IF;
        IF NEW.subscription_status IS DISTINCT FROM OLD.subscription_status OR
           NEW.subscription_valid_until IS DISTINCT FROM OLD.subscription_valid_until THEN
            RAISE EXCEPTION 'Status e vigência de assinatura só podem ser manipulados pelo backend de faturamento.';
        END IF;
        IF NOT (OLD.role = 'trainer' OR 'trainer' = ANY(COALESCE(OLD.roles, ARRAY[]::TEXT[]))) AND (
            NEW.username IS DISTINCT FROM OLD.username OR
            NEW.bio IS DISTINCT FROM OLD.bio OR
            NEW.specialties IS DISTINCT FROM OLD.specialties OR
            NEW.public_whatsapp IS DISTINCT FROM OLD.public_whatsapp OR
            NEW.photo_url IS DISTINCT FROM OLD.photo_url OR
            NEW.professional_document IS DISTINCT FROM OLD.professional_document OR
            NEW.public_directory_enabled IS DISTINCT FROM OLD.public_directory_enabled
        ) THEN
            RAISE EXCEPTION 'Somente treinadores podem alterar os campos da vitrine pública.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_privilege_escalation ON public.profiles;
DROP TRIGGER IF EXISTS trg_protect_profile_escalation ON public.profiles;
CREATE TRIGGER protect_profile_privilege_escalation
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_privilege_escalation();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anamnesis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adaptation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gamification_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_ai_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view trainers profile" ON public.profiles;
DROP POLICY IF EXISTS "Public can view trainer profiles" ON public.profiles;
DROP POLICY IF EXISTS "Clients can view their trainer profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id AND public.is_current_session_valid());
DROP POLICY IF EXISTS "Trainers can view their associated clients" ON public.profiles;
CREATE POLICY "Trainers can view their associated clients" ON public.profiles
    FOR SELECT USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Clients can view their assigned trainer" ON public.profiles;
CREATE POLICY "Clients can view their assigned trainer" ON public.profiles
    FOR SELECT USING (
        id = (SELECT p.trainer_id FROM public.profiles p WHERE p.id = auth.uid())
        AND public.current_user_has_role('client')
    );
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id AND public.is_current_session_valid())
    WITH CHECK (auth.uid() = id AND public.is_current_session_valid());

DROP POLICY IF EXISTS "Trainers manage workouts" ON public.workouts;
CREATE POLICY "Trainers manage workouts" ON public.workouts
    FOR ALL USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'))
    WITH CHECK (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Clients can view their workouts" ON public.workouts;
CREATE POLICY "Clients can view their workouts" ON public.workouts
    FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));

DROP POLICY IF EXISTS "Trainers manage anamnesis" ON public.anamnesis;
CREATE POLICY "Trainers manage anamnesis" ON public.anamnesis
    FOR ALL USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'))
    WITH CHECK (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Clients can view their own anamnesis" ON public.anamnesis;
CREATE POLICY "Clients can view their own anamnesis" ON public.anamnesis
    FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));

DROP POLICY IF EXISTS "Clients can create adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can create adaptation logs" ON public.adaptation_logs
    FOR INSERT WITH CHECK (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND trainer_id = (
            SELECT p.trainer_id
            FROM public.profiles p
            WHERE p.id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "Clients can view their adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can view their adaptation logs" ON public.adaptation_logs
    FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
DROP POLICY IF EXISTS "Trainers can view students adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Trainers can view students adaptation logs" ON public.adaptation_logs
    FOR SELECT USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Trainers can update adaptation logs acknowledgment" ON public.adaptation_logs;
CREATE POLICY "Trainers can update adaptation logs acknowledgment" ON public.adaptation_logs
    FOR UPDATE USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'))
    WITH CHECK (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));

DROP POLICY IF EXISTS "Clients can view own gamification stats" ON public.gamification_stats;
CREATE POLICY "Clients can view own gamification stats" ON public.gamification_stats
    FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
DROP POLICY IF EXISTS "Trainers can view their clients gamification stats" ON public.gamification_stats;
CREATE POLICY "Trainers can view their clients gamification stats" ON public.gamification_stats
    FOR SELECT USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));

DROP POLICY IF EXISTS "Treinadores leem sua própria assinatura" ON public.subscriptions;
CREATE POLICY "Treinadores leem sua própria assinatura" ON public.subscriptions
    FOR SELECT USING (auth.uid() = trainer_id AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Treinadores modificam sua própria assinatura" ON public.subscriptions;
CREATE POLICY "Treinadores modificam sua própria assinatura" ON public.subscriptions
    FOR ALL USING (auth.uid() = trainer_id AND public.current_user_has_role('trainer'))
    WITH CHECK (auth.uid() = trainer_id AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Trainers read their own AI usage" ON public.trainer_ai_usage;
CREATE POLICY "Trainers read their own AI usage" ON public.trainer_ai_usage
    FOR SELECT USING (auth.uid() = trainer_id AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "Treinadores leem suas proprias sessoes" ON public.checkout_sessions;
CREATE POLICY "Treinadores leem suas proprias sessoes" ON public.checkout_sessions
    FOR SELECT USING (auth.uid() = trainer_id AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "trainer_read_own_invites" ON public.invite_tokens;
CREATE POLICY "trainer_read_own_invites" ON public.invite_tokens
    FOR SELECT TO authenticated
    USING (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));
DROP POLICY IF EXISTS "trainer_create_own_invites" ON public.invite_tokens;
CREATE POLICY "trainer_create_own_invites" ON public.invite_tokens
    FOR INSERT TO authenticated
    WITH CHECK (trainer_id = auth.uid() AND public.current_user_has_role('trainer'));

DROP POLICY IF EXISTS "Clients insert own sessions" ON public.workout_sessions;
CREATE POLICY "Clients insert own sessions" ON public.workout_sessions
    FOR INSERT WITH CHECK (client_id = auth.uid() AND public.current_user_has_role('client'));
DROP POLICY IF EXISTS "Clients read own sessions" ON public.workout_sessions;
CREATE POLICY "Clients read own sessions" ON public.workout_sessions
    FOR SELECT USING (client_id = auth.uid() AND public.current_user_has_role('client'));
DROP POLICY IF EXISTS "Trainers read their students sessions" ON public.workout_sessions;
CREATE POLICY "Trainers read their students sessions" ON public.workout_sessions
    FOR SELECT USING (
        public.current_user_has_role('trainer')
        AND EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = workout_sessions.client_id AND p.trainer_id = auth.uid()
        )
    );

COMMIT;