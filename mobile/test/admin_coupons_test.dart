import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_pricing_manager_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin SaaS Coupons & Promo Engine Models & Serialization', () {
    test('AdminCouponItem parses JSON correctly and tests helper getters', () {
      final json = {
        'id': 'TEST50',
        'code': 'TEST50',
        'description': '50% de desconto para testes',
        'discount_type': 'percentage',
        'discount_value': 50.0,
        'max_uses': 100,
        'current_uses': 40,
        'applicable_plan': 'all',
        'is_active': true,
        'expires_at': '2026-12-31T23:59:59Z',
        'created_at': '2026-01-01T00:00:00Z',
      };

      final coupon = AdminCouponItem.fromJson(json);
      expect(coupon.id, 'TEST50');
      expect(coupon.code, 'TEST50');
      expect(coupon.discountType, 'percentage');
      expect(coupon.discountValue, 50.0);
      expect(coupon.maxUses, 100);
      expect(coupon.currentUses, 40);
      expect(coupon.isDepleted, isFalse);
      expect(coupon.usageProgress, closeTo(0.40, 0.01));
      expect(coupon.formattedDiscount, '50% OFF');

      final depletedCoupon = coupon.copyWith(currentUses: 100);
      expect(depletedCoupon.isDepleted, isTrue);
      expect(depletedCoupon.usageProgress, 1.0);

      final fixedCoupon = coupon.copyWith(discountType: 'fixed', discountValue: 25.0);
      expect(fixedCoupon.formattedDiscount, 'R\$ 25.00 OFF');

      final exported = coupon.toJson();
      expect(exported['code'], 'TEST50');
      expect(exported['discount_value'], 50.0);
    });

    test('AdminCouponsOverview parses summary and coupon list correctly', () {
      final json = {
        'summary': {
          'active_coupons': 2,
          'total_redemptions': 55,
          'total_discount_granted_brl': 1250.0,
          'depleted_or_expired_coupons': 1,
        },
        'coupons': [
          {
            'id': 'VIP10',
            'code': 'VIP10',
            'description': 'R\$ 10 OFF',
            'discount_type': 'fixed',
            'discount_value': 10.0,
            'max_uses': 50,
            'current_uses': 10,
            'applicable_plan': 'pro',
            'is_active': true,
          }
        ],
      };

      final overview = AdminCouponsOverview.fromJson(json);
      expect(overview.activeCoupons, 2);
      expect(overview.totalRedemptions, 55);
      expect(overview.totalDiscountGrantedBrl, 1250.0);
      expect(overview.depletedOrExpiredCoupons, 1);
      expect(overview.coupons.length, 1);
      expect(overview.coupons.first.code, 'VIP10');
    });
  });

  group('AdminDataService Coupons Engine Methods & Offline Resilience', () {
    test('getCouponsOverview returns valid default coupons', () async {
      final overview = await AdminDataService.getCouponsOverview();
      expect(overview, isNotNull);
      expect(overview.coupons, isNotEmpty);
      expect(overview.activeCoupons, greaterThan(0));
      expect(overview.coupons.any((c) => c.code == 'LAUNCH50'), isTrue);
    });

    test('createOrUpdateCoupon creates new coupon and updates list', () async {
      const newCoupon = AdminCouponItem(
        id: 'TESTNEW30',
        code: 'TESTNEW30',
        description: 'Cupom de teste 30%',
        discountType: 'percentage',
        discountValue: 30.0,
        maxUses: 20,
        currentUses: 0,
        applicablePlan: 'all',
        isActive: true,
      );

      final success = await AdminDataService.createOrUpdateCoupon(newCoupon);
      expect(success, isTrue);

      final overview = await AdminDataService.getCouponsOverview();
      expect(overview.coupons.any((c) => c.code == 'TESTNEW30'), isTrue);
    });

    test('toggleCouponActive updates active state of coupon', () async {
      final overview = await AdminDataService.getCouponsOverview();
      final coupon = overview.coupons.first;
      final originalState = coupon.isActive;

      final success = await AdminDataService.toggleCouponActive(coupon.id, !originalState);
      expect(success, isTrue);

      final updatedOverview = await AdminDataService.getCouponsOverview();
      final toggled = updatedOverview.coupons.firstWhere((c) => c.id == coupon.id);
      expect(toggled.isActive, !originalState);
    });

    test('deleteCoupon removes coupon from list', () async {
      const tempCoupon = AdminCouponItem(
        id: 'TEMPDELETE',
        code: 'TEMPDELETE',
        description: 'Temporário para deleção',
        discountType: 'fixed',
        discountValue: 5.0,
        maxUses: 5,
        currentUses: 0,
        applicablePlan: 'starter',
        isActive: true,
      );

      await AdminDataService.createOrUpdateCoupon(tempCoupon);
      var overview = await AdminDataService.getCouponsOverview();
      expect(overview.coupons.any((c) => c.id == 'TEMPDELETE'), isTrue);

      final deleted = await AdminDataService.deleteCoupon('TEMPDELETE');
      expect(deleted, isTrue);

      overview = await AdminDataService.getCouponsOverview();
      expect(overview.coupons.any((c) => c.id == 'TEMPDELETE'), isFalse);
    });
  });

  group('AdminPricingManagerScreen Widget with Coupons Tab', () {
    testWidgets('renders screen, switches to coupons tab and validates UI', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPricingManagerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Header and TabBar
      expect(find.text('Gestão de Preços & Planos SaaS'), findsOneWidget);
      expect(find.text('Planos & Mensalidades'), findsOneWidget);
      expect(find.text('Cupons Promocionais'), findsOneWidget);

      // Verify Plan Tab is active by default
      expect(find.text('Planos Ativos'), findsOneWidget);

      // Switch to Coupons Tab
      await tester.tap(find.text('Cupons Promocionais'));
      await tester.pumpAndSettle();

      // Verify Coupons KPI Cards
      expect(find.text('Cupons Ativos'), findsOneWidget);
      expect(find.text('Total de Resgates'), findsOneWidget);
      expect(find.text('Desconto Concedido'), findsOneWidget);
      expect(find.text('Esgotados / Expirados'), findsOneWidget);

      // Verify Campaign Banner & Action Button
      expect(find.text('Motor de Campanhas & Aquisição (CAC)'), findsOneWidget);
      expect(find.text('Novo Cupom'), findsOneWidget);

      // Verify coupons list
      expect(find.text('LAUNCH50'), findsOneWidget);

      // Tap 'Novo Cupom' button to open dialog
      await tester.tap(find.text('Novo Cupom'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Cupom Promocional'), findsOneWidget);
      expect(find.text('Código do Cupom (ex: PROMO50, BLACKFRIDAY)'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Cupom Promocional'), findsNothing);
    });
  });
}
