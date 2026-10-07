-- Fecha escrita client-side em public.subscriptions; mutações só via backend (service_role) ou RPCs SECURITY DEFINER.
-- Forward-only: não reverte a policy FOR ALL antiga.

DROP POLICY IF EXISTS "Treinadores modificam sua própria assinatura" ON public.subscriptions;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.subscriptions FROM anon, authenticated;

-- SELECT permanece, restrito pela policy "Treinadores leem sua própria assinatura" (auth.uid() = trainer_id).
GRANT SELECT ON TABLE public.subscriptions TO authenticated;
