import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_retention_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trainer Predictive Churn & CAC Payback Cohorts Models & Service Tests', () {
    test('AdminTrainerChurnRiskItem.fromJson parses JSON accurately', () {
      final json = {
        'trainer_id': 'trn-risk-01',
        'trainer_name': 'Marcos Andrade Consultoria',
        'plan_id': 'pro',
        'phone': '11987654321',
        'days_inactive': 19,
        'inactive_students_pct': 64.0,
        'risk_level': 'CRITICAL',
        'churn_probability_pct': 86.5,
        'risk_factors': [
          'Sem prescrever novas fichas há 19 dias',
          '64% dos alunos sem bater check-in nesta semana',
        ],
        'suggested_action': 'Disparar intervenção executiva VIP via WhatsApp.',
      };

      final item = AdminTrainerChurnRiskItem.fromJson(json);
      expect(item.trainerId, 'trn-risk-01');
      expect(item.trainerName, 'Marcos Andrade Consultoria');
      expect(item.planId, 'pro');
      expect(item.daysInactive, 19);
      expect(item.inactiveStudentsPct, 64.0);
      expect(item.riskLevel, 'CRITICAL');
      expect(item.churnProbabilityPct, 86.5);
      expect(item.riskFactors.length, 2);
    });

    test('AdminCacPaybackCohortItem.fromJson parses JSON accurately', () {
      final json = {
        'cohort_month': '2026-07 (Julho)',
        'initial_trainers': 10,
        'active_trainers': 9,
        'retention_rate_pct': 90.0,
        'cac_invested_total': 1200.0,
        'recovered_revenue_total': 5120.0,
        'payback_progress_pct': 100.0,
        'payback_status': 'PAGO',
        'months_since_onboarding': 3,
        'net_profit_generated': 3920.0,
      };

      final cohort = AdminCacPaybackCohortItem.fromJson(json);
      expect(cohort.cohortMonth, '2026-07 (Julho)');
      expect(cohort.initialTrainers, 10);
      expect(cohort.activeTrainers, 9);
      expect(cohort.retentionRatePct, 90.0);
      expect(cohort.cacInvestedTotal, 1200.0);
      expect(cohort.recoveredRevenueTotal, 5120.0);
      expect(cohort.paybackProgressPct, 100.0);
      expect(cohort.paybackStatus, 'PAGO');
      expect(cohort.netProfitGenerated, 3920.0);
    });

    test('AdminDataService getTrainerRetentionCohortsOverview returns realistic metrics', () async {
      final service = AdminDataService();
      final overview = await service.getTrainerRetentionCohortsOverview();

      expect(overview.totalTrainers, greaterThan(0));
      expect(overview.trainersAtRisk, greaterThan(0));
      expect(overview.avgCohortRetentionPct, greaterThan(80.0));
      expect(overview.avgCacPaybackMonths, greaterThan(0.0));
      expect(overview.riskTrainers, isNotEmpty);
      expect(overview.cohorts, isNotEmpty);
    });

    test('AdminDataService triggerTrainerRescue triggers action successfully', () async {
      final service = AdminDataService();
      final success = await service.triggerTrainerRescue(
        trainerId: 'trn-risk-01',
        channel: 'whatsapp',
        customNote: 'Mensagem de teste de resgate',
      );

      expect(success, isTrue);
    });
  });

  group('AdminRetentionScreen Trainer B2B Cohorts Widget Tests', () {
    testWidgets('renders segment switcher and toggles to Trainer B2B Cohorts view', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminRetentionScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica presença do switcher de segmentos
      expect(find.text('Alunos 360° (B2C)'), findsOneWidget);
      expect(find.text('Treinadores B2B & Cohorts'), findsOneWidget);

      // Alterna para o segmento de Treinadores B2B
      await tester.tap(find.text('Treinadores B2B & Cohorts'));
      await tester.pumpAndSettle();

      // Verifica KPIs do segmento de Treinadores
      expect(find.text('TREINADORES EM RISCO PREDITIVO'), findsOneWidget);
      expect(find.text('RETENÇÃO MÉDIA DE COORTE'), findsOneWidget);
      expect(find.text('PAYBACK MÉDIO DO CAC'), findsOneWidget);
      expect(find.text('ARR PROTEGIDO EM RISCO'), findsOneWidget);

      // Verifica Matriz de Coortes e Tabela
      expect(find.text('Matriz de Coortes & Velocidade de Payback do CAC'), findsOneWidget);
      expect(find.text('2026-06 (Junho)'), findsOneWidget);

      // Verifica Radar Preditivo de Churn
      expect(find.text('Radar Preditivo de Churn de Treinadores (B2B)'), findsOneWidget);
      expect(find.text('Marcos Andrade Consultoria'), findsOneWidget);
      expect(find.text('Resgate VIP'), findsWidgets);
    });
  });
}

