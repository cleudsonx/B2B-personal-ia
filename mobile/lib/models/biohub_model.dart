import 'package:flutter/material.dart';

class ReadinessScoreModel {
  final int score;
  final String level; // high, moderate, low, critical
  final String headline;
  final String recommendation;
  final double sleepFactor;
  final double fatigueFactor;
  final double jointFactor;
  final double streakFactor;

  const ReadinessScoreModel({
    required this.score,
    required this.level,
    required this.headline,
    required this.recommendation,
    this.sleepFactor = 0.0,
    this.fatigueFactor = 0.0,
    this.jointFactor = 0.0,
    this.streakFactor = 0.0,
  });

  factory ReadinessScoreModel.fromJson(Map<String, dynamic> json) {
    return ReadinessScoreModel(
      score: (json['score'] as num?)?.toInt() ?? 85,
      level: json['level'] as String? ?? 'high',
      headline: json['headline'] as String? ?? 'Prontidão Neuromuscular Máxima',
      recommendation: json['recommendation'] as String? ??
          'Sistema neuromuscular recuperado e apto para treino intenso.',
      sleepFactor: (json['sleep_factor'] as num?)?.toDouble() ?? 0.0,
      fatigueFactor: (json['fatigue_factor'] as num?)?.toDouble() ?? 0.0,
      jointFactor: (json['joint_factor'] as num?)?.toDouble() ?? 0.0,
      streakFactor: (json['streak_factor'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
      'headline': headline,
      'recommendation': recommendation,
      'sleep_factor': sleepFactor,
      'fatigue_factor': fatigueFactor,
      'joint_factor': jointFactor,
      'streak_factor': streakFactor,
    };
  }

  bool get isHigh => level == 'high';
  bool get isModerate => level == 'moderate';
  bool get isLow => level == 'low';
  bool get isCritical => level == 'critical';

  String get levelLabel {
    switch (level) {
      case 'high':
        return 'Alta Prontidão';
      case 'moderate':
        return 'Prontidão Estável';
      case 'low':
        return 'Atenção / Fadiga';
      case 'critical':
        return 'Crítica / Deload';
      default:
        return 'Prontidão Normal';
    }
  }

  Color get scoreColor {
    if (score >= 80) return const Color(0xFF10B981); // Emerald Green
    if (score >= 60) return const Color(0xFFF59E0B); // Amber / Yellow
    if (score >= 40) return const Color(0xFFF97316); // Orange
    return const Color(0xFFEF4444); // Red
  }
}

class DailyBiometricLogModel {
  final double? sleepHours;
  final int? sleepQuality;
  final int? perceivedStress;
  final int? sorenessLevel;
  final bool hasJointPain;
  final String? notes;

  const DailyBiometricLogModel({
    this.sleepHours = 7.5,
    this.sleepQuality = 4,
    this.perceivedStress = 2,
    this.sorenessLevel = 2,
    this.hasJointPain = false,
    this.notes,
  });

  factory DailyBiometricLogModel.fromJson(Map<String, dynamic> json) {
    return DailyBiometricLogModel(
      sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      sleepQuality: (json['sleep_quality'] as num?)?.toInt(),
      perceivedStress: (json['perceived_stress'] as num?)?.toInt(),
      sorenessLevel: (json['soreness_level'] as num?)?.toInt(),
      hasJointPain: json['has_joint_pain'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sleep_hours': sleepHours,
      'sleep_quality': sleepQuality,
      'perceived_stress': perceivedStress,
      'soreness_level': sorenessLevel,
      'has_joint_pain': hasJointPain,
      if (notes != null) 'notes': notes,
    };
  }
}

class MuscleRecoveryItemModel {
  final String muscleGroup; // chest, back, quadriceps, hamstrings_glutes, shoulders, arms_core
  final String label;
  final int recoveryPercentage;
  final String status; // recovered, recovering, fatigued
  final double? lastTrainedHoursAgo;
  final int hoursUntilRecovered;

  const MuscleRecoveryItemModel({
    required this.muscleGroup,
    required this.label,
    required this.recoveryPercentage,
    required this.status,
    this.lastTrainedHoursAgo,
    required this.hoursUntilRecovered,
  });

  factory MuscleRecoveryItemModel.fromJson(Map<String, dynamic> json) {
    return MuscleRecoveryItemModel(
      muscleGroup: json['muscle_group'] as String? ?? 'chest',
      label: json['label'] as String? ?? 'Peitoral',
      recoveryPercentage: (json['recovery_percentage'] as num?)?.toInt() ?? 100,
      status: json['status'] as String? ?? 'recovered',
      lastTrainedHoursAgo: (json['last_trained_hours_ago'] as num?)?.toDouble(),
      hoursUntilRecovered: (json['hours_until_recovered'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'muscle_group': muscleGroup,
      'label': label,
      'recovery_percentage': recoveryPercentage,
      'status': status,
      'last_trained_hours_ago': lastTrainedHoursAgo,
      'hours_until_recovered': hoursUntilRecovered,
    };
  }

  bool get isRecovered => status == 'recovered';
  bool get isRecovering => status == 'recovering';
  bool get isFatigued => status == 'fatigued';

  String get statusLabel {
    switch (status) {
      case 'recovered':
        return '100% Recuperado';
      case 'recovering':
        return '$recoveryPercentage% Regenerando';
      case 'fatigued':
        return '$recoveryPercentage% Fadiga Alta';
      default:
        return '$recoveryPercentage%';
    }
  }

  Color get statusColor {
    if (recoveryPercentage >= 80) return const Color(0xFF10B981);
    if (recoveryPercentage >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class MuscleRecoveryReportModel {
  final int overallRecoveryPercentage;
  final List<MuscleRecoveryItemModel> muscles;
  final int readyMusclesCount;
  final int fatiguedMusclesCount;
  final String summary;

  const MuscleRecoveryReportModel({
    required this.overallRecoveryPercentage,
    this.muscles = const [],
    required this.readyMusclesCount,
    required this.fatiguedMusclesCount,
    required this.summary,
  });

  factory MuscleRecoveryReportModel.fromJson(Map<String, dynamic> json) {
    return MuscleRecoveryReportModel(
      overallRecoveryPercentage:
          (json['overall_recovery_percentage'] as num?)?.toInt() ?? 100,
      muscles: (json['muscles'] as List<dynamic>?)
              ?.map((e) => MuscleRecoveryItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      readyMusclesCount: (json['ready_muscles_count'] as num?)?.toInt() ?? 6,
      fatiguedMusclesCount:
          (json['fatigued_muscles_count'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? 'Músculos recuperados.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_recovery_percentage': overallRecoveryPercentage,
      'muscles': muscles.map((m) => m.toJson()).toList(),
      'ready_muscles_count': readyMusclesCount,
      'fatigued_muscles_count': fatiguedMusclesCount,
      'summary': summary,
    };
  }
}

class StrengthPrItemModel {
  final String exerciseName;
  final double weightKg;
  final int reps;
  final double estimated1rm;
  final String formulaUsed;
  final double volumeLoadKg;
  final String achievedAt;
  final double? previous1rm;
  final double? gainPercent;

  const StrengthPrItemModel({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.estimated1rm,
    this.formulaUsed = 'brzycki',
    required this.volumeLoadKg,
    required this.achievedAt,
    this.previous1rm,
    this.gainPercent,
  });

  factory StrengthPrItemModel.fromJson(Map<String, dynamic> json) {
    return StrengthPrItemModel(
      exerciseName: json['exercise_name'] as String? ?? 'Exercício',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      reps: (json['reps'] as num?)?.toInt() ?? 1,
      estimated1rm: (json['estimated_1rm'] as num?)?.toDouble() ?? 0.0,
      formulaUsed: json['formula_used'] as String? ?? 'brzycki',
      volumeLoadKg: (json['volume_load_kg'] as num?)?.toDouble() ?? 0.0,
      achievedAt: json['achieved_at'] as String? ?? '',
      previous1rm: (json['previous_1rm'] as num?)?.toDouble(),
      gainPercent: (json['gain_percent'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_name': exerciseName,
      'weight_kg': weightKg,
      'reps': reps,
      'estimated_1rm': estimated1rm,
      'formula_used': formulaUsed,
      'volume_load_kg': volumeLoadKg,
      'achieved_at': achievedAt,
      'previous_1rm': previous1rm,
      'gain_percent': gainPercent,
    };
  }
}

class StrengthEvolutionReportModel {
  final String studentId;
  final double totalVolume7dKg;
  final int prsCount;
  final List<StrengthPrItemModel> recentPrs;
  final Map<String, StrengthPrItemModel> keyLifts;

  const StrengthEvolutionReportModel({
    required this.studentId,
    required this.totalVolume7dKg,
    required this.prsCount,
    this.recentPrs = const [],
    this.keyLifts = const {},
  });

  factory StrengthEvolutionReportModel.fromJson(Map<String, dynamic> json) {
    final liftsRaw = json['key_lifts'] as Map<String, dynamic>? ?? {};
    final parsedLifts = <String, StrengthPrItemModel>{};
    liftsRaw.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        parsedLifts[k] = StrengthPrItemModel.fromJson(v);
      }
    });

    return StrengthEvolutionReportModel(
      studentId: json['student_id'] as String? ?? '',
      totalVolume7dKg: (json['total_volume_7d_kg'] as num?)?.toDouble() ?? 0.0,
      prsCount: (json['prs_count'] as num?)?.toInt() ?? 0,
      recentPrs: (json['recent_prs'] as List<dynamic>?)
              ?.map((e) => StrengthPrItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keyLifts: parsedLifts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'total_volume_7d_kg': totalVolume7dKg,
      'prs_count': prsCount,
      'recent_prs': recentPrs.map((p) => p.toJson()).toList(),
      'key_lifts': keyLifts.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}

class TrainerFatigueRadarModel {
  final String trainerId;
  final int totalStudents;
  final int highReadinessCount;
  final int moderateReadinessCount;
  final int lowReadinessCount;
  final int criticalReadinessCount;
  final List<Map<String, dynamic>> studentsNeedingDeload;
  final List<Map<String, dynamic>> studentsSummary;

  const TrainerFatigueRadarModel({
    required this.trainerId,
    required this.totalStudents,
    required this.highReadinessCount,
    required this.moderateReadinessCount,
    required this.lowReadinessCount,
    required this.criticalReadinessCount,
    this.studentsNeedingDeload = const [],
    this.studentsSummary = const [],
  });

  factory TrainerFatigueRadarModel.fromJson(Map<String, dynamic> json) {
    return TrainerFatigueRadarModel(
      trainerId: json['trainer_id'] as String? ?? '',
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      highReadinessCount: (json['high_readiness_count'] as num?)?.toInt() ?? 0,
      moderateReadinessCount:
          (json['moderate_readiness_count'] as num?)?.toInt() ?? 0,
      lowReadinessCount: (json['low_readiness_count'] as num?)?.toInt() ?? 0,
      criticalReadinessCount:
          (json['critical_readiness_count'] as num?)?.toInt() ?? 0,
      studentsNeedingDeload: (json['students_needing_deload'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      studentsSummary: (json['students_summary'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trainer_id': trainerId,
      'total_students': totalStudents,
      'high_readiness_count': highReadinessCount,
      'moderate_readiness_count': moderateReadinessCount,
      'low_readiness_count': lowReadinessCount,
      'critical_readiness_count': criticalReadinessCount,
      'students_needing_deload': studentsNeedingDeload,
      'students_summary': studentsSummary,
    };
  }
}
