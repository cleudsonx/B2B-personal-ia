-- ==============================================================================
-- FIX: Erro 42P17 (Infinite Recursion) na Tabela Profiles
-- ==============================================================================

-- 1. Removemos a política antiga que causava o loop infinito
DROP POLICY IF EXISTS "Clients can view their trainer profile" ON public.profiles;

-- 2. Criamos uma função segura (SECURITY DEFINER) para buscar o ID do professor
-- Isso faz com que a consulta não passe novamente pelas regras do RLS, quebrando o loop.
CREATE OR REPLACE FUNCTION public.get_my_trainer_id()
RETURNS UUID AS $$
  SELECT trainer_id FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- 3. Recriamos a política de forma otimizada e sem recursão
CREATE POLICY "Clients can view their trainer profile"
    ON public.profiles FOR SELECT
    USING (id = public.get_my_trainer_id());
