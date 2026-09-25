-- ==============================================================================
-- Seed Data: supabase/seed.sql
-- Development and testing data for B2B Personal IA
-- ==============================================================================

-- Note: In Supabase local development, auth.users ids can be mocked or created via Supabase Studio.
-- Here is sample script to seed mock data once a trainer and client user are created.

-- Sample Trainer ID: '00000000-0000-0000-0000-000000000001'
-- Sample Client ID:  '00000000-0000-0000-0000-000000000002'

-- Exemplifying profile rows:
/*
INSERT INTO public.profiles (id, role, full_name, phone, subscription_status)
VALUES 
    ('00000000-0000-0000-0000-000000000001', 'trainer', 'Carlos Eduardo Personal', '+5511999990001', 'active')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, role, full_name, phone, trainer_id)
VALUES 
    ('00000000-0000-0000-0000-000000000002', 'client', 'Lucas Aluno Teste', '+5511999990002', '00000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;
*/
