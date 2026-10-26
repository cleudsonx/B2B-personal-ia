import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/theme/theme_controller.dart';
import 'package:personal_ia/core/widgets/thematic_editorial_card.dart';
import 'package:personal_ia/core/widgets/thematic_watermarks.dart';

void main() {
  group('Trainer Thematic Editorial Cards Contrast & Modes Suite', () {
    testWidgets('renders Trainer Wallet Pix Payout Card in Editorial 3D mode with Wallet Watermark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'CARTEIRA B2B • REPASSE AUTOMÁTICO',
                palette: ThematicCardPalette.businessEmerald,
                customWatermark: ThematicWatermarkType.walletFinance,
                overrideMode: CardVisualThemeMode.editorial3D,
                trailingBadge: const Text('Pix Imediato', style: TextStyle(color: Colors.white)),
                customContent: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saldo Disponível', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 4),
                    Text('R\$ 1.250,00', style: TextStyle(color: Colors.white, fontSize: 24)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CARTEIRA B2B • REPASSE AUTOMÁTICO'), findsOneWidget);
      expect(find.text('Pix Imediato'), findsOneWidget);
      expect(find.text('Saldo Disponível'), findsOneWidget);
      expect(find.text('R\$ 1.250,00'), findsOneWidget);
      expect(find.byType(ThematicWatermark), findsOneWidget);
    });

    testWidgets('renders Trainer Wallet Card in Minimalist mode without watermark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'CARTEIRA B2B • REPASSE AUTOMÁTICO',
                palette: ThematicCardPalette.businessEmerald,
                customWatermark: ThematicWatermarkType.walletFinance,
                overrideMode: CardVisualThemeMode.minimalist,
                customContent: const Text('Saldo: R\$ 500,00'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CARTEIRA B2B • REPASSE AUTOMÁTICO'), findsOneWidget);
      expect(find.text('Saldo: R\$ 500,00'), findsOneWidget);
      expect(find.byType(ThematicWatermark), findsNothing);
    });

    testWidgets('renders Trainer Business Tip Card in Light Pastel mode with high contrast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: ThematicEditorialCard(
                category: 'COMO ESCALAR',
                title: 'Divulgue seus treinos e planos',
                description: 'Compartilhe links diretos da sua Vitrine Pública no Instagram e WhatsApp.',
                palette: ThematicCardPalette.businessEmerald,
                customWatermark: ThematicWatermarkType.walletFinance,
                overrideMode: CardVisualThemeMode.lightPastel,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMO ESCALAR'), findsOneWidget);
      expect(find.text('Divulgue seus treinos e planos'), findsOneWidget);
      expect(find.text('Compartilhe links diretos da sua Vitrine Pública no Instagram e WhatsApp.'), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('Divulgue seus treinos e planos'));
      expect(titleWidget.style?.color, equals(ThematicCardPalette.businessEmerald.lightTextColor));
    });
  });
}
