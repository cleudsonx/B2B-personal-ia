
# Auditoria Completa do Sistema — B2B Personal IA ("Mr. Coach")

> Documento vivo de referência técnica e de negócio para o projeto B2B Personal IA.
>
> - Última atualização: 2026-10-01
> - Escopo revisado: `backend/`, `mobile/`, `supabase/`, `landing/`, arquivos de deploy e serviços externos observados no código real.
> - Verificação em 2026-10-01: revisão do batch 4; `57 passed, 2 warnings`, `flutter analyze` sem issues (0 erros / 0 avisos) e `render.yaml` válido.
> - Estado verificado no código: sessões e RPC de cotas foram implementadas; `/process-card` rejeita PAN/CVV em produção e valida ownership; webhook grava eventos após mutação. Persistência de sessão, atomicidade sob falha/concorrência e configuração remota ainda não foram comprovadas integralmente.
> - Limite da verificação: disponibilidade pública do frontend não comprova os fluxos autenticados, o estado do banco remoto ou a operação de pagamentos.

---

## 0. Resumo Executivo (TL;DR)

O projeto **B2B Personal IA** é uma plataforma SaaS B2B voltada a personal trainers e consultorias que usam IA para:

1. gerar fichas de treino personalizadas a partir de anamnese clínica;
2. adaptar exercícios em tempo real no ambiente físico da academia;
3. gerenciar alunos, assinaturas e alertas biomecânicos;
4. oferecer um assistente de IA focado em biomecânica, fisiologia, periodização e estratégia de retenção comercial.

A revisão atual do código mostra uma base modular em FastAPI e Flutter, e o frontend está publicado em `shaipados.com`. O backend implementa fluxos de geração de treino, adaptação, assinatura, validação documental e IA conversacional. A publicação do frontend não foi tratada como prova de que todos os serviços de backend e pagamentos estejam operacionais.

O batch 4 adiciona sessões no Supabase, reserva SQL de cota, ownership em `/process-card` e rejeição de PAN/CVV em produção. O checkout hospedado está na tela Flutter. Permanecem ressalvas: o contrato legado ainda recebe PAN/CVV antes de rejeitá-los; falha no `upsert` da sessão pode ser apenas logada; o registro idempotente não é atômico com a mutação; e a reserva de cota usa fallback não atômico quando a RPC falha. Migrations e configuração remotas não foram verificadas nesta revisão.

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
1. **Checkout hospedado de cartão**: ✅ A tela Flutter abre checkout oficial do Asaas; o endpoint legado `/process-card` retorna `400` em produção. ⚠️ A rota e o schema ainda aceitam campos PAN/CVV no request antes da rejeição.
2. **Ativação direta de plano pago**: ✅ BLOQUEADA em `/activate-plan` em produção; `starter` continua ativável diretamente.
3. **Autenticação de checkout/polling**: ✅ `/checkout-session` e `/check-status/{order_nsu}` exigem JWT e derivam o treinador do token.
4. **Persistência de sessão**: ⚠️ migration/tabela e leitura/escrita existem; `save_checkout_session()` apenas registra warning se o `upsert` falhar, então o checkout pode responder com sessão não durável.
5. **Ownership no pagamento com cartão**: ✅ o código consulta o proprietário e bloqueia sessão de outro treinador antes de qualquer chamada Asaas; teste local cobre `403`.
6. **PAN/CVV na API**: ⚠️ produção rejeita `/process-card` com `400`, mas o endpoint e schema continuam recebendo esses campos. O fluxo visual atual usa checkout hospedado; remover o contrato legado para reduzir a superfície PCI.
7. **Webhook/idempotência**: ⚠️ evento só é marcado depois de uma mutação persistida, mas `check → efeito → insert` não é transacional; falha no insert é ignorada pela rota e duplicatas concorrentes ainda podem aplicar efeitos duas vezes.
8. **Cotas de IA**: ⚠️ RPC reserva atomicamente quando disponível; em exceção o serviço faz fallback para consultar e incrementar, que não é atômico. Cota pode exceder sob concorrência nesse caminho.
9. **JWT/configuração remota**: tokens sem assinatura são rejeitados em produção; secrets, migrations e versão ativa no Render/Supabase não foram verificados remotamente.
10. **Cobertura local**: ✅ `57` testes passam; ⚠️ fixture global substitui Supabase por memória, então testes de sessão/idempotência/cota não cobrem falhas de gravação, Postgres ou concorrência real.


