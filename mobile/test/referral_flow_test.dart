import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/services/referral_service.dart';
import 'package:personal_ia/features/referral/screens/referral_landing_screen.dart';
import 'package:personal_ia/features/auth/register_screen.dart';
import 'package:personal_ia/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReferralService.clearReferral();
  });

  group('Referral Models & Service Unit Tests', () {
    test('ReferralPartnerInfo.fromJson parses correctly with all attributes', () {
      final json = {
        'slug': 'CREFSP',
        'partner_name': 'Conselho Regional de Educação Física (CREF-SP)',
        'partner_type': 'association',
        'associated_coupon_code': 'CREFSP20',
        'commission_percent': 15.0,
        'is_active': true,
        'headline': 'Parceria Homologada CREF-SP & Mr. Coach',
        'badge': 'PARCERIA HOMOLOGADA',
        'description': 'Benefício exclusivo para profissionais registrados.',
      };

      final partner = ReferralPartnerInfo.fromJson(json);
      expect(partner.slug, 'CREFSP');
      expect(partner.partnerName, 'Conselho Regional de Educação Física (CREF-SP)');
      expect(partner.associatedCouponCode, 'CREFSP20');
      expect(partner.commissionPercent, 15.0);
      expect(partner.badge, 'PARCERIA HOMOLOGADA');
      expect(partner.toJson()['slug'], 'CREFSP');
    });

    test('ReferralService fallback canonical partners return valid partners', () async {
      final cref = await ReferralService.getOrFetchPartner('CREFSP', recordClick: false);
      expect(cref, isNotNull);
      expect(cref!.slug, 'CREFSP');
      expect(cref.associatedCouponCode, 'CREFSP20');
      expect(ReferralService.getActiveReferralSlug(), 'CREFSP');
      expect(ReferralService.getActiveReferralCoupon(), 'CREFSP20');

      final iron = await ReferralService.getOrFetchPartner('IRONRUNNER', recordClick: false);
      expect(iron, isNotNull);
      expect(iron!.slug, 'IRONRUNNER');
      expect(iron.associatedCouponCode, 'IRON30');
    });

    test('ReferralService.initFromUri extracts ref query parameter correctly', () async {
      final uri = Uri.parse('https://app.sheipados.com/?ref=RODRIGO-VIP');
      final partner = await ReferralService.initFromUri(uri);
      expect(partner, isNotNull);
      expect(partner!.slug, 'RODRIGO-VIP');
      expect(ReferralService.getActiveReferralCoupon(), 'RODRIGO15');
    });

    test('ReferralService.clearReferral resets state', () async {
      await ReferralService.getOrFetchPartner('FITSTUDIO', recordClick: false);
      expect(ReferralService.getActiveReferralSlug(), 'FITSTUDIO');

      await ReferralService.clearReferral();
      expect(ReferralService.getActiveReferralSlug(), isNull);
      expect(ReferralService.getActiveReferralCoupon(), isNull);
    });
  });

  group('ReferralLandingScreen Widget Tests', () {
    testWidgets('renders partner details, badge, coupon pill and action buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: ReferralLandingScreen(slug: 'CREFSP'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('MR. COACH'), findsOneWidget);
      expect(find.text('PARCERIA HOMOLOGADA'), findsOneWidget);
      expect(find.text('Conselho Regional de Educação Física (CREF-SP)'), findsOneWidget);
      expect(find.text('CUPOM VINCULADO: CREFSP20'), findsOneWidget);
      expect(find.text('Ativar Parceria e Criar Conta'), findsOneWidget);
      expect(find.text('Conhecer Recursos da Plataforma'), findsOneWidget);
    });

    testWidgets('tapping Ativar Parceria navigates to RegisterScreen with partner badge', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: ReferralLandingScreen(slug: 'CREFSP'),
        ),
      );

      await tester.pumpAndSettle();

      final ctaButton = find.text('Ativar Parceria e Criar Conta');
      expect(ctaButton, findsOneWidget);

      await tester.tap(ctaButton);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Criar sua conta'), findsOneWidget);
      expect(find.text('Parceria Conselho Regional de Educação Física (CREF-SP)'), findsOneWidget);
    });
  });

  group('Referral Deep-Linking Router Tests', () {
    testWidgets('navigating to /r/IRONRUNNER opens ReferralLandingScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/r/IRONRUNNER',
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name ?? '/');
            final segments = uri.pathSegments;
            if (segments.length >= 2 && (segments[0] == 'r' || segments[0] == 'ref')) {
              return MaterialPageRoute(
                builder: (_) => ReferralLandingScreen(slug: segments[1]),
              );
            }
            return MaterialPageRoute(builder: (_) => const SizedBox());
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ReferralLandingScreen), findsOneWidget);
      expect(find.text('Iron Runner Assessoria & Running Club'), findsOneWidget);
      expect(find.text('CUPOM VINCULADO: IRON30'), findsOneWidget);
    });
  });
}
