import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/assistant/b2b_assistant_screen.dart';
import 'package:personal_ia/core/widgets/one_ui_glass_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentChromeVisibility.reset();
  });

  group('B2BAssistantScreen (Aba Mr. Coach AI Aluno — Zen 3.1 & Fluidez no Scroll)', () {
    testWidgets('renders cleanly under Light mode with high contrast and without redundancies', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('light_assistant'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hero Spotlight Card e Tipografia de alto contraste no Light Mode
      expect(find.text('Qual a dúvida da sua série agora?'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Qual a dúvida da sua série agora?'));
      expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));

      // 2. Smart Header Unificado (1 linha)
      expect(find.text('COPILOTO DE SALÃO • TEMPO REAL'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);
      expect(find.text('HOJE'), findsOneWidget);
      expect(find.text('Sync Zap'), findsOneWidget);

      // 3. Opção A: Cápsulas Slim (48px) substituindo a grade 2x2 antiga
      expect(find.text('Senti Dor / Fisgada'), findsOneWidget);
      expect(find.text('Pausa segura'), findsOneWidget);
      expect(find.text('Carga & RIR'), findsOneWidget);
      expect(find.text('Calcular peso'), findsOneWidget);

      // 4. Validação de ausência das redundâncias aposentadas (#1 e #2)
      expect(find.text('AÇÕES RÁPIDAS DE ACADEMIA'), findsNothing);
      expect(find.text('Aparelho Ocupado? Trocar em 1 Toque'), findsNothing);

      // 5. Barra Inferior Limpa (sem ícones duplicados)
      expect(find.text('Ofensiva'), findsOneWidget);
      expect(find.text('+250ml Água'), findsOneWidget);
      expect(find.text('Comandos WhatsApp'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast and without redundancies', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('dark_assistant'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hero Spotlight Card e Tipografia no Dark Mode
      expect(find.text('Qual a dúvida da sua série agora?'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Qual a dúvida da sua série agora?'));
      expect(titleWidget.style?.color, equals(Colors.white));

      // 2. Smart Header Unificado
      expect(find.text('COPILOTO DE SALÃO • TEMPO REAL'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);
      expect(find.text('HOJE'), findsOneWidget);
      expect(find.text('Sync Zap'), findsOneWidget);

      // 3. Opção A: Cápsulas Slim (48px)
      expect(find.text('Senti Dor / Fisgada'), findsOneWidget);
      expect(find.text('Carga & RIR'), findsOneWidget);

      // 4. Validação de ausência das redundâncias antigas
      expect(find.text('AÇÕES RÁPIDAS DE ACADEMIA'), findsNothing);
      expect(find.text('Aparelho Ocupado? Trocar em 1 Toque'), findsNothing);

      // 5. Atalhos inferiores limpos
      expect(find.text('Ofensiva'), findsOneWidget);
      expect(find.text('+250ml Água'), findsOneWidget);
      expect(find.text('Comandos WhatsApp'), findsOneWidget);
    });

    testWidgets('1-Tap Swap workflow: opens busy machine sheet via row button and applies adaptation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('swap_workflow_test'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Toca no botão '🔄 Trocar' direto na linha do exercício
      final trocarBtn = find.text('🔄 Trocar').first;
      expect(trocarBtn, findsOneWidget);
      await tester.tap(trocarBtn);
      await tester.pumpAndSettle();

      // 2. Verifica que as opções de equivalência foram geradas no chat
      expect(find.text('Opções de Substituição em 1 Toque'), findsOneWidget);
      expect(find.textContaining('94% Match'), findsOneWidget);

      // 3. Aplica a substituição tocando na opção recomendada
      final primaryOption = find.textContaining('94% Match');
      await tester.tap(primaryOption);
      await tester.pumpAndSettle();

      // 4. Confirma que a adaptação foi registrada com sucesso
      expect(find.textContaining('Adaptação Registrada para a Sessão de Hoje'), findsOneWidget);
      expect(find.textContaining('Sua ficha oficial do mesociclo segue 100% intacta'), findsOneWidget);
    });

    testWidgets('Clinical Pain Guardrail: halts exercise on pain keyword and offers immediate trainer contact', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('pain_guardrail_test'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Toca na cápsula slim de "Senti Dor / Fisgada"
      final painAction = find.text('Senti Dor / Fisgada');
      expect(painAction, findsOneWidget);
      await tester.tap(painAction);
      await tester.pumpAndSettle();

      // 2. Verifica o acionamento imediato do protocolo clínico (0 tokens)
      expect(find.textContaining('Atenção Clínica & Segurança Articular'), findsOneWidget);
      expect(find.text('Suporte Clínico Imediato'), findsOneWidget);
      expect(find.text('Sugerir Substituto sem Dor'), findsOneWidget);
      expect(find.textContaining('interrompa a série imediatamente'), findsOneWidget);
    });

    testWidgets('Omnichannel WhatsApp modal: opens and displays synchronization status', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('whatsapp_sync_test'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Toca no atalho de comandos WhatsApp
      final zapShortcut = find.text('Comandos WhatsApp');
      expect(zapShortcut, findsOneWidget);
      await tester.tap(zapShortcut);
      await tester.pumpAndSettle();

      // 2. Verifica se a folha One UI abriu com a sincronização
      expect(find.text('Espelho Omnichannel WhatsApp'), findsOneWidget);
      expect(find.text('Falar com o Robô Oficial no WhatsApp'), findsOneWidget);
    });

    testWidgets('Cockpit Contextual 3.1: renders exercises, expands accordion, and triggers 3D loop', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('cockpit_3_1_test'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Barra contextual HOJE + Linhas interativas do Cockpit com botões 🧬 3D e 🔄 Trocar
      expect(find.text('HOJE'), findsOneWidget);
      expect(find.text('Supino Reto Barra'), findsOneWidget);
      expect(find.text('🧬 3D'), findsWidgets);
      expect(find.text('🔄 Trocar'), findsWidgets);

      // 2. Acordeão de exercícios (mostra 3 por padrão, botão para expandir para o 4º)
      final expandAccordionBtn = find.text('Ver todos os 4 exercícios da série ▾');
      expect(expandAccordionBtn, findsOneWidget);
      await tester.tap(expandAccordionBtn);
      await tester.pumpAndSettle();

      // 3. Após expandir, o 4º exercício fica visível e o botão muda para "Mostrar menos ▴"
      expect(find.text('Tríceps Corda Polia'), findsOneWidget);
      expect(find.text('Mostrar menos ▴'), findsOneWidget);

      // Recolhe novamente
      await tester.tap(find.text('Mostrar menos ▴'));
      await tester.pumpAndSettle();
      expect(find.text('Ver todos os 4 exercícios da série ▾'), findsOneWidget);

      // 4. Testa botão 🧬 3D direto na linha do Cockpit
      await tester.tap(find.text('🧬 3D').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Raio-X Biomecânico em 5 Segundos'), findsOneWidget);
      expect(find.text('Abrir Loop 3D em Tela Cheia'), findsOneWidget);
    });

    testWidgets('Scroll choreography: scrolling down collapses header to Dynamic Island and hides bottom nav', (tester) async {
      tester.view.physicalSize = const Size(1080, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('scroll_choreography_test'),
              isStudentView: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente visível
      expect(StudentChromeVisibility.isNavVisible.value, isTrue);

      // Expande acordeão para garantir conteúdo rolável
      await tester.tap(find.text('Ver todos os 4 exercícios da série ▾'));
      await tester.pumpAndSettle();

      // Rola para baixo no SingleChildScrollView
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pump();

      // Verifica que a navegação recolheu (auto-hide)
      expect(StudentChromeVisibility.isNavVisible.value, isFalse);

      // Verifica que o mini-composer pill apareceu
      expect(find.text('Perguntar ao Mr. Coach...'), findsOneWidget);

      // Toca no mini-composer para restaurar
      await tester.tap(find.text('Perguntar ao Mr. Coach...'));
      await tester.pumpAndSettle();

      // Verifica que restaurou a visibilidade completa
      expect(StudentChromeVisibility.isNavVisible.value, isTrue);
    });
  });
}
