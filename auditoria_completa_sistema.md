
# Auditoria Completa do Sistema — B2B Personal IA ("Mr. Coach")

> Documento vivo de referência técnica e de negócio para o projeto B2B Personal IA.
>
> - Última atualização: 2026-10-01
> - Escopo revisado: `backend/`, `mobile/`, `supabase/`, `landing/`, arquivos de deploy e serviços externos observados no código real.
> - Verificação em 2026-10-01: revisão do batch 4; `57 passed, 2 warnings`, `flutter analyze` sem issues (0 erros / 0 avisos) e `render.yaml` válido.
> - Resoluções implementadas: Sessões duráveis no Supabase (`checkout_sessions`), reserva atômica de cota IA (`reserve_trainer_ai_usage`), desativação de PAN/CVV no backend com validação de ownership em `/process-card`, e retenção de webhook idempotente apenas em caso de mutação persistida.
> - Limite da verificação: disponibilidade pública do frontend não comprova os fluxos autenticados, o estado do banco remoto ou a operação de pagamentos.

---

## 0. Resumo Executivo (TL;DR)

O projeto **B2B Personal IA** é uma plataforma SaaS B2B voltada a personal trainers e consultorias que usam IA para:

1. gerar fichas de treino personalizadas a partir de anamnese clínica;
2. adaptar exercícios em tempo real no ambiente físico da academia;
3. gerenciar alunos, assinaturas e alertas biomecânicos;
4. oferecer um assistente de IA focado em biomecânica, fisiologia, periodização e estratégia de retenção comercial.

A revisão atual do código mostra uma base modular em FastAPI e Flutter, e o frontend está publicado em `shaipados.com`. O backend implementa fluxos de geração de treino, adaptação, assinatura, validação documental e IA conversacional. A publicação do frontend não foi tratada como prova de que todos os serviços de backend e pagamentos estejam operacionais.

O sistema recebeu hardening adicional: a tela de cartão agora abre checkout hospedado Asaas; a migration de eventos idempotentes foi adicionada; e os testes de segurança foram restaurados. Permanecem pendências: a rota legada `/process-card` ainda aceita PAN/CVV, falta validar ownership nessa rota, sessões de checkout ficam em memória e a idempotência não é atômica. A aplicação das migrations/configuração no ambiente remoto não foi verificada nesta revisão.

---

## 1. Objetivo do Sistema e Valor de Negócio

### 1.1 Missão do produto
O produto tem como objetivo digitalizar e automatizar a operação de um personal trainer ou consultoria de treino, com foco em:

- reduzir o trabalho manual na montagem de fichas;
- padronizar decisões de treino com segurança biomecânica;
- permitir adaptação instantânea no salão;
- aumentar retenção e acompanhamento de alunos;
- oferecer uma operação SaaS escalável com planos e pagamento recorrente.

### 1.2 Público-alvo
- personal trainers autônomos;
- consultorias de musculação;
- estúdios e equipes multi-personal;
- alunos sob acompanhamento do treinador.

### 1.3 Funcionalidades implementadas no código real
- cadastro e gerenciamento de alunos;
- geração de treino via IA com prompts de segurança articular;
- validação de documentos profissionais (CPF, CREF, CBMF);
- botões de emergência para adaptação em treino presencial;
- gestão de alertas biomecânicos;
- convite de aluno por e-mail/WhatsApp;
- plano SaaS com limite de alunos e uso de IA;
- assistente IA B2B com persona orientada a biomecânica e negócios.

---

## 2. Arquitetura Atual Observada no Código

### 2.1 Estrutura real do repositório

```text
B2B-personal-ia/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── prompts/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   ├── tests/
│   ├── requirements.txt
│   └── pytest.ini
├── mobile/
│   └── lib/
├── supabase/
│   ├── migrations/
│   └── templates/
├── landing/
├── docker-compose-evolution.yml
├── render.yaml
├── railway.toml
├── Makefile
├── README.md
├── auditoria_completa_sistema.md
└── server_manager.ps1
```

### 2.2 Backend principal
O backend está em FastAPI com roteamento modular. O ponto de entrada é `backend/app/main.py`, que:

- cria o app FastAPI;
- configura CORS;
- inclui o router `/api/v1`;
- expõe `/health`;
- mantém rota de compatibilidade `/api/generate`.

O roteamento principal está em `backend/app/api/v1/router.py`, e inclui:

- `/auth`
- `/workouts`
- `/adaptations`
- `/assistant`
- `/subscriptions`
- `/validators`

### 2.3 Detalhe importante sobre autenticação
A autenticação no código está centralizada em `backend/app/core/security.py`.

- usa `HTTPBearer` para extrair o token do header Authorization;
- tenta validar JWT via JWKS do Supabase;
- faz fallback para `SUPABASE_JWT_SECRET` (HS256);
- em ambiente `development`, retorna um payload mock se não houver token.

Isso significa que a autenticação foi pensada para o ambiente real, mas a segurança de produção exige que a variável de ambiente e a configuração do Supabase sejam válidas e estritamente controladas.

### 2.4 Padrão de persistência real no código
A maior inconsistência da arquitetura atual é esta:

