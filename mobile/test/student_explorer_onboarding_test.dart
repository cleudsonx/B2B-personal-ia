import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/client/welcome_onboarding_screen.dart';

void main() {
  testWidgets('WelcomeOnboardingScreen displays Aluno Explorador Hub and active CTA when unlinked', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeOnboardingScreen(
          studentName: 'Aluno Explorador',
          trainerId: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Deve exibir o card do Aluno Explorador e atalho para a vitrine
    expect(find.text('Aluno Explorador'), findsOneWidget);
    expect(find.text('DEGUSTAÇÃO'), findsOneWidget);
    expect(find.text('Conhecer e Escolher Personal Trainer'), findsOneWidget);

    // O botão principal de calibração deve estar visível e habilitado
    expect(find.text('Iniciar Calibração Biomecânica (3 min)'), findsOneWidget);
  });
}
