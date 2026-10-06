# Fluxo Seguro de Convites Intransferíveis & Auditoria (Mr. Coach)

Este documento descreve a arquitetura, modelo de segurança e fluxo operacional para geração, envio, consumo e auditoria de convites para alunos no Mr. Coach.

---

## 🔒 Princípios de Segurança

1. **Tokens Criptográficos de Alta Entropia:** Tokens gerados via `secrets.token_urlsafe(32)` com 256 bits de aleatoriedade.
2. **Intransferibilidade:** Cada convite é vinculado obrigatoriamente a um destinatário (`target_email` ou `target_phone`).
3. **Uso Único:** Uma vez consumido, o registro é atualizado com `used_at = now()` e novas tentativas são bloqueadas (`400 Bad Request`).
4. **Expiração Automática:** Validade máxima de 24 horas (`expires_at`).
5. **Auditoria Imutável:** Todas as tentativas (criação, envio, sucesso e falhas de abuso) são gravadas em `public.audit_log` via `service_role`.

---

## 🗺️ Diagrama Mermaid do Fluxo

```mermaid
sequenceDiagram
    autonumber
    actor Treinador
    participant Backend as FastAPI Backend
    participant DB as Supabase (invite_tokens & audit_log)
    actor Aluno
    participant App as Mobile/Web Flutter

    Treinador->>Backend: POST /api/v1/invites/create (email/whatsapp)
    Backend->>DB: Salva token em invite_tokens
    Backend->>DB: Grava invite_created em audit_log
    Backend-->>Treinador: Retorna link seguro de convite

    Treinador->>Aluno: Envia link (WhatsApp / E-mail)
    Aluno->>App: Abre convite no app ou navegador
    App->>Backend: POST /api/v1/invites/consume { token }
    
    alt Token Inválido / Expirado / Já Usado
        Backend->>DB: Grava invite_failed em audit_log (com IP e UA)
        Backend-->>App: Erro 400 ou 404
        App-->>Aluno: Exibe alerta de erro/expiração
    else Token Válido
        Backend->>DB: Atualiza used_at = now()
        Backend->>DB: Grava invite_consumed em audit_log
        Backend-->>App: Sucesso + Dados do Treinador
        App->>Aluno: Exibe InviteSuccessScreen (Acolhimento)
        Aluno->>App: Completa Cadastro e Anamnese
    end
```

---

## 🗄️ Tabelas Envolvidas

- `public.invite_tokens`: Guarda os convites ativos, validade e estado de consumo. Protegida por Row Level Security (RLS).
- `public.audit_log`: Tabela imutável de compliance para registro forense de todas as transações de convites.

