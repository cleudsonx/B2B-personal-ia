# Plano de Testes Mestre - B2B Personal IA (Mr. Coach)

**Versão:** 2.0 (Atualizada em Outubro/2026)  
**Escopo:** Backend FastAPI (Python 3.12), Mobile/Web Flutter 3.x, Supabase Auth/DB (RLS/MFA), Evolution API (WhatsApp), Gateway de Pagamentos (Asaas/Pix) e Motor de IA (Gemini).  
**Status Atual de Execução:** Baseline Verde — 108/108 testes backend aprovados | 41/41 testes Flutter aprovados.  
**Regra Operacional Crítica:** Testes de regressão e suites completas devem ser executados após grandes mudanças ou alterações críticas no sistema, **sempre solicitando autorização prévia ao usuário** antes de sua aplicação.

---

## 1. Sumário Executivo & Baseline Atual

O sistema conta com cobertura automatizada nas camadas unitária, integração de serviços, schemas e regras de segurança (MFA AAL2, controle de quotas de IA, idempotência de webhooks, trava educativa de convites e travas profissionais de CREF).

| Camada / Componente | Qtd. Testes Automatizados | Status Atual | Ferramenta |
|---|---|---|---|
| **Backend Unitário & API** | 108 testes | **100% Aprovado (108/108)** | `pytest` + `pytest-asyncio` |
| **Mobile Flutter Widgets & Services** | 41 testes | **100% Aprovado (41/41)** | `flutter test` |
| **Segurança & Controle de Acesso (MFA/RLS)** | 24 testes específicos | **100% Aprovado** | `test_auth_capabilities.py` + `teacher_mfa_test.dart` |
| **Auditoria e Webhooks Idempotentes** | 38 testes específicos | **100% Aprovado** | `test_security_audit.py` + `test_webhook_leases.py` |
| **Testes de Stress & Carga (Performance)** | Em planejamento (k6) | *Pendente implementação* | k6 / Locust |
| **Testes E2E (End-to-End em dispositivos/browser)** | Manuais estruturados | *Pendente automação* | Patrol (Mobile) / Playwright (Web) |

---

## 2. Inventário de Suítes Automatizadas Existentes

### 2.1 Backend (`backend/tests/` — 108 testes)

1. **`test_auth_capabilities.py` (7 testes):**
   - Exigência de AAL2 (MFA TOTP) para endpoints restritos de treinador.
   - Bloqueio de clientes tentando acessar escopos de treinador.
   - Alternância de contexto em perfis com duplo papel (`trainer` e `client`).
   - Bloqueio de sessões emitidas antes de evento de revogação global (`session_revoked_at`).
2. **`test_security_audit.py` (20 testes):**
   - Ausência de API keys mockadas/chumbadas em produção.
   - Bloqueio de concorrência atômica em webhooks de pagamento (anti-duplicação).
   - Idempotência de eventos recebidos (Asaas / Pix).
   - Reserva e liberação atômica de quota de tokens de IA com fail-closed em produção.
   - Isolamento de dados entre inquilinos/treinadores diferentes.
3. **`test_subscriptions.py` (23 testes):**
   - Criação de planos, cálculo de prorrogação e proration.
   - Ciclo de vida da assinatura (ativação, suspensão, inadimplência e cancelamento).
   - Sessões duráveis de checkout atreladas unicamente ao usuário autenticado.
4. **`test_webhook_leases.py` (18 testes):**
   - Controle distribuído de locks e leases para processamento concorrente seguro de webhooks.
5. **`test_workouts.py` (12 testes):**
   - Prescrição de treinos, montagem de fichas, divisões A/B/C/D.
   - Trava de proteção de créditos: bloqueio de geração de treino para aluno com convite ainda pendente.
6. **`test_public.py` (3 testes):**
   - Vitrine pública de treinadores (`GET /api/v1/public/trainers/{username}`).
   - Trava de CREF: bloqueio de vitrine caso o documento profissional esteja ausente/inválido.
