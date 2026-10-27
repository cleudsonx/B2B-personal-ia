import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/theme/theme_controller.dart';
import 'package:personal_ia/core/widgets/card_style_selection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CardStyleSelectionSheet Tests', () {
    testWidgets('renders all 3 card visual theme options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: CardStyleSelectionSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estilo dos Cards & Destaques'), findsOneWidget);
      expect(find.text('Editorial 3D (Samsung Health)'), findsOneWidget);
      expect(find.text('Minimalista Executivo'), findsOneWidget);
      expect(find.text('Pastel Suave'), findsOneWidget);
    });

    testWidgets('tapping an option triggers mode change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: CardStyleSelectionSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Minimalista Executivo'));
      await tester.pumpAndSettle();

      expect(ThemeController.instance.cardThemeMode, equals(CardVisualThemeMode.minimalist));
    });
  });
}

