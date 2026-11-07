import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/trainer_public_landing_screen.dart';
import 'package:personal_ia/features/landing/widgets/quick_screening_modal.dart';
import 'package:personal_ia/services/consultancy_plan_service.dart';
import 'package:personal_ia/models/public_showcase_model.dart';
import 'package:personal_ia/services/api_service.dart';

class MockFlowApiService extends ApiService {
  @override
  Future<LeadScreeningResponse> submitLeadScreening(
    String username,
    LeadScreeningRequest request,
  ) async {
    return LeadScreeningResponse(
      leadId: 'lead-flow-999',
      trainerId: 'trainer-flow-1',
      trainerName: 'Prof. Marcos Vinicius',
      trainerWhatsapp: '5511999998888',
      biomechanicalInsight: 'Ativação do manguito rotador e reforço escapuloumeral para ${request.goal}.',
      whatsappDirectUrl: 'https://wa.me/5511999998888?text=Análise+Cinesiológica',
      createdAt: '2026-11-07T12:00:00Z',
      status: 'registered',
    );
  }
}

void main() {
  testWidgets('End-to-End Visitor Flow: Showcase -> Lead Magnet -> Biomechanical AI Insight', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTrainerData = {
      'id': 'trainer-flow-1',
      'full_name': 'Prof. Marcos Vinicius',
      'username': 'prof-marcos',
      'bio': 'Especialista em hipertrofia articular e prevenção de lesões.',
      'specialties': ['Hipertrofia', 'Biomecânica'],
      'cref': 'CREF 65432-G/SP',
      'public_whatsapp': '11999998888',
      'photo_url': '',
      'rating_avg': 4.9,
      'rating_count': 28,
      'active_students_range': '25-50 alunos ativos',
      'cref_verified': true,
      'transformation_stories_count': 18,
    };

    final mockPlans = [
      ConsultancyPlan(
        id: 'plan_mensal',
        trainerId: 'trainer-flow-1',
        name: 'Consultoria Mensal',
        priceCents: 16000,
        billingPeriod: 'monthly',
        features: ['Treinos pelo App', 'Ajuste de Cargas'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TrainerPublicLandingScreen(
          username: 'prof-marcos',
          initialTrainerData: mockTrainerData,
          initialPlans: mockPlans,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Vitrine carregada com prova social e credenciais verificadas
    expect(find.text('PROF. MARCOS VINICIUS'), findsOneWidget);
    expect(find.textContaining('65432-G/SP'), findsWidgets);
    expect(find.text('Planos de Consultoria'), findsOneWidget);
    expect(find.text('Consultoria Mensal'), findsOneWidget);

    // 2. Banner de Triagem Biomecânica Gratuita presente
    final bannerButtonFinder = find.byKey(const Key('btn_open_screening_banner'));
    expect(bannerButtonFinder, findsOneWidget);

    // 3. Abre o modal diretamente usando o mock de ApiService
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickScreeningModal(
            username: 'prof-marcos',
            trainerName: 'Prof. Marcos Vinicius',
            trainerPhone: '11999998888',
            apiService: MockFlowApiService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4. Preenche a Triagem
    expect(find.text('Triagem Biomecânica Rápida'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('input_lead_name')), 'Gabriel Alencar');
    await tester.enterText(find.byKey(const Key('input_lead_phone')), '11987654321');

    // Seleciona dor no Ombro
    await tester.tap(find.byKey(const Key('chip_pain_Ombro')));
    await tester.pumpAndSettle();

    // Submete a análise
    await tester.ensureVisible(find.byKey(const Key('btn_submit_screening')));
    await tester.tap(find.byKey(const Key('btn_submit_screening')));
    await tester.pumpAndSettle();

    // 5. Sucesso e entrega do insight cinesiológico
    expect(find.text('Triagem Concluída com Sucesso! 🎉'), findsOneWidget);
    expect(find.textContaining('Ativação do manguito rotador'), findsOneWidget);
    expect(find.byKey(const Key('btn_open_whatsapp_result')), findsOneWidget);
  });
}
