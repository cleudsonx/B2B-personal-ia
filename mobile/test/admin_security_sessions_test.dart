import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_audit_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Security & Impersonation Audit Models', () {
    test('AdminActiveSessionItem parses JSON and helper methods correctly', () {
      final json = {
        'session_id': 'sess-101',
        'user_id': 'usr-alpha',
        'user_name': 'Rodrigo Personal',
        'user_email': 'rodrigo@gym.com',
        'user_role': 'trainer',
        'ip_address': '187.54.210.12',
        'location': 'São Paulo, BR',
        'device': 'iPhone 15 Pro',
        'platform': 'iOS 17.4',
        'last_active': 'Há 2 min',
        'is_current_session': true,
        'is_simultaneous': false,
        'status': 'active',
      };

      final item = AdminActiveSessionItem.fromJson(json);
      expect(item.sessionId, 'sess-101');
      expect(item.userName, 'Rodrigo Personal');
      expect(item.userRole, 'trainer');
      expect(item.isCurrentSession, isTrue);
      expect(item.isSimultaneous, isFalse);
      expect(item.status, 'active');

      final copied = item.copyWith(status: 'revoked');
      expect(copied.status, 'revoked');
      expect(copied.sessionId, 'sess-101');
    });

    test('AdminSecurityAlertItem parses JSON accurately', () {
      final json = {
        'id': 'alt-999',
        'type': 'brute_force',
        'title': 'Múltiplas falhas de autenticação',
        'description': '5 tentativas consecutivas com senha inválida',
        'target_user': 'Admin Super',
        'ip_address': '45.162.229.8',
        'attempts_count': 5,
        'severity': 'critical',
        'timestamp': 'Há 12 min',
        'is_resolved': false,
      };

      final alert = AdminSecurityAlertItem.fromJson(json);
      expect(alert.id, 'alt-999');
      expect(alert.type, 'brute_force');
      expect(alert.severity, 'critical');
      expect(alert.attemptsCount, 5);
      expect(alert.isResolved, isFalse);
    });

    test('AdminSecuritySessionsOverview parses summary, sessions and alerts', () {
      final json = {
        'summary': {
          'total_active_sessions': 42,
          'simultaneous_users_count': 3,
          'failed_logins_24h': 8,
          'active_alerts_count': 2,
          'last_audit_scan': 'Há 5 segundos',
        },
        'sessions': [
          {
            'session_id': 's1',
            'user_id': 'u1',
            'user_name': 'Admin',
            'user_email': 'admin@test.com',
            'user_role': 'admin',
            'ip_address': '127.0.0.1',
            'location': 'Localhost',
            'device': 'Chrome',
            'platform': 'Windows',
            'last_active': 'Agora',
            'is_current_session': true,
            'is_simultaneous': false,
            'status': 'active',
          }
        ],
        'security_alerts': [
          {
            'id': 'a1',
            'type': 'concurrent_login',
            'title': 'Acesso concorrente detectado',
            'description': 'Login de 2 locais distintos',
            'target_user': 'Aluno Teste',
            'ip_address': '10.0.0.1',
            'attempts_count': 1,
            'severity': 'high',
            'timestamp': 'Há 3 min',
            'is_resolved': false,
          }
        ],
      };

      final overview = AdminSecuritySessionsOverview.fromJson(json);
      expect(overview.totalActiveSessions, 42);
      expect(overview.simultaneousUsersCount, 3);
      expect(overview.failedLogins24h, 8);
      expect(overview.activeAlertsCount, 2);
      expect(overview.sessions.length, 1);
      expect(overview.securityAlerts.length, 1);
      expect(overview.sessions.first.sessionId, 's1');
      expect(overview.securityAlerts.first.id, 'a1');
    });
  });

  group('AdminDataService Security Endpoints & Fallback Resilience', () {
    test('getSecuritySessionsOverview returns non-null fallback overview', () async {
      final overview = await AdminDataService.getSecuritySessionsOverview();
      expect(overview, isNotNull);
      expect(overview.sessions, isNotEmpty);
      expect(overview.totalActiveSessions, greaterThan(0));
    });

    test('revokeActiveSession handles execution and returns boolean', () async {
      final result = await AdminDataService.revokeActiveSession('sess-test-01');
      expect(result, isTrue);
    });

    test('resolveSecurityAlert handles action and returns boolean', () async {
      final result = await AdminDataService.resolveSecurityAlert('alt-test-01', action: 'block_ip');
      expect(result, isTrue);
    });
  });

  group('AdminAuditScreen Widget Tests', () {
    testWidgets('renders all 4 tabs and loads security overview KPIs', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminAuditScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Check header and tabs
      expect(find.text('Auditoria, Sessões & Segurança'), findsOneWidget);
      expect(find.text('Sessões & Segurança'), findsOneWidget);
      expect(find.text('Logs de Auditoria'), findsOneWidget);
      expect(find.text('Telemetria IA'), findsOneWidget);
      expect(find.text('Health Check & Ping'), findsOneWidget);

      // Check 4 KPI Cards
      expect(find.text('Sessões Ativas'), findsOneWidget);
      expect(find.text('Acessos Simultâneos'), findsOneWidget);
      expect(find.text('Falhas de Login (24h)'), findsOneWidget);
      expect(find.text('Alertas de Ameaça'), findsOneWidget);

      // Check Dispositivos & Sessões Conectadas Section
      expect(find.text('Dispositivos & Sessões Conectadas'), findsOneWidget);
    });
  });
}

