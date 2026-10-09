# Plano de Testes - B2B Personal IA

**Versao:** 1.0
**Escopo:** backend FastAPI, Flutter Android/Web, landing page, Supabase, integrações externas e deploy.
**Status:** plano operacional; nem todas as suites descritas estão implementadas.

## 1. Objetivo e regra de leitura

Este documento orienta pessoas e agentes de programação por IA a escolher, executar, avaliar e relatar testes do projeto sem confundir cobertura existente com cobertura planejada. A combinação de dados, estados, plataformas e falhas é virtualmente ilimitada; portanto, este plano cobre as classes de risco relevantes e prioriza caminhos críticos, limites, isolamento entre usuários, falhas e recuperação.

Os status usados nas tabelas são:

- **Existe:** há teste automatizado identificado no repositório. Isso não significa cobertura completa.
- **Parcial:** há cobertura relacionada, mas faltam cenários, integração real ou execução em CI.
- **Planejado:** requer novos testes, ferramentas ou infraestrutura.
- **Manual:** exige dispositivo, ambiente ou avaliação humana; automatize quando houver retorno suficiente.

Não declare uma etapa aprovada só porque o comando terminou: confira o código de saída, o resumo e os testes efetivamente descobertos. Não transforme falhas em sucesso, não pule testes sem registrar o motivo e não afirme que uma categoria foi validada se a infraestrutura dela não existe.

## 2. Diagnóstico da cobertura atual

### 2.1 Suites identificadas

Backend: `backend/tests/` contém testes de configuração, schemas, validadores, workouts/alunos, convites, perfis públicos, autenticação/capacidades, notícias de IA, assinaturas e auditoria de segurança. Os arquivos incluem `test_workouts.py`, `test_subscriptions.py`, `test_security_audit.py`, `test_auth_capabilities.py`, `test_invites.py`, `test_public.py`, `test_schemas.py`, `test_validators.py`, `test_config.py` e `test_ai_news.py`.

Flutter: `mobile/test/` contém testes de widget/navegação, perfil do aluno, serialização do plano e sessão de treino/cache/sincronização offline. `meta_navigation_test.dart` contém apenas um teste dummy e não representa cobertura real.

CI/deploy: `.github/workflows/ci.yml` instala dependências Python, executa pytest e Flutter analyze; os workflows separados compilam APK e Web, e constroem a imagem Docker do backend.

### 2.2 Limitações e débitos conhecidos

- **Bloqueador P0:** o comando de pytest no CI termina com `|| echo "Testes concluídos com sucesso"`, mascarando falhas. Remover o fallback e deixar o exit code do pytest determinar o resultado.
- **Bloqueador P0:** CI não executa `flutter test`; adicionar essa etapa depois de `flutter pub get`.
- **Bloqueador P0:** a última execução registrada durante a elaboração deste plano terminou com **66 aprovados e 9 falhos** no backend. Reexecutar no commit atual e investigar antes de usar como baseline verde. Falhas registradas: `test_evolution_api_key_has_no_hardcoded_default`, `test_update_subscription_status_dev_mode`, `test_webhook_idempotency_service_methods`, `test_webhook_asaas_ignores_duplicate_event`, `test_atomic_ai_quota_reservation_and_release`, `test_ai_quota_reservation_fails_closed_in_production_if_rpc_fails`, `test_durable_checkout_session_storage`, `test_webhook_does_not_mark_event_processed_if_metadata_missing` e `test_webhook_atomic_claim_blocks_concurrent_duplicate`.
- `backend/tests/conftest.py` força `ENVIRONMENT=development` e substitui o cliente Supabase por `None` em todos os testes. Isso isola testes unitários, mas não prova persistência, RLS, migrations, concorrência real ou comportamento de produção.
- `supabase/` contém migrations, mas não foi identificada configuração local `supabase/config.toml`; os testes de banco descritos adiante ainda exigem setup.
- Não foi identificada configuração/suite de Playwright, browser E2E, Flutter integration test, teste de carga ou ambiente de staging automatizado.
- Flutter analyze permite que infos e warnings não sejam fatais. APK/Web/Docker build não substituem testes de comportamento nem smoke test do serviço implantado.

**Conclusão:** não, a suíte atual não cobre todos os cenários relevantes nem todos os tipos de teste aplicáveis. Há uma base útil, mas insuficiente para afirmar cobertura integral ou aprovação para release.

## 3. Preparação e comandos existentes

Execute na raiz do repositório. Em PowerShell, use `;` para comandos sequenciais. Não coloque chaves reais em argumentos, logs, relatórios ou commits.

