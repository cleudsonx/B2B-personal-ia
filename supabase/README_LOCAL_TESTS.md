# Guia de Testes Locais com Supabase e RLS

Este ambiente permite executar e validar todas as políticas de Row Level Security (RLS) e integridade referencial diretamente contra um banco PostgreSQL local.

## 1. Pré-requisitos

- Docker Desktop instalado e em execução.
- Supabase CLI instalado:
  ```powershell
  # Windows (via scoop ou winget/npm):
  npm install -g supabase
  # ou
  scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
  scoop install supabase
  ```

## 2. Inicializando o Supabase Local

Na raiz do repositório:
```powershell
supabase start
```
Isso iniciará os containers locais:
- **API URL:** `http://localhost:54321`
- **GraphQL:** `http://localhost:54321/graphql/v1`
- **DB URL:** `postgresql://postgres:postgres@localhost:54322/postgres`
- **Studio (Dashboard local):** `http://localhost:54323`

## 3. Aplicando as Migrations e o Seed de Testes

Para aplicar todas as migrações em ordem estrita seguidas do arquivo `supabase/seed.sql`:
```powershell
supabase db reset
```

Isso garante um banco completamente limpo, com todas as 23 migrations aplicadas e usuários/treinadores de teste populados para testes determinísticos.
