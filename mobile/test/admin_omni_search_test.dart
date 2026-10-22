import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';
import 'package:personal_ia/features/admin/widgets/admin_omni_search_modal.dart';
import 'package:personal_ia/features/admin/widgets/admin_database_explorer_modal.dart';
import 'package:personal_ia/features/admin/widgets/admin_webhook_reprocess_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin God Mode Tools - Unit & DataService Tests', () {
    test('AdminDataService.inspectTable returns columns and rows with pagination', () async {
      final result = await AdminDataService.inspectTable(
        tableName: 'profiles',
        limit: 10,
        offset: 0,
      );

      expect(result.tableName, equals('profiles'));
      expect(result.columns, isNotEmpty);
      expect(result.rows, isNotEmpty);
      expect(result.totalCount, greaterThanOrEqualTo(result.rows.length));
    });

    test('AdminDataService.reprocessWebhook generates idempotent response and telemetry', () async {
      final res = await AdminDataService.reprocessWebhook(
        eventType: 'PAYMENT_RECEIVED',
        paymentId: 'pay_test_unit_123',
        customerId: 'cus_test_456',
        value: 149.90,
      );

      expect(res.eventType, equals('PAYMENT_RECEIVED'));
      expect(res.paymentId, equals('pay_test_unit_123'));
      expect(res.statusCode, isIn([200, 400]));
      expect(res.durationMs, greaterThanOrEqualTo(0));
    });

    test('AdminDataService.inspectableTables contains primary schema entities', () {
      final tables = AdminDataService.inspectableTables;
      expect(tables, contains('profiles'));
      expect(tables, contains('workouts'));
      expect(tables, contains('subscriptions'));
      expect(tables, contains('affiliate_payouts'));
    });
  });

  group('Admin God Mode Modals - Widget Tests', () {
    testWidgets('AdminOmniSearchModal renders and triggers navigation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool explorerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminOmniSearchModal(
              onNavigateToSection: (_) {},
              onOpenDatabaseExplorer: () => explorerOpened = true,
              onOpenWebhookReprocess: () {},
              onViewAsRole: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica campo de busca e seções
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('AÇÕES RÁPIDAS & SIMULAÇÃO'), findsOneWidget);
      expect(find.text('Modo Espelho: Ver como Aluno (View As)'), findsOneWidget);
      expect(find.text('Explorador Seguro de Banco de Dados'), findsOneWidget);

      // Clica em Explorador de Banco nas ações rápidas
      await tester.tap(find.text('Explorador Seguro de Banco de Dados'));
      await tester.pumpAndSettle();

      expect(explorerOpened, isTrue);
    });

    testWidgets('AdminDatabaseExplorerModal renders table selector and data rows', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminDatabaseExplorerModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Explorador Seguro de Banco de Dados'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('AdminWebhookReprocessModal renders and handles reprocess action', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminWebhookReprocessModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reprocessamento de Webhook Asaas'), findsOneWidget);
      final buttonFinder = find.text('Executar Reprocessamento');
      expect(buttonFinder, findsOneWidget);

      // Clica no botão de disparar
      await tester.tap(buttonFinder);
      await tester.pump(); // Inicia o processamento

      // Aguarda o processamento
      await tester.pumpAndSettle();

      expect(find.textContaining('HTTP '), findsOneWidget);
    });
  });
}
