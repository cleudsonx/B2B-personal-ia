# Proposta UX/UI: Perfil do Aluno ("Eu") — Mr. Coach

> Status: **PROPOSTA (aguardando aprovação)** · Escopo: `StudentProfileScreen` (`mobile/lib/features/client/student_profile_screen.dart`, ~1.540 linhas)
> Referências: Apple Fitness+/Saúde, Google Fit/Material 3 Expressive, Samsung Health/One UI 7, Whoop, Nubank.
> Guardrails obrigatórios: `Visual_Edge_to_Edge_Mobile.md` e `docs/design_system_meta_style.md`.

---

## 1. Diagnóstico do perfil atual

A tela hoje é **um formulário longo e único** (`ListView` com ~12 blocos em caixa-alta), misturando três naturezas diferentes de conteúdo:

| Bloco atual | Natureza | Problema |
|---|---|---|
| Foto, "Usar aplicativo como", Dados pessoais, Biometria, Fuso, Restrições + botão "Salvar Alterações" | **Edição de dados** | Todo acesso ao perfil já cai em modo formulário; teclado e validação disputam atenção |
| Central de Metas & 1RM, Galeria de Conquistas | **Progresso / motivação** | Enterrados no meio do formulário, parecem "botões", não conquistas |
| Treinador responsável, Anamnese | **Relacionamento / saúde** | Cards grandes e pesados antes de qualquer dado do próprio aluno |
| Aparência, Segurança, Sessão | **Configurações** | Misturadas ao perfil, sem hierarquia |

Consequências: identidade fraca (a foto é só mais um item), motivação escondida, ação primária ambígua ("Salvar" sempre visível) e sensação de "tela administrativa" em vez de "meu espaço".

## 2. Princípio de design

> **Perfil = vitrine do progresso; edição = ação sob demanda; configurações = camada separada.**
> É o padrão de Apple Saúde/Fitness (cabeçalho de identidade + resumos), Samsung Health ("Eu" com cards) e Google (hub de conta com atalhos).

Regras:
1. **Leitura primeiro, edição depois** — nada de campos abertos na tela principal.
2. **Um foco por bloco**, cards em `MetaCard` com raio 24, sem bordas pesadas; hierarquia por tipografia e espaço, não por caixa-alta.
3. **Edge-to-edge real** — `CustomScrollView` sem `SafeArea(bottom: true)`, `bottomInset = paddingOf(context).bottom + 110` (dock flutuante), cabeçalho que sangra sob a status bar.
4. **Ícones dinâmicos** — Material Symbols arredondados com peso/preenchimento variável por estado (ativo = preenchido + tom emerald; pendente = contorno + âmbar), micro-animação ao entrar no viewport.
5. **Reuso antes de criar** — aproveitar widgets que já existem (ver seção 6).

## 3. Arquitetura da nova tela (wireframe)

```
┌──────────────────────────────────────────────┐
│ ░░░ gradiente suave sob a status bar ░░░     │  <- ScrollAwareGlassHeader (já existe)
│                                              │
│            ( foto 96px + anel de streak )    │  <- anel = progresso da meta semanal
│              Nome do Aluno                   │
│     🔥 12 dias  ·  Nível 7  ·  Desde Mar/26  │
│        [ Editar perfil ]   [ Compartilhar ]  │
│                                              │
│ ┌────────────┬────────────┬────────────┐     │
│ │ 72,4 kg    │ 1,78 m     │ IMC 22,8   │     │  <- Estatísticas vivas (toque = edita)
│ │ ▼ 0,6 sem. │ altura     │ saudável   │     │
│ └────────────┴────────────┴────────────┘     │
│                                              │
│  Meu treinador                               │
│ ┌──────────────────────────────────────────┐ │
│ │ (foto) Prof. Cleudson · CREF ativo   [💬]│ │  <- 1 linha, atalho WhatsApp
│ └──────────────────────────────────────────┘ │
│                                              │
│  Meu progresso                               │
│ ┌────────────────────┐ ┌───────────────────┐ │
│ │ Metas & 1RM        │ │ Conquistas        │ │  <- 2 cards lado a lado
│ │ Supino 82 kg ▲ 4%  │ │ 🏅 3 novas        │ │     (abrem as sheets existentes)
│ └────────────────────┘ └───────────────────┘ │
│                                              │
│  Saúde                                       │
│ ┌──────────────────────────────────────────┐ │
│ │ Anamnese  ●●●●○  80% completa        ›   │ │  <- anel de completude, não card gigante
│ │ Restrições: 1 ativa (ombro)          ›   │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│  Preferências e conta           (lista agrupada, estilo iOS/One UI)
│  ◐ Aparência           Automático        ›   │
│  🌐 Fuso horário        São Paulo         ›   │
│  🔐 Segurança           Autenticador ativo›  │
│  🔔 Notificações        ›                    │
│  ⎋ Sair deste aparelho / de todos            │
│                                              │
│   v1.9.0 · Mr. Coach Personal IA             │  <- AppVersionFooter
└──────────────────────────────────────────────┘
```

### 3.1 Cabeçalho de identidade
- Avatar 96 px com **anel de progresso** (meta semanal de treinos) e selo de streak; toque abre `AvatarSelectorSheet` (já existe).
- Linha de status em chips: streak, nível, "membro desde".
- Ações: **Editar perfil** (botão principal tonal) e **Compartilhar** (card de conquistas; reaproveita o fluxo de indicação existente).
- Cabeçalho colapsa com o scroll para um título compacto translúcido (`ScrollAwareGlassHeader`).

