import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_profile_setup_screen.dart';

void main() {
  testWidgets('TrainerProfileSetupScreen renders 60s Triad, AI bio generator and default plans card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Provide initial profile with only photo filled (1 of 3 complete)
    final initialProfile = {
      'username': 'coachcleudson',
      'bio': '',
      'public_whatsapp': '',
      'phone': '',
      'professional_document': '',
      'photo_url': 'https://example.com/avatar.jpg',
      'specialties': ['Hipertrofia', 'Emagrecimento'],
      'public_directory_enabled': true,
    };

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerProfileSetupScreen(
          initialProfile: initialProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Tríade da Vitrine card exists and shows 1/3 initially
    expect(find.text('Tríade da Vitrine em 60s'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('1. Foto/Avatar'), findsOneWidget);
    expect(find.text('2. WhatsApp'), findsOneWidget);
    expect(find.text('3. CREF'), findsOneWidget);

    // 2. Verify AI Bio generation button exists
    expect(find.text('Gerar com IA'), findsOneWidget);

    // Tap "Gerar com IA" and verify bio text field is populated
    await tester.tap(find.text('Gerar com IA'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Personal Trainer especialista em hipertrofia, emagrecimento'), findsOneWidget);
    expect(find.textContaining('Bio profissional gerada pela IA'), findsOneWidget);

    // 3. Verify Default Plans card renders the 3 recommendations
    expect(find.text('Planos de Consultoria na Vitrine'), findsOneWidget);
    expect(find.text('Consultoria Mensal Pro'), findsOneWidget);
    expect(find.text('Plano Trimestral Evolução'), findsOneWidget);
    expect(find.text('Ficha de Treino Avulsa'), findsOneWidget);
    expect(find.text('Ativar estes 3 planos recomendados'), findsOneWidget);

    // 4. Test filling in WhatsApp and CREF to complete the triad (3/3)
    final whatsappField = find.widgetWithText(TextField, '(11) 98765-4321');
    await tester.enterText(whatsappField, '61999998888');
    await tester.pumpAndSettle();

    final crefField = find.widgetWithText(TextField, 'CREF 000000-G/UF');
    await tester.enterText(crefField, 'CREF 012345-G/DF');
    await tester.pumpAndSettle();

    // Verify Tríade count is now 3/3 and shows ready banner
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('✨ Vitrine pronta com os 3 itens essenciais!'), findsOneWidget);
  });
}

