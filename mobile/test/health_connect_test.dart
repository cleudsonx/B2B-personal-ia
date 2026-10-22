import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/health_metrics_card.dart';
import 'package:personal_ia/services/health_connect_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DailyHealthSnapshot Model & Calculations Tests', () {
    test('calculates stepProgress, waterProgress and recoveryScore accurately', () {
      final snap = DailyHealthSnapshot(
        date: DateTime.now(),
        steps: 8000,
        stepGoal: 10000,
        activeCaloriesKcal: 500,
        restingHeartRateBpm: 60, // ideal 50 pts
        sleepHours: 8.0, // ideal 50 pts
        waterMl: 2000,
        waterGoalMl: 3000,
        isSynced: true,
        platform: HealthSyncPlatform.appleHealth,
      );

      expect(snap.stepProgress, 0.8);
      expect(snap.waterProgress, closeTo(0.666, 0.01));
      expect(snap.recoveryScore, 100);
      expect(snap.recoveryLabel, 'Recuperação Ótima');
    });

    test('serializes and deserializes DailyHealthSnapshot correctly', () {
      final now = DateTime.now();
      final original = DailyHealthSnapshot(
        date: now,
        steps: 9200,
        stepGoal: 12000,
        activeCaloriesKcal: 610,
        restingHeartRateBpm: 64,
        sleepHours: 7.2,
        waterMl: 2500,
        waterGoalMl: 3500,
        isSynced: true,
        lastSyncedAt: now,
        platform: HealthSyncPlatform.healthConnect,
      );

      final json = original.toJson();
      final restored = DailyHealthSnapshot.fromJson(json);

      expect(restored.steps, 9200);
      expect(restored.stepGoal, 12000);
      expect(restored.activeCaloriesKcal, 610);
      expect(restored.restingHeartRateBpm, 64);
      expect(restored.sleepHours, 7.2);
      expect(restored.platform, HealthSyncPlatform.healthConnect);
    });

    test('HealthConnectService triggerSync, logWater and updateGoals persist changes',
        () async {
      final initial = await HealthConnectService.getTodaySnapshot(userId: 'u1');
      expect(initial.steps, 8420);

      // Sincroniza telemetria
      final synced = await HealthConnectService.triggerSync(
        userId: 'u1',
        platform: HealthSyncPlatform.healthConnect,
      );
      expect(synced.isSynced, isTrue);
      expect(synced.steps, 8420 + 240);

      // Registra copo d'água (+250ml)
      final watered = await HealthConnectService.logWater(amountMl: 500, userId: 'u1');
      expect(watered.waterMl, initial.waterMl + 500);

      // Altera metas
      final updatedGoals = await HealthConnectService.updateGoals(
        stepGoal: 15000,
        waterGoalMl: 4000,
        userId: 'u1',
      );
      expect(updatedGoals.stepGoal, 15000);
      expect(updatedGoals.waterGoalMl, 4000);
    });
  });

  group('HealthMetricsCard Widget Tests', () {
    testWidgets('renders card, metric tiles, triggers sync and logs water',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HealthMetricsCard(userId: 'test_student'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica Header e Tiles
      expect(find.text('Saúde & Telemetria Vital'), findsOneWidget);
      expect(find.text('Passos Diários'), findsOneWidget);
      expect(find.text('Calorias Ativas'), findsOneWidget);
      expect(find.text('FC em Repouso'), findsOneWidget);
      expect(find.text('Sono & Repouso'), findsOneWidget);
      expect(find.text('Hidratação Diária'), findsOneWidget);

      // Clica em adicionar água (+250ml)
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // Clica em Sincronizar Agora
      await tester.tap(find.text('Sincronizar Agora'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sincronizado com'), findsOneWidget);

      // Clica no botão de Configurar Metas
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Configuração de Metas de Saúde'), findsOneWidget);
      expect(find.text('Salvar Metas'), findsOneWidget);

      await tester.tap(find.text('Salvar Metas'));
      await tester.pumpAndSettle();

      expect(find.text('Configuração de Metas de Saúde'), findsNothing);
    });
  });
}
