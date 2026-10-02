# 🛠️ Task Specification: Implementação Visual Edge-to-Edge no Mobile (Flutter)

## 1. Objetivo
Modernizar a interface do aplicativo móvel (**Shaipados / B2B Personal IA**), implementando uma experiência de renderização **Edge-to-Edge nativa contínua** (estilo Fintechs como Nubank e Itaú) nas telas centrais de Treino Ativo (`active_workout_screen.dart`) e Anamnese (`anamnesis_screen.dart`).

O layout visual deve se estender por trás da Status Bar e Navigation Bar nativas (Android e iOS), garantindo que os elementos de interação (toques, textos, botões e modais) respeitem rigorosamente o Notch, a Dynamic Island e a barra inferior de gestos (Home Indicator).

---

## 2. Regras Rígidas e Pontos de Atenção (Anti-Patterns)
1. **PROIBIDO** envolver o `Scaffold` inteiro com `SafeArea`. Isso gera letterboxing artificial (barras cinzas/pretas nas bordas).
2. O `SafeArea` deve ser aplicado **apenas cirurgicamente** aos componentes interativos e cabeçalhos internos.
3. Listas roláveis (`ListView`, `SingleChildScrollView`) devem SEMPRE calcular o padding inferior dinamicamente utilizando `MediaQuery.paddingOf(context).bottom + [margem_extra]` para evitar que o último item fique sob a barra de gestos.
4. Manter estrita sincronia de contraste da Status Bar:
   - Fundo superior escuro → Ícones brancos (`statusBarIconBrightness: Brightness.light` no Android e `statusBarBrightness: Brightness.dark` no iOS).
   - Fundo superior claro → Ícones escuros (`statusBarIconBrightness: Brightness.dark` no Android e `statusBarBrightness: Brightness.light` no iOS).

---

## 3. Passo a Passo de Execução

### Passo 1: Configuração Nativa do Android
**Arquivo:** `mobile/android/app/src/main/res/values/styles.xml`
Configurar as barras de sistema para transparência e desativar o contraste forçado do SO:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
        <item name="android:enforceNavigationBarContrast">false</item>
        <item name="android:enforceStatusBarContrast">false</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
</resources>
```

### Passo 2: Configuração Nativa do iOS
**Arquivo:** `mobile/ios/Runner/Info.plist`
Garantir o controle declarativo da barra de status pelo Flutter:
```xml
<key>UIViewControllerBasedStatusBarAppearance</key>
<true/>
```

### Passo 3: Ativação Global no Flutter
**Arquivo:** `mobile/lib/main.dart`
Habilitar o modo edge‑to‑edge na inicialização:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // ... outras inicializações (Supabase, serviços, etc.)
  runApp(const MyApp());
}
```

### Passo 4: Refatoração da Tela de Treino Ativo (Visão Aluno)
**Arquivo:** `mobile/lib/features/client/active_workout_screen.dart`
Substituir o layout existente pela estrutura em `Stack` com cabeçalho imersivo, folha de cards com bordas arredondadas e modal de adaptação compatível com a base da tela.
*(O código completo está incluído no documento original; manter a lógica de `MediaQuery.paddingOf(context).bottom` para o padding inferior.)*

### Passo 5: Refatoração da Tela de Anamnese (Visão Treinador)
**Arquivo:** `mobile/lib/features/trainer/anamnesis_screen.dart`
Garantir scroll sem overflow e ancoragem inferior do botão de submissão acima do Home Indicator, usando `MediaQuery.paddingOf(context).bottom`.
*(O código completo está incluído no documento original.)*

### Passo 6: Validação e Testes
- Executar `flutter analyze` para garantir ausência de warnings de lint.
- Executar `flutter run` em emulador ou dispositivo físico e validar:
  - Fundo do cabeçalho escuro sangrando atrás do relógio/bateria.
  - Ícones superiores visíveis e com contraste adequado.
  - Rolagem completa das listas até o fim sem obstrução pela barra de navegação/Home Indicator.

---

## 6. Plano de Ação Detalhado e Avaliação de Impacto

### 6.1 Visão Geral
- **Objetivo:** Aplicar a experiência *edge‑to‑edge* nas telas **ActiveWorkoutScreen** e **AnamnesisScreen**, garantindo compatibilidade total com Android (incluindo Dynamic Island) e iOS (Home Indicator).
- **Escopo:** Atualizações nativas (Android `styles.xml`, iOS `Info.plist`), configuração global Flutter, refatoração de UI e testes de regressão.

