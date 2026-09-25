class AdaptationModel {
  final String originalExercise;
  final String adaptedExercise;
  final String reason;
  final int sets;
  final String reps;
  final int restSeconds;
  final String notes;
  final String biomechanicalRationale;

  const AdaptationModel({
    required this.originalExercise,
    required this.adaptedExercise,
    required this.reason,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.notes,
    required this.biomechanicalRationale,
  });

  factory AdaptationModel.fromJson(Map<String, dynamic> json) {
    return AdaptationModel(
      originalExercise: json['original_exercise'] as String? ?? '',
      adaptedExercise: json['adapted_exercise'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      sets: json['sets'] as int? ?? 3,
      reps: json['reps'] as String? ?? '10-12',
      restSeconds: json['rest_seconds'] as int? ?? 60,
      notes: json['notes'] as String? ?? '',
      biomechanicalRationale: json['biomechanical_rationale'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original_exercise': originalExercise,
      'adapted_exercise': adaptedExercise,
      'reason': reason,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      'notes': notes,
      'biomechanical_rationale': biomechanicalRationale,
    };
  }
}
