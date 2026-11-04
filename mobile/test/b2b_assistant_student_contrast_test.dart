import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/assistant/b2b_assistant_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('B2BAssistantScreen (Aba Mr. Coach AI no perfil do Aluno)', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
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

      // 2. Header do Aluno e Pílula
      expect(find.text('COPILOTO DE SALÃO • TEMPO REAL'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);

      // 3. Grade de Ações Rápidas de Academia
      expect(find.text('AÇÕES RÁPIDAS DE ACADEMIA'), findsOneWidget);
      expect(find.text('Aparelho Ocupado?'), findsOneWidget);
      expect(find.text('Senti Dor / Fisgada'), findsOneWidget);
      expect(find.text('Execução em 3 Passos'), findsOneWidget);
      expect(find.text('Carga & Repetições'), findsOneWidget);

      // 4. Barra de Envio e Atalhos Rápidos
      expect(find.text('📋 Ficha Ativa'), findsOneWidget);
      expect(find.text('🔥 Ofensiva'), findsOneWidget);
      expect(find.text('⚠️ Aparelho Ocupado'), findsOneWidget);
      expect(find.text('💬 Comandos WhatsApp'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
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

      // 2. Header do Aluno e Pílula
      expect(find.text('COPILOTO DE SALÃO • TEMPO REAL'), findsOneWidget);
      expect(find.text('COACH'), findsOneWidget);

      // 3. Grade de Ações Rápidas de Academia
      expect(find.text('AÇÕES RÁPIDAS DE ACADEMIA'), findsOneWidget);
      expect(find.text('Aparelho Ocupado?'), findsOneWidget);
      expect(find.text('Senti Dor / Fisgada'), findsOneWidget);
      expect(find.text('Execução em 3 Passos'), findsOneWidget);
      expect(find.text('Carga & Repetições'), findsOneWidget);

      // 4. Barra de Envio e Atalhos Rápidos
      expect(find.text('📋 Ficha Ativa'), findsOneWidget);
      expect(find.text('🔥 Ofensiva'), findsOneWidget);
      expect(find.text('⚠️ Aparelho Ocupado'), findsOneWidget);
      expect(find.text('💬 Comandos WhatsApp'), findsOneWidget);
    });

    testWidgets('1-Tap Swap workflow: opens busy machine sheet, renders equivalence options, and applies adaptation', (tester) async {
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

      // 1. Toca no atalho de "⚠️ Aparelho Ocupado"
      final busyShortcut = find.text('⚠️ Aparelho Ocupado');
      expect(busyShortcut, findsOneWidget);
      await tester.tap(busyShortcut);
      await tester.pumpAndSettle();

      // 2. Verifica se o BottomSheet abriu com as opções de exercícios
      expect(find.text('Qual exercício você precisa adaptar só hoje?'), findsOneWidget);
      expect(find.text('Supino Reto com Barra'), findsWidgets);

      // 3. Seleciona "Supino Reto com Barra"
      await tester.tap(find.text('Supino Reto com Barra').first);
      await tester.pumpAndSettle();

      // 4. Verifica que as opções de equivalência foram geradas no chat
      expect(find.text('Opções de Substituição em 1 Toque'), findsOneWidget);
      expect(find.textContaining('94% Match'), findsOneWidget);

      // 5. Aplica a substituição tocando no botão primário
      final primaryOption = find.textContaining('94% Match');
      await tester.tap(primaryOption);
      await tester.pumpAndSettle();

      // 6. Confirma que a adaptação foi registrada com sucesso
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

      // 1. Toca na ação rápida de "Senti Dor / Fisgada"
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

      // 1. Toca na pílula de comandos WhatsApp
      final zapShortcut = find.text('💬 Comandos WhatsApp');
      expect(zapShortcut, findsOneWidget);
      await tester.tap(zapShortcut);
      await tester.pumpAndSettle();

      // 2. Verifica se a folha One UI abriu com a sincronização
      expect(find.text('Espelho Omnichannel WhatsApp'), findsOneWidget);
      expect(find.text('Falar com o Robô Oficial no WhatsApp'), findsOneWidget);
    });

    testWidgets('Cockpit Contextual 3.0: renders live exercise rows with 1-tap 3D and Trocar pills', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: B2BAssistantScreen(
              key: ValueKey('cockpit_3_0_test'),
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

      // 2. Toca no card 2x2 "Aparelho Ocupado?" e valida abertura do seletor em 1 toque
      await tester.tap(find.text('Aparelho Ocupado?'));
      await tester.pumpAndSettle();
      expect(find.text('Qual exercício você precisa adaptar só hoje?'), findsOneWidget);

      // Fecha modal clicando fora ou voltando e testa botão 🧬 3D direto na linha do Cockpit
      Navigator.of(tester.element(find.text('Qual exercício você precisa adaptar só hoje?'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('🧬 3D').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Raio-X Biomecânico em 5 Segundos'), findsOneWidget);
      expect(find.text('Abrir Loop 3D em Tela Cheia'), findsOneWidget);
    });
  });
}
