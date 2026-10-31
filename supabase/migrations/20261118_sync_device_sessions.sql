-- =============================================================================
-- Migration: 20261118_sync_device_sessions.sql
-- Sincronização automática entre auth.sessions e public.user_device_sessions
-- =============================================================================

CREATE OR REPLACE FUNCTION public.sync_my_device_sessions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    curr_user_id UUID := auth.uid();
    sess RECORD;
    detected_platform TEXT;
    detected_name TEXT;
    ip_str TEXT;
BEGIN
    IF curr_user_id IS NULL THEN
        RETURN;
    END IF;

    FOR sess IN 
        SELECT id, ip, user_agent, created_at, updated_at
        FROM auth.sessions
        WHERE user_id = curr_user_id
    LOOP
        -- Detecta plataforma e nome a partir do User-Agent
        IF sess.user_agent ILIKE '%iPhone%' THEN
            detected_platform := 'iOS';
            detected_name := 'Apple iPhone';
        ELSIF sess.user_agent ILIKE '%iPad%' THEN
            detected_platform := 'iOS';
            detected_name := 'Apple iPad';
        ELSIF sess.user_agent ILIKE '%Android%' THEN
            detected_platform := 'Android';
            detected_name := 'Dispositivo Android';
        ELSIF sess.user_agent ILIKE '%Windows%' THEN
            detected_platform := 'Windows';
            detected_name := 'Computador Windows';
        ELSIF sess.user_agent ILIKE '%Macintosh%' OR sess.user_agent ILIKE '%Mac OS%' THEN
            detected_platform := 'macOS';
            detected_name := 'Apple Mac';
        ELSIF sess.user_agent ILIKE '%Linux%' THEN
            detected_platform := 'Linux';
            detected_name := 'Computador Linux';
        ELSE
            detected_platform := 'Web';
            detected_name := 'Navegador Web';
        END IF;

        IF sess.user_agent ILIKE '%Chrome%' AND sess.user_agent NOT ILIKE '%Edg%' THEN
            detected_name := detected_name || ' (Chrome)';
        ELSIF sess.user_agent ILIKE '%Safari%' AND sess.user_agent NOT ILIKE '%Chrome%' THEN
            detected_name := detected_name || ' (Safari)';
        ELSIF sess.user_agent ILIKE '%Firefox%' THEN
            detected_name := detected_name || ' (Firefox)';
        ELSIF sess.user_agent ILIKE '%Edg%' THEN
            detected_name := detected_name || ' (Edge)';
        END IF;

        ip_str := host(sess.ip);
        IF ip_str IS NULL OR ip_str = '' THEN
            ip_str := '127.0.0.1';
        END IF;

        -- Se o usuário já tiver sessões registradas pelo app com device_id nativo,
        -- só inserimos a do auth.sessions se não houver colisão
        INSERT INTO public.user_device_sessions (
            user_id,
            device_id,
            device_name,
            platform,
            ip_address,
            location,
            user_agent,
            last_active_at,
            created_at,
            is_revoked
        )
        VALUES (
            curr_user_id,
            'auth_sess_' || sess.id::text,
            detected_name,
            detected_platform,
            ip_str,
            'Sessão Autenticada',
            COALESCE(sess.user_agent, 'Supabase Auth Session'),
            COALESCE(sess.updated_at, sess.created_at, now()),
            COALESCE(sess.created_at, now()),
            false
        )
        ON CONFLICT (user_id, device_id) DO UPDATE
        SET last_active_at = EXCLUDED.last_active_at,
            ip_address = EXCLUDED.ip_address;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_my_device_sessions() TO authenticated;
