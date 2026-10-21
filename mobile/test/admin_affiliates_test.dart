import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_pricing_manager_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin SaaS Affiliates & Referral Engine Models & Serialization', () {
    test('AdminAffiliatePartnerItem parses JSON correctly and tests helper getters', () {
      final json = {
        'id': 'aff-test',
        'partner_name': 'Parceiro Teste',
        'slug': 'TESTPARTNER',
        'partner_type': 'entity',
        'commission_percent': 10.0,
        'associated_coupon_code': 'TEST50',
        'clicks_count': 100,
        'conversions_count': 25,
        'total_revenue_generated_brl': 2500.0,
        'total_commission_due_brl': 250.0,
        'contact_email': 'test@parceiro.com',
        'pix_key': 'test@parceiro.com',
        'is_active': true,
        'created_at': '2026-01-01',
      };

      final partner = AdminAffiliatePartnerItem.fromJson(json);
      expect(partner.id, 'aff-test');
      expect(partner.partnerName, 'Parceiro Teste');
      expect(partner.slug, 'TESTPARTNER');
      expect(partner.referralUrl, 'https://app.sheipados.com/r/TESTPARTNER');
      expect(partner.partnerTypeLabel, 'Conselho / Entidade');
      expect(partner.commissionPercent, 10.0);
      expect(partner.conversionRate, 25.0);
      expect(partner.formattedRevenue, 'R\$ 2500.00');
      expect(partner.formattedCommission, 'R\$ 250.00');
      expect(partner.isActive, isTrue);

      final exported = partner.toJson();
      expect(exported['slug'], 'TESTPARTNER');
      expect(exported['commission_percent'], 10.0);
    });

    test('AdminAffiliatesOverview parses summary and affiliates list correctly', () {
      final json = {
        'summary': {
          'total_partners_count': 4,
          'active_partners_count': 3,
          'total_clicks': 450,
          'total_conversions': 110,
          'average_conversion_rate_percent': 24.4,
          'total_revenue_generated_brl': 11800.0,
          'total_commission_due_brl': 1450.0,
          'last_updated': 'Hoje às 18:00 UTC',
        },
        'affiliates': [
          {
            'id': 'aff-1',
            'partner_name': 'Parceiro 1',
            'slug': 'P1',
            'partner_type': 'influencer',
            'commission_percent': 20.0,
            'clicks_count': 50,
            'conversions_count': 10,
            'total_revenue_generated_brl': 1000.0,
            'total_commission_due_brl': 200.0,
            'is_active': true,
          }
        ],
      };

      final overview = AdminAffiliatesOverview.fromJson(json);
      expect(overview.totalPartnersCount, 4);
      expect(overview.activePartnersCount, 3);
      expect(overview.totalClicks, 450);
      expect(overview.totalConversions, 110);
      expect(overview.averageConversionRatePercent, 24.4);
      expect(overview.totalRevenueGeneratedBrl, 11800.0);
      expect(overview.totalCommissionDueBrl, 1450.0);
      expect(overview.affiliates.length, 1);
      expect(overview.affiliates.first.partnerTypeLabel, 'Influenciador / Creator');
    });
  });

  group('AdminDataService Affiliate Engine Methods & Offline Resilience', () {
    test('getAffiliatesOverview returns valid canonical partners', () async {
      final overview = await AdminDataService.getAffiliatesOverview();
      expect(overview, isNotNull);
      expect(overview.affiliates, isNotEmpty);
      expect(overview.activePartnersCount, greaterThan(0));
      expect(overview.affiliates.any((p) => p.slug == 'CREFSP'), isTrue);
      expect(overview.affiliates.any((p) => p.slug == 'IRONRUNNER'), isTrue);
    });

    test('createOrUpdateAffiliate creates new partner and reflects in overview', () async {
      const newPartner = AdminAffiliatePartnerItem(
        id: 'aff-newtest',
        partnerName: 'Academia Gold Fit',
        slug: 'GOLDFIT',
        partnerType: 'gym_chain',
        commissionPercent: 12.0,
        associatedCouponCode: 'START2026',
        clicksCount: 0,
        conversionsCount: 0,
        totalRevenueGeneratedBrl: 0.0,
        totalCommissionDueBrl: 0.0,
        isActive: true,
      );

      final success = await AdminDataService.createOrUpdateAffiliate(newPartner);
      expect(success, isTrue);

      final overview = await AdminDataService.getAffiliatesOverview();
      expect(overview.affiliates.any((p) => p.slug == 'GOLDFIT'), isTrue);
    });

    test('toggleAffiliateActive toggles partner active status', () async {
      final overview = await AdminDataService.getAffiliatesOverview();
      final target = overview.affiliates.first;
      final original = target.isActive;

      final success = await AdminDataService.toggleAffiliateActive(target.id, !original);
      expect(success, isTrue);

      final updatedOverview = await AdminDataService.getAffiliatesOverview();
      final toggled = updatedOverview.affiliates.firstWhere((p) => p.id == target.id);
      expect(toggled.isActive, !original);
    });

    test('deleteAffiliate removes partner from list', () async {
      const tempPartner = AdminAffiliatePartnerItem(
        id: 'aff-tempdel',
        partnerName: 'Temporário Deleção',
        slug: 'TEMPDEL',
        partnerType: 'coach',
        commissionPercent: 10.0,
        clicksCount: 0,
        conversionsCount: 0,
        totalRevenueGeneratedBrl: 0.0,
        totalCommissionDueBrl: 0.0,
        isActive: true,
      );

      await AdminDataService.createOrUpdateAffiliate(tempPartner);
      var overview = await AdminDataService.getAffiliatesOverview();
      expect(overview.affiliates.any((p) => p.id == 'aff-tempdel'), isTrue);

      final deleted = await AdminDataService.deleteAffiliate('aff-tempdel');
      expect(deleted, isTrue);

      overview = await AdminDataService.getAffiliatesOverview();
      expect(overview.affiliates.any((p) => p.id == 'aff-tempdel'), isFalse);
    });
  });

  group('AdminPricingManagerScreen Widget with Affiliates Tab', () {
    testWidgets('renders screen, switches to affiliates tab and validates UI', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 950));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminPricingManagerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Header and 3 Tabs
      expect(find.text('Gestão de Preços & Planos SaaS'), findsOneWidget);
      expect(find.text('Planos & Mensalidades'), findsOneWidget);
      expect(find.text('Cupons Promocionais'), findsOneWidget);
      expect(find.text('Afiliados & Parcerias'), findsOneWidget);

      // Switch to Affiliates Tab
      await tester.tap(find.text('Afiliados & Parcerias'));
      await tester.pumpAndSettle();

      // Verify Affiliates KPI Cards
      expect(find.text('Parceiros Ativos'), findsOneWidget);
      expect(find.text('Total de Cliques'), findsOneWidget);
      expect(find.text('Total de Conversões'), findsOneWidget);
      expect(find.text('Comissões a Repassar'), findsOneWidget);

      // Verify Banner & Action Button
      expect(find.text('Rede de Parcerias, Entidades & Afiliados'), findsOneWidget);
      expect(find.text('Novo Parceiro'), findsOneWidget);

      // Verify canonical partners list
      expect(find.text('CREF4/SP - Conselho Regional'), findsOneWidget);
      expect(find.textContaining('https://app.sheipados.com/r/CREFSP'), findsOneWidget);

      // Open "Novo Parceiro" dialog
      await tester.tap(find.text('Novo Parceiro'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Parceiro Afiliado'), findsOneWidget);
      expect(find.text('Slug do Link (ex: CREFSP)'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Novo Parceiro Afiliado'), findsNothing);
    });
  });
}