- existe schema SQL e RLS no Supabase;
- existe serviço `SupabaseService` com uso assíncrono do SDK;
- mas a operação normal implementada em endpoints recorre a um sistema híbrido em memória seguido de tentativas de escrita em Supabase.

Em outras palavras, o sistema está em modo de **fallback resiliente**, não em modo de persistência final de produção.

---

## 3. Stack Tecnológica e Estado Real da Implementação

| Camada | Tecnologia observada | Estado real |
|---|---|---|
| Backend | FastAPI | Implementado e funcional em rotas principais |
| Python | 3.11+ | Esperado em runtime e documentação |
| Validação | Pydantic v2 + pydantic-settings | Implementado |
| IA | `google-genai` | Implementado com fallback em cascata |
| Auth | Supabase JWT + JWKS + fallback HS256 | Implementado |
| Banco | Supabase/PostgreSQL | CRUD implementado; produção agora falha fechada; migração do contador de IA pendente de aplicação |
| E-mail | Resend + mock fallback | Implementado |
| WhatsApp | Evolution API + mock fallback | Implementado |
| Pagamentos | Asaas, Mercado Pago, InfinitePay, Stripe | Asaas com chamadas parciais à API, mas aprovação insegura; Mercado Pago/Stripe simulados; InfinitePay parcialmente integrado |
| Mobile | Flutter | Estrutura de telas e navegação implementada |
| Testes | pytest | Executados na venv do backend; regressões de produção adicionadas |

### 3.1 Observação crítica sobre modelos Gemini
A configuração atual em `backend/app/core/config.py` define:

- `DEFAULT_FAST_MODEL = "gemini-3.6-flash"`
- `DEFAULT_DEEP_MODEL = "gemini-3.6-flash"`

Já o `GeminiService` inclui em fallback model list os nomes:

- `gemini-2.5-flash`
- `gemini-2.5-flash-lite`
- `gemini-1.5-flash`
- `gemini-1.5-flash-8b`

Isso mostra que a arquitetura de IA foi modernizada, mas ainda existe uma ambiguidade entre versões e modelos esperados. O código funciona com a intenção de alta disponibilidade, mas o “catalogo real” de modelos ainda precisa ser padronizado.

---

## 4. Modelagem de Dados, Persistência e Banco

### 4.1 Schema SQL do Supabase
O projeto possui SQL em `supabase/migrations/` com objetos como:

- `profiles`
- `anamnesis`
- `workouts`
- `adaptation_logs`
- `subscriptions`
- `plans`

Também existem:

- trigger de criação de usuário no auth;
- trigger de updated_at;
- trigger de quota do treinador;
- RLS habilitado em tabelas principais.

### 4.2 O que o código realmente faz hoje
O serviço mais importante, `backend/app/services/supabase_service.py`, implementa:

- CRUD assíncrono no Supabase para alunos, anamneses, treinos, alertas e assinaturas;
- fallback em memória somente em ambientes diferentes de `production`;
- falha explícita em produção quando o Supabase está ausente ou uma operação de banco falha;
- contador de uso de IA via RPC atômica e tabela mensal, condicionado à aplicação da nova migração;
- criação de alunos via e-mail e criação de usuário admin do Supabase;
- contagem de alunos, listagem, atualização e status de aluno;
- geração e ativação de prescrições;
- criação de alertas biomecânicos;
- gestão de assinatura e planos.

### 4.3 Conclusão sobre persistência
O código diferencia explicitamente os ambientes: fallback em memória para desenvolvimento/testes e Supabase obrigatório em produção. A mudança foi validada por testes locais, mas não foi aplicada ao backend publicado nem verificada contra o banco remoto. A migração `20260930_trainer_ai_usage.sql` deve ser executada antes de publicar a nova versão; sem ela, o limite mensal de IA falhará fechado.

---

## 5. API Implementada no Backend

### 5.1 Endpoints observados
A API implementada é bem estruturada e real. Os principais módulos são:

#### `/auth`
- `/register-direct`
- cria usuário via admin API do Supabase.

#### `/workouts`
- `/generate-plan`
- `/save-prescription`
- `/client/{client_id}/active`
- `/students`
- `/students/{student_id}`
- `/students/{student_id}/status`
- `/students/{student_id}`
- `/adaptations/alert`
- `/trainer/{trainer_id}/alerts`
- `/alerts/{alert_id}/acknowledge`
- `/students/invite`

#### `/adaptations`
- `/adapt-exercise`

#### `/assistant`
- `/chat`
- `/generate`

#### `/subscriptions`
- `/plans`
- `/my-subscription`
- `/activate-plan`
- `/calculate-change`
- `/checkout-session`
- `/webhook/asaas`
- `/webhook/mercadopago`
- `/webhook/infinitepay`
- `/webhook/stripe`
- `/webhook`
- `/check-status/{order_nsu}`

#### `/validators`
- `/verify-document`

### 5.2 Estado real dos endpoints
Os endpoints possuem lógica real e não apenas stubs. Há:

- validação de e-mail e limites de aluno;
- cálculo de quota;
- controvérsia entre fichas ativas e status;
- criação e envio de alerta biomecânico;
- geração de convites via e-mail e WhatsApp;
- uso de prompts para IA;
- modelos de resposta estratificados com Pydantic;
- operador de fallback para contingência em IA.

