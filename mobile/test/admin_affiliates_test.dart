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
        'total_commission_paid_brl': 150.0,
        'contact_email': 'test@parceiro.com',
        'pix_key': 'test@parceiro.com',
        'is_active': true,
        'created_at': '2026-01-01',
      };

      final partner = AdminAffiliatePartnerItem.fromJson(json);
      expect(partner.id, 'aff-test');
      expect(partner.partnerName, 'Parceiro Teste');
      expect(partner.slug, 'TESTPARTNER');
      expect(partner.referralUrl, 'https://shaipados.com/#/r/TESTPARTNER');
      expect(partner.partnerTypeLabel, 'Conselho / Entidade');
      expect(partner.commissionPercent, 10.0);
      expect(partner.conversionRate, 25.0);
      expect(partner.formattedRevenue, 'R\$ 2500.00');
      expect(partner.formattedCommission, 'R\$ 250.00');
      expect(partner.formattedPaidCommission, 'R\$ 150.00');
      expect(partner.hasPendingCommission, isTrue);
      expect(partner.isActive, isTrue);

      final exported = partner.toJson();
      expect(exported['slug'], 'TESTPARTNER');
      expect(exported['commission_percent'], 10.0);
      expect(exported['total_commission_paid_brl'], 150.0);
    });

    test('AdminAffiliatePayoutRecord parses JSON and formats correctly', () {
      final json = {
        'id': 'pay-001',
        'affiliate_id': 'aff-test',
        'partner_name': 'Parceiro Teste',
        'amount_brl': 350.50,
        'paid_at': '2026-03-20 15:00:00',
        'pix_key': 'pix@parceiro.com',
        'pix_transaction_id': 'E2E-TEST-001',
        'notes': 'Repasse teste',
        'status': 'PAID',
        'receipt_number': 'REC-2026-0099',
      };

      final record = AdminAffiliatePayoutRecord.fromJson(json);
      expect(record.id, 'pay-001');
      expect(record.affiliateId, 'aff-test');
      expect(record.partnerName, 'Parceiro Teste');
      expect(record.amountBrl, 350.50);
      expect(record.formattedAmount, 'R\$ 350.50');
      expect(record.receiptNumber, 'REC-2026-0099');
      expect(record.status, 'PAID');

      final exported = record.toJson();
      expect(exported['amount_brl'], 350.50);
      expect(exported['receipt_number'], 'REC-2026-0099');
    });

    test('AdminAffiliatesOverview parses summary, payouts and affiliates list correctly', () {
      final json = {
        'summary': {
          'total_partners_count': 4,
          'active_partners_count': 3,
          'total_clicks': 450,
          'total_conversions': 110,
          'average_conversion_rate_percent': 24.4,
          'total_revenue_generated_brl': 11800.0,
          'total_commission_due_brl': 1450.0,
          'total_commission_paid_brl': 550.0,
          'total_payouts_count': 2,
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
            'total_commission_paid_brl': 100.0,
            'is_active': true,
          }
        ],
        'recent_payouts': [
          {
            'id': 'pay-01',
            'affiliate_id': 'aff-1',
            'partner_name': 'Parceiro 1',
            'amount_brl': 100.0,
            'paid_at': '2026-03-01 10:00:00',
            'pix_key': 'chave-pix',
            'pix_transaction_id': 'E2E-1',
            'receipt_number': 'REC-2026-0001',
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
      expect(overview.totalCommissionPaidBrl, 550.0);
      expect(overview.totalPayoutsCount, 2);
      expect(overview.affiliates.length, 1);
      expect(overview.recentPayouts.length, 1);
      expect(overview.recentPayouts.first.receiptNumber, 'REC-2026-0001');
    });
  });

  group('AdminDataService Affiliate Engine & Payout Methods', () {
    test('getAffiliatesOverview returns valid canonical partners with paid metrics', () async {
      final overview = await AdminDataService.getAffiliatesOverview();
      expect(overview, isNotNull);
      expect(overview.affiliates, isNotEmpty);
      expect(overview.activePartnersCount, greaterThan(0));
      expect(overview.affiliates.any((p) => p.slug == 'CREFSP'), isTrue);
      expect(overview.affiliates.any((p) => p.slug == 'IRONRUNNER'), isTrue);
      expect(overview.totalCommissionPaidBrl, greaterThanOrEqualTo(0.0));
    });

    test('payoutAffiliate executes Pix liquidation, updates balances and records payout', () async {
      const partner = AdminAffiliatePartnerItem(
        id: 'aff-payout-test',
        partnerName: 'Parceiro Para Payout',
        slug: 'PAYTEST',
        partnerType: 'coach',
        commissionPercent: 10.0,
        clicksCount: 10,
        conversionsCount: 5,
        totalRevenueGeneratedBrl: 1000.0,
        totalCommissionDueBrl: 100.0,
        totalCommissionPaidBrl: 0.0,
        pixKey: 'pix@paytest.com',
        isActive: true,
      );

      await AdminDataService.createOrUpdateAffiliate(partner);

      final result = await AdminDataService.payoutAffiliate(
        affiliateId: 'aff-payout-test',
        amountBrl: 100.0,
        pixKey: 'pix@paytest.com',
        pixTransactionId: 'E2E-TEST-999',
        notes: 'Pagamento total de comissão',
      );

      expect(result['success'], isTrue);
      expect(result['message'], contains('liquidado com sucesso'));

      final updatedOverview = await AdminDataService.getAffiliatesOverview();
      final updatedPartner = updatedOverview.affiliates.firstWhere((p) => p.id == 'aff-payout-test');
      expect(updatedPartner.totalCommissionDueBrl, 0.0);
      expect(updatedPartner.totalCommissionPaidBrl, 100.0);
      expect(updatedPartner.hasPendingCommission, isFalse);

      final payouts = await AdminDataService.getAffiliatePayouts(affiliateId: 'aff-payout-test');
      expect(payouts, isNotEmpty);
      expect(payouts.any((p) => p.pixTransactionId == 'E2E-TEST-999'), isTrue);
    });

    test('createOrUpdateAffiliate creates new partner and reflects in overview', () async {
      const newPartner = AdminAffiliatePartnerItem(
        id: 'aff-newtest',
        partnerName: 'Academia Gold Fit',
        slug: 'GOLDFIT',
        partnerType: 'gym_chain',
        commissionPercent: 12.0,
        associatedCouponCode: 'GOLD12',
        clicksCount: 15,
        conversionsCount: 3,
        totalRevenueGeneratedBrl: 450.0,
        totalCommissionDueBrl: 54.0,
        contactEmail: 'contato@goldfit.com.br',
        pixKey: 'contato@goldfit.com.br',
        isActive: true,
      );

      final success = await AdminDataService.createOrUpdateAffiliate(newPartner);
      expect(success, isTrue);

      final overview = await AdminDataService.getAffiliatesOverview();
      expect(overview.affiliates.any((p) => p.slug == 'GOLDFIT'), isTrue);
      final created = overview.affiliates.firstWhere((p) => p.slug == 'GOLDFIT');
      expect(created.partnerName, 'Academia Gold Fit');
      expect(created.commissionPercent, 12.0);
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

  group('AdminPricingManagerScreen Widget with Affiliates & Payout Tab', () {
    testWidgets('renders screen, switches to affiliates tab and validates UI & payout actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));

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

      // Verify Affiliates KPI Cards (including Payout KPI)
      expect(find.text('Parceiros Ativos'), findsOneWidget);
      expect(find.text('Total de Cliques'), findsOneWidget);
      expect(find.text('Total de Conversões'), findsOneWidget);
      expect(find.text('Comissões a Repassar'), findsOneWidget);
      expect(find.text('Total Liquidado Pix'), findsOneWidget);

      // Verify Banner & Action Buttons
      expect(find.text('Rede de Parcerias, Entidades & Afiliados'), findsOneWidget);
      expect(find.text('Extrato de Repasses'), findsOneWidget);
      expect(find.text('Novo Parceiro'), findsOneWidget);

      // Verify canonical partners list & Payout buttons
      expect(find.text('CREF4/SP - Conselho Regional'), findsOneWidget);
      expect(find.textContaining('https://shaipados.com/#/r/CREFSP'), findsOneWidget);
      expect(find.text('Liquidar Pix'), findsWidgets);

      // Open Payout Dialog for CREFSP
      await tester.ensureVisible(find.text('Liquidar Pix').first);
      await tester.tap(find.text('Liquidar Pix').first);
      await tester.pumpAndSettle();

      expect(find.text('Liquidar Comissão via Pix'), findsOneWidget);
      expect(find.text('Saldo Pendente'), findsOneWidget);
      expect(find.text('Confirmar Liquidação Pix'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Liquidar Comissão via Pix'), findsNothing);

      // Open Extrato de Repasses modal
      await tester.ensureVisible(find.text('Extrato de Repasses'));
      await tester.tap(find.text('Extrato de Repasses'));
      await tester.pumpAndSettle();

      expect(find.text('Extrato Geral de Repasses Pix'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Extrato Geral de Repasses Pix'), findsNothing);
    });
  });
}
