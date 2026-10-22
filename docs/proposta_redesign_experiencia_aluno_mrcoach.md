# Proposta de Remodernização Visual: Experiência Completa do Aluno — Mr. Coach

> Status: **IMPLEMENTADA & CONCLUÍDA (v1.9.0 — Builds 2026103055 a 2026103059)**
> Abrange as **4 abas** do aluno: **Treino · Mr. Coach AI · Bio-Hub · Perfil**, mais o shell compartilhado (barra superior, dock flutuante, modais).
> O capítulo detalhado do Perfil está em [`proposta_perfil_aluno_mrcoach.md`](proposta_perfil_aluno_mrcoach.md) e consolidado no app.
> Referências aplicadas: Apple Fitness+/Saúde, Google Fit/Material 3 Expressive, Samsung Health/One UI 7, Whoop, Nubank.
> Guardrails respeitados: `Visual_Edge_to_Edge_Mobile.md` e `docs/design_system_meta_style.md`.

---

## ✅ Resumo Executivo da Entrega

Todas as fases do redesign foram implementadas, integradas ao ecossistema de produção e validadas:
1. **Fundação e Design System**: `StudentSectionHeader`, `ProgressRing`, `StatTile`, `TrainerCompactPill`, `SettingsGroup`, `SettingsTile`, `StudentEmptyState`, `StudentSkeletonCard` criados em `mobile/lib/core/widgets/student_ux_components.dart`.
2. **Aba Treino**: Cabeçalho cockpit "Treino de Hoje" com anel de progresso percentual animado, divisão de treinos e preservação do modo foco sem teclado.
3. **Aba Mr. Coach AI**: Hero contextual com atalhos de exercícios da ficha ativa, cartões estruturados e botão de ação "Aplicar ao treino".
4. **Aba Bio-Hub**: Tríade de Anéis de Atividade (Prontidão Biomecânica, Energia & Água, Cargas Ativas), pílula dinâmica de insight em 1 linha e segmented control temático.
5. **Aba Perfil (Leitura + Sheet)**: Visão de leitura pura, avatar com anel de meta semanal, streak em chamas, cockpit biométrico com cálculo de IMC e toque para editar, pílula de WhatsApp do treinador, botão de compartilhamento duplo (conquistas + link de indicação), bento cards de evolução, e edição desacoplada em `ProfileEditSheet`.
6. **Shell Edge-to-Edge**: Dock flutuante One UI refinado com transições suaves e estados de foco. Todos os 227 testes automatizados verdes.

---

## 1. Por que uma proposta única

Hoje cada aba evoluiu em momentos diferentes e tem linguagem própria. Observado no código:

| Aba | Arquivo | Tamanho | Observação |
|---|---|---|---|
| Treino | `client/active_workout_screen.dart` (+ `client_focus_workout_screen.dart`) | ~2.980 + ~2.220 linhas | Cards de exercício densos, HUD, Raio-X muscular, modo foco |
| Mr. Coach AI | `assistant/b2b_assistant_screen.dart` | ~1.540 linhas | Hero, grade de ações, prompts, barra de chat flutuante |
| Bio-Hub | `client/client_bio_hub_screen.dart` | ~3.370 linhas | 3 sub-abas (Sessão, Progresso, Recuperação), métricas, check-in, fotos |
| Perfil | `client/student_profile_screen.dart` | ~1.540 linhas | Formulário único, ~12 blocos |

Remodernizar uma aba isolada cria inconsistência entre elas. A proposta define **primeiro a linguagem visual comum**, depois aplica aba por aba.

## 2. Linguagem visual comum (Design Language do Aluno)