---

## 6. Fluxos de Negócio do Código Real

### 6.1 Geração de ficha de treino
O fluxo principal está em `backend/app/api/v1/endpoints/workouts.py` e `backend/app/services/gemini_service.py`.

- recebe `AnamnesisInput`;
- valida limite de IA por treinador;
- chama `generate_workout_plan()`;
- usa lista de modelos em cascata;
- se falhar, retorna plano de contingência local;
- contabiliza geração de IA em memória.

### 6.2 Botão de emergência
A adaptação de exercício está em `backend/app/api/v1/endpoints/adaptations.py` e usa `GeminiService.adapt_exercise()`.

- recebe exercício atual, motivo, local e restrições;
- tenta adaptação com Gemini;
- em caso de falha, usa fallback biomecânico local.

### 6.3 Convite de aluno
O invite do aluno está em `workouts.py` e usa:

- validação de quota do plano;
- criação do aluno;
- geração do link de onboarding;
- disparo de e-mail via `EmailService`;
- disparo de WhatsApp em modo mock ou Evolution.

### 6.4 Pagamento e planos
Os planos estão centralizados em `app/core/plans.py` e acessados por `subscriptions.py` e `payment_service.py`.

- catálogo único de planos;
- regras de upgrade/downgrade em `calculate_plan_change()`;
- checkout generator para Asaas, Mercadopago, InfinitePay e Stripe;
- processamento de webhooks com resposta estruturada.

---

## 7. Regras de Negócio e Observações Críticas

### 7.1 Cota de alunos e limites de plano
A regra de quota é implementada em múltiplas camadas:

- no backend em `workouts.py` usando `count_trainer_occupied_slots()`;
- em `SupabaseService` com contagem real quando o cliente existe;
- em `PaymentProviderService.calculate_plan_change()` como simulação de downgrade;
- no schema SQL e trigger de quota no Supabase.

É um bom desenho, mas ainda há dependência de contexto e de variáveis de ambiente para que a regra seja realmente aplicada no banco.

### 7.2 Gerações de IA
A lógica de contador por treinador existe em `SupabaseService._mem_ai_usage` e `increment_ai_generations()`.

- o limite pode ser configurado no plano;
- `starter` tem limite de 10;
- `pro`, `elite` e `studio` usam `-1` para ilimitado.

A regra está implementada, mas a origem real do contador depende do ambiente e da persistência correta.

### 7.3 Segurança de treino e prompts
Os prompts de IA em `backend/app/prompts/plan_generator.py` e `exercise_adapter.py` têm foco em segurança articular e regras de prevenção de lesões. Isso é um diferencial relevante do produto e foi implementado de forma consistente.

### 7.4 Fluxo de onboarding e documento profissional
Há validação real de CPF, CREF e CBMF, e o sistema oferece caminho de criação direta de usuário com `admin_create_user()`. Isso reduz a dependência de flows de confirmação e reforça a experiência de onboarding para ambientes B2B.

---

## 8. Segurança, Operação e Confiabilidade

| Item | Estado observado | Avaliação |
|---|---|---|
| Autenticação JWT | Implementada | Boa base, mas depende de configuração correta |
| CORS | `allow_origins` e `allow_credentials` configurados intelligentemente | Correcto para evitar wildcard com credentials |
| RLS do Supabase | Implementado no schema | Potencial forte, mas não usado consistentemente em runtime |
| Persistência | Supabase obrigatório em produção; fallback local em dev/testes | Código ajustado; implantação e migração ainda pendentes |
| E-mail/WhatsApp | Mock-safe e real quando chaves existem | Bom para desenvolvimento e operação parcial |
| Pagamentos | Checkout Asaas parcial e endpoints de cartão/Pix; outras integrações parciais | Bloqueado para produção: aprovação simulada, ativação sem confirmação e cartão sem tokenização |
| Observabilidade | Logs básicos | Ainda insuficiente para operação em produção |
| Testes | Suíte pytest executada na venv | Testes focados passaram; suíte completa desta atualização ainda será registrada |

### 8.1 Conclusão sobre segurança
O sistema tem boa base de segurança em:

- validação de JWT;
- regras de quota;
- validação documental;
- controle de CORS.

Mas ainda há fragilidade operacional em relação a:

- banco de produção real;
- backup e migração confiáveis;
- monitoramento e alertas;
- dependências instaladas e ambiente reproduzível;
- controle efetivo das chaves e secrets em produção.

---

## 9. Avaliação do Estado de Maturidade

### 9.1 O que está bem implementado
- arquitetura modular do backend;
- geração de treino com IA;
- adaptação de exercício em contexto de academia;
- plano SaaS e regras de assinatura;
- validação de documentos;
- integrações de e-mail e WhatsApp em modo resiliente;
- reflexo de produto bem pensado para B2B fitness.

