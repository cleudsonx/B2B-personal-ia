import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_onboarding_screen.dart';

void main() {
  testWidgets('TrainerOnboardingScreen renders cleanly under Light mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: TrainerOnboardingScreen(key: ValueKey('light_onboarding')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boas-vindas ao Mr. Coach'), findsOneWidget);
    expect(find.text('Avançar'), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.text('Boas-vindas ao Mr. Coach'));
    expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
  });

  testWidgets('TrainerOnboardingScreen renders cleanly under Dark mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const TrainerOnboardingScreen(key: ValueKey('dark_onboarding')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boas-vindas ao Mr. Coach'), findsOneWidget);
    final darkTitleWidget = tester.widget<Text>(find.text('Boas-vindas ao Mr. Coach'));
    expect(darkTitleWidget.style?.color, equals(MetaColors.textPrimary));
  });
}
