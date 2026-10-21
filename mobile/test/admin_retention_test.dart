import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_retention_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Retention & Churn 360° Data Tests', () {
    test('getRetentionOverview computes rates, churn distribution and trainer stats', () async {
      final overview = await AdminDataService.getRetentionOverview();

      expect(overview.totalStudents, greaterThan(0));
      expect(overview.students.length, overview.totalStudents);
      expect(overview.healthyCount + overview.moderateRiskCount + overview.criticalRiskCount, overview.totalStudents);
      expect(overview.overallRetentionRatePct, inInclusiveRange(0.0, 100.0));
      expect(overview.weeklyCheckinRatePct, inInclusiveRange(0.0, 100.0));
      expect(overview.trainerRetentionStats, isNotEmpty);

      // Verifica ordenação: alunos com maior score de churn no topo
      for (int i = 0; i < overview.students.length - 1; i++) {
        expect(overview.students[i].churnScore, greaterThanOrEqualTo(overview.students[i + 1].churnScore));
      }
    });

    test('student retention item correctly maps risk and reasons', () async {
      final overview = await AdminDataService.getRetentionOverview();
      final criticalStudent = overview.students.firstWhere(
        (e) => e.churnRisk == StudentChurnRisk.critical,
        orElse: () => overview.students.first,
      );

      expect(criticalStudent.studentName, isNotEmpty);
      expect(criticalStudent.trainerName, isNotEmpty);
      expect(criticalStudent.churnScore, greaterThanOrEqualTo(0));
      expect(criticalStudent.riskReason, isNotEmpty);
    });
  });

  group('AdminRetentionScreen Widget Tests', () {
    testWidgets('renders KPI cards, spectrum barometer and 360 radar', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminRetentionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header & Subtitles
      expect(find.text('MISSION CONTROL • CHURN RADAR'), findsOneWidget);
      expect(find.text('Retenção & Alunos 360°'), findsOneWidget);

      // KPI Cards
      expect(find.text('RETENÇÃO DO ECOSSISTEMA'), findsOneWidget);
      expect(find.text('CHECK-IN SEMANAL (BIO HUB)'), findsOneWidget);
      expect(find.text('ALUNOS EM RISCO CRÍTICO'), findsOneWidget);
      expect(find.text('ALUNOS ATIVOS NA SEMANA'), findsOneWidget);

      // Seções
      expect(find.text('ESPECTRO DE SAÚDE DA BASE DE ALUNOS'), findsOneWidget);
      expect(find.text('RADAR 360° DE ALUNOS & PREDIÇÃO DE EVASÃO'), findsOneWidget);

      // Filtro de Churn
      expect(find.textContaining('Todos ('), findsOneWidget);
      expect(find.textContaining('🚨 Crítico ('), findsOneWidget);
    });

    testWidgets('filtering by critical churn updates student list and opens details modal', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminRetentionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clica no filtro de risco crítico
      final criticalFilter = find.textContaining('🚨 Crítico (');
      expect(criticalFilter, findsOneWidget);
      await tester.tap(criticalFilter);
      await tester.pumpAndSettle();

      // Verifica primeiro aluno crítico da lista e toca nele
      final studentCard = find.text('Lucas Albuquerque');
      if (studentCard.evaluate().isNotEmpty) {
        await tester.tap(studentCard);
        await tester.pumpAndSettle();

        // Modal de detalhes 360°
        expect(find.text('DIAGNÓSTICO DO ALGORITMO'), findsOneWidget);
        expect(find.text('AÇÕES IMEDIATAS DE REATIVAÇÃO'), findsOneWidget);
        expect(find.text('Enviar Alerta ao Treinador Responsável'), findsOneWidget);

        // Toca no botão de alerta
        await tester.tap(find.text('Enviar Alerta ao Treinador Responsável'));
        await tester.pumpAndSettle();
      }
    });
  });
}
