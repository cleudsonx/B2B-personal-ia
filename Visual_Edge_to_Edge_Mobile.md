# 🛠️ Arquitetura & Especificação Técnica: Experiência Visual Edge-to-Edge Global (Mobile, Web & PWA)

## 1. Objetivo e Escopo Sistêmico
Garantir uma experiência de renderização **Edge-to-Edge imersiva, contínua e sem costuras** (padrão *Tier-1 Fintech & Fitness*: Apple Fitness+, Whoop, Nubank e Samsung One UI 7) em **toda a plataforma Mr. Coach / Shaipados**:
- **Android Nativo (API 21 a Android 15+)**: Temas `LaunchTheme` e `NormalTheme` tanto em modo claro (`values/styles.xml`) quanto escuro (`values-night/styles.xml`), com suporte total a *camera cutouts* (`shortEdges`) e remoção de *scrims* semitransparentes do sistema.
- **iOS Nativo (iOS 13 a iOS 18+)**: Controle declarativo por *View Controller* respeitando *Notch*, *Dynamic Island* e *Home Indicator*.
- **Web & PWA Standalone (Safari iOS / Chrome Android)**: Renderização `viewport-fit=cover`, barra de status translúcida (`black-translucent`), bloqueio de *elastic overscroll* (`overscroll-behavior: none`) e altura dinâmica `100dvh`.
- **Três Ecossistemas do App (Aluno, Personal Trainer e Admin Mission Control)**: Padronização nos 3 shells principais (`MainShellScreen`, `TrainerMainLayout` e `AdminShellScreen`), telas internas, barras de chat (`B2BAssistantScreen`) e *BottomSheets* modais.

---

## 2. Regras Rígidas de Arquitetura e Anti-Patterns (Design System Guardrails)

1. **PROIBIDO envolver o `Scaffold` inteiro ou listas roláveis com `SafeArea(bottom: true)`**:
   - Isso cria *letterboxing* artificial (faixas opacas cortando o scroll antes do fim físico do display).
   - Quando `SafeArea` for usado no `body`, deve-se declarar explicitamente `SafeArea(bottom: false, ...)` e delegar o espaçamento inferior ao `padding` interno do `ListView` / `SingleChildScrollView` / `CustomScrollView`.
2. **Prevenção de *Double Top Inset* em Layouts Compostos**:
   - Quando um Shell superior (ex.: `MainShellScreen` no mobile) já consome `MediaQuery.paddingOf(context).top` no seu cabeçalho fixo, a área filha (`Expanded` / `IndexedStack`) **DEVE** ser envolvida por `MediaQuery.removePadding(context: context, removeTop: true, ...)` para impedir que as telas filhas apliquem o deslocamento do *Notch* uma segunda vez.
3. **Barras Inferiores de Input / Ação Fixa (`Container` externo + `SafeArea(top: false)` interno)**:
   - Em barras ancoradas no rodapé (ex.: `_buildFloatingPromptBar` no `B2BAssistantScreen` ou modais inferiores), o `Container` com a cor de fundo e borda superior deve ficar **por fora**, e o `SafeArea(top: false)` **por dentro**. Assim, o fundo sangra até a borda física inferior enquanto o campo de texto permanece protegido acima da barra de gestos.
4. **Cálculo Dinâmico de `bottomInset` em Listas Roláveis**:
   - Telas com `OneUiFloatingNavBar` (`extendBody: true`): `bottom: MediaQuery.paddingOf(context).bottom + 110` (ou `+ 140` quando houver FAB/banners).
   - Telas avulsas sem dock flutuante: `bottom: MediaQuery.paddingOf(context).bottom + 24`.
5. **Sincronia Absoluta de Contraste e Desativação de Scrims (`AppTheme.systemUiOverlayFor`)**:
   - Fundo superior escuro (`isDark == true`) → Ícones claros (`statusBarIconBrightness: Brightness.light` no Android / `statusBarBrightness: Brightness.dark` no iOS).
   - Fundo superior claro (`isDark == false`) → Ícones escuros (`statusBarIconBrightness: Brightness.dark` no Android / `statusBarBrightness: Brightness.light` no iOS).
   - Sempre definir `systemStatusBarContrastEnforced: false` e `systemNavigationBarContrastEnforced: false` para impedir que o Android 10–15 pinte faixas cinzas sobre barras transparentes.

---

## 3. Arquitetura Implementada por Camada

### Camada 1: Configuração Nativa Android (Light & Night Modes)
**Arquivos:**
- `mobile/android/app/src/main/res/values/styles.xml`
- `mobile/android/app/src/main/res/values-night/styles.xml`