### 6.2 Impacto Técnico
| Área | Impacto | Risco | Mitigação |
|------|---------|-------|-----------|
| UI/UX | Melhoria de fluidez visual e percepção de modernidade. | Quebras de layout em telas existentes. | Testes manuais em dispositivos com notch e gestos. |
| Performance | Marginal (uso de `Stack` e `AnnotatedRegion`). | Overdraw se `Scaffold` ainda envolver `SafeArea`. | Auditoria de renderização via Flutter DevTools (`flutter run --profile`). |
| Segurança | Nenhum risco direto; apenas alterações de cores e paddings. | Exposição de assets se `windowBackground` for alterado. | Manter `android:windowBackground` como transparent apenas para UI. |
| Compatibilidade | Android 6+ / iOS 12+. | Dispositivos legacy podem não suportar `SystemUiMode.edgeToEdge`. | Fallback automático via `SystemUiMode.manual` nas versões antigas. |

### 6.3 Passos de Implementação (Ordem Lógica)
1. **Verificar pré‑requisitos**
   - Confirme que o projeto já inclui `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);` em `main.dart` (já presente). 
   - Atualize o `minSdkVersion` para **21** (necessário para transparência total).
2. **Android – estilos**
   - Confirmar que `styles.xml` contém `android:statusBarColor` e `android:navigationBarColor` como `@android:color/transparent`.
   - Add `android:windowLayoutInDisplayCutoutMode="shortEdges"` ao tema para suportar cutouts.
3. **iOS – Info.plist**
   - Garantir a chave `UIViewControllerBasedStatusBarAppearance` = `true` (já listada).
   - No Xcode, habilitar "View controller-based status bar appearance" e definir `UIStatusBarStyle` conforme tema.
4. **Refatorar `ActiveWorkoutScreen`**
   - Verificar uso de `SafeArea(bottom: false)` já presente – OK.
   - Ajustar `bottomInset` cálculo para usar `MediaQuery.paddingOf(context).bottom` (já usado).
   - Garantir que o `ListView` dentro da folha de cards use `padding: EdgeInsets.only(bottom: bottomInset + 30)` – já configurado.
5. **Refatorar `AnamnesisScreen`**
   - Substituir `SafeArea(bottom: false)` por `SafeArea(bottom: false, top: true)` se necessário para barra de status escura.
   - Atualizar `bottomInset` uso já presente.
6. **Testes Unitários / UI**
   - Adicionar testes de widget para garantir que `MediaQuery.paddingOf(context).bottom` é considerado (ex.: golden tests).
   - Executar `flutter test --update-goldens` nas telas modificadas.
7. **Validação em Dispositivos Reais**
   - Testar em iPhone 14 Pro (Dynamic Island) e Pixel 7 (cutout).
   - Verificar que nenhum elemento fica oculto sob a barra de navegação/gestos.
8. **Performance & Lint**
   - Rode `flutter analyze` e `flutter run --profile` para medir FPS; garantir >55 FPS.
   - Corrigir qualquer warning de `avoid_unnecessary_containers`.
9. **Documentação**
   - Atualizar este documento **Visual_Edge_to_Edge_Mobile.md** com notas de conclusão e links para tickets JIRA.
   - Inserir checklist de entrega.

### 6.4 Checklist de Entrega
- [ ] `styles.xml` com `windowLayoutInDisplayCutoutMode="shortEdges"`
- [ ] `Info.plist` com `UIViewControllerBasedStatusBarAppearance=true`
- [ ] `main.dart` habilita `edgeToEdge` (já conferido)
- [ ] `ActiveWorkoutScreen` usa `MediaQuery.paddingOf` para padding inferior
- [ ] `AnamnesisScreen` respeta safe area superior e inferior
- [ ] Testes de widget aprovados
- [ ] Lint limpo (`flutter analyze` = 0 issues)
- [ ] Performance >55 FPS em dispositivos de teste
- [ ] Documentação atualizada no repo

---

*Este plano reflete a realidade atual do código (já há suporte ao modo edge‑to‑edge em `main.dart` e uso correto de `MediaQuery.paddingOf`). As etapas 2‑3 garantem a configuração nativa necessária; as etapas 4‑5 adaptam as telas existentes; as etapas 6‑9 asseguram qualidade, performance e rastreabilidade.*
