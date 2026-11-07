import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/models/public_showcase_model.dart';
import 'package:personal_ia/features/landing/widgets/showcase_hero_card.dart';
import 'package:personal_ia/features/landing/widgets/quick_screening_modal.dart';
import 'package:personal_ia/services/api_service.dart';

class MockSuccessApiService extends ApiService {
  @override
  Future<LeadScreeningResponse> submitLeadScreening(
    String username,
    LeadScreeningRequest request,
  ) async {
    return const LeadScreeningResponse(
      leadId: 'mock-lead-123',
      trainerId: 'trainer-mock-1',
      trainerName: 'Prof. Treinador Teste',
      trainerWhatsapp: '5511999999999',
      biomechanicalInsight: 'Estabilização lombopélvica recomendada com foco em glúteo.',
      whatsappDirectUrl: 'https://wa.me/5511999999999?text=Teste',
      createdAt: '2026-11-07T12:00:00Z',
      status: 'registered',
    );
  }
}

void main() {
  group('ShowcaseHeroCard Widget Tests', () {
    testWidgets('renders trainer profile with verified CREF and social proof metrics', (tester) async {
      const profile = PublicTrainerProfile(
        id: 'trainer-1',
        fullName: 'Prof. Rodrigo Silva',
        bio: 'Especialista em biomecânica e hipertrofia segura.',
        cref: 'CREF 12345-G/SP',
        crefVerified: true,
        ratingAvg: 4.95,
        ratingCount: 32,
        activeStudentsRange: '20-40 alunos ativos',
        transformationStoriesCount: 15,
        showcaseBadges: ['CREF Verificado', 'Biomecânica Clínica', 'Suporte WhatsApp'],
      );

      bool screeningClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShowcaseHeroCard(
              profile: profile,
              onStartScreening: () {
                screeningClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Prof. Rodrigo Silva'), findsOneWidget);
      expect(find.text('CREF 12345-G/SP'), findsOneWidget);
      expect(find.text('Especialista em biomecânica e hipertrofia segura.'), findsOneWidget);
      expect(find.text('5.0 ★'), findsOneWidget);
      expect(find.text('32 avaliações'), findsOneWidget);
      expect(find.text('15+'), findsOneWidget);
      expect(find.text('Biomecânica Clínica'), findsOneWidget);
      expect(find.byKey(const Key('btn_lead_magnet_screening')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_lead_magnet_screening')));
      await tester.pump();
      expect(screeningClicked, isTrue);
    });
  });

  group('QuickScreeningModal Widget Tests', () {
    testWidgets('validates required fields before submitting', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuickScreeningModal(
              username: 'prof-rodrigo',
              trainerName: 'Prof. Rodrigo',
            ),
          ),
        ),
      );

      // Garante visibilidade e tenta submeter formulário vazio
      await tester.ensureVisible(find.byKey(const Key('btn_submit_screening')));
      await tester.tap(find.byKey(const Key('btn_submit_screening')));
      await tester.pumpAndSettle();

      expect(find.text('Informe seu nome'), findsOneWidget);
      expect(find.text('Informe um WhatsApp válido'), findsOneWidget);
    });

    testWidgets('fills form, submits and renders biomechanical insight success view', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockApi = MockSuccessApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickScreeningModal(
              username: 'prof-rodrigo',
              trainerName: 'Prof. Rodrigo',
              apiService: mockApi,
            ),
          ),
        ),
      );

      // Preenche Nome e WhatsApp
      await tester.enterText(find.byKey(const Key('input_lead_name')), 'Mariana Santos');
      await tester.enterText(find.byKey(const Key('input_lead_phone')), '11988887777');

      // Seleciona dor Lombar
      await tester.tap(find.byKey(const Key('chip_pain_Lombar')));
      await tester.pumpAndSettle();

      // Garante visibilidade do botão e submete
      await tester.ensureVisible(find.byKey(const Key('btn_submit_screening')));
      await tester.tap(find.byKey(const Key('btn_submit_screening')));
      await tester.pumpAndSettle();

      expect(find.text('Triagem Concluída com Sucesso! 🎉'), findsOneWidget);
      expect(find.text('Estabilização lombopélvica recomendada com foco em glúteo.'), findsOneWidget);
      expect(find.byKey(const Key('btn_open_whatsapp_result')), findsOneWidget);
    });
  });
}
