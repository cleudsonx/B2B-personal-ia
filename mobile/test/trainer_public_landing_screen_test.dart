import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/trainer_public_landing_screen.dart';
import 'package:personal_ia/services/consultancy_plan_service.dart';

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

    // Initial state is Rodrigo M. with Before and After metrics visible
    expect(find.text('Rodrigo M. (32 anos)'), findsOneWidget);
    expect(find.text('ANTES'), findsOneWidget);
    expect(find.text('DEPOIS'), findsOneWidget);
    expect(find.text('79 kg • 11% gordura'), findsOneWidget);
    expect(find.text('94 kg (+34 kg)'), findsOneWidget);

    // 2. Toggle preset to "Antes"
    expect(find.text('Antes'), findsOneWidget);
    await tester.tap(find.text('Antes'));
    await tester.pumpAndSettle();

    expect(find.text('74 kg • 18% gordura'), findsOneWidget);
    expect(find.text('60 kg (estagnado)'), findsOneWidget);

    // 3. Switch category to "Reabilitação Lombar"
    await tester.tap(find.text('Reabilitação Lombar'));
    await tester.pumpAndSettle();

    expect(find.text('Juliana S. (28 anos)'), findsOneWidget);
    expect(find.text('Capacidade de Carga em Pernas:'), findsWidgets);

    // 4. Tap CTA button
    final ctaButton = find.text('Quero Uma Transformação Assim');
    expect(ctaButton, findsOneWidget);
    await tester.tap(ctaButton);
    expect(planSelected, isTrue);
  });

  testWidgets('TrainerPublicLandingScreen renders all 7 logical sections of the new funnel', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockTrainerData = {
      'id': '6f645308-f1b2-4d73-ac45-9890c27e20d4',
      'full_name': 'Prof. Cleudson Cavalcante',
      'username': 'mrcoach',
      'bio': 'Especialista em biomecânica aplicada e hipertrofia.',
      'specialties': ['Hipertrofia', 'Biomecânica', 'Reabilitação'],
      'cref': 'CREF 012345-G/DF',
      'public_whatsapp': '61999999999',
      'photo_url': '',
    };

    final mockPlans = [
      ConsultancyPlan(
        id: 'plan_1',
        trainerId: '6f645308-f1b2-4d73-ac45-9890c27e20d4',
        name: 'Consultoria Mensal Pro',
        priceCents: 15000,
        billingPeriod: 'monthly',
        features: ['Prescrição completa', 'Suporte WhatsApp'],
      ),
      ConsultancyPlan(
        id: 'plan_2',
        trainerId: '6f645308-f1b2-4d73-ac45-9890c27e20d4',
        name: 'Plano Trimestral Evolução',
        priceCents: 39000,
        billingPeriod: 'quarterly',
        features: ['3 Mesociclos', 'Prioridade no WhatsApp'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerPublicLandingScreen(
          username: 'mrcoach',
          initialTrainerData: mockTrainerData,
          initialPlans: mockPlans,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header / Bio / Authority Stats
    expect(find.text('PROF. CLEUDSON CAVALCANTE'), findsOneWidget);
    expect(find.textContaining('012345-G/DF'), findsWidgets);
    expect(find.textContaining('VERIFICADO'), findsOneWidget);
    expect(find.text('10+'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);

    // 2. Metodologia
    expect(find.text('Metodologia & Prescrição Inteligente'), findsOneWidget);
    expect(find.text('Prescrição Biomecânica Fina'), findsOneWidget);
    expect(find.text('Sobrecarga Progressiva com Fórmulas de IA'), findsOneWidget);

    // 3. Casos Reais / BeforeAfter
    expect(find.text('TRANSFORMAÇÕES REAIS'), findsOneWidget);

    // 4. Para Quem É
    expect(find.text('Esta consultoria é ideal para você se:'), findsOneWidget);

    // 5. Experiência no App
    expect(find.text('A Experiência no App Mr. Coach'), findsOneWidget);
    expect(find.text('Substituição por IA em 5 Segundos'), findsOneWidget);

    // 6. Planos & Lead Magnet
    expect(find.text('Planos de Consultoria'), findsOneWidget);
    expect(find.text('Consultoria Mensal Pro'), findsOneWidget);
    expect(find.text('Plano Trimestral Evolução'), findsOneWidget);
    expect(find.text('Dúvida de qual plano escolher?'), findsOneWidget);
    expect(find.byKey(const Key('btn_open_screening_banner')), findsOneWidget);

    // 7. Pós-Compra & FAQ
    expect(find.text('Como funciona após a matrícula?'), findsOneWidget);
    expect(find.text('Perguntas Frequentes (FAQ)'), findsOneWidget);
    expect(find.text('Nunca treinei antes na vida, a consultoria serve para mim?'), findsOneWidget);

    // 8. Bottom bar / Action buttons
    expect(find.textContaining('Contratar Imediato'), findsWidgets);
  });
}
