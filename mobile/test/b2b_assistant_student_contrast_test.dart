import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/assistant/b2b_assistant_screen.dart';

void main() {
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
  });
}