### 3.2 Estatísticas vivas (substitui "Biometria rápida")
- 3 tiles: **peso (com delta semanal)**, **altura**, **IMC com faixa**. Os dados já existem no check-in semanal e em `HealthConnectService`.
- Toque abre um **bottom sheet de edição** com teclado numérico e stepper — o mesmo padrão sem teclado do foco de treino.
- Selo discreto "via Apple Saúde / Health Connect" quando o dado vier do conector.

### 3.3 Meu treinador (compacto)
- De card hero para **linha de 72 px**: foto, nome, CREF e botão de WhatsApp. Estado "pendente" vira call-to-action de convite.

### 3.4 Meu progresso
- **Metas & 1RM** e **Conquistas** viram 2 cards de dados reais (último 1RM e variação; badges novas), não botões. Abrem as sheets que já existem (`StudentOverloadCenterSheet`, `StudentAchievementsSheet`).

### 3.5 Saúde
- **Anamnese** vira linha com **anel de completude** (%), em vez do card gigante; o card hero só reaparece quando a revisão está vencida (renovação de periodização).
- **Restrições/lesões** como chips editáveis (adicionar/remover), com ícone por região corporal.

### 3.6 Preferências e conta (lista agrupada)
- Estilo "Ajustes" nativo: grupos com cantos arredondados, ícone em quadrado tonal, valor atual à direita e chevron.
- Aparência, fuso, segurança, notificações, "usar aplicativo como", sair. Cada item abre sheet/rota dedicada — **nenhum campo inline**.

## 4. Edição sob demanda (substitui o formulário + "Salvar")

| Antes | Depois |
|---|---|
| Formulário único + botão "Salvar Alterações" | **"Editar perfil"** abre `DraggableScrollableSheet` em tela cheia com Dados pessoais, Biometria, Restrições, Fuso |
| Validação ao salvar tudo | Validação por campo; botão fixo no rodapé (barra com fundo sangrando até a borda, `SafeArea(top:false)` interno) |
| Sem rascunho | Alterações pendentes → confirmação ao fechar ("Descartar alterações?") |

A lógica de persistência (`_saveProfile`, validações, snacks "Perfil atualizado com sucesso") é **mantida**; muda só onde ela é invocada.

## 5. Sistema visual

- **Cores**: tokens existentes (`MetaColors.emerald`, surface/card/cardBorder, light/dark). Âmbar para pendências, azul para dados de saúde. Sem novas cores soltas.
- **Tipografia**: títulos de seção em sentence case 13/600 (adeus caixa-alta de 10 px), números grandes 28/800 tabulares.
- **Ícones dinâmicos**: troca outline→filled por estado, `AnimatedSwitcher` 200 ms, anel de progresso com `TweenAnimationBuilder`; haptics leves nas ações.
- **Movimento**: entrada escalonada dos cards (fade + 8 px), respeitando `MediaQuery.disableAnimations`.
- **Acessibilidade**: alvos ≥ 48 dp, `Semantics` nos tiles, contraste AA nos dois temas, fonte escalável sem overflow (textScaler até 1.3).
- **Cantos**: 24 (cards) / 16 (tiles) / 999 (chips), consistente com o resto do app.

## 6. Reuso de componentes existentes

| Necessidade | Já existe |
|---|---|
| Cabeçalho translúcido ao scroll | `scroll_aware_glass_header.dart` |
| Seleção de foto/avatar | `avatar_selector_sheet.dart` |
| Metas, 1RM, conquistas | `student_overload_center_sheet.dart`, `student_achievements_sheet.dart` |
| Telemetria de peso/saúde | `health_metrics_card.dart`, `health_connect_service.dart` |
| Rodapé de versão | `app_version_footer.dart` |
| Compartilhar / indicar | `referral_service.dart`, `referral_landing_screen.dart` |

Novos componentes mínimos: `ProfileIdentityHeader`, `ProfileStatTile`, `ProfileSettingsGroup`, `ProfileEditSheet` (todos em `core/widgets`, com `widgetbook`/preview).

## 7. Plano de entrega (incremental, sem big-bang)

| Fase | Entrega | Risco |
|---|---|---|
| **1** | Cabeçalho de identidade + estatísticas + treinador compacto (leitura) | Baixo |
| **2** | Cards Meu progresso + linha de Saúde com anel de anamnese | Baixo |
| **3** | Lista de Preferências e conta (agrupada) | Baixo |
| **4** | `ProfileEditSheet` e remoção do formulário inline | **Médio** (mover validações e testes) |
| **5** | Polimento: animações, a11y, textScaler, dark/light, testes de widget | Baixo |

Cada fase é publicável sozinha; a Fase 4 só entra após as anteriores estarem estáveis.

## 8. Testes e critérios de aceite

- Testes de widget: renderização por estado (com/sem treinador, anamnese incompleta, dado de saúde), abertura das sheets, edição + descarte, textScaler 1.3 sem overflow, light/dark.
- Manter verdes `student_profile_test.dart` e os testes de gamificação; adaptar os que dependem do formulário inline.
- Edge-to-edge conferido em Android (gestos e 3 botões), iOS (Dynamic Island) e PWA standalone.
- Nenhum dado de exemplo: tudo vindo do perfil/serviços reais (regra já adotada em `student_profile_test`).
- Changelog por perfil (aluno) na release correspondente.

## 9. Decisões em aberto (precisam do seu "ok")

1. **Edição em sheet** (recomendado) ou manter edição inline com botão salvar?
2. Exibir **nível/XP** no cabeçalho, ou apenas streak e meta semanal?
3. Botão **Compartilhar** no perfil: card de conquistas, convite de indicação, ou ambos?
4. "Usar aplicativo como" (troca de papel) fica na lista de preferências ou visível só para quem tem mais de um papel?
5. Começar pela **Fase 1** em uma única entrega ou já agrupar Fases 1–3?
