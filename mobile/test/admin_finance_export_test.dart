import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';
import 'package:personal_ia/features/admin/widgets/admin_finance_export_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockTransactions = [
    AdminTransaction(
      id: 'tx_test_001',
      providerPaymentId: 'pay_123',
      trainerId: 'trainer_1',
      trainerName: 'Carlos Silva',
      trainerEmail: 'carlos@personal.com',
      planId: 'plan_gold',
      planName: 'Consultoria Premium',
      amountCents: 15000, // R$ 150,00
      paymentMethod: 'pix',
      status: 'paid',
      billingInterval: 'monthly',
      createdAt: DateTime(2026, 10, 21, 10, 30),
    ),
    AdminTransaction(
      id: 'tx_test_002',
      providerPaymentId: 'pay_456',
      trainerId: 'trainer_2',
      trainerName: 'Fernanda Lima',
      trainerEmail: 'fernanda@personal.com',
      planId: 'plan_silver',
      planName: 'Treino Hipertrofia',
      amountCents: 10000, // R$ 100,00
      paymentMethod: 'credit_card',
      status: 'paid',
      billingInterval: 'monthly',
      createdAt: DateTime(2026, 10, 20, 14, 0),
    ),
  ];

  testWidgets('AdminFinanceExportModal renders consolidated GMV, 5% split and export buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminFinanceExportModal(transactions: mockTransactions),
        ),
      ),
    );

    // Verifica cabeçalho
    expect(find.text('Relatório Contábil & Auditoria de Splits'), findsOneWidget);

    // GMV Total = R$ 150 + R$ 100 = R$ 250,00
    expect(find.text('R\$ 250,00'), findsOneWidget);

    // Split 5% da Plataforma = R$ 250 * 0.05 = R$ 12,50
    expect(find.text('R\$ 12,50'), findsOneWidget);

    // Repasse aos Personals 95% = R$ 250 * 0.95 = R$ 237,50
    expect(find.text('R\$ 237,50'), findsOneWidget);

    // Verifica nomes dos treinadores na tabela analítica
    expect(find.text('Carlos Silva'), findsOneWidget);
    expect(find.text('Fernanda Lima'), findsOneWidget);

    // Botões de Ação
    expect(find.text('Baixar Relatório CSV'), findsOneWidget);
    expect(find.text('Copiar Tabela (Excel)'), findsOneWidget);
  });
}