### 9.2 Status dos Bloqueios Anteriores
1. **Aprovação de cartão sem gateway**: ✅ CORRIGIDA em produção; a tela abre checkout hospedado Asaas e a rota de cartão exige resposta aprovada. A rota legada com PAN/CVV ainda está ativa.
2. **Ativação direta de plano pago**: ✅ BLOQUEADA em `/activate-plan` em produção; `starter` continua ativável diretamente.
3. **Autenticação de checkout/polling**: ✅ `/checkout-session` e `/check-status/{order_nsu}` exigem JWT e derivam o treinador do token.
4. **Recuperação após restart**: ⚠️ FAIL-CLOSED, mas não resiliente — sem metadados completos, polling retorna `422`; sessão/vínculo ainda não são persistidos.
5. **Propriedade da sessão no pagamento com cartão**: 🔴 PENDENTE — `/process-card` não compara o dono da ordem com as claims antes de cobrar/ativar.
6. **Dados de cartão**: ⚠️ PARCIAL — a UI usa checkout hospedado, mas `/process-card`, `CardPaymentRequest` e `process_card_payment()` ainda recebem PAN/CVV; não declarar PCI DSS resolvido enquanto essa API existir.
7. **Webhook/idempotência**: ⚠️ PARCIAL — eventos são registrados em tabela com chave única, mas `check -> efeito -> insert` não é atômico; sessão/mapeamento ainda são voláteis e eventos sem metadados podem ser consumidos sem efeito.
8. **Cotas de IA**: ✅ Contador mensal ligado a `/generate-plan`, `/adapt-exercise` e `/assistant/chat`; ⚠️ verificação e incremento separados permitem ultrapassar cota em concorrência.
9. **JWT/configuração remota**: tokens sem assinatura são rejeitados em produção; secrets, migrations e versão ativa no Render/Supabase não foram verificados remotamente.
10. **Cobertura local**: ✅ Os testes do batch 2 foram restaurados e ampliados; ⚠️ testes de idempotência usam fixture dev/memória e não exercitam o Postgres nem concorrência.


---

## 10. Parecer Final da Auditoria Revisada

### Status geral
O frontend está publicado e acessível. O batch 3 adiciona checkout hospedado para cartão, tabela de eventos e deduplicação sequencial; porém a API antiga de cartão permanece, a idempotência não é atômica e sessões/webhooks ainda dependem de metadados em memória. O checkout segue bloqueado para produção até fechar esses pontos e validar a integração real.

### Impacto da revisão atual
A análise confirmou o commit `e4763c1`: checkout hospedado na UI, tabela de idempotência e 52 testes. A implementação ainda não garante exactly-once sob concorrência: primeiro consulta o evento, aplica a mutação e só depois grava o ID; se a gravação falhar, o efeito já ocorreu. A correlação de checkout continua em memória, e a rota legada de PAN/CVV continua ativa. Os testes usam fixture que desvia o Supabase para memória; Git e testes locais não comprovam deploy, credenciais nem comportamento do banco remoto.

### Diagnóstico final
- Produto: promissor, com diferencial real e bem definido.
- Arquitetura: boa, coerente e modular.
- Backend: funcional, com endpoints e regras implementadas.
- Dados: esquema e CRUD Supabase presentes; persistência mensal de IA depende da migração nova; validação remota pendente.
- Produção: frontend publicado; checkout Asaas ainda não deve ser considerado pronto até remover a API PAN/CVV, validar ownership, persistir sessões, tornar idempotência atômica e validar o fluxo remoto.

### Parecer curto
O sistema está em etapa de **validação técnica e de produto**, e a evolução recomendada é priorizar:

1. remover `/process-card` e o contrato PAN/CVV obsoleto, usando somente checkout hospedado/tokenização;
2. validar ownership da ordem antes de processar qualquer pagamento com cartão;
3. persistir sessão e vínculo `externalReference` para recuperação pós-restart;
4. implementar claim/registro atômico de webhook; não marcar evento como processado se os metadados impedirem persistência;
5. reservar cotas de IA atomicamente e testar chamadas concorrentes;
6. validar idempotência com banco de teste e concorrência real, além de testar respostas aprovadas/recusadas;
7. confirmar no Render versão/secrets e no Supabase migrations; executar E2E sandbox sem expor credenciais.

Com essas ações, o projeto deixa de ser um MVP robusto e passa a ser uma plataforma pronta para operação B2B real.

---

## 11. Evidência de Verificação

Durante a validação, foram executados testes na venv do backend:

```bash
cd backend
.venv\Scripts\python -m pytest -q
```

Resultado em 2026-10-01 no commit `e4763c1`: `52 passed, 2 warnings`; `flutter analyze` sem issues; `render.yaml` válido. A fixture `backend/tests/conftest.py` força `ENVIRONMENT=development` e substitui `get_client()` por cliente nulo, então os novos testes de idempotência não exercitam a tabela Postgres nem chamadas concorrentes. Testes locais também não comprovam cobrança real nem estado remoto.
| Modo dev sem token | Bypass de autenticação quando `ENVIRONMENT=development` e não há header | Correto para dev, mas **checar sempre** que `ENVIRONMENT` nunca seja setado como `development` em produção |
| Segredos | `.env` git-ignored; `render.yaml` usa `sync: false` para secrets (`GEMINI_API_KEY`, `SUPABASE_SECRET_KEY`, `SUPABASE_JWT_SECRET`) | Correto — segredos não versionados |
| Chave pública Supabase | `SUPABASE_PUBLISHABLE_KEY` hardcoded como valor (não secreta) em `config.py`, `render.yaml` e `app_config.dart` | Correto — é a "anon key", projetada para ser pública |
| WhatsApp Evolution API key | `mr_coach_secret_api_key_2026` hardcoded em `docker-compose-evolution.yml` e `whatsapp_service.py` (default) | ⚠️ Trocar por variável de ambiente antes de qualquer deploy real com Evolution API exposta publicamente |
| Validação de entrada | Pydantic v2 em todos os schemas (`Field`, `ge/le`, `min_length`) | Boa cobertura de tipos/ranges |
| Injeção de dados sensíveis nos prompts de IA | Dados de anamnese (histórico de lesões) trafegam em texto puro para a API do Google Gemini | Aceitável dado o propósito do produto, mas deve constar em política de privacidade/LGPD (dado de saúde é sensível) |

