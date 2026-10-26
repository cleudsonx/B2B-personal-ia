import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_wallet_screen.dart';

void main() {
  testWidgets('TrainerWalletScreen renders cleanly under Light and Dark modes with proper contrast', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Render in Light Mode
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        themeMode: ThemeMode.light,
        home: const TrainerWalletScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carteira do Personal'), findsOneWidget);
    expect(find.text('Saldo Disponível'), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.text('Carteira do Personal'));
    expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));

    // 2. Render in Dark Mode
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const TrainerWalletScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carteira do Personal'), findsOneWidget);
    final darkTitleWidget = tester.widget<Text>(find.text('Carteira do Personal'));
    expect(darkTitleWidget.style?.color, equals(MetaColors.textPrimary));
  });
}