### 3.1 Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m pytest -q
```

Em Linux/macOS, a ativação é `source .venv/bin/activate`. Alternativa já existente na raiz: `make test-backend` (requer `pytest` acessível no ambiente). Para localizar/repetir uma falha:

```powershell
python -m pytest tests/test_security_audit.py -q
python -m pytest tests/test_security_audit.py::test_webhook_atomic_claim_blocks_concurrent_duplicate -q
python -m pytest -vv --tb=short
```

### 3.2 Flutter

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

Builds equivalentes aos workflows existentes:

```powershell
flutter build apk --release --dart-define=API_BASE_URL="https://b2b-personal-ia-backend.onrender.com/api/v1"
flutter build web --release --base-href "/" --dart-define=API_BASE_URL="https://b2b-personal-ia-backend.onrender.com/api/v1"
```

Build não substitui teste em emulador/dispositivo/browser. Para diagnóstico local, execute a suite mais focada primeiro, depois a suite completa.

### 3.3 Backend local e verificação manual

Com ambiente e variáveis de desenvolvimento configurados conforme `README.md`:

```powershell
cd backend
uvicorn app.main:app --reload --port 8000
```

Verifique `GET http://localhost:8000/health` (esperado: HTTP 200 e `status: healthy`) e abra `http://localhost:8000/docs`. Não chame APIs reais de pagamento, Gemini ou WhatsApp durante testes automatizados sem sandbox e autorização explícita.

### 3.4 Ferramentas não configuradas

Os comandos abaixo são alvos de implementação, não comandos garantidos no checkout atual:

- Browser E2E: adicionar Playwright e configuração; alvo recomendado `npx playwright test`.
- Supabase local: instalar/validar Supabase CLI, adicionar configuração local e seed descartável; só então executar reset/migrations e testes de RLS contra essa instância.
- Carga: adicionar scripts e dados sintéticos; alvo recomendado `k6 run tests/performance/<arquivo>.js`.
- Acessibilidade automatizada: escolher ferramenta compatível com Flutter Web/browser após configurar E2E. Completar com avaliação manual em Android.
- Auditoria de dependências: adotar ferramenta aprovada pelo projeto (por exemplo `pip-audit` para Python e auditoria compatível com pub para Dart), fixar/registrar versões e definir política de severidade.

Agente: não instale nem introduza essas ferramentas silenciosamente. Proponha a dependência e seu custo, ou documente o cenário como bloqueado por infraestrutura ausente.

## 4. Níveis de teste e critérios

| ID | Nível/tipo | Escopo e critério de aprovação | Estado |
|---|---|---|---|
| T01 | Unitário backend | Funções isoladas, validações, regras de quota/proration, parsing e estados; resultados determinísticos, incluindo limites e erros. | Existe, parcial |
| T02 | Contrato/schema API | Pydantic request/response, tipos, campos obrigatórios/opcionais, limites, erros HTTP e compatibilidade OpenAPI. | Existe, parcial |
| T03 | Integração API | FastAPI + dependências substituídas por doubles controlados; auth, autorização, códigos HTTP e integração entre serviços. | Existe, parcial |
| T04 | Integração real de dados | Supabase/Postgres descartável, migrations aplicadas do zero e sobre banco atualizado, constraints, transações, concorrência e RLS por papel. | Planejado |
| T05 | Contrato de provedores | Stubs/sandbox de Gemini, Asaas, Mercado Pago, Stripe, InfinitePay, Evolution/WhatsApp e SMTP; payloads válidos/inválidos e evolução de contrato. | Parcial |
| T06 | Widget/unidade Flutter | Estado, validação de formulários, navegação, renderização, loading/error/empty, serialização e ações. | Existe, parcial |
| T07 | Integração mobile | Fluxos reais em emulador/dispositivo com API de teste: login, treino, offline, retomada, deep links e permissões. | Planejado |
| T08 | Browser E2E | Landing e Flutter Web em navegador real; jornadas ponta a ponta e regressão visual essencial. | Planejado |
| T09 | Segurança/privacidade | Autenticação/autorização, isolamento entre contas, RLS, segredo, webhook, abuso, dados pessoais e logs. | Parcial; integração planejada |
| T10 | Resiliência/compatibilidade | Timeout, indisponibilidade, retry, idempotência, duplicidade, perda de rede, atualização/retomada e versões suportadas. | Parcial |
| T11 | Performance/carga | Latência e taxa de erro sob carga realista, quota/concorrência e consumo de recursos; orçamento definido antes do teste. | Planejado |
| T12 | Acessibilidade/usabilidade | Leitor de tela, contraste, foco, tamanho de alvo, fonte ampliada, orientação e compreensão dos estados/erros. | Manual/planejado |
| T13 | Build/deploy/smoke | Build reproduzível, inicialização do container, healthcheck, configuração, deploy em staging e rollback testável. | Parcial |
| T14 | Exploratória/regressão | Checklist orientado a risco em contas limpas, dados persistentes, papéis e dispositivos; defeitos reproduzíveis viram testes. | Manual |
| T15 | IA/qualidade de conteúdo | Schema, segurança, pertinência às restrições, grounding, recusa segura e revisão humana; não exigir texto idêntico do modelo. | Parcial |