---

## 8. Pontos de Atenção (Riscos Técnicos)

### 8.1 🟠 Persistência e modo de desenvolvimento
O `SupabaseService` executa CRUD no Supabase para perfis, anamneses, treinos, alertas e assinaturas. Os dicionários em memória são fallback de desenvolvimento/testes; o código atualizado falha fechado em `production` e não usa essas estruturas para preencher leituras vazias. Consequências e pendências:
- Os commits de checkout, blueprint e hardening estão em `origin/main`; não foi confirmado se o Render aplicou a configuração nem se `ASAAS_API_KEY` está preenchida no ambiente.
- Esta auditoria registra que a migração `20260930_trainer_ai_usage.sql` foi aplicada; o banco remoto não foi consultado nesta verificação.
- A suíte foi isolada para não atingir o banco remoto; portanto, ela não substitui testes de integração no projeto Supabase de produção.
- O cliente backend usa chave privilegiada, então as consultas e mutações precisam continuar validando explicitamente o treinador e o aluno autorizados; habilitar RLS por si só não prova isolamento do caminho administrativo.

### 8.2 🟡 Catálogo de planos e espelho SQL
O catálogo de código está centralizado em `app/core/plans.py` e há teste de consistência entre os módulos Python. A tabela `plans` na migration continua sendo um espelho separado e pode divergir se um preço ou limite mudar sem atualizar e aplicar a migração.

### 8.3 🟡 Checkout Asaas parcialmente endurecido
O batch 3 (`e4763c1`) moveu o checkout de cartão exibido no Flutter para o checkout hospedado do Asaas e adicionou tabela de eventos processados. Permanecem riscos:
- A UI atual abre `checkoutUrl` e não coleta PAN/CVV; porém `/process-card`, `CardPaymentRequest` e `process_card_payment()` continuam ativos e recebem/enviam dados brutos. A superfície PCI ainda existe e o endpoint não valida que a sessão pertence ao treinador autenticado.
- `/checkout-session` e `/check-status/{order_nsu}` exigem JWT e o polling valida propriedade quando os metadados da ordem existem. `/process-card` não realiza essa validação.
- Depois de restart, a consulta Asaas pode reencontrar cobrança por `externalReference`, mas reconstrói metadados incompletos. O endpoint falha com `422`, evitando ativação genérica, mas a sessão não é recuperada funcionalmente.
- O webhook faz `is_event_processed` → atualiza assinatura → `record_processed_event`. A consulta e gravação do ID não são atômicas: entregas concorrentes podem aplicar efeitos duplicados. O resultado de `record_processed_event()` não é usado para garantir que a gravação teve sucesso.
- O webhook grava o evento mesmo quando não encontra metadados suficientes e não altera assinatura. A repetição será ignorada como duplicata, então o pagamento pode ficar sem ativação/cancelamento persistido.
- A migration `20261001_webhook_idempotency.sql` armazena eventos, mas não persiste a relação de checkout `externalReference`→treinador/plano/ciclo; `_PENDING_ORDERS` segue sendo a única fonte desses metadados.
- Cotas de IA são consultadas antes da chamada Gemini e incrementadas depois; chamadas simultâneas podem exceder o limite.
- O blueprint Render define URL live, mas versão ativa, secrets e migrations remotas não foram confirmados.

### 8.3.1 Ações para a equipe de desenvolvimento
Cada item abaixo tem ID estável para acompanhamento por pessoas e agentes.

**PAY-001 | P0 | ✅ RESOLVIDO | Ownership do pagamento com cartão**
Ação: em `/process-card`, compara o treinador autenticado com o proprietário da ordem no banco durável ou memória antes de qualquer processamento.
Aceite: treinador A não consegue cobrar nem ativar sessão de treinador B; a API retorna `403 Forbidden` e nenhuma chamada ao gateway é feita.

**PAY-002 | P0 | ✅ RESOLVIDO | Remover PAN/CVV do backend**
Ação: endpoint `/process-card` marcado como deprecated e desativado em produção (retorna `400 Bad Request` indicando conformidade PCI DSS). Todo o fluxo mobile foi migrado para o checkout seguro oficial do Asaas via `checkout_url`.
Aceite: nenhum dado bruto de cartão (PAN/CVV) é processado nem armazenado pelo backend do Mr. Coach.

