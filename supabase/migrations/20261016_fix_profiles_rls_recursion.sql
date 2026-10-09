-- A policy de profiles consultava a propria profiles (erro 42P17: infinite recursion).
-- A leitura do trainer_id passa a ser feita por funcao SECURITY DEFINER, que nao reaplica RLS.

CREATE OR REPLACE FUNCTION public.current_user_trainer_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT p.trainer_id FROM public.profiles p WHERE p.id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.current_user_trainer_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_trainer_id() TO authenticated, service_role;

DROP POLICY IF EXISTS "Clients can view their assigned trainer" ON public.profiles;
CREATE POLICY "Clients can view their assigned trainer" ON public.profiles
    FOR SELECT USING (
        id = public.current_user_trainer_id()
        AND public.current_user_has_role('client')
    );

DROP POLICY IF EXISTS "Clients can create adaptation logs" ON public.adaptation_logs;
CREATE POLICY "Clients can create adaptation logs" ON public.adaptation_logs
    FOR INSERT WITH CHECK (
        client_id = auth.uid()
        AND public.current_user_has_role('client')
        AND trainer_id = public.current_user_trainer_id()
    );