## 5. Matriz de jornadas e cenários

Cada cenário abaixo precisa ter: pré-condição, dados, ação, resultado observável e limpeza. Automatize cenários críticos e determinísticos; use mocks para serviços externos em unitários e sandbox apenas em integração autorizada.

| ID | Jornada/categoria | Cenários mínimos e resultado esperado | Prioridade/estado |
|---|---|---|---|
| J01 | Inicialização/API | API inicia sem segredo opcional em desenvolvimento; `/health` responde 200; erro de configuração crítica falha fechado em produção; CORS aceita apenas origens configuradas. | P0; parcial |
| J02 | Cadastro e autenticação | Cadastro válido/inválido, login, sessão expirada, token malformado/sem assinatura, recuperação OTP válido/expirado/reutilizado, logout/revogação e sessão antiga recusada. | P0; parcial |
| J03 | Papel e autorização | Cliente não acessa função de treinador; treinador sem MFA/AAL2 não entra em contexto privilegiado; perfil multi-papel alterna apenas com nível exigido; aluno não lê/escreve dados de outro aluno. | P0; parcial em mocks, RLS real pendente |
| J04 | Convite/vínculo | Criar convite autorizado, normalizar telefone, validar sem consumir, token expirado/inexistente/reutilizado, vínculo correto e tentativas concorrentes sem vínculo duplicado. | P0; parcial |
| J05 | Perfil/anamnese | Validar campos/limites, restrições e lesões; salvar/carregar/editar; falha de persistência não exibe sucesso nem dispara revisão prematura; dado de exemplo nunca aparece como real. | P0; parcial |
| J06 | Alunos | Criar/listar/editar/arquivar/excluir, isolamento por treinador, quota, tentativa de desarquivar acima do limite e recuperação após erro. | P0; parcial |
| J07 | Prescrição/treino | Gerar treino com divisões, séries, repetições, descanso e instruções válidos; respeitar anamnese/restrições; editar, aprovar/publicar, substituir ficha e verificar visibilidade correta para aluno. | P0; parcial |
| J08 | Adaptação/emergência | Aparelho ocupado e dor: alternativa biomecanicamente compatível; restrição não pode ser violada; indisponibilidade/saída inválida da IA deve falhar com segurança; registrar motivo e alertar treinador uma única vez. | P0; parcial |
| J09 | Sessão/offline | Sem rede: salvar em fila `pendingSync`, nunca declarar `synced`; reiniciar app e retomar fila; reconectar e enviar; retry não duplica; cache/fila isolados por conta e removidos no logout/limpeza. | P0; parcial em unidade/widget |
| J10 | Assistente/IA | Usuário autorizado, quota disponível, entrada válida, saída conforme schema; quota concorrente não excede limite; falha Gemini libera/reserva quota corretamente; timeout, resposta malformada, prompt injection e pedido inseguro têm tratamento controlado. | P0/P1; parcial |
| J11 | Assinatura/pagamento | Catálogo único; cálculo upgrade/downgrade/proration; checkout durável e vinculado ao usuário autenticado; acesso cruzado negado; pendente/recusado não ativa plano; cartão bruto nunca armazenado/processado. | P0; parcial |
| J12 | Webhooks de pagamento | Assinatura/token inválido recusado; evento válido atualiza estado correto; evento duplicado/concurrente processado uma vez; metadata incompleta ou falha de persistência não marca evento como concluído; replay não concede acesso indevido. | P0; parcial em mocks, banco concorrente pendente |
| J13 | Social e vitrine | Perfil privado/incompleto não aparece nem por URL direta; publicar/despublicar muda listagem; dados públicos são mínimos; ranking não inventa atividade; filtros/paginação/limites e links/contatos funcionam. | P1; parcial |
| J14 | WhatsApp/Evolution | Webhook autenticado, payload inválido/duplicado, timeout, retry e indisponibilidade; nenhuma chave em resposta/log; estado de conexão reflete o provedor, não uma simulação. | P1; parcial |
| J15 | Landing/Web | Página abre em desktop/mobile; links e CTA levam ao destino correto; carregamento/erros/deep links e refresh não quebram rota; sem overflow ou conteúdo essencial inacessível. | P1; manual, E2E ausente |
| J16 | Migração/deploy | Banco novo aplica migrations na ordem; upgrade de banco anterior preserva dados; container inicia com configuração documentada; healthcheck passa; secrets ausentes não fazem serviço de produção iniciar em modo inseguro. | P0/P1; planejado |

