import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plataforma de sincronização de dados de saúde
enum HealthSyncPlatform {
  appleHealth,
  healthConnect,
  manual;

  String get label {
    switch (this) {
      case HealthSyncPlatform.appleHealth:
        return 'Apple Health';
      case HealthSyncPlatform.healthConnect:
        return 'Health Connect';
      case HealthSyncPlatform.manual:
        return 'Registro Manual';
    }
  }

  String get badgeName {
    switch (this) {
      case HealthSyncPlatform.appleHealth:
        return 'APPLE HEALTH';
      case HealthSyncPlatform.healthConnect:
        return 'HEALTH CONNECT';
      case HealthSyncPlatform.manual:
        return 'MANUAL';
    }
  }
}

/// Instantâneo das métricas diárias de saúde do aluno
class DailyHealthSnapshot {
  final DateTime date;
  final int steps;
  final int stepGoal;
  final int activeCaloriesKcal;
  final int restingHeartRateBpm;
  final double sleepHours;
  final int waterMl;
  final int waterGoalMl;
  final bool isSynced;
  final DateTime? lastSyncedAt;
  final HealthSyncPlatform platform;

  const DailyHealthSnapshot({
    required this.date,
    required this.steps,
    this.stepGoal = 10000,
    required this.activeCaloriesKcal,
    required this.restingHeartRateBpm,
    required this.sleepHours,
    this.waterMl = 0,
    this.waterGoalMl = 3000,
    this.isSynced = false,
    this.lastSyncedAt,
    this.platform = HealthSyncPlatform.healthConnect,
  });

  double get stepProgress => (steps / (stepGoal <= 0 ? 1 : stepGoal)).clamp(0.0, 1.0);
  double get waterProgress => (waterMl / (waterGoalMl <= 0 ? 1 : waterGoalMl)).clamp(0.0, 1.0);

  /// Score de recuperação (0 a 100) baseado em sono e FC de repouso
  int get recoveryScore {
    // 7 a 9h de sono ideal (50 pts)
    double sleepScore = 0;
    if (sleepHours >= 7 && sleepHours <= 9) {
      sleepScore = 50;
    } else if (sleepHours >= 6) {
      sleepScore = 38;
    } else {
      sleepScore = (sleepHours / 6) * 30;
    }

    // FC de repouso: 50-70 bpm ideal (50 pts)
    double hrScore = 0;
    if (restingHeartRateBpm >= 48 && restingHeartRateBpm <= 68) {
      hrScore = 50;
    } else if (restingHeartRateBpm <= 78) {
      hrScore = 38;
    } else {
      hrScore = 25;
    }

    return (sleepScore + hrScore).clamp(0, 100).round();
  }

  String get recoveryLabel {
    final score = recoveryScore;
    if (score >= 85) return 'Recuperação Ótima';
    if (score >= 70) return 'Recuperação Boa';
    if (score >= 50) return 'Recuperação Moderada';
    return 'Atenção ao Descanso';
  }

  DailyHealthSnapshot copyWith({
    DateTime? date,
    int? steps,
    int? stepGoal,
    int? activeCaloriesKcal,
    int? restingHeartRateBpm,
    double? sleepHours,
    int? waterMl,
    int? waterGoalMl,
    bool? isSynced,
    DateTime? lastSyncedAt,
    HealthSyncPlatform? platform,
  }) {
    return DailyHealthSnapshot(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      activeCaloriesKcal: activeCaloriesKcal ?? this.activeCaloriesKcal,
      restingHeartRateBpm: restingHeartRateBpm ?? this.restingHeartRateBpm,
      sleepHours: sleepHours ?? this.sleepHours,
      waterMl: waterMl ?? this.waterMl,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      isSynced: isSynced ?? this.isSynced,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      platform: platform ?? this.platform,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'steps': steps,
        'stepGoal': stepGoal,
        'activeCaloriesKcal': activeCaloriesKcal,
        'restingHeartRateBpm': restingHeartRateBpm,
        'sleepHours': sleepHours,
        'waterMl': waterMl,
        'waterGoalMl': waterGoalMl,
        'isSynced': isSynced,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'platform': platform.name,
      };

  factory DailyHealthSnapshot.fromJson(Map<String, dynamic> json) {
    return DailyHealthSnapshot(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      stepGoal: (json['stepGoal'] as num?)?.toInt() ?? 10000,
      activeCaloriesKcal: (json['activeCaloriesKcal'] as num?)?.toInt() ?? 0,
      restingHeartRateBpm: (json['restingHeartRateBpm'] as num?)?.toInt() ?? 65,
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 7.0,
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
      waterGoalMl: (json['waterGoalMl'] as num?)?.toInt() ?? 3000,
      isSynced: json['isSynced'] as bool? ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String)
          : null,
      platform: HealthSyncPlatform.values.firstWhere(
        (e) => e.name == json['platform'],
        orElse: () => HealthSyncPlatform.healthConnect,
      ),
    );
  }
}

/// Serviço de integração de métricas de saúde com persistência local e cache
class HealthConnectService {
  static const String _prefKey = 'health_connect_snapshot_v1_';

  static DailyHealthSnapshot get defaultSnapshot {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return DailyHealthSnapshot(
      date: DateTime.now(),
      steps: 8420,
      stepGoal: 10000,
      activeCaloriesKcal: 540,
      restingHeartRateBpm: 62,
      sleepHours: 7.5,
      waterMl: 2250,
      waterGoalMl: 3000,
      isSynced: true,
      lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      platform: isIOS ? HealthSyncPlatform.appleHealth : HealthSyncPlatform.healthConnect,
    );
  }

  static Future<DailyHealthSnapshot> getTodaySnapshot({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKey${userId ?? "default"}';
    final raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) {
      return defaultSnapshot;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return DailyHealthSnapshot.fromJson(decoded);
    } catch (_) {
      return defaultSnapshot;
    }
  }

  static Future<void> saveSnapshot(DailyHealthSnapshot snapshot, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKey${userId ?? "default"}';
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
  }

  static Future<DailyHealthSnapshot> triggerSync({
    String? userId,
    HealthSyncPlatform? platform,
  }) async {
    final current = await getTodaySnapshot(userId: userId);
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final selectedPlatform =
        platform ?? (isIOS ? HealthSyncPlatform.appleHealth : HealthSyncPlatform.healthConnect);

    // Simula telemetria recente sincronizada
    final updated = current.copyWith(
      isSynced: true,
      lastSyncedAt: DateTime.now(),
      platform: selectedPlatform,
      steps: current.steps + 240,
      activeCaloriesKcal: current.activeCaloriesKcal + 18,
    );

    await saveSnapshot(updated, userId: userId);
    return updated;
  }

  static Future<DailyHealthSnapshot> logWater({
    int amountMl = 250,
    String? userId,
  }) async {
    final current = await getTodaySnapshot(userId: userId);
    final updated = current.copyWith(
      waterMl: (current.waterMl + amountMl).clamp(0, 10000),
      lastSyncedAt: DateTime.now(),
    );
    await saveSnapshot(updated, userId: userId);
    return updated;
  }

  static Future<DailyHealthSnapshot> updateGoals({
    int? stepGoal,
    int? waterGoalMl,
    String? userId,
  }) async {
    final current = await getTodaySnapshot(userId: userId);
    final updated = current.copyWith(
      stepGoal: stepGoal ?? current.stepGoal,
      waterGoalMl: waterGoalMl ?? current.waterGoalMl,
    );
    await saveSnapshot(updated, userId: userId);
    return updated;
  }
}