7. **`test_gamification_service.py` (8 testes):**
   - Motor de streaks (dias consecutivos treinados) e progresso da meta diária (`daily_goal_progress`).
8. **`test_invites.py` (7 testes):**
   - Geração de tokens de convite, validação de unicidade, telefone normalizado e resgate seguro.
9. **`test_validators.py` (5 testes):**
   - Sanitização de entradas, formatação de telefone, CPF e dados biométricos.
10. **`test_config.py` (1 teste):**
    - Validação de integridade das variáveis de ambiente e fallbacks seguros.
11. **`test_ai_news.py` (1 teste):**
    - Parsing e entrega das atualizações e insights de inteligência artificial.
12. **`test_schemas.py` (3 testes):**
    - Validação de contratos Pydantic v2 de entrada e saída da API.

### 2.2 Mobile Flutter (`mobile/test/` — 41 testes)

1. **`meta_navigation_test.dart` (6 testes):**
   - Conformidade visual dos temas Meta Dark e Meta Light (cores, superfícies e sem sombras).
   - Inicialização padrão de fábrica em `ThemeMode.system` (acompanha o sistema operacional).
   - Alternância e persistência de tema no `SharedPreferences`.
   - Resolução dinâmica de tokens de contexto via `MetaColors` e adaptação do `SquircleButton`.
2. **`teacher_mfa_test.dart` (4 testes):**
   - Tratamento amigável e conversão de `AuthApiException` (422 `mfa_verification_failed`).
   - Tratamento de falhas de conexão de rede e erros de sincronização de relógio TOTP.
3. **`student_details_test.dart` (15 testes):**
   - Edição de perfil do aluno com proteção do e-mail (read-only).
   - Confirmação explícita para arquivamento e exclusão de alunos.
   - Tratamento de timeout de exclusão com feedback limpo.
   - Reativação controlada de alunos arquivados.
4. **`student_profile_test.dart` (11 testes):**
   - Validações de limites físicos, dados de anamnese e restrições médicas.
   - Disparo de revisão biomecânica apenas quando restrições físicas forem alteradas.
   - Garantia de que dados mockados nunca apareçam no lugar de dados reais.
5. **`workout_session_test.dart` (1 teste):**
   - Persistência e sincronização de sessões de treino com cache offline.
6. **`widget_test.dart` (4 testes):**
   - Navegação na casca do treinador através das 5 abas sem overflow de layout.
   - Serialização e desserialização JSON de planos de treino para cache local.

---

## 3. Matriz de Cobertura por Tipo de Teste

| Categoria de Teste | O que cobre | Status Atual | Lacuna / Oportunidade de Melhoria |
|---|---|---|---|
| **Testes Unitários** | Lógicas puras de cálculo, schemas, validações e parsing | **Coberto** | Expandir testes de edge-cases com entradas de payload gigantes |
| **Testes de Integração API** | Endpoints FastAPI com mocks assíncronos do Supabase | **Coberto** | Criar container de Supabase local para testes de RLS real |
| **Testes de Regressão** | Garantia de que alterações recentes não quebram funcionalidades | **Coberto** | Automatizar gatilho no GitHub Actions |
| **Testes Funcionais Mobile** | Componentes visuais, fluxos de navegação e reatividade de estado | **Coberto** | Adicionar testes de tela para o fluxo do Aluno durante o treino |
| **Testes de Stress & Carga** | Desempenho sob alta concorrência e picos de requisições | **Pendente** | Implementar scripts k6 para simular picos de webhooks de pagamento e IA |
| **Testes E2E (End-to-End)** | Jornada real do usuário da tela até o banco de dados | **Manual** | Criar suíte E2E automatizada com Patrol ou Playwright |
| **Testes de Segurança (SAST/DAST)**| Injeção de prompt, escalada de privilégios e vazamento de chaves | **Parcial** | Integrar verificação de dependências (`pip-audit`, `trivy`) ao CI |