---

## 10. Parecer Final da Auditoria Revisada

### Status geral
O frontend está publicado e acessível. O batch 4 adiciona sessões persistidas, reserva de cota por RPC, ownership e bloqueio de cartão bruto em produção. A prontidão do checkout ainda não está demonstrada: gravação de sessão pode falhar sem impedir resposta, idempotência não é transacional e cota tem fallback não atômico.

### Impacto da revisão atual
A análise revisou o commit `c8b400b`: checkout hospedado na UI, tabela `checkout_sessions`, RPC de reserva e 57 testes. No código, a escrita da sessão captura falhas sem propagá-las; a reserva de cota cai para leitura/incremento não atômicos se a RPC falhar; webhook verifica, aplica efeito e grava evento em operações separadas. O endpoint legado ainda recebe PAN/CVV, embora rejeite em produção. Os testes mockam Supabase; Git/testes locais não comprovam deploy, secrets, migrations remotas ou comportamento sob concorrência real.

### Diagnóstico final
- Produto: promissor, com diferencial real e bem definido.
- Arquitetura: boa, coerente e modular.
- Backend: funcional, com endpoints e regras implementadas.
- Dados: esquema e CRUD Supabase presentes; persistência mensal de IA depende da migração nova; validação remota pendente.
- Produção: frontend publicado; checkout Asaas ainda não deve ser considerado pronto até remover o contrato PAN/CVV, fazer persistência falhar fechado, tornar idempotência e cota atômicas e validar o fluxo remoto.

### Parecer curto
O sistema está em etapa de **validação técnica e de produto**, e a evolução recomendada é priorizar:

1. remover `/process-card` e `CardPaymentRequest` com PAN/CVV, mantendo somente checkout hospedado;
2. fazer falha no `save_checkout_session` impedir criação/retorno de sessão em produção;
3. implementar claim/efeito/registro de webhook em operação transacional ou atômica, com retry recuperável;
4. remover fallback não atômico da reserva de cotas em produção;
5. validar propriedade da sessão em cartão e callback com cenários positivos/negativos;
6. testar concorrência e falhas contra Supabase/Postgres de teste, não apenas memória;
7. confirmar no Render versão/secrets e no Supabase migrations; executar E2E sandbox sem expor credenciais.

Com essas ações, o projeto deixa de ser um MVP robusto e passa a ser uma plataforma pronta para operação B2B real.

---

## 11. Evidência de Verificação

Durante a validação, foram executados testes na venv do backend:

```bash
cd backend
.venv\Scripts\python -m pytest -q
```

Resultado em 2026-10-01 no commit `c8b400b`: `57 passed, 2 warnings`; `flutter analyze` sem issues; `render.yaml` válido. A fixture `backend/tests/conftest.py` força `ENVIRONMENT=development` e substitui `get_client()` por cliente nulo. Portanto, a suíte não exercita falhas reais de upsert, RPC Supabase, concorrência/idempotência no Postgres ou cobrança real; estado remoto permanece não verificado.
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

