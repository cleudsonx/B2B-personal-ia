-- ==============================================================================
-- FIX: Políticas RLS e Triggers para Integridade Aluno-Professor (Mr. Coach)
-- ==============================================================================

-- 1. Permitir que alunos leiam o perfil básico de seu professor vinculado
DROP POLICY IF EXISTS "Clients can view their trainer profile" ON public.profiles;
CREATE POLICY "Clients can view their trainer profile"
    ON public.profiles FOR SELECT
    USING (
        id IN (
            SELECT p.trainer_id 
            FROM public.profiles p 
            WHERE p.id = auth.uid()
        )
    );

-- 2. Permitir que o aluno insira sua própria anamnese (Vital para o fluxo de onboarding)
DROP POLICY IF EXISTS "Clients can insert their own anamnesis" ON public.anamnesis;
CREATE POLICY "Clients can insert their own anamnesis"
    ON public.anamnesis FOR INSERT
    WITH CHECK (client_id = auth.uid());

-- 3. Permitir que o aluno atualize sua própria anamnese
DROP POLICY IF EXISTS "Clients can update their own anamnesis" ON public.anamnesis;
CREATE POLICY "Clients can update their own anamnesis"
    ON public.anamnesis FOR UPDATE
    USING (client_id = auth.uid());

-- 4. Blindar o trigger de novo usuário para aceitar trainer_id nulo/inválido sem quebrar (Evita falha no SignUp)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_trainer_id UUID := NULL;
    v_raw_trainer TEXT;
BEGIN
    v_raw_trainer := NEW.raw_user_meta_data->>'trainer_id';
    
    -- Validação segura de formato UUID para evitar crash de casting (Erro 500)
    IF v_raw_trainer IS NOT NULL AND v_raw_trainer ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_trainer_id := v_raw_trainer::UUID;
    END IF;

    INSERT INTO public.profiles (id, full_name, role, phone, trainer_id)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuário'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'client'),
        NEW.raw_user_meta_data->>'phone',
        v_trainer_id
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        trainer_id = COALESCE(EXCLUDED.trainer_id, public.profiles.trainer_id),
        updated_at = now();
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

