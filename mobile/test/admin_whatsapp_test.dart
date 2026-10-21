import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_whatsapp_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin WhatsApp & Evolution API Service Tests', () {
    test('getWhatsAppInstancesOverview returns metrics and instances list', () async {
      final overview = await AdminDataService.getWhatsAppInstancesOverview();

      expect(overview.totalInstances, greaterThan(0));
      expect(overview.connectedCount + overview.disconnectedCount, lessThanOrEqualTo(overview.totalInstances));
      expect(overview.messagesSent24h, greaterThanOrEqualTo(0));
      expect(overview.uptimePct, inInclusiveRange(0.0, 100.0));
      expect(overview.instances, isNotEmpty);

      final first = overview.instances.first;
      expect(first.trainerName, isNotEmpty);
      expect(first.instanceName, startsWith('trainer_'));
      expect(first.plan, isNotEmpty);
    });

    test('getWhatsAppInstancesOverview filters by status and search query', () async {
      final connectedOnly = await AdminDataService.getWhatsAppInstancesOverview(statusFilter: 'connected');
      expect(connectedOnly.instances.every((i) => i.isConnected), isTrue);

      final disconnectedOnly = await AdminDataService.getWhatsAppInstancesOverview(statusFilter: 'disconnected');
      expect(disconnectedOnly.instances.every((i) => i.isDisconnected), isTrue);

      final searchResult = await AdminDataService.getWhatsAppInstancesOverview(searchQuery: 'Faro');
      expect(searchResult.instances.length, 1);
      expect(searchResult.instances.first.trainerName, contains('Faro'));
    });

    test('performWhatsAppInstanceAction returns success status', () async {
      final pingRes = await AdminDataService.performWhatsAppInstanceAction(
        instanceName: 'trainer_usrfaro1',
        action: 'ping',
      );
      expect(pingRes['status'], 'success');

      final restartRes = await AdminDataService.performWhatsAppInstanceAction(
        instanceName: 'trainer_usrfaro1',
        action: 'restart',
      );
      expect(restartRes['status'], 'success');
    });
  });

  group('AdminWhatsAppScreen Widget Tests', () {
    testWidgets('renders KPI cards, status chips and instance cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminWhatsAppScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top KPIs
      expect(find.text('TOTAL INSTÂNCIAS'), findsOneWidget);
      expect(find.text('ONLINE / ATIVAS'), findsOneWidget);
      expect(find.text('DESCONECTADAS'), findsOneWidget);
      expect(find.text('DISPAROS 24H'), findsOneWidget);

      // Search bar
      expect(find.byType(TextField), findsOneWidget);

      // Status Filter Chips
      expect(find.textContaining('Todas ('), findsOneWidget);
      expect(find.textContaining('Conectadas ('), findsOneWidget);
      expect(find.textContaining('Desconectadas ('), findsOneWidget);

      // Instâncias listadas
      expect(find.text('Rodrigo Faro'), findsOneWidget);
      expect(find.text('Renato Cariani'), findsOneWidget);
      expect(find.text('Juliana Salimeni'), findsOneWidget);
      expect(find.text('ONLINE'), findsWidgets);
      expect(find.text('OFFLINE'), findsWidgets);
    });

    testWidgets('triggers ping action and opens logout confirm dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminWhatsAppScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toca no botão de ping da instância do Rodrigo Faro
      final pingBtn = find.byKey(const Key('admin_wa_ping_trainer_usrfaro1'));
      expect(pingBtn, findsOneWidget);
      await tester.tap(pingBtn);
      await tester.pumpAndSettle();

      // Toca no botão de logout para testar o modal de confirmação
      final logoutBtn = find.byKey(const Key('admin_wa_logout_trainer_usrfaro1'));
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Verifica se o AlertDialog abriu
      expect(find.text('Desconectar Instância?'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);

      // Toca em cancelar para fechar com segurança
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });
}