## 6. Segurança, dados e testes negativos

Antes de release, executar testes para:

1. **Autorização:** ausência de token, token inválido/expirado, papel errado, AAL2 insuficiente, ID de outro tenant/aluno/treinador e tentativa de escalada por alteração de campos.
2. **RLS:** leitura, inserção, atualização e exclusão permitidas/negadas para anon, aluno A, aluno B, treinador A e treinador B. Testar service-role apenas em backend controlado; nunca embutir essa chave no app.
3. **Webhooks e pagamentos:** assinatura ausente/inválida, corpo adulterado, replay, duplicidade, evento fora de ordem, concorrência e metadata inconsistente.
4. **Dados sensíveis:** CPF, telefone, lesões, anamnese, tokens e dados de cartão não aparecem em logs, analytics, mensagens de erro ou cache de outra conta. Usar dados sintéticos.
5. **Abuso:** payload enorme/malformado, limites de paginação, chamadas repetidas, quota excedida, prompt injection e consumo não autorizado de IA.
6. **Segredos/dependências:** detectar segredo com scanner aprovado e revisar CVEs; não colar achados que contenham credenciais no relatório. Rotacionar imediatamente qualquer segredo exposto.

Nunca testar pagamentos ou mensagens reais contra usuários reais. Usar sandbox, mocks ou ambiente descartável; verificar cleanup e não reutilizar dados de produção.

## 7. Resiliência, concorrência e qualidade de IA

- Simular latência, timeout, 4xx/5xx, desconexão antes/depois de persistir e retorno malformado dos provedores.
- Confirmar retries limitados com backoff, sem retry de operação não idempotente sem chave/idempotência.
- Exercitar duas requisições simultâneas na última unidade de quota, no mesmo webhook, no mesmo convite e no mesmo registro de sessão.
- Verificar consistência após fechar/reabrir app, alternar usuário, atualizar versão e recuperar conexão.
- Para Gemini, não comparar frase exata. Validar JSON/schema, campos obrigatórios, respeito a restrições explícitas, ausência de alegações médicas indevidas, conteúdo seguro e comportamento de fallback. Fixar versão/modelo e conjunto de casos sintéticos quando medir regressão.
- Registrar latência, tokens/custo estimado e taxa de saída inválida em testes de IA; usar limites e chaves de sandbox com orçamento definido.

## 8. Execução por prioridade e gates

### P0 - Gate obrigatório de PR/release

1. Reproduzir e triagem das 9 falhas conhecidas do backend; estabelecer baseline confiável.
2. Backend: `python -m pytest -q`, com exit code preservado. CI deve falhar quando pytest falhar.
3. Flutter: `flutter analyze` e `flutter test`; nenhuma falha. Remover teste dummy ou substituí-lo por cenário real.
4. Testar auth/autorização, papéis, convites, prescrição/adaptação, offline, quota e pagamento/webhook (mocks unitários/API).
5. Validar isolamento por conta e ausência de sucesso falso em falha de persistência/sincronização.
6. Compilar artefatos afetados: APK para mudança Android/mobile; Web para mudança Flutter Web; imagem Docker para mudança backend.

**Gate atual:** não aprovado até as falhas de backend serem explicadas/resolvidas e o CI deixar de mascarar resultados. Não liberar com suite vermelha apenas porque um workflow exibiu status verde.

### P1 - Gate de release candidato

1. Testes de integração com Supabase/Postgres descartável: migrations, constraints, RLS e concorrência.
2. Flutter integration em ao menos Android suportado; browser E2E para a superfície Web/landing implantada.
3. Contratos em sandbox dos provedores realmente habilitados no release.
4. Smoke test em staging: health, login, fluxo principal por papel, publicação de treino, leitura pelo aluno, adaptação e webhook de sandbox.
5. Acessibilidade manual, rotação/orientação, rede ruim, reinstalação/atualização e verificação de logs.

### P2 - Antes de escala ou periodicamente