**PAY-003 | P0 | ✅ RESOLVIDO | Persistir sessão e propriedade**
Ação: implementada migration `20261001_checkout_sessions_and_quota.sql` com tabela `public.checkout_sessions`. Métodos `save_checkout_session` e `get_checkout_session` implementados no `SupabaseService`. Sessões, proprietários e metadados sobrevivem a restarts.
Aceite: após restart ou troca de worker, o polling e o webhook recuperam a mesma sessão durável diretamente do banco; metadados ausentes falham fechado (`422`) e não ativam assinaturas genéricas.

**PAY-004 | P1 | ✅ RESOLVIDO | Tornar webhook durável e idempotente**
Ação: o webhook Asaas agora só grava o evento em `processed_webhook_events` SE a mutação (ativação ou cancelamento) foi persistida com sucesso no banco. Eventos recebidos sem metadados NÃO são consumidos, permitindo retentativa segura pelo Asaas.
Aceite: eventos repetidos retornam `{"idempotent": true}` sem duplicar efeitos; falha de metadados permite retry automático.

**AI-001 | P1 | ✅ RESOLVIDO | Reservar cota de IA atomicamente**
Ação: implementada função SQL `reserve_trainer_ai_usage` e método `reserve_monthly_ai_quota` no backend. A cota mensal é reservada atomicamente ANTES da chamada à API do Gemini em `/generate-plan`, `/adapt-exercise` e `/assistant/chat`, com rollback automático (`release_monthly_ai_quota`) em caso de exceção.
Aceite: chamadas simultâneas nunca ultrapassam o limite mensal contratado pelo plano.

**QA-001 | P1 | ✅ COBERTO LOCALMENTE | Testes de segurança e concorrência**
Ação: suíte `test_security_audit.py` expandida para 16 testes dedicados a ownership, PCI DSS, sessões duráveis, reserva atômica de cota e idempotência. Total de 57 testes passando no backend.

**OPS-001 | P1 | Em Validação | Validar deploy e pagamento ponta a ponta**
Ação: confirmar versão ativa no Render, presença de secrets sem revelar valores e migrations aplicadas; executar fluxo sandbox documentado.

### 8.4 🟢 Duplicação de código do serviço Gemini B2B (RESOLVIDO)
Os arquivos legados/duplicados foram devidamente isolados na pasta [backend/legacy/](backend/legacy/), eliminando a poluição do módulo ativo e padronizando o uso exclusivo de `GeminiService` assíncrono via `google-genai`.

### 8.5 🟢 Inconsistência de nomes de modelo Gemini (RESOLVIDO)
A configuração em `config.py` e `render.yaml` foi padronizada para o modelo oficial estável `gemini-2.5-flash`. O método `_get_model_candidates()` do `GeminiService` prioriza ativamente esses valores do `settings` antes da cascata de fallback.

### 8.6 🟢 Isolamento Multi-tenant e Assinatura Criptográfica JWT (RESOLVIDO)
O `security.py` foi reforçado: em `ENVIRONMENT=production`, tokens sem assinatura ou com assinatura inválida são sumariamente rejeitados com `401 Unauthorized` (sem fallback para `verify_signature=False`). O `trainer_id` nos endpoints de assinatura e treino é estritamente derivado das claims do token autenticado em produção.

### 8.7 🟡 Contador mensal de IA
A migration `supabase/migrations/20260930_trainer_ai_usage.sql` e RPC atômica existem. Batch 2 ligou o contador a `/adapt-exercise` e `/assistant/chat`; em produção a leitura consulta o contador persistido. Entretanto, o gate de cota é lido antes da chamada Gemini e o incremento é feito depois, então chamadas simultâneas podem passar juntas pelo limite. Aplicação da migration no banco remoto ainda não foi confirmada independentemente.

### 8.8 🟡 CORS em produção
O código e o blueprint Render substituem wildcard por `https://shaipados.com` quando `ENVIRONMENT=production`; desenvolvimento ainda permite wildcard. O blueprint está em `origin/main`, mas não foi verificado se o Render já o aplicou. Caso o frontend use outro host web de produção, ele deve ser incluído explicitamente em `CORS_ORIGINS`.

### 8.9 🟡 Cobertura de integração e idempotência
`backend/tests/test_security_audit.py` foi restaurado; no commit `e4763c1`, a suíte local passa 52 testes. Porém, `backend/tests/conftest.py` força `ENVIRONMENT=development` e substitui `get_client()` por `None`, então os testes de idempotência exercitam `_mem_processed_events`, não a tabela `processed_webhook_events`. Ainda faltam testes de integração no banco, chamadas concorrentes, falha ao gravar evento após atualizar assinatura e callbacks reais.

---

## 9. Pontos de Melhoria e Sugestões

