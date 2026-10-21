import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_simulator_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';
import 'package:personal_ia/features/admin/widgets/admin_simulator_export_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin SaaS Unit Economics & Pricing Simulator Models & Service', () {
    test('AdminTierEconomics.fromJson parses JSON accurately', () {
      final json = {
        'tier': 'Pro',
        'trainers': 14,
        'students_total': 252,
        'price': 89.0,
        'mrr_subs': 1246.0,
        'mrr_split': 2268.0,
        'cogs_ai': 17.64,
        'net_margin': 3496.36,
        'margin_pct': 97.1,
      };

      final tier = AdminTierEconomics.fromJson(json);
      expect(tier.tier, 'Pro');
      expect(tier.trainers, 14);
      expect(tier.studentsTotal, 252);
      expect(tier.price, 89.0);
      expect(tier.mrrSubs, 1246.0);
      expect(tier.mrrSplit, 2268.0);
      expect(tier.cogsAi, 17.64);
      expect(tier.netMargin, 3496.36);
      expect(tier.marginPct, 97.1);
    });

    test('AdminTrainerEconomics.fromJson parses JSON accurately', () {
      final json = {
        'trainer_id': 'trn-01',
        'trainer_name': 'Studio Fit Performance',
        'plan_id': 'studio',
        'students_count': 94,
        'gmv': 18800.0,
        'platform_revenue': 1139.0,
        'cogs_total': 11.95,
        'net_margin': 1127.05,
        'net_margin_pct': 98.9,
      };

      final trn = AdminTrainerEconomics.fromJson(json);
      expect(trn.trainerId, 'trn-01');
      expect(trn.trainerName, 'Studio Fit Performance');
      expect(trn.planId, 'studio');
      expect(trn.studentsCount, 94);
      expect(trn.gmv, 18800.0);
      expect(trn.platformRevenue, 1139.0);
      expect(trn.cogsTotal, 11.95);
      expect(trn.netMargin, 1127.05);
      expect(trn.netMarginPct, 98.9);
    });

    test('AdminDataService getUnitEconomicsOverview returns realistic SaaS metrics', () async {
      final service = AdminDataService();
      final overview = await service.getUnitEconomicsOverview();

      expect(overview.totalTrainers, greaterThan(0));
      expect(overview.payingTrainers, greaterThan(0));
      expect(overview.totalStudentsActive, greaterThan(0));
      expect(overview.totalMrr, greaterThan(0));
      expect(overview.netMarginPct, greaterThan(90.0));
      expect(overview.ltvToCacRatio, greaterThan(1.0));
      expect(overview.paybackMonths, greaterThan(0.0));
      expect(overview.tierEconomics, isNotEmpty);
      expect(overview.topTrainerEconomics, isNotEmpty);
    });

    test('AdminDataService simulatePricingScenario recalculates MRR and margins correctly', () async {
      final service = AdminDataService();
      
      // Simulação conservadora
      final sim = await service.simulatePricingScenario(
        proPrice: 99.0,
        elitePrice: 169.0,
        studioPrice: 249.0,
        takeRatePct: 6.0,
        geminiOptFactor: 0.70,
        projectedGrowthPct: 20.0,
      );

      expect(sim.projectedMrr, greaterThan(sim.currentMrr));
      expect(sim.deltaMrr, greaterThan(0));
      expect(sim.projectedNetMarginPct, greaterThan(90.0));
      expect(sim.cogsBreakdown['gemini_ai'], isNotNull);
      expect(sim.cogsBreakdown['whatsapp'], isNotNull);
      expect(sim.tierProjections.length, 3);
    });
  });

  group('AdminSimulatorScreen Widget Tests', () {
    testWidgets('renders KPI cards, sliders and tier economics table', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminSimulatorScreen(),
          ),
        ),
      );

      // Aguarda carregamento inicial e primeira simulação
      await tester.pumpAndSettle();

      // Verifica cabeçalho
      expect(find.text('Simulador de Precificação & Margem Líquida'), findsOneWidget);
      expect(find.text('Exportar Relatório'), findsOneWidget);

      // Verifica KPIs do Unit Economics
      expect(find.text('MRR CONSOLIDADO'), findsOneWidget);
      expect(find.text('MARGEM LÍQUIDA'), findsWidgets);
      expect(find.text('LTV / CAC RATIO'), findsOneWidget);
      expect(find.text('PAYBACK & ARR'), findsOneWidget);

      // Verifica seção de Parâmetros e Sliders
      expect(find.text('Parâmetros Comerciais & Precificação'), findsOneWidget);
      expect(find.text('Plano Pro (Mensal)'), findsOneWidget);
      expect(find.text('Plano Elite (Mensal)'), findsOneWidget);
      expect(find.text('Plano Studio (Mensal)'), findsOneWidget);

      // Verifica resultado da simulação
      expect(find.text('Impacto Projetado'), findsOneWidget);
      expect(find.text('MRR PROJETADO'), findsOneWidget);

      // Verifica tabela de Tiers e Ranking de Personals
      expect(find.text('Matriz de Unit Economics por Tier de Assinatura'), findsOneWidget);
      expect(find.text('Top Personals por Margem Líquida Contribuída'), findsOneWidget);
      expect(find.text('Studio Fit Performance'), findsOneWidget);
    });

    testWidgets('opens AdminSimulatorExportModal and displays export options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminSimulatorScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clica no botão de exportação
      final exportBtn = find.text('Exportar Relatório');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Verifica elementos do modal de exportação
      expect(find.text('Exportação Executiva & Pitch Deck'), findsOneWidget);
      expect(find.text('Baixar CSV (Excel)'), findsOneWidget);
      expect(find.text('Copiar Pitch Deck'), findsOneWidget);
      expect(find.text('Copiar CSV em Texto Bruto'), findsOneWidget);

      // Fecha o modal de forma segura
      Navigator.of(tester.element(find.text('Exportação Executiva & Pitch Deck'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Exportação Executiva & Pitch Deck'), findsNothing);
    });
  });
}
