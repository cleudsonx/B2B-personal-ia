import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_ai_usage_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin AI Usage & Gemini Telemetry Service Tests', () {
    test('getAiUsageOverview returns aggregated metrics and trainers', () async {
      final overview = await AdminDataService.getAiUsageOverview();

      expect(overview.totalTokens, greaterThan(0));
      expect(overview.promptTokens + overview.completionTokens, overview.totalTokens);
      expect(overview.estimatedCostBrl, greaterThan(0));
      expect(overview.zeroCostCommandsExecuted, greaterThan(0));
      expect(overview.geminiCallsExecuted, greaterThan(0));
      expect(overview.efficiencyPercentage, inInclusiveRange(0.0, 100.0));
      expect(overview.modelsBreakdown, isNotEmpty);
      expect(overview.trainers, isNotEmpty);

      final firstTrainer = overview.trainers.first;
      expect(firstTrainer.trainerName, isNotEmpty);
      expect(firstTrainer.tokensUsed, greaterThan(0));
      expect(firstTrainer.costBrl, greaterThan(0));
      expect(firstTrainer.plan, isNotEmpty);
    });

    test('getAiUsageOverview filters by plan and search query', () async {
      final proOnly = await AdminDataService.getAiUsageOverview(planFilter: 'pro');
      expect(proOnly.trainers.every((t) => t.plan.toLowerCase().contains('pro')), isTrue);

      final searchResult = await AdminDataService.getAiUsageOverview(searchQuery: 'Cariani');
      expect(searchResult.trainers.length, 1);
      expect(searchResult.trainers.first.trainerName, contains('Cariani'));
    });

    test('adjustTrainerAiQuota returns success and updates quota', () async {
      final res = await AdminDataService.adjustTrainerAiQuota(
        trainerId: 'usr_camilo_2',
        customMonthlyQuota: 200,
      );

      expect(res['status'], 'success');
      expect(res['trainer_id'], 'usr_camilo_2');
      expect(res['custom_monthly_quota'], 200);
    });
  });

  group('AdminAiUsageScreen Widget Tests', () {
    testWidgets('renders header, KPI cards, efficiency barometer and trainers list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAiUsageScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header checks
      expect(find.text('Inteligência & Custos de IA'), findsOneWidget);
      expect(find.textContaining('Auditoria de tokens Gemini 2.5'), findsOneWidget);

      // KPI Checks
      expect(find.text('TOKENS GEMINI'), findsOneWidget);
      expect(find.text('CUSTO ESTIMADO'), findsOneWidget);
      expect(find.text('COMANDOS ZERO-COST'), findsOneWidget);
      expect(find.text('ECONOMIA GERADA'), findsOneWidget);

      // Barometer check
      expect(find.textContaining('Barômetro de Eficiência de IA'), findsOneWidget);
      expect(find.textContaining('Zero-Cost Nativos'), findsOneWidget);
      expect(find.textContaining('Chamadas Gemini LLM'), findsOneWidget);

      // Models check
      expect(find.text('Modelos Google Gemini em Operação'), findsOneWidget);
      expect(find.text('gemini-2.5-flash-lite'), findsOneWidget);
      expect(find.text('gemini-2.5-flash'), findsOneWidget);

      // Trainers section check
      expect(find.textContaining('Consumo de IA e Cotas por Treinador'), findsOneWidget);
      expect(find.text('Renato Cariani'), findsOneWidget);
      expect(find.text('Rodrigo Faro'), findsOneWidget);

      // Filter chips
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Elite'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Starter'), findsOneWidget);
    });

    testWidgets('opens quota adjustment dialog on Cota button click', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminAiUsageScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cotaButton = find.widgetWithText(OutlinedButton, 'Cota').first;
      expect(cotaButton, findsOneWidget);

      await tester.tap(cotaButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Ajustar Cota IA:'), findsOneWidget);
      expect(find.text('Cota Mensal de Gerações:'), findsOneWidget);
      expect(find.text('Salvar Cota'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar Cota'), findsNothing);
    });
  });
}