### 8.3 🟡 Checkout Asaas parcialmente endurecido (batch 4)
O commit `c8b400b` adiciona sessões persistidas, reserva de cotas por RPC e validação de ownership. Revisão do código encontrou ressalvas que impedem marcar todos os critérios como resolvidos:
- A UI usa checkout hospedado Asaas e não apresenta campos de PAN/CVV. O endpoint deprecated `/process-card` ainda existe com `CardPaymentRequest` contendo esses campos; em produção retorna `400` antes de encaminhá-los ao gateway, mas o backend ainda recebe e valida o payload. Remover o endpoint/schema legado para retirar essa superfície.
- `/process-card` compara o treinador autenticado com o dono da sessão, mas o processamento direto foi desativado em produção; o critério de ownership deve continuar coberto caso o endpoint seja removido ou reaproveitado.
- Sessões usam a tabela `checkout_sessions`, mas `save_checkout_session()` captura erro no `upsert`, registra warning e retorna normalmente. `/checkout-session` pode, portanto, responder com sessão que não ficou durável; o app pode iniciar pagamento e webhook/polling perder o vínculo após restart.
- `get_checkout_session()` também converte erros de leitura em `None`; o webhook pode não recuperar metadados e não ativar a assinatura, embora responda sucesso ao provedor.
- Idempotência segue a sequência consulta evento → aplica mutação → insere evento. A chave única evita gravação duplicada, mas não serializa a mutação concorrente; retorno `False` de `record_processed_event()` não impede resposta de sucesso. Duas entregas podem aplicar efeitos antes da disputa pelo insert.
- Evento com metadados ausentes não é marcado pelo handler, mas erro de escrita da tabela de idempotência após mutação também não é propagado. O resultado é retry ambíguo e possível repetição de efeitos.
- A reserva SQL é atômica quando `reserve_trainer_ai_usage` funciona. Em exceção, `reserve_monthly_ai_quota()` faz fallback de leitura seguida de incremento, que não é atômico e pode exceder cota sob concorrência.
- Testes batch 4 passam localmente, mas fixture global substitui Supabase por memória; não valida falhas de `upsert`, corrida de webhooks ou fallback da RPC em produção.
- URL live e variáveis do blueprint não comprovam versão ativa, segredo configurado nem migrations aplicadas no Render/Supabase remoto.

### 8.3.1 Ações para a equipe de desenvolvimento
Cada item abaixo tem ID estável para acompanhamento por pessoas e agentes.

**PAY-001 | P0 | ✅ MITIGADO EM PRODUÇÃO | Ownership do pagamento com cartão**
Ação: `/process-card` compara o treinador autenticado com o proprietário da sessão; em produção, o endpoint também rejeita processamento direto de PAN/CVV.
Aceite verificado em teste local: treinador A não consegue usar a sessão do treinador B (`403`) e chamadas de cartão em produção são rejeitadas (`400`); a execução real do gateway permanece bloqueada.

**PAY-002 | P0 | ⚠️ PARCIAL | Remover PAN/CVV do backend**
Ação: a UI Flutter usa checkout hospedado Asaas e o endpoint `/process-card` retorna `400` em produção. Entretanto, endpoint e schema ainda aceitam PAN/CVV e o corpo chega à aplicação antes da rejeição.
Aceite pendente: remover endpoint/schema e confirmar que nenhum PAN/CVV é enviado à API Shaipados; não declarar conformidade PCI com o contrato atual.

**PAY-003 | P0 | ⚠️ PARCIAL | Persistir sessão e propriedade**
Ação: migration `20261001_checkout_sessions_and_quota.sql` e métodos de persistência existem, mas `save_checkout_session()` engole falhas do `upsert` e retorna sem erro.
Aceite pendente: falha de gravação deve impedir emissão/retorno da sessão; após restart/worker diferente, polling e webhook devem recuperar treinador, plano e ciclo do Supabase. Aplicação remota da migration ainda precisa de evidência.

**PAY-004 | P1 | ⚠️ PARCIAL | Tornar webhook durável e idempotente**
Ação: evento só é registrado após mutação bem-sucedida, mas a verificação, mutação e inserção não formam uma transação/claim atômica; falha no insert é ignorada pela rota.
Aceite pendente: eventos concorrentes geram um único efeito; erro ao registrar evento não retorna sucesso; eventos sem metadados permanecem reprocessáveis; comprovar contra Supabase de teste.