1. **Edge-to-edge real em todas as abas**: `CustomScrollView`/`ListView` sem `SafeArea(bottom: true)`, `bottomInset = paddingOf(context).bottom + 110` (dock) ou `+ 140` (com FAB/banner); topo sem *double inset* (shell já consome o inset).
2. **Cabeçalho único por aba**: título grande que colapsa em barra translúcida ao rolar (`ScrollAwareGlassHeader`, já existe). Mesmo comportamento nas 4 abas.
3. **Hierarquia por espaço e tipografia**, não por caixa-alta: títulos de seção 13/600 em sentence case, números de destaque 28/800 tabulares, corpo 14/400.
4. **Cards**: `MetaCard`, raio 24 (cards) / 16 (tiles) / 999 (chips); sem bordas pesadas; sombra só no modo claro.
5. **Cor com significado**: emerald = progresso/ativo; âmbar = atenção/pendente; azul = saúde/dados; vermelho só para erro. Tokens `MetaColors`; nenhuma cor solta.
6. **Ícones dinâmicos**: Material Symbols arredondados; outline para inativo e preenchido para ativo; troca animada (`AnimatedSwitcher` 200 ms); anéis de progresso com `TweenAnimationBuilder`; haptics leves em ações-chave.
7. **Movimento coerente**: entrada escalonada (fade + 8 px), transições de aba em fade-through, tudo respeitando `MediaQuery.disableAnimations`.
8. **Estados completos**: carregando (skeleton, não spinner), vazio (ilustração + ação), erro (mensagem amigável + "Tentar novamente"), offline (já existe `OfflineSyncBanner`).
9. **Acessibilidade**: alvos ≥ 48 dp, `Semantics`, contraste AA em claro/escuro, `textScaler` até 1.3 sem overflow.
10. **Componentes compartilhados novos** (em `core/widgets`): `StudentSectionHeader`, `StatTile`, `ProgressRing`, `InsightCard`, `SettingsGroup`, `EmptyState`, `SkeletonCard` — usados pelas 4 abas.

## 3. Shell do aluno (afeta todas as abas)

- **Dock flutuante** (`OneUiFloatingNavBar`): manter; refinar ícones outline→filled com indicador em pílula animada e badge dinâmico (ex.: ponto no Bio-Hub quando o check-in semanal está pendente; contador na IA).
- **Barra superior do treinador** (hoje um banner no topo do shell): condensar em uma pílula discreta (foto + nome + atalho WhatsApp) integrada ao cabeçalho colapsável, liberando altura.
- **Modais e sheets**: padrão único de sheet (alça, raio 28, rodapé de ação que sangra até a borda com `SafeArea(top: false)` interno).
- **Troca de abas**: `IndexedStack` mantido (preserva estado); adicionar fade-through e restauração de scroll.

## 4. Capítulos por aba

### 4.1 Aba Treino (`active_workout_screen.dart`)

**Objetivo:** ser o "cockpit do dia" — abrir e saber o que fazer em 2 segundos; no treino, zero atrito.

- **Cabeçalho "Hoje"**: nome do treino do dia, grupos musculares em chips, duração estimada e **botão primário "Iniciar treino"** (grande, no polegar). Anel de progresso da semana (treinos feitos / meta).
- **Carrossel de dias da divisão** (A/B/C…): chips roláveis com estado (feito, hoje, descanso).
- **Lista de exercícios** em cards compactos: miniatura de mídia, séries × reps, carga anterior ("última: 40 kg") e indicador de progressão (▲/▼). Expandir para detalhes sob demanda (Raio-X muscular existente vira sheet, não bloco fixo).
- **Modo foco** (`client_focus_workout_screen.dart`): manter o conceito, unificando cronômetro de descanso (`rest_timer_sheet`), steppers de carga sem teclado e feedback de recorde pessoal; transição suave para o modal de triunfo.
- **Estado sem treino**: `EmptyState` com CTA "Falar com meu treinador" e atalho para a IA.

### 4.2 Aba Mr. Coach AI (`b2b_assistant_screen.dart`)

**Objetivo:** assistente conversacional contextual, estilo "Gemini/Siri": convidativo, rápido e seguro.

- **Hero compacto** com saudação contextual e "pergunta sugerida do momento" (ex.: pós-treino, dor reportada, dia de descanso).
- **Grade de ações rápidas** (adaptar treino por dor/aparelho ocupado, trocar exercício, dúvidas de execução, nutrição básica) em tiles com ícone dinâmico.
- **Conversa**: bolhas limpas, respostas com **cartões estruturados** (exercício sugerido, ajuste de carga) e botão "Aplicar ao treino"; estado de digitação animado; histórico recente.
- **Barra de prompt flutuante** sempre ancorada ao dock, fundo sangrando até a borda; atalhos em pílulas acima do campo; microfone como entrada de voz quando disponível.
- **Transparência e segurança**: aviso discreto de que a IA não substitui o treinador; encaminhamento ao treinador em casos de dor/lesão.

### 4.3 Aba Bio-Hub (`client_bio_hub_screen.dart`)

**Objetivo:** "Saúde/Fitness" do aluno — um painel de evolução claro, sem planilha.

