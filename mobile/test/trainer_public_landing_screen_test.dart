import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/trainer_public_landing_screen.dart';

void main() {
  testWidgets('BeforeAfterCaseViewer renders transformation showcase, switches cases, and toggles before/after', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var planSelected = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BeforeAfterCaseViewer(
              onSelectPlan: () => planSelected = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify presence of transformation showcase
    expect(find.text('TRANSFORMAÇÕES REAIS'), findsOneWidget);
    expect(find.text('Resultados Comprovados com Mr. Coach'), findsOneWidget);
    expect(find.text('Hipertrofia & Força'), findsOneWidget);
    expect(find.text('Reabilitação Lombar'), findsOneWidget);
    expect(find.text('Emagrecimento & Definição'), findsOneWidget);

    // Initial state is "Depois" for Rodrigo M.
    expect(find.text('Rodrigo M. (32 anos)'), findsOneWidget);
    expect(find.text('ESTADO ATUAL (COM MR. COACH)'), findsOneWidget);
    expect(find.text('79 kg • 11% gordura'), findsOneWidget);
    expect(find.text('94 kg (+34 kg)'), findsOneWidget);

    // 2. Toggle to "Antes"
    expect(find.text('Antes'), findsOneWidget);
    await tester.tap(find.text('Antes'));
    await tester.pumpAndSettle();

    expect(find.text('ESTADO INICIAL (SEM CONSULTORIA)'), findsOneWidget);
    expect(find.text('74 kg • 18% gordura'), findsOneWidget);
    expect(find.text('60 kg (estagnado)'), findsOneWidget);

    // 3. Switch category to "Reabilitação Lombar"
    await tester.tap(find.text('Reabilitação Lombar'));
    await tester.pumpAndSettle();

    expect(find.text('Juliana S. (28 anos)'), findsOneWidget);
    expect(find.text('Capacidade de Carga em Pernas: '), findsOneWidget);

    // 4. Tap CTA button
    final ctaButton = find.text('Quero Uma Transformação Assim');
    expect(ctaButton, findsOneWidget);
    await tester.tap(ctaButton);
    expect(planSelected, isTrue);
  });
}
