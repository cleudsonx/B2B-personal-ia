import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_finance_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LTV/CAC & Runway Forecast Models & Service Tests', () {
    test('AdminRunwayMonthForecast.fromJson parses accurately', () {
      final json = {
        'month_index': 3,
        'month_label': 'M3 (Dez/26)',
        'trainers_count': 71,
        'students_count': 1562,
        'mrr_saas': 8165.0,
        'mrr_split_gmv': 14058.0,
        'total_revenue': 22223.0,
        'total_cogs': 664.91,
        'cac_spend': 1800.0,
        'fixed_opex': 4500.0,
        'total_expenses': 6964.91,
        'net_cashflow': 15258.08,
        'end_cash_balance': 118021.58,
        'is_profitable': true,
      };

      final m = AdminRunwayMonthForecast.fromJson(json);
      expect(m.monthIndex, equals(3));
      expect(m.monthLabel, equals('M3 (Dez/26)'));
      expect(m.trainersCount, equals(71));
      expect(m.studentsCount, equals(1562));
      expect(m.totalRevenue, equals(22223.0));
      expect(m.isProfitable, isTrue);
      expect(m.netCashflow, equals(15258.08));
    });

    test('AdminRunwaySummary.fromJson parses accurately', () {
      final json = {
        'initial_cash_balance': 85000.0,
        'final_cash_balance': 430238.11,
        'net_cash_delta': 345238.11,
        'runway_months': 999.0,
        'is_default_alive': true,
        'breakeven_month': 1,
        'current_net_burn_rate': 0.0,
        'ltv': 11894.0,
        'cac': 120.0,
        'ltv_to_cac_ratio': 99.1,
        'status': 'DEFAULT_ALIVE',
      };

      final s = AdminRunwaySummary.fromJson(json);
      expect(s.initialCashBalance, equals(85000.0));
      expect(s.isDefaultAlive, isTrue);
      expect(s.breakevenMonth, equals(1));
      expect(s.status, equals('DEFAULT_ALIVE'));
    });

    test('AdminDataService getRunwayOverview returns 12 months forecast', () async {
      final res = await AdminDataService.getRunwayOverview();
      expect(res.forecastMonths.length, equals(12));
      expect(res.summary.initialCashBalance, equals(85000.0));
      expect(res.summary.ltvToCacRatio, greaterThan(0));
    });

    test('AdminDataService simulateRunwayForecast recalculates with custom parameters', () async {
      final res = await AdminDataService.simulateRunwayForecast(
        initialCashBalance: 50000.0,
        monthlyFixedOpex: 8000.0,
        monthlyCacSpend: 3000.0,
        monthlyTrainerGrowthPct: 15.0,
        monthlyChurnPct: 3.0,
      );

      expect(res.summary.initialCashBalance, equals(50000.0));
      expect(res.forecastMonths.length, equals(12));
      expect(res.forecastMonths[0].fixedOpex, equals(8000.0));
      expect(res.forecastMonths[0].cacSpend, equals(3000.0));
    });
  });

  group('AdminFinanceScreen Runway Widget Tests', () {
    testWidgets('renders AdminFinanceScreen and switches to Runway Forecast Tab',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminFinanceScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica Header e Abas
      expect(find.text('Financeiro & Unit Economics'), findsOneWidget);
      expect(find.text('Faturamento & Split (Transações Asaas)'), findsOneWidget);
      expect(find.text('Modelagem LTV/CAC & Runway Forecast (12M)'), findsOneWidget);

      // Alterna para aba de Modelagem LTV/CAC & Runway Forecast
      await tester.tap(find.text('Modelagem LTV/CAC & Runway Forecast (12M)'));
      await tester.pumpAndSettle();

      // Verifica KPIs de Runway
      expect(find.text('Saldo Final Projetado (12M)'), findsOneWidget);
      expect(find.text('Status de Sobrevivência'), findsOneWidget);
      expect(find.text('Relação LTV / CAC'), findsOneWidget);
      expect(find.text('Mês de Breakeven Operacional'), findsOneWidget);

      // Verifica Sliders
      expect(find.text('Caixa Inicial Disponível'), findsOneWidget);
      expect(find.text('Custo Operacional Fixo (OPEX Mensal)'), findsOneWidget);
      expect(find.text('Investimento Mensal em CAC / Anúncios'), findsOneWidget);

      // Verifica Tabela
      expect(find.text('Fluxo de Caixa Projetado Mês a Mês (Horizonte 12 Meses)'), findsOneWidget);
      expect(find.text('Diagnóstico Executivo de Runway & Alocação de Capital'), findsOneWidget);
    });
  });
}