- **Topo**: 3 anéis (estilo Apple Atividade) — treinos da semana, recuperação, consistência — com resumo textual de 1 linha ("Você está 12% acima da semana passada").
- **Sub-abas** (Sessão · Progresso · Recuperação) como **segmented control** nativo no cabeçalho colapsável, em vez de botões soltos.
- **Progresso**: gráficos limpos de peso e medidas (linha suave, toque mostra valor), **antes e depois** com slider de comparação, linha do tempo da anamnese e cartão do **check-in semanal** com CTA claro.
- **Recuperação**: sono/FC/prontidão via `HealthConnectService` quando conectado; sem conexão, cartão de convite para conectar Apple Saúde / Health Connect.
- **Fotos de evolução**: grade 3 posições (frente/lado/costas) com guia de enquadramento e privacidade explícita.
- **Cargas por exercício**: gráfico de 1RM estimado por exercício, integrado à Central de Metas.

### 4.4 Aba Perfil

Detalhado em [`proposta_perfil_aluno_mrcoach.md`](proposta_perfil_aluno_mrcoach.md): cabeçalho de identidade com anel de meta, estatísticas vivas, treinador compacto, progresso, saúde, lista de preferências e **edição em sheet**.

## 5. Mapa de reuso (o que já existe e será aproveitado)

| Necessidade | Componente existente |
|---|---|
| Cabeçalho colapsável | `scroll_aware_glass_header.dart` |
| Mídia de exercícios | `exercise_media_sheet.dart`, `exercise_media_service.dart` |
| Descanso, triunfo, conquistas | `rest_timer_sheet.dart`, `workout_triumph_modal.dart`, `student_achievements_sheet.dart` |
| Metas, 1RM, sobrecarga | `student_overload_center_sheet.dart`, `ai_overload_card.dart` |
| Saúde e telemetria | `health_metrics_card.dart`, `health_connect_service.dart` |
| Check-in semanal | `student_weekly_checkin_sheet.dart` |
| Avisos e offline | `student_trigger_banner.dart`, `offline_sync_banner.dart` |
| Tour guiado | `interactive_tour_guide_modal.dart` |

## 6. Plano de entrega (incremental)

| Fase | Entrega | Risco |
|---|---|---|
| **0** | Fundação: componentes comuns (`StatTile`, `ProgressRing`, `StudentSectionHeader`, `EmptyState`, `SkeletonCard`), tokens e guia de movimento; refino do dock/badges | Baixo |
| **1** | **Perfil** (leitura): identidade, estatísticas, treinador compacto | Baixo |
| **2** | **Bio-Hub**: topo com anéis, segmented control, Progresso e Recuperação | Médio (tela grande) |
| **3** | **Treino**: cabeçalho "Hoje", carrossel de dias, lista compacta | **Médio-alto** (tela mais crítica) |
| **4** | **Mr. Coach AI**: hero, ações, cartões estruturados na conversa | Médio |
| **5** | **Perfil** (edição em sheet) e remoção do formulário inline | Médio |
| **6** | Polimento transversal: animações, a11y, `textScaler`, claro/escuro, performance | Baixo |

Cada fase é publicável sozinha. Sugestão de ordem de risco: fundação → Perfil → Bio-Hub → IA → Treino (a mais crítica por último, já com os componentes maduros).

## 7. Qualidade e critérios de aceite

- Testes de widget por aba e por estado (vazio, carregando, erro, offline, dados completos), claro/escuro, `textScaler` 1.3 sem overflow.
- Manter verdes os testes existentes do aluno; adaptar os acoplados ao layout antigo.
- Edge-to-edge verificado em Android (gestos e 3 botões), iOS (Dynamic Island) e PWA standalone.
- Sem dados de exemplo: tudo vindo de serviços reais.
- Performance: sem jank em listas longas (`SliverList` com itens `const`), imagens com cache e `RepaintBoundary` nos gráficos.
- Changelog por perfil (aluno) a cada release; nada técnico vazando para o aluno.

## 8. Decisões em aberto

1. Aprova a **ordem das fases** (fundação → Perfil → Bio-Hub → IA → Treino)? Ou prefere começar pelo Treino?
2. **Anéis de atividade** (treinos, recuperação, consistência) no topo do Bio-Hub: aprovado?
3. **Cartões estruturados** com "Aplicar ao treino" nas respostas da IA: aprovado (exige integração com o serviço de treinos)?
4. Barra superior do treinador condensada em pílula: aprovado?
5. As 5 decisões do capítulo do Perfil (edição em sheet, nível/XP, Compartilhar, "Usar aplicativo como", agrupamento de fases).