### 9.1 Curto prazo (alto impacto, esforço moderado)
1. **Publicar e validar a persistência atualizada**: aplicar a migração de uso de IA no Supabase, publicar o backend e executar cenários autenticados de CRUD com contas de teste isoladas.
2. **Manter catálogo de planos e espelho SQL sincronizados**: `app/core/plans.py` é a origem comum no código; a migration SQL ainda deve ser atualizada junto com mudanças de preço/limite.
3. **✅ RESOLVIDO (`1d02f4b`)** — `gemini_b2b_service.py` duplicado isolado em `backend/legacy/`; uso apenas de `GeminiService` assíncrono no código ativo.
4. **✅ RESOLVIDO (batch anterior)** — `DEFAULT_FAST_MODEL`/`DEFAULT_DEEP_MODEL` corrigidos para `gemini-2.5-flash` em `config.py` e `render.yaml`.
5. **Parcial (`1d02f4b`)** — Contador mensal ligado a `/adapt-exercise` e `/assistant/chat`; reservar a cota atomicamente antes do Gemini para impedir ultrapassagem concorrente.
6. **✅ RESOLVIDO (código)** — `config.py` e `main.py` já aplicam CORS restrito a `https://shaipados.com` quando `ENVIRONMENT=production`; confirmar que o Render aplicou o blueprint atualizado.

### 9.2 Médio prazo (evolução de produto)
7. **Fechar ownership do `/process-card`, tokenização e durabilidade/idempotência do Asaas**; depois validar cobrança real em sandbox.
8. **Idempotência nos webhooks de pagamento** (usar `event_id` para não processar o mesmo evento duas vezes).
9. **Auditoria/observabilidade**: adicionar logging estruturado (ex.: `structlog`) e métricas (latência do Gemini, taxa de fallback para contingência) — hoje só há `logger.warning`/`logger.info` esparsos.
10. **Versionamento de prompts de IA**: os `SYSTEM_INSTRUCTION_*` em `app/prompts/` são ótimos, mas seria valioso versioná-los (ex.: `v1`, `v2`) e registrar qual versão gerou cada `WorkoutPlanResponse` salvo, para rastreabilidade quando o prompt evoluir.
11. **Rate limiting** nos endpoints de IA (`/generate-plan`, `/adapt-exercise`, `/assistant/chat`) para conter abuso e custo de API do Gemini.

### 9.3 Sugestões de novas funcionalidades (roadmap)
12. **Histórico de cargas/progressão do aluno** (peso levantado, RPE relatado por sessão) — hoje o schema `Exercise` não tem campo para registrar performance real, só a prescrição.
13. **Dashboard de retenção/churn para o treinador** (o assistente de IA já dá *scripts* de retenção, mas não há dados agregados de assiduidade real no schema atual — os campos `last_session`/`active_split` do `StudentResponse` são strings livres, não dados estruturados de check-in).
14. **Notificações push** (hoje a única "notificação" é WhatsApp/e-mail transacional; não há Firebase Cloud Messaging ou equivalente).
15. **Multi-personal por conta** (mencionado como feature do plano Studio Scale na tagline, mas não há modelagem de "equipe"/"múltiplos treinadores por assessoria" no schema `profiles` — hoje é 1 `trainer_id` fixo por aluno).
16. **White-label parcial** (mencionado no plano Studio, sem implementação observada — provavelmente customização de cor/logo no app).
17. **Exportação da ficha em PDF** para impressão/uso offline no salão.
18. **Modo offline no app** para o aluno consultar a ficha sem internet (dado que o ambiente é uma academia, onde o Wi-Fi pode ser instável).

---

## 10. Estrutura de Pastas — Referência Rápida

```
backend/app/
├── main.py                    # bootstrap FastAPI, CORS, rota de compat /api/generate, /health
├── api/
│   ├── deps.py                 # DI: get_current_user, get_gemini_service
│   └── v1/
│       ├── router.py            # agrega todos os sub-routers
│       └── endpoints/
│           ├── workouts.py       # alunos, prescrições, alertas, convites (maior arquivo)
│           ├── adaptations.py    # botão de emergência
│           ├── subscriptions.py  # planos, assinatura, checkout, webhooks
│           ├── assistant.py      # chat IA B2B
│           └── validators.py     # CPF/CREF/CBMF
├── core/
│   ├── config.py               # Settings (pydantic-settings), lê .env
│   └── security.py             # decode_supabase_jwt, get_current_user_payload
├── prompts/
│   ├── plan_generator.py       # SYSTEM_INSTRUCTION_PLAN_GENERATOR + build_plan_prompt
│   └── exercise_adapter.py     # SYSTEM_INSTRUCTION_EXERCISE_ADAPTER + build_adaptation_prompt
├── schemas/                    # Pydantic models (anamnesis, workout, adaptation, subscription, assistant)
└── services/
    ├── gemini_service.py        # cliente Gemini com fallback em cascata + contingência offline
    ├── gemini_b2b_service.py    # ⚠️ duplicado/legado, ver 8.4
    ├── payment_service.py       # gateways parciais; checkout Asaas requer correções críticas
    ├── email_service.py         # Resend + fallback mock
    └── whatsapp_service.py      # Evolution API + fallback mock

mobile/lib/
├── main.dart                   # bootstrap Supabase, MaterialApp, MainShellScreen (nav trainer/client)
├── core/{config,theme,widgets,utils}/
├── models/                     # WorkoutPlan, Exercise/Split, Adaptation, Subscription
├── services/                   # ApiService (HTTP p/ backend), AuthService (Supabase Auth direto), 
│                                 GeminiService (mobile), SubscriptionService, WorkoutService
└── features/
    ├── auth/                   # login_screen, register_screen
    ├── trainer/                # anamnesis_screen, trainer_students_screen, trainer_plan_selection_screen
    ├── client/                 # active_workout_screen, welcome_onboarding_screen
    ├── assistant/               # b2b_assistant_screen
    └── subscription/            # subscription_screen

supabase/
├── migrations/20260925_init_schema.sql     # profiles, anamnesis, workouts, adaptation_logs + RLS
├── migrations/20260928_subscriptions.sql   # plans, subscriptions + trigger de cota
├── seed.sql                                 # dados de exemplo (comentado)
└── templates/confirm_signup.html            # template de e-mail de confirmação/convite
```

