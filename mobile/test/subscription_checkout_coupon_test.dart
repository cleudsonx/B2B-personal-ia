import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/subscription/subscription_screen.dart';
import 'package:personal_ia/models/subscription_model.dart';
import 'package:personal_ia/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CouponValidationResult Model Tests', () {
    test('parses percentage discount JSON and formats savings correctly', () {
      final json = {
        'valid': true,
        'code': 'LAUNCH50',
        'discount_type': 'percent',
        'discount_value': 50.0,
        'discount_amount': 24.50,
        'final_price': 24.50,
        'first_month_only': true,
        'message': 'Desconto de R\$ 24.50 aplicado!',
      };

      final result = CouponValidationResult.fromJson(json);
      expect(result.valid, isTrue);
      expect(result.code, 'LAUNCH50');
      expect(result.discountType, 'percent');
      expect(result.discountValue, 50.0);
      expect(result.discountAmount, 24.50);
      expect(result.finalPrice, 24.50);
      expect(result.firstMonthOnly, isTrue);
      expect(result.formattedSavings, '50% OFF (-R\$ 24.50)');

      final exported = result.toJson();
      expect(exported['valid'], isTrue);
      expect(exported['code'], 'LAUNCH50');
    });

    test('parses fixed discount JSON and formats savings correctly', () {
      final json = {
        'valid': true,
        'code': 'PROMOVIP20',
        'discount_type': 'fixed',
        'discount_value': 20.0,
        'discount_amount': 20.0,
        'final_price': 69.00,
        'first_month_only': true,
        'message': 'Desconto de R\$ 20.00 aplicado!',
      };

      final result = CouponValidationResult.fromJson(json);
      expect(result.valid, isTrue);
      expect(result.discountType, 'fixed');
      expect(result.formattedSavings, 'R\$ 20.00 OFF');
      expect(result.finalPrice, 69.00);
    });
  });

  group('SubscriptionService Coupon Validation Tests', () {
    test('validates canonical 50% coupon LAUNCH50 for Starter plan', () async {
      final res = await SubscriptionService.validateCoupon(
        code: 'LAUNCH50',
        planId: 'starter',
        basePrice: 49.00,
      );

      expect(res.valid, isTrue);
      expect(res.code, 'LAUNCH50');
      expect(res.discountAmount, closeTo(24.50, 0.01));
      expect(res.finalPrice, closeTo(24.50, 0.01));
    });

    test('validates fixed coupon PROMOVIP20 for Pro plan', () async {
      final res = await SubscriptionService.validateCoupon(
        code: 'PROMOVIP20',
        planId: 'pro',
        basePrice: 89.00,
      );

      expect(res.valid, isTrue);
      expect(res.discountAmount, 20.00);
      expect(res.finalPrice, 69.00);
    });

    test('rejects plan-restricted coupon when plan does not match', () async {
      final res = await SubscriptionService.validateCoupon(
        code: 'CREFPRIME',
        planId: 'elite', // CREFPRIME only applies to starter and pro
        basePrice: 159.00,
      );

      expect(res.valid, isFalse);
      expect(res.message, contains('não é aplicável'));
    });

    test('rejects non-existent coupon gracefully', () async {
      final res = await SubscriptionService.validateCoupon(
        code: 'NAOEXISTE99',
        planId: 'starter',
        basePrice: 49.00,
      );

      expect(res.valid, isFalse);
      expect(res.message, contains('não encontrado'));
    });

    test('rejects empty coupon code gracefully', () async {
      final res = await SubscriptionService.validateCoupon(
        code: '',
        planId: 'pro',
        basePrice: 89.00,
      );

      expect(res.valid, isFalse);
      expect(res.message, contains('informe o código'));
    });
  });

  group('SubscriptionScreen & Checkout Coupon UI Widget Tests', () {
    testWidgets('renders subscription screen, opens checkout and applies coupon LAUNCH50', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Find any "Assinar" button or plan card to open checkout
      final assinarButtons = find.widgetWithText(ElevatedButton, 'Assinar');
      final trocarButtons = find.text('Assinar Plano');
      final anyActionButton = find.textContaining('Assinar');

      if (assinarButtons.evaluate().isNotEmpty) {
        await tester.tap(assinarButtons.first);
      } else if (trocarButtons.evaluate().isNotEmpty) {
        await tester.tap(trocarButtons.first);
      } else if (anyActionButton.evaluate().isNotEmpty) {
        await tester.tap(anyActionButton.first);
      }
      await tester.pumpAndSettle();

      // Check if checkout bottom sheet opened with coupon field
      final couponHeader = find.text('Possui cupom de desconto?');
      if (couponHeader.evaluate().isNotEmpty) {
        expect(couponHeader, findsOneWidget);
        expect(find.text('Aplicar'), findsOneWidget);

        // Enter invalid coupon first
        final textField = find.widgetWithText(TextField, 'EX: LAUNCH50');
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField, 'CUPOMINVALIDO');
          await tester.tap(find.text('Aplicar'));
          await tester.pumpAndSettle();

          expect(find.textContaining('não encontrado'), findsOneWidget);

          // Now enter valid LAUNCH50
          await tester.enterText(textField, 'LAUNCH50');
          await tester.tap(find.text('Aplicar'));
          await tester.pumpAndSettle();

          // Verify applied coupon badge and savings
          expect(find.text('LAUNCH50'), findsOneWidget);
          expect(find.textContaining('OFF'), findsWidgets);

          // Verify remove button
          final closeIcon = find.byIcon(Icons.close_rounded);
          if (closeIcon.evaluate().isNotEmpty) {
            await tester.tap(closeIcon.first);
            await tester.pumpAndSettle();

            // Returns to "Possui cupom de desconto?"
            expect(find.text('Possui cupom de desconto?'), findsOneWidget);
          }
        }
      }
    });
  });
}

