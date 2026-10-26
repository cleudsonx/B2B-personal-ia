import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/theme/theme_controller.dart';
import 'package:personal_ia/core/widgets/thematic_editorial_card.dart';
import 'package:personal_ia/core/widgets/thematic_watermarks.dart';

void main() {
  group('Student Thematic Editorial Cards Contrast & Modes Suite', () {
    testWidgets('renders Day Hero Workout Card in Editorial 3D mode with Biomechanics Watermark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'DIVISÃO A • PROGRAMADO',
                palette: ThematicCardPalette.biomechanicsCyan,
                overrideMode: CardVisualThemeMode.editorial3D,
                trailingBadge: const Text('00:45 min', style: TextStyle(color: Colors.white)),
                customContent: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peitoral & Tríceps Hipertrofia', style: TextStyle(color: Colors.white, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('6 exercícios • ~48 min', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DIVISÃO A • PROGRAMADO'), findsOneWidget);
      expect(find.text('Peitoral & Tríceps Hipertrofia'), findsOneWidget);
      expect(find.text('6 exercícios • ~48 min'), findsOneWidget);
      expect(find.byType(ThematicWatermark), findsOneWidget);
    });

    testWidgets('renders BioHub Telemetry Card in Light Pastel mode with high contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Telemetria & Prontidão Bio-Hub',
                title: 'Prontidão alta (85%) — excelente janela para progredir carga hoje.',
                description: 'Análise integrada de sono, hidratação e estresse de carga para guiar seu treino.',
                palette: ThematicCardPalette.cardioCobalt,
                overrideMode: CardVisualThemeMode.lightPastel,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TELEMETRIA & PRONTIDÃO BIO-HUB'), findsOneWidget);
      expect(find.text('Prontidão alta (85%) — excelente janela para progredir carga hoje.'), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('Prontidão alta (85%) — excelente janela para progredir carga hoje.'));
      expect(titleWidget.style?.color, equals(ThematicCardPalette.cardioCobalt.lightTextColor));
    });

    testWidgets('renders Rest Timer ATP-CP Recovery Card in Minimalist mode without watermark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Recuperação Fisiológica ATP-CP',
                title: 'Resíntese de Fosfocreatina Ativa',
                description: 'Intervalo calibrado para restaurar substrato energético muscular antes da próxima série pesada.',
                palette: ThematicCardPalette.muscleMagenta,
                overrideMode: CardVisualThemeMode.minimalist,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECUPERAÇÃO FISIOLÓGICA ATP-CP'), findsOneWidget);
      expect(find.text('Resíntese de Fosfocreatina Ativa'), findsOneWidget);
      expect(find.byType(ThematicWatermark), findsNothing);
    });
  });
}