1. Carga representativa de leitura, treino/IA, sincronização e webhooks com SLO acordado; sem carga contra produção sem autorização.
2. Testes de longa duração, degradação/recovery, backup/restore e rollback de migrations/deploy.
3. Auditoria de dependências/segredos, revisão OWASP aplicável, compatibilidade de dispositivos/navegadores e teste exploratório.

## 9. Matriz de ambiente e dados

| Ambiente | Permitido | Proibido/controle |
|---|---|---|
| Unitário/CI | Mocks determinísticos, relógio controlado, dados sintéticos e IDs fixos quando úteis. | Rede/provedor real, segredo de produção e dependência de ordem entre testes. |
| Integração local | Banco/Supabase descartável, seed idempotente e usuário fictício por papel. | Reset de projeto compartilhado; apontar `SUPABASE_URL` para produção. |
| Staging/sandbox | Contas e cartões sandbox dedicados, WhatsApp de teste e logs com acesso controlado. | Dados pessoais reais, envio a clientes, pagamento real ou chave privilegiada no cliente. |
| Produção | Apenas smoke de leitura/health explicitamente autorizado e seguro. | CRUD destrutivo, carga, reset, webhooks falsos, mensagens e pagamentos de teste. |

Dados criados devem usar prefixo identificável de teste, ser isolados por execução e removidos ao final. Em caso de falha de cleanup, registrar IDs sem dados pessoais e limpar antes da próxima execução.

## 10. Protocolo obrigatório para agente de IA

Ao receber uma tarefa de código, o agente deve:

1. Ler este plano e as instruções do repositório; identificar a jornada, o risco e os módulos afetados.
2. Verificar branch/estado do workspace e mudanças existentes. Não sobrescrever nem reverter alterações do usuário.
3. Escolher primeiro o teste mais próximo e barato que pode refutar a hipótese; escrever/ajustar teste antes ou junto da implementação quando aplicável.
4. Usar mocks em unitários e não chamar serviços externos reais. Se o cenário exigir infraestrutura ausente, explicar o bloqueio e não alegar aprovação.
5. Rodar teste focado após a edição; depois rodar os gates P0 pertinentes e a suite completa quando viável. Capturar comando, exit code, resumo, ambiente e falhas.
6. Nunca desabilitar teste, afrouxar assert, esconder erro, converter falha em sucesso ou marcar cenário como coberto sem evidência. Correção de teste só é válida se refletir o contrato pretendido, não para tornar a suite verde artificialmente.
7. Se falhar, classificar: regressão de código, teste inválido/flaky, dependência/ambiente, serviço externo ou requisito ambíguo. Reproduzir e registrar; não atribuir causa sem evidência.
8. Atualizar este plano quando uma suite/ferramenta/contrato mudar de forma relevante. Não registrar segredos, tokens, CPF real, payload pessoal ou dumps integrais de produção.

### Formato de relatório de execução

```text
Plano: Plano_de_Testes.md (versão 1.0)
Commit/branch:
Ambiente (OS, Python, Flutter, banco):
Escopo/jornadas e IDs:
Comandos executados + diretório:
Resultado: APROVADO | REPROVADO | BLOQUEADO | PARCIAL
Resumo: total / passou / falhou / ignorado
Falhas: ID, sintoma, evidência sanitizada, classificação e issue/ação
Limitações e infraestrutura não exercitada:
Dados de teste removidos? Sim/Não; evidência:
```

**APROVADO** só quando todos os testes obrigatórios do escopo passaram e não há gate aplicável ignorado. **PARCIAL** quando alguma categoria aplicável não foi exercitada. **BLOQUEADO** quando dependência/infraestrutura impede teste. **REPROVADO** quando há falha reproduzível ou critério não atendido.

## 11. Definição de pronto para considerar cobertura confiável

- CI executa backend e `flutter test` com falha não mascarada; `flutter analyze` tem política explícita de severidade.
- Todas as falhas conhecidas do backend têm causa, correção ou issue com responsável e decisão de release.
- Cenários P0 têm teste automatizado determinístico e evidência no pipeline; exceções têm aprovação explícita.
- Banco/RLS, browser/mobile E2E e smoke de staging têm ambientes e comandos reproduzíveis documentados.
- Nenhum teste usa dados ou credenciais reais; segredos não aparecem no cliente ou nos relatórios.
- Testes de IA e provedores têm mocks/sandbox, limites de custo e critérios de conteúdo seguros.
- A matriz deste documento é atualizada quando jornadas, provedores, políticas, tabelas ou plataformas mudarem.