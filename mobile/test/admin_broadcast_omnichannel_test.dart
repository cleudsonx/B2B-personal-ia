import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_broadcast_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Omnichannel Broadcast Models & Service Tests', () {
    test('AdminBroadcastAudienceStats.fromJson parses correctly', () {
      final json = {
        'audience_counts': {
          'all': 1392,
          'trainers_all': 142,
          'trainers_starter': 48,
          'trainers_pro': 68,
          'trainers_studio': 26,
          'trainers_full_capacity': 19,
          'trainers_inactive': 12,
          'students_all': 1250,
          'students_inactive': 168,
          'students_expiring': 54,
        },
        'channels': {
          'push': {
            'active_tokens': 1280,
            'cost_per_msg': 0.0,
          },
          'whatsapp': {
            'connected_instances': 138,
            'cost_per_msg': 0.05,
          },
        },
        'summary': {
          'total_users': 1392,
          'total_trainers': 142,
          'total_students': 1250,
          'estimated_delivery_rate_pct': 98.5,
        },
      };

      final stats = AdminBroadcastAudienceStats.fromJson(json);
      expect(stats.totalUsers, equals(1392));
      expect(stats.totalTrainers, equals(142));
      expect(stats.totalStudents, equals(1250));
      expect(stats.activePushTokens, equals(1280));
      expect(stats.connectedWhatsAppInstances, equals(138));
      expect(stats.whatsappCostPerMsg, equals(0.05));
      expect(stats.estimatedDeliveryRatePct, equals(98.5));
      expect(stats.audienceCounts['trainers_full_capacity'], equals(19));
      expect(stats.audienceCounts['students_inactive'], equals(168));
    });

    test('AdminBroadcastCampaignItem.fromJson parses correctly', () {
      final json = {
        'id': 'CMP-001',
        'title': 'Lançamento v1.9',
        'message': 'Mensagem de teste',
        'channels': ['push', 'whatsapp'],
        'target_audience': 'trainers_all',
        'target_audience_label': 'Todos os Treinadores (B2B)',
        'total_targets': 142,
        'sent_count': 142,
        'delivered_count': 140,
        'failed_count': 2,
        'delivery_rate_pct': 98.6,
        'read_rate_pct': 85.0,
        'click_rate_pct': 42.0,
        'estimated_cost_brl': 7.10,
        'severity': 'info',
        'status': 'DELIVERED',
        'created_at': '21/10/2026 14:00',
        'created_by': 'Admin',
      };

      final item = AdminBroadcastCampaignItem.fromJson(json);
      expect(item.id, equals('CMP-001'));
      expect(item.channels, contains('push'));
      expect(item.channels, contains('whatsapp'));
      expect(item.totalTargets, equals(142));
      expect(item.estimatedCostBrl, equals(7.10));
      expect(item.deliveryRatePct, equals(98.6));
    });

    test('AdminBroadcastDispatchResult.fromJson parses correctly', () {
      final json = {
        'success': true,
        'summary': {
          'campaign_id': 'CMP-12345',
          'dispatched_at': '21/10/2026 15:00',
          'total_sent': 200,
          'delivered': 197,
          'estimated_cost_brl': 10.0,
          'channels': ['whatsapp'],
          'target_audience': 'Alunos Inativos',
        },
      };

      final res = AdminBroadcastDispatchResult.fromJson(json);
      expect(res.success, isTrue);
      expect(res.campaignId, equals('CMP-12345'));
      expect(res.totalSent, equals(200));
      expect(res.delivered, equals(197));
      expect(res.failed, equals(3));
      expect(res.estimatedCostBrl, equals(10.0));
    });

    test('AdminDataService getBroadcastAudienceStats returns valid data', () async {
      final stats = await AdminDataService.getBroadcastAudienceStats();
      expect(stats.totalUsers, greaterThan(0));
      expect(stats.audienceCounts.containsKey('all'), isTrue);
      expect(stats.audienceCounts.containsKey('trainers_full_capacity'), isTrue);
    });

    test('AdminDataService sendBroadcastCampaign dispatches successfully', () async {
      final result = await AdminDataService.sendBroadcastCampaign(
        title: 'Teste Automatizado',
        message: 'Disparo de teste para suite de testes',
        channels: ['push', 'in_app'],
        targetAudience: 'trainers_all',
        severity: 'info',
      );

      expect(result.success, isTrue);
      expect(result.totalSent, greaterThan(0));
      expect(result.delivered, greaterThan(0));
    });
  });

  group('AdminBroadcastScreen Widget Tests', () {
    testWidgets('renders AdminBroadcastScreen, switches tabs and previews correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminBroadcastScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica Header e Banners de Estatísticas
      expect(find.text('Central de Notificações & Broadcast Multicanal'), findsOneWidget);
      expect(find.text('Tokens Push Ativos'), findsOneWidget);
      expect(find.text('Instâncias WhatsApp'), findsOneWidget);

      // Verifica Tabs
      expect(find.text('Disparo de Broadcast'), findsOneWidget);
      expect(find.textContaining('Histórico & Telemetria'), findsOneWidget);
      expect(find.textContaining('Banners In-App'), findsOneWidget);

      // Verifica Seções do Composer
      expect(find.text('1. Canais de Envio Multicanal'), findsOneWidget);
      expect(find.text('2. Segmentação Inteligente do Público-Alvo'), findsOneWidget);
      expect(find.text('3. Modelos & Templates de Alta Conversão'), findsOneWidget);
      expect(find.text('Radar de Alcance & Custo'), findsOneWidget);
      expect(find.text('Live Preview em Tempo Real'), findsOneWidget);

      // Alterna para aba de Histórico & Telemetria
      await tester.tap(find.textContaining('Histórico & Telemetria'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Versão 1.9.0 Disponível no App'), findsOneWidget);

      // Alterna para aba de Banners In-App
      await tester.tap(find.textContaining('Banners In-App'));
      await tester.pumpAndSettle();
    });
  });
}

