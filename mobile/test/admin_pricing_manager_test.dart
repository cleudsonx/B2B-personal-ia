import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_pricing_manager_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin SaaS Pricing Manager Models & Serialization', () {
    test('AdminPricingPlanItem parses JSON correctly and tests helper getters', () {
      final json = {
        'id': 'pro',
        'name': 'Pro',
        'badge': 'Mais Popular',
        'price_monthly': 89.0,
        'price_yearly': 850.0,
        'student_limit': 20,
        'platform_fee_percent': 5.0,
        'ai_quota_limit': 60,
        'has_custom_branding': true,
        'has_priority_support': true,
        'is_active': true,
        'subscriber_count': 14,
      };

      final plan = AdminPricingPlanItem.fromJson(json);
      expect(plan.id, 'pro');
      expect(plan.name, 'Pro');
      expect(plan.priceMonthly, 89.0);
      expect(plan.priceYearly, 850.0);
      expect(plan.studentLimit, 20);
      expect(plan.isUnlimitedStudents, isFalse);
      expect(plan.isUnlimitedAi, isFalse);
      expect(plan.hasCustomBranding, isTrue);

      final unlimitedPlan = plan.copyWith(studentLimit: 0, aiQuotaLimit: 0);
      expect(unlimitedPlan.isUnlimitedStudents, isTrue);
      expect(unlimitedPlan.isUnlimitedAi, isTrue);

      final exported = plan.toJson();
      expect(exported['id'], 'pro');
      expect(exported['price_monthly'], 89.0);
    });

    test('AdminPricingConfigOverview parses summary and plan list', () {
      final json = {
        'summary': {
          'active_plans_count': 3,
          'total_subscribers': 28,
          'average_monthly_price': 99.0,
          'platform_fee_average': 5.0,
          'last_updated': 'Hoje às 18:00 UTC',
        },
        'plans': [
          {
            'id': 'starter',
            'name': 'Starter',
            'badge': 'Entrada',
            'price_monthly': 49.0,
            'price_yearly': 470.0,
            'student_limit': 5,
            'platform_fee_percent': 5.0,
            'ai_quota_limit': 15,
            'has_custom_branding': false,
            'has_priority_support': false,
            'is_active': true,
            'subscriber_count': 8,
          }
        ],
      };

      final overview = AdminPricingConfigOverview.fromJson(json);
      expect(overview.activePlansCount, 3);
      expect(overview.totalSubscribers, 28);
      expect(overview.averageMonthlyPrice, 99.0);
      expect(overview.plans.length, 1);
      expect(overview.plans.first.id, 'starter');
    });
  });

  group('AdminDataService Pricing Manager Endpoints & Offline Resilience', () {
    test('getPricingPlansOverview returns valid default config', () async {
      final overview = await AdminDataService.getPricingPlansOverview();
      expect(overview, isNotNull);
      expect(overview.plans, isNotEmpty);
      expect(overview.activePlansCount, greaterThan(0));
    });

    test('updatePricingPlan updates plan and reflects in overview', () async {
      final overview = await AdminDataService.getPricingPlansOverview();
      final targetPlan = overview.plans.firstWhere((p) => p.id == 'starter');

      final updated = targetPlan.copyWith(priceMonthly: 55.0);
      final success = await AdminDataService.updatePricingPlan(updated);
      expect(success, isTrue);

      final newOverview = await AdminDataService.getPricingPlansOverview();
      final modified = newOverview.plans.firstWhere((p) => p.id == 'starter');
      expect(modified.priceMonthly, 55.0);
    });

    test('resetDefaultPricingPlans restores starter price to 49.0', () async {
      final resetSuccess = await AdminDataService.resetDefaultPricingPlans();
      expect(resetSuccess, isTrue);

      final defaultOverview = await AdminDataService.getPricingPlansOverview();
      final starter = defaultOverview.plans.firstWhere((p) => p.id == 'starter');
      expect(starter.priceMonthly, 49.0);
    });
  });

  group('AdminPricingManagerScreen Widget Tests', () {
    testWidgets('renders screen header, 4 KPI cards and plan cards', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminPricingManagerScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Header
      expect(find.text('Gestão de Preços & Planos SaaS'), findsOneWidget);
      expect(find.text('Padrões'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);

      // KPI Cards
      expect(find.text('Planos Ativos'), findsOneWidget);
      expect(find.text('Ticket Médio Mensal'), findsOneWidget);
      expect(find.text('Assinantes Vinculados'), findsOneWidget);
      expect(find.text('Taxa Split Plataforma'), findsOneWidget);

      // Plans List
      expect(find.text('Starter'), findsAtLeastNWidgets(1));
      expect(find.text('Pro'), findsAtLeastNWidgets(1));
      expect(find.text('Elite / Studio'), findsAtLeastNWidgets(1));

      // Open Edit Dialog for first plan
      final editButtons = find.text('Editar Parâmetros');
      expect(editButtons, findsAtLeastNWidgets(1));

      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Salvar Alterações'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });
}