Ambos os arquivos configuram `LaunchTheme` e `NormalTheme` com transparência total e suporte a *Display Cutouts* (`shortEdges`), garantindo que nem o boot (Splash) nem o modo noturno do sistema operacional criem barras pretas na base ou no topo:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
        <item name="android:enforceNavigationBarContrast">false</item>
        <item name="android:enforceStatusBarContrast">false</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
        <item name="android:enforceNavigationBarContrast">false</item>
        <item name="android:enforceStatusBarContrast">false</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
</resources>
```

### Camada 2: Configuração Nativa iOS & Web/PWA
1. **iOS (`mobile/ios/Runner/Info.plist`)**:
   ```xml
   <key>UIViewControllerBasedStatusBarAppearance</key>
   <true/>
   ```
2. **Web & PWA (`mobile/web/index.html`)**:
   - Meta viewport com `viewport-fit=cover` e `apple-mobile-web-app-status-bar-style="black-translucent"`.
   - CSS raiz com `min-height: 100dvh` e `overscroll-behavior: none` evitando *rubber-banding* branco nas extremidades.

### Camada 3: Motor Central de Tema e Inicialização (`AppTheme` + `main.dart`)
**Arquivos:**
- `mobile/lib/core/theme/app_theme.dart`
- `mobile/lib/main.dart`

1. **Helper Canônico `AppTheme.systemUiOverlayFor({required bool isDark})`**:
   Centraliza a criação do `SystemUiOverlayStyle` com barras transparentes e `ContrastEnforced: false`, injetado automaticamente no `AppBarTheme` de `AppTheme.darkTheme` e `AppTheme.lightTheme`.
2. **Wrapper Global no `MaterialApp.builder` (`main.dart`)**:
   Envolve toda a árvore de rotas (`PwaUpdateWrapper`) em um `AnnotatedRegion<SystemUiOverlayStyle>` reativo ao `ThemeController.instance`, garantindo que todas as telas do sistema herdem o comportamento Edge-to-Edge mesmo quando não possuem `AppBar`.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    AppTheme.systemUiOverlayFor(isDark: true),
  );
  // ...
  runApp(const B2BPersonalIaApp());
}
```

### Camada 4: Shells de Navegação e Dock Flutuante (`OneUiFloatingNavBar`)
1. **Dock Flutuante Translúcido (`mobile/lib/core/widgets/meta_components.dart`)**:
   - `OneUiFloatingNavBar` utiliza `BackdropFilter` (`sigmaX: 18, sigmaY: 18`) e calcula dinamicamente `bottomInset = MediaQuery.paddingOf(context).bottom`, aplicando `bottomInset > 0 ? bottomInset + 8 : 14` para flutuar acima do *Home Indicator*.
2. **Shell do Personal Trainer (`mobile/lib/features/trainer/presentation/screens/trainer_main_layout.dart`)**:
   - `Scaffold(extendBody: true)` com `AnnotatedRegion` dinâmico e 5 abas principais (`Alunos`, `Treinos`, `Social`, `Vitrine`, `Conta`).
3. **Shell do Aluno (`mobile/lib/main.dart` -> `MainShellScreen`)**:
   - `Scaffold(extendBody: true)` com cabeçalho compacto superior absorvendo `MediaQuery.paddingOf(context).top + 6` e `MediaQuery.removePadding(context: context, removeTop: true)` no `IndexedStack` das abas (`Treino`, `Mr. Coach AI`, `Bio-Hub`, `Perfil`).
4. **Shell do Admin Mission Control (`mobile/lib/features/admin/admin_shell_screen.dart`)**:
   - Envolvido por `AnnotatedRegion<SystemUiOverlayStyle>` configurado com `AppTheme.systemUiOverlayFor(isDark: true)` para manter fidelidade visual em todo o painel executivo.

### Camada 5: Telas Core, Perfis, Assistente IA e Modais
- **Treino Ativo & Modo Foco (`active_workout_screen.dart`, `client_focus_workout_screen.dart`)**:
  - `ListView` com `top: topPadding + 14` e `bottom: bottomPadding + 140`, permitindo que os cards de exercícios passem por trás da `OneUiFloatingNavBar` com efeito de vidro fosco e parem acima dela ao chegar ao fim.
- **Prescrição & Anamnese (`anamnesis_screen.dart`)**:
  - Formulário e revisor de periodização com `bottomInset` dinâmico para que o botão de submissão/aprovação nunca colida com a barra de gestos.
- **Assistente IA (`b2b_assistant_screen.dart`)**:
  - `_buildFloatingPromptBar` refatorado com `Container` externo e `SafeArea(top: false)` interno, eliminando espaçamento superior indevido e sangrando a cor de fundo até a borda inferior.
- **Conta & Perfil do Aluno (`account_screen.dart`, `student_profile_screen.dart`)**:
  - Paddings dinâmicos baseados em `MediaQuery.paddingOf(context).top` e `MediaQuery.paddingOf(context).bottom + 110`, garantindo leitura e toque desimpedidos nos botões de logout e rodapé de versão.
