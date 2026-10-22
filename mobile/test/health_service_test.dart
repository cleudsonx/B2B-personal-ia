import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:personal_ia/services/health_connect_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Health Service & Platform Tests', () {
    test('Health package classes and data types are available', () {
      final health = Health();
      expect(health, isNotNull);
      expect(HealthDataType.STEPS, isNotNull);
      expect(HealthDataType.HEART_RATE, isNotNull);
      expect(HealthDataType.ACTIVE_ENERGY_BURNED, isNotNull);
    });

    test('HealthConnectService default snapshot has correct recovery score metrics', () {
      final snapshot = HealthConnectService.defaultSnapshot;
      expect(snapshot.steps, equals(8420));
      expect(snapshot.stepGoal, equals(10000));
      expect(snapshot.sleepHours, equals(7.5));
      expect(snapshot.restingHeartRateBpm, equals(62));
      expect(snapshot.recoveryScore, inInclusiveRange(70, 100));
      expect(snapshot.recoveryLabel, equals('Recuperação Ótima'));
    });

    test('HealthConnectService saves, loads and logs water accurately', () async {
      final initial = await HealthConnectService.getTodaySnapshot(userId: 'test_user');
      expect(initial.waterMl, equals(2250));

      final logged = await HealthConnectService.logWater(amountMl: 500, userId: 'test_user');
      expect(logged.waterMl, equals(2750));

      final reloaded = await HealthConnectService.getTodaySnapshot(userId: 'test_user');
      expect(reloaded.waterMl, equals(2750));
    });

    test('HealthConnectService updateGoals alters targets and persists', () async {
      final updated = await HealthConnectService.updateGoals(
        stepGoal: 12000,
        waterGoalMl: 3500,
        userId: 'test_user_goals',
      );

      expect(updated.stepGoal, equals(12000));
      expect(updated.waterGoalMl, equals(3500));

      final reloaded = await HealthConnectService.getTodaySnapshot(userId: 'test_user_goals');
      expect(reloaded.stepGoal, equals(12000));
      expect(reloaded.waterGoalMl, equals(3500));
    });

    test('HealthConnectService triggerSync syncs with graceful fallback', () async {
      final synced = await HealthConnectService.triggerSync(
        userId: 'test_sync_user',
        platform: HealthSyncPlatform.appleHealth,
      );

      expect(synced.isSynced, isTrue);
      expect(synced.lastSyncedAt, isNotNull);
      expect(synced.platform, equals(HealthSyncPlatform.appleHealth));
      expect(synced.steps, greaterThanOrEqualTo(8420));
    });

    test('HealthConnectService native platform checks handle non-native environments gracefully', () async {
      final hasPerm = await HealthConnectService.hasPermissions();
      // Em testes headless desktop/VM, nativo retorna false graciosamente
      expect(hasPerm, isA<bool>());

      final reqPerm = await HealthConnectService.requestPermissions();
      expect(reqPerm, isA<bool>());
    });
  });
}
