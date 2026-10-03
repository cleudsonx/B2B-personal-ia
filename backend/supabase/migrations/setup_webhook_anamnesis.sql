-- =================================================================================
-- GATILHO DE SEGURANÇA IA - WEBHOOK SUPABASE
-- Execute este script no SQL Editor do Supabase para ativar a integração com o Backend.
-- =================================================================================

-- 1. Certifique-se de que a extensão pg_net está ativada
create extension if not exists "pg_net";

-- 2. Função que dispara a requisição POST para o nosso FastAPI
create or replace function public.handle_anamnesis_update()
returns trigger as $$$
begin
  -- Dispara apenas se o aluno alterou a restrição clínica (lesão/dor)
  if NEW.clinical_restrictions is distinct from OLD.clinical_restrictions then
    perform net.http_post(
        url:='https://b2b-personal-ia-backend.onrender.com/api/v1/webhooks/supabase/anamnesis',
        headers:='{"Content-Type": "application/json"}'::jsonb,
        body:=jsonb_build_object(
          'type', 'UPDATE',
          'table', 'profiles',
          'record', row_to_json(NEW),
          'old_record', row_to_json(OLD)
        )
    );
  end if;
  return NEW;
end;
$$$ language plpgsql security definer;

-- 3. Criação do Trigger na tabela profiles
drop trigger if exists on_anamnesis_update on public.profiles;
create trigger on_anamnesis_update
  after update on public.profiles
  for each row execute procedure public.handle_anamnesis_update();