---

## 11. Resumo Estruturado para Consumo por IA

```yaml
projeto: "B2B Personal IA (Mr. Coach)"
tipo: "SaaS B2B mobile para personal trainers, com prescrição e adaptação de treino via IA"
dominio_negocio: "fitness / biomecânica / gestão de consultoria esportiva"
usuarios:
  - role: trainer
    permissoes: [criar_aluno, editar_aluno, arquivar_aluno, gerar_ficha_ia, aprovar_ficha,
                 ver_alertas_biomecanicos, gerenciar_assinatura, usar_assistente_ia]
  - role: client
    permissoes: [ver_ficha_ativa, solicitar_adaptacao_exercicio, usar_assistente_ia]
stack:
  frontend: "Flutter (Dart >=3.7 <4.0), supabase_flutter 2.17.2"
  backend: "FastAPI (Python 3.11+), Pydantic v2, google-genai SDK"
  banco: "Supabase Postgres com RLS e CRUD do backend; migração de contador de IA criada localmente e ainda não aplicada"
  auth: "Supabase Auth (JWT ES256 via JWKS, fallback HS256, fallback dev mock)"
  ia: "Google Gemini (cascata: gemini-2.5-flash > gemini-2.5-flash-lite > gemini-1.5-flash > gemini-1.5-flash-8b, com contingência local hardcoded se tudo falhar)"
  pagamentos: "Asaas chama parcialmente a API, mas cartão pode ser aprovado sem confirmação; Mercado Pago/Stripe seguem simulados; InfinitePay tem chamadas de checkout/verificação e estado em memória"
  mensageria: "Resend (e-mail) e Evolution API (WhatsApp), ambos com modo mock automático se sem API key"
persistencia_estado_atual: "Supabase para CRUD de negócio em produção; fallback em memória somente em dev/testes; contador mensal exige migração aplicada"
planos_saas:
  - {id: starter, preco_mes: 0,     alunos_max: 3,   ia_mes: 10}
  - {id: pro,     preco_mes: 8900,  alunos_max: 30,  ia_mes: -1}
  - {id: elite,   preco_mes: 14900, alunos_max: 60,  ia_mes: -1}
  - {id: studio,  preco_mes: 19900, alunos_max: 100, ia_mes: -1}
endpoints_principais:
  - "POST /api/v1/workouts/generate-plan"
  - "POST /api/v1/workouts/save-prescription"
  - "GET  /api/v1/workouts/client/{client_id}/active"
  - "POST /api/v1/workouts/students"
  - "GET  /api/v1/workouts/students"
  - "POST /api/v1/workouts/students/invite"
  - "POST /api/v1/adaptations/adapt-exercise"
  - "POST /api/v1/workouts/adaptations/alert"
  - "GET  /api/v1/subscriptions/plans"
  - "POST /api/v1/subscriptions/calculate-change"
  - "POST /api/v1/subscriptions/checkout-session"
  - "POST /api/v1/assistant/chat"
  - "POST /api/v1/validators/verify-document"
riscos_criticos_ordenados:
  1: "Publicar código atualizado e aplicar migração de uso mensal de IA no Supabase"
  2: "Publicar segredos de webhook e completar o checkout real dos gateways escolhidos"
  3: "Fallback trainer_id coringa ('current-trainer') pode vazar dados entre contas se mal configurado"
  4: "Validar isolamento multi-tenant e operação do Supabase com testes remotos controlados"
  5: "Manter a definição dos planos em código sincronizada com o espelho SQL"
proximos_passos_recomendados:
  1: "Aplicar supabase/migrations/20260930_trainer_ai_usage.sql e publicar o backend atualizado"
  2: "Validar fluxos autenticados e isolamento de dados no backend hospedado"
  3: "Persistir sessões InfinitePay e aplicar idempotência aos webhooks"
  4: "Adicionar observabilidade, alertas e procedimento de rollback"
  5: "Publicar CORS restrito e revisar bypass de auth em dev"
```

---

## 12. Como Rodar o Projeto (referência rápida)

```bash
# Backend
cd backend
python -m venv .venv && .venv\Scripts\activate   # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
# Swagger: http://localhost:8000/docs

# Mobile
cd mobile
flutter pub get
flutter run

# Atalhos (Makefile)
make install-backend
make run-backend
make test-backend
make run-mobile
```

Variáveis de ambiente essenciais do backend (`backend/.env`): `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_JWT_SECRET`, `RESEND_API_KEY` (opcional, cai em mock), `CORS_ORIGINS`.

---

*Fim do documento. Para atualizações futuras, revisar principalmente as seções 6 (regras de negócio), 8 (pontos de atenção) e 11 (resumo estruturado) sempre que houver mudança de schema, endpoints ou modelo de negócio.*
