-- =========================================================================
-- Seed Idempotente para Ambiente de Desenvolvimento e Testes Locais
-- Mr. Coach / B2B Personal IA
-- =========================================================================

-- 1. Criação de Usuários de Autenticação no Schema auth.users (se suportado no local)
-- Nota: Ao rodar via 'supabase db reset', a extensão pgcrypto está ativa.

DO $$
BEGIN
  -- Criação de Treinador Homologado (CREF Ativo)
  INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
  VALUES (
    '11111111-1111-1111-1111-111111111111',
    'treinador.ativo@mrcoach.test',
    '{"full_name": "Professor Carlos Silva", "role": "trainer"}'::jsonb,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  -- Criação de Treinador Pendente (Sem CREF - Vitrine Bloqueada)
  INSERT INTO auth.users (id, email, raw_user_meta_data, created_at, updated_at)
  VALUES (
    '22222222-2222-2222-2222-222222222222',
    'treinador.pendente@mrcoach.test',
    '{"full_name": "Instrutor Sem CREF", "role": "trainer"}'::jsonb,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  -- Criação de Aluno Ativo (Com Anamnese Completa)
  INSERT INTO auth.users (id, email, raw_user_meta_at, created_at, updated_at)
  VALUES (
    '33333333-3333-3333-3333-333333333333',
    'aluno.ativo@mrcoach.test',
    '{"full_name": "Aluno João Souza", "role": "client"}'::jsonb,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

EXCEPTION WHEN OTHERS THEN
  -- Em ambientes onde auth.users é gerenciado exclusivamente pelo GoTrue, ignora erros de chave
  RAISE NOTICE 'auth.users seed ignorado ou executado com restrições: %', SQLERRM;
END $$;

-- 2. Perfis Públicos (public.profiles)
INSERT INTO public.profiles (
  id,
  full_name,
  role,
  roles,
  username,
  professional_document,
  bio,
  specialties,
  has_completed_anamnesis,
  trainer_id,
  created_at,
  updated_at
) VALUES 
-- Treinador Válido
(
  '11111111-1111-1111-1111-111111111111',
  'Professor Carlos Silva',
  'trainer',
  ARRAY['trainer'],
  'carlossilva',
  'CREF 012345-G/SP',
  'Especialista em hipertrofia e biomecânica avançada.',
  ARRAY['Hipertrofia', 'Emagrecimento', 'Biomecânica'],
  true,
  NULL,
  NOW(),
  NOW()
),
-- Treinador Sem CREF (para teste de bloqueio de vitrine pública)
(
  '22222222-2222-2222-2222-222222222222',
  'Instrutor Sem CREF',
  'trainer',
  ARRAY['trainer'],
  'semcref',
  NULL,
  'Instrutor em formação.',
  ARRAY['Iniciantes'],
  true,
  NULL,
  NOW(),
  NOW()
),
-- Aluno Ativo Vinculado ao Treinador Carlos
(
  '33333333-3333-3333-3333-333333333333',
  'Aluno João Souza',
  'client',
  ARRAY['client'],
  'joaosouza',
  NULL,
  NULL,
  NULL,
  true,
  '11111111-1111-1111-1111-111111111111',
  NOW(),
  NOW()
),
-- Aluno Pendente (sem vínculo completo / convite pendente)
(
  '44444444-4444-4444-4444-444444444444',
  'Aluno Convite Pendente',
  'client',
  ARRAY['client'],
  'alunopendente',
  NULL,
  NULL,
  NULL,
  false,
  '11111111-1111-1111-1111-111111111111',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  username = EXCLUDED.username,
  professional_document = EXCLUDED.professional_document,
  has_completed_anamnesis = EXCLUDED.has_completed_anamnesis,
  trainer_id = EXCLUDED.trainer_id,
  updated_at = NOW();

-- 3. Planos e Assinaturas (public.subscriptions)
INSERT INTO public.subscriptions (
  id,
  trainer_id,
  plan_tier,
  status,
  current_period_end,
  created_at,
  updated_at
) VALUES (
  '55555555-5555-5555-5555-555555555555',
  '11111111-1111-1111-1111-111111111111',
  'pro',
  'active',
  NOW() + INTERVAL '30 days',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- 4. Convites de Demonstração
INSERT INTO public.student_invites (
  id,
  trainer_id,
  student_name,
  student_phone,
  token,
  status,
  created_at
) VALUES (
  '66666666-6666-6666-6666-666666666666',
  '11111111-1111-1111-1111-111111111111',
  'Aluno Convite Teste',
  '5511999998888',
  'invite-seed-token-12345',
  'pending',
  NOW()
)
ON CONFLICT (id) DO NOTHING;
