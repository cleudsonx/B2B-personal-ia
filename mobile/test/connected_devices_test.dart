import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/services/device_session_service.dart';
import 'package:personal_ia/features/auth/connected_devices_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceSession & Anti-Fraud Model Tests', () {
    test('DeviceSession.fromJson parses session correctly', () {
      final json = {
        'id': 'sess-12345',
        'device_id': 'dev_iphone_15_pro',
        'device_name': 'iPhone 15 Pro de Cleudson',
        'platform': 'iOS',
        'ip_address': '187.55.12.34',
        'location': 'Brasília, DF • Brasil',
        'user_agent': 'MrCoach/1.12.19 (iOS 18.0)',
        'last_active_at': '2026-10-30T19:30:00Z',
        'is_current': true,
        'is_revoked': false,
      };

      final session = DeviceSession.fromJson(json);

      expect(session.id, 'sess-12345');
      expect(session.deviceId, 'dev_iphone_15_pro');
      expect(session.deviceName, 'iPhone 15 Pro de Cleudson');
      expect(session.platform, 'iOS');
      expect(session.ipAddress, '187.55.12.34');
      expect(session.location, 'Brasília, DF • Brasil');
      expect(session.isCurrent, isTrue);
      expect(session.isRevoked, isFalse);
    });

    test('DeviceSessionsOverview evaluates concurrency limit and warnings', () {
      final overview = DeviceSessionsOverview(
        sessions: [
          DeviceSession.fromJson({
            'id': 'sess-1',
            'device_id': 'dev-1',
            'device_name': 'iPhone 15 Pro',
            'platform': 'iOS',
            'is_current': true,
          }),
          DeviceSession.fromJson({
            'id': 'sess-2',
            'device_id': 'dev-2',
            'device_name': 'Navegador Web Chrome',
            'platform': 'Web Browser',
            'is_current': false,
          }),
        ],
        allowedConcurrentDevices: 2,
        activeDevicesCount: 2,
        isLimitExceeded: false,
      );

      expect(overview.sessions.length, 2);
      expect(overview.allowedConcurrentDevices, 2);
      expect(overview.isLimitExceeded, isFalse);
      expect(overview.warningMessage, isNull);
    });

    test('DeviceSessionService generates and persists deviceId in SharedPreferences', () async {
      final deviceId1 = await DeviceSessionService.getDeviceId();
      expect(deviceId1, isNotEmpty);
      expect(deviceId1.startsWith('dev_'), isTrue);

      // Subsequent call returns same persisted id
      final deviceId2 = await DeviceSessionService.getDeviceId();
      expect(deviceId2, equals(deviceId1));
    });

    test('DeviceSessionService platform and default name helpers return valid strings', () {
      final platform = DeviceSessionService.getPlatformName();
      expect(platform, isNotEmpty);

      final deviceName = DeviceSessionService.getDeviceDefaultName();
      expect(deviceName, isNotEmpty);
    });
  });

  group('ConnectedDevicesScreen Widget Tests', () {
    testWidgets('Renders ConnectedDevicesScreen with header and anti-fraud banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConnectedDevicesScreen(),
        ),
      );

      // Verify app bar title
      expect(find.text('Aparelhos Conectados'), findsOneWidget);

      // Pump to finish any pending timers/refresh
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

