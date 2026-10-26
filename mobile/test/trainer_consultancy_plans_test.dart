import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_consultancy_plans_screen.dart';

void main() {
  testWidgets('TrainerConsultancyPlansScreen adapts to Dark and Light modes with proper text contrast', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Render in Light Mode
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        themeMode: ThemeMode.light,
        home: const TrainerConsultancyPlansScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and elements exist
    expect(find.text('Planos de Consultoria'), findsOneWidget);
    expect(find.text('Adicionar Novo Plano'), findsOneWidget);

    // Verify Title text color is dark in Light Mode
    final titleWidget = tester.widget<Text>(find.text('Planos de Consultoria'));
    expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));

    // 2. Render in Dark Mode
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const TrainerConsultancyPlansScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planos de Consultoria'), findsOneWidget);
    final darkTitleWidget = tester.widget<Text>(find.text('Planos de Consultoria'));
    expect(darkTitleWidget.style?.color, equals(MetaColors.textPrimary));
  });
}
