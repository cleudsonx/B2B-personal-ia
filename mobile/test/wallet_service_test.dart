import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/wallet_service.dart';

void main() {
  group('WalletService Model Parsing & Split Integrity', () {
    test('WalletSummary.fromJson parses split KPIs and Asaas credentials', () {
      final json = {
        'balance_cents': 95000,
        'pending_balance_cents': 19000,
        'total_billed_month_cents': 95000,
        'pix_key': '12345678900',
        'pix_key_type': 'cpf',
        'bank_name': 'Banco Inter',
        'asaas_account_id': 'cus_123456',
        'asaas_wallet_id': 'wlt_trainer_99',
        'asaas_account_status': 'active',
        'total_splits_count': 5,
        'settled_splits_count': 4,
        'pending_splits_count': 1,
        'settled_gross_cents': 100000,
        'settled_net_cents': 95000,
        'settled_fee_cents': 5000,
        'pending_gross_cents': 20000,
        'pending_net_cents': 19000,
      };

      final summary = WalletSummary.fromJson(json);

      expect(summary.balance, 950.0);
      expect(summary.pendingBalance, 190.0);
      expect(summary.totalBilledMonth, 950.0);
      expect(summary.settledGross, 1000.0);
      expect(summary.settledNet, 950.0);
      expect(summary.settledFee, 50.0);
      expect(summary.pendingGross, 200.0);
      expect(summary.pendingNet, 190.0);
      expect(summary.isAsaasActive, isTrue);
      expect(summary.asaasWalletId, 'wlt_trainer_99');
    });

    test('StudentInvoice.fromJson parses split status, payment method and JWS audit token', () {
      final json = {
        'id': 'inv-abc-123',
        'trainer_id': 'trainer-1',
        'student_name': 'Lucas Silva',
        'title': 'Consultoria Semestral VIP',
        'amount_cents': 60000,
        'platform_fee_cents': 3000,
        'net_amount_cents': 57000,
        'status': 'paid',
        'due_date': '2026-11-20',
        'paid_at': '2026-11-06T20:00:00Z',
        'payment_method': 'pix',
        'asaas_payment_id': 'pay_98765',
        'asaas_wallet_id': 'wlt_trainer_99',
        'jws_split_token': 'eyJhbGciOiJSUzI1NiJ9.signature.mock',
        'split_status': 'settled',
        'created_at': '2026-11-06T19:00:00Z',
      };

      final invoice = StudentInvoice.fromJson(json);

      expect(invoice.amount, 600.0);
      expect(invoice.netAmount, 570.0);
      expect(invoice.platformFee, 30.0);
      expect(invoice.isPaid, isTrue);
      expect(invoice.isSettled, isTrue);
      expect(invoice.isReversed, isFalse);
      expect(invoice.hasJwsAudit, isTrue);
      expect(invoice.paymentMethod, 'pix');
      expect(invoice.jwsSplitToken, contains('eyJhbGciOiJSUzI1NiJ9'));
    });

    test('WalletSplitsCockpitData.fromJson parses consolidated payload', () {
      final json = {
        'summary': {
          'balance_cents': 50000,
          'pending_balance_cents': 10000,
          'total_billed_month_cents': 50000,
        },
        'items': [
          {
            'id': 'inv-1',
            'trainer_id': 'trainer-1',
            'student_name': 'Ana Paula',
            'title': 'Consultoria Mensal',
            'amount_cents': 15000,
            'platform_fee_cents': 750,
            'net_amount_cents': 14250,
            'status': 'paid',
            'split_status': 'settled',
            'due_date': '2026-11-15',
            'created_at': '2026-11-06T12:00:00Z',
          }
        ]
      };

      final cockpit = WalletSplitsCockpitData.fromJson(json);

      expect(cockpit.summary.balance, 500.0);
      expect(cockpit.items.length, 1);
      expect(cockpit.items.first.studentName, 'Ana Paula');
      expect(cockpit.items.first.netAmount, 142.50);
      expect(cockpit.items.first.isSettled, isTrue);
    });
  });
}
