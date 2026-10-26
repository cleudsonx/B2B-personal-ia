import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/theme/theme_controller.dart';
import 'package:personal_ia/core/widgets/thematic_editorial_card.dart';
import 'package:personal_ia/core/widgets/thematic_watermarks.dart';

void main() {
  group('ThematicEditorialCard Tests (One UI 7 Health Style)', () {
    testWidgets('renders cleanly in Editorial 3D mode with watermark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Biomecânica IA',
                title: 'Ângulo e trajetória das séries em tempo real',
                description: 'Acompanhe a cadência perfeita para hipertrofia sem lesão.',
                palette: ThematicCardPalette.biomechanicsCyan,
                overrideMode: CardVisualThemeMode.editorial3D,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BIOMECÂNICA IA'), findsOneWidget);
      expect(find.text('Ângulo e trajetória das séries em tempo real'), findsOneWidget);
      expect(find.text('Acompanhe a cadência perfeita para hipertrofia sem lesão.'), findsOneWidget);

      // Marca d'água presente no modo editorial
      expect(find.byType(ThematicWatermark), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('Ângulo e trajetória das séries em tempo real'));
      expect(titleWidget.style?.color, equals(Colors.white));
    });

    testWidgets('renders cleanly in Minimalist mode without watermark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Sobrecarga Muscular',
                title: 'Recuperação & RPE Acumulado',
                description: 'O algoritmo prevê o estresse miofascial.',
                palette: ThematicCardPalette.muscleMagenta,
                overrideMode: CardVisualThemeMode.minimalist,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SOBRECARGA MUSCULAR'), findsOneWidget);
      expect(find.text('Recuperação & RPE Acumulado'), findsOneWidget);

      // Marca d'água deve ser oculta no modo minimalista
      expect(find.byType(ThematicWatermark), findsNothing);
    });

    testWidgets('renders cleanly in Light Pastel mode with high contrast', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Copiloto WhatsApp 24h',
                title: 'Atendimento Automático de Alunos',
                description: 'Tire dúvidas e envie avisos pelo WhatsApp.',
                palette: ThematicCardPalette.aiOrchid,
                overrideMode: CardVisualThemeMode.lightPastel,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COPILOTO WHATSAPP 24H'), findsOneWidget);
      expect(find.text('Atendimento Automático de Alunos'), findsOneWidget);

      // Marca d'água presente com opacidade suave
      expect(find.byType(ThematicWatermark), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('Atendimento Automático de Alunos'));
      expect(titleWidget.style?.color, equals(ThematicCardPalette.aiOrchid.lightTextColor));
    });

    testWidgets('triggers onTap callback when pressed', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'Vendas & Carteira',
                title: 'Checkout Instantâneo na Vitrine',
                palette: ThematicCardPalette.businessEmerald,
                overrideMode: CardVisualThemeMode.editorial3D,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout Instantâneo na Vitrine'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