---

## 4. Plano de Testes de Stress e Carga (Novo - Proposta de Implementação)

Para suportar o crescimento da base de personal trainers sem degradação de performance, propõe-se a seguinte suíte de stress com **k6**:

### Cenário 1: Disparo Concorrente de Webhooks de Pagamento (Asaas)
- **Objetivo:** Garantir que 100 requisições simultâneas de confirmação de Pix não gerem ativações duplicadas nem causem deadlock no banco de dados.
- **Métrica Alvo:** Taxa de erro de 0%, tempo de resposta p95 < 800ms.
- **Mecanismo Testado:** Locks de concorrência em `test_webhook_leases.py`.

### Cenário 2: Prescrição Massiva via Motor Gemini
- **Objetivo:** Avaliar a estabilidade das filas quando 20 professores solicitam periodização/treinos ao mesmo tempo.
- **Métrica Alvo:** Respeito rigoroso às quotas de tokens (sem estourar o limite de taxa do modelo), fila graciosa com retorno de status em progresso.

### Cenário 3: Sincronização de Treinos Concorrentes (App Aluno)
- **Objetivo:** Testar 200 alunos finalizando treinos e enviando payloads de exercícios simultaneamente.
- **Métrica Alvo:** Latência p99 < 1.2s, integridade de gravação das séries e cálculo do streak sem desvios.

---

## 5. Diretrizes para Testes End-to-End (E2E) e Manuais Críticos

### Checklist Manual para Releases Críticos
1. **Fluxo do Professor:**
   - [ ] Login com e-mail/senha.
   - [ ] Ativação/Confirmação de MFA (TOTP) com abertura direta no Google Authenticator.
   - [ ] Criação de convite para novo aluno com envio via WhatsApp.
   - [ ] Prescrição de treino bloqueada preventivamente se o aluno estiver pendente.
   - [ ] Edição da Vitrine Pública e verificação de bloqueio caso CREF esteja vazio.
   - [ ] Alternância entre Modo Escuro e Modo Claro respeitando o Meta Design System.
2. **Fluxo do Aluno:**
   - [ ] Abertura do link de convite na Landing Page.
   - [ ] Cadastro com preenchimento da ficha de anamnese.
   - [ ] Execução de treino no `ActiveWorkoutScreen` com incremento real de Streak 🔥.
   - [ ] Teste de perda de conexão: treino marcado offline e sincronizado ao reconectar.

---

## 6. Procedimento Operacional Obrigatório (Protocolo de IA)

> [!IMPORTANT]
> **REGRA DE OURO:** Após qualquer refatoração estrutural, grande mudança arquitetural ou alteração em módulos críticos (Autenticação, MFA, Pagamentos, Prescrição com IA ou Banco de Dados):
> 1. O agente **NÃO deve rodar suítes pesadas em loop** sem alinhamento.
> 2. O agente deve **solicitar autorização expressa ao usuário** antes de disparar os testes:
>    > *"Identifiquei uma mudança crítica no módulo [X]. Deseja que eu execute a suíte de testes de regressão agora para validar a estabilidade?"*
> 3. Caso autorizado, executar a suíte correspondente (`mobile` ou `backend`), registrar o resultado no formato padronizado e comprovar 100% de sucesso antes do push.

---

## 7. Formato Padronizado de Relatório de Execução

```text
Plano: Plano_de_Testes.md (Versão 2.0)
Data/Hora: [AAAA-MM-DD HH:MM:SS]
Módulo Afetado: [MFA / Pagamentos / Prescrição / Tema / Perfil]
Suíte Executada: [flutter test / pytest]
Resultado: [APROVADO (100%) | REPROVADO | PARCIAL]
Contagem: Total: X | Passou: X | Falhou: 0 | Ignorado: 0
Impacto em Produção: [Nenhum risco de quebra identificado]
```