**AI-001 | P1 | ⚠️ PARCIAL | Reservar cota de IA atomicamente**
Ação: RPC de reserva e chamadas antes do Gemini estão implementadas; quando a RPC lança erro, o serviço usa fallback de leitura seguida de incremento, que não é atômico.
Aceite pendente: em produção, indisponibilidade/ausência da RPC deve falhar fechado ou usar alternativa comprovadamente atômica; chamadas simultâneas nunca ultrapassam a cota.

**QA-001 | P1 | ⚠️ COBERTURA LOCAL, SEM INTEGRAÇÃO REAL | Testes de segurança e concorrência**
Ação: 57 testes passam localmente, incluindo regressões de ownership, sessão, cota e webhook. A fixture global força desenvolvimento e mocka o cliente Supabase; os testes não validam transações/concorrência no Postgres.
Aceite pendente: integração com banco de teste cobre corrida de webhooks, erro de gravação, recuperação pós-restart e reserva de cotas concorrente.

**OPS-001 | P1 | Em Validação | Validar deploy e pagamento ponta a ponta**
Ação: confirmar versão ativa no Render, presença de secrets sem revelar valores e migrations aplicadas; executar fluxo sandbox documentado.

### 8.4 🟢 Duplicação de código do serviço Gemini B2B (RESOLVIDO)
Os arquivos legados/duplicados foram devidamente isolados na pasta [backend/legacy/](backend/legacy/), eliminando a poluição do módulo ativo e padronizando o uso exclusivo de `GeminiService` assíncrono via `google-genai`.

### 8.5 🟢 Inconsistência de nomes de modelo Gemini (RESOLVIDO)
A configuração em `config.py` e `render.yaml` foi padronizada para o modelo oficial estável `gemini-2.5-flash`. O método `_get_model_candidates()` do `GeminiService` prioriza ativamente esses valores do `settings` antes da cascata de fallback.

### 8.6 🟢 Isolamento Multi-tenant e Assinatura Criptográfica JWT (RESOLVIDO)
O `security.py` foi reforçado: em `ENVIRONMENT=production`, tokens sem assinatura ou com assinatura inválida são sumariamente rejeitados com `401 Unauthorized` (sem fallback para `verify_signature=False`). O `trainer_id` nos endpoints de assinatura e treino é estritamente derivado das claims do token autenticado em produção.

### 8.7 🟡 Contador mensal de IA
O batch 4 adicionou `reserve_trainer_ai_usage` e chama `reserve_monthly_ai_quota()` antes do Gemini nos três endpoints de IA. A RPC é atômica quando disponível, mas `reserve_monthly_ai_quota()` captura exceções e recorre a leitura seguida de incremento, que não é atômico. Em produção, falha/ausência da RPC pode reabrir condição de corrida; não marcar AI-001 como resolvido até remover o fallback ou provar alternativa atômica. Aplicação da migration no banco remoto não foi confirmada.

### 8.8 🟡 CORS em produção
O código e o blueprint Render substituem wildcard por `https://shaipados.com` quando `ENVIRONMENT=production`; desenvolvimento ainda permite wildcard. O blueprint está em `origin/main`, mas não foi verificado se o Render já o aplicou. Caso o frontend use outro host web de produção, ele deve ser incluído explicitamente em `CORS_ORIGINS`.

### 8.9 🟡 Cobertura de integração e idempotência
No commit `c8b400b`, `backend/tests/test_security_audit.py` e a suíte totalizam 57 testes passando. Porém, `backend/tests/conftest.py` força `ENVIRONMENT=development` e substitui `get_client()` por `None`; os testes de sessão/idempotência/reserva cobrem memória, não a tabela `processed_webhook_events`, `checkout_sessions` ou as RPCs reais. Faltam testes de integração com banco, concorrência, falha de gravação e callbacks do provedor.

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