- **Telas Complementares & Landing Pages (`whatsapp_connection_screen.dart`, `trainer_consultancy_plans_screen.dart`, `trainer_plan_selection_screen.dart`, `ai_news_screen.dart`, `b2b_landing_screen.dart`, `public_trainer_directory_screen.dart`, `student_demo_screen.dart`, `auth_gate.dart`)**:
  - Padronizadas com `SafeArea(bottom: false)` e compensação inferior via `MediaQuery.paddingOf(context).bottom`.

### Camada 6: Scroll-Aware Glass Header / App Bar Dinâmica nos Feeds & Dashboards
**Arquivos:**
- `mobile/lib/core/widgets/scroll_aware_glass_header.dart`
- `mobile/lib/core/widgets/meta_components.dart`
- `mobile/lib/features/trainer/trainer_students_screen.dart`
- `mobile/lib/main.dart`

1. **Interpolação Dinâmica de Vidro Fosco (`ScrollAwareGlassHeader` & `SliverScrollAwareGlassHeader`)**:
   - Transição suave do estado de repouso (`scrollOffset == 0`: 100% cristalino e integrado ao background) para a lâmina de vidro translúcida (`scrollOffset >= 28px`: `BackdropFilter` com `sigmaX: 18, sigmaY: 18`, fundo translúcido `alpha: 0.85/0.90` e borda luminescente de 1px).
   - Suporte nativo tanto a `CustomScrollView` (via `SliverScrollAwareGlassHeader`) quanto a `Stack` e `ListView` roláveis com escuta reativa de `ScrollController`.
2. **Feed do Personal Trainer (`TrainerStudentsScreen`)**:
   - A lista de alunos flui continuamente por trás da barra superior e do campo de busca com desfoque de alta fidelidade visual, eliminando cortes secos.
3. **Cockpit do Aluno (`MainShellScreen`)**:
   - Barra superior com `BackdropFilter` em vidro fosco na transição das abas de Treino, Bio-Hub e Perfil.

---

## 4. Matriz de Impacto Técnico e Qualidade

| Dimensão | Implementação no Sistema | Benefício Direto |
|----------|--------------------------|------------------|
| **Android (Light & Dark)** | `styles.xml` e `values-night/styles.xml` sincronizados com `shortEdges` e `enforceNavigationBarContrast=false` | Elimina barras pretas no modo escuro do Android e na transição da Splash Screen. |
| **iOS & Dynamic Island** | `UIViewControllerBasedStatusBarAppearance=true` + `MediaQuery.paddingOf` | Respeito cirúrgico à Dynamic Island e ao Home Indicator em toda a navegação. |
| **Scroll-Aware Glass Header** | `ScrollAwareGlassHeader` com `BackdropFilter` (0 a 18px de blur dinâmico) | Transição translúcida premium nos feeds de alunos e treinos sem cortes secos. |
| **Prevenção de Duplo Padding** | `MediaQuery.removePadding(removeTop: true)` no `MainShellScreen` | Elimina espaço morto extra no topo das abas do aluno abaixo do cabeçalho. |
| **Consistência de Temas** | `AppTheme.systemUiOverlayFor(isDark: ...)` global no `MaterialApp.builder` e `AppBarTheme` | Qualquer nova tela criada já nasce 100% Edge-to-Edge no modo claro e escuro. |
| **Estabilidade & Testes** | `flutter analyze` (0 issues) + 166 testes automatizados passando | Garantia de zero regressão funcional ou visual. |

---

## 5. Checklist de Conformidade Global (100% Concluído)
- [x] `values/styles.xml` e `values-night/styles.xml` com `windowLayoutInDisplayCutoutMode="shortEdges"` e barras transparentes em `LaunchTheme` e `NormalTheme`
- [x] `Info.plist` com `UIViewControllerBasedStatusBarAppearance=true`
- [x] `web/index.html` com `viewport-fit=cover`, `black-translucent` e `overscroll-behavior: none`
- [x] `AppTheme.systemUiOverlayFor` criado e aplicado globalmente em `main.dart` e `AppBarTheme`
- [x] `ScrollAwareGlassHeader` e `SliverScrollAwareGlassHeader` implementados e testados
- [x] `MainShellScreen`, `TrainerMainLayout` e `TrainerStudentsScreen` integrados com cabeçalho de vidro translúcido dinâmico
- [x] `ActiveWorkoutScreen`, `TrainerAnamnesisScreen`, `B2BAssistantScreen`, `AccountScreen` e `StudentProfileScreen` calibrados com `MediaQuery.paddingOf(context)`
- [x] `SafeArea(bottom: false)` aplicado nas telas com rolagem vertical para sangria contínua até a base da tela
- [x] `flutter analyze` limpo (0 warnings/errors) e suíte de testes 100% verde (166 testes)
