class ExerciseModel {
  final int order;
  final String name;
  final String targetMuscleGroup;
  final int sets;
  final String reps;
  final int restSeconds;
  final String notes;
  final String substitutionVector;

  const ExerciseModel({
    required this.order,
    required this.name,
    required this.targetMuscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.notes,
    required this.substitutionVector,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      order: json['order'] as int? ?? 1,
      name: json['name'] as String? ?? 'Exercício',
      targetMuscleGroup: json['target_muscle_group'] as String? ?? '',
      sets: json['sets'] as int? ?? 3,
      reps: json['reps'] as String? ?? '10-12',
      restSeconds: json['rest_seconds'] as int? ?? 60,
      notes: json['notes'] as String? ?? '',
      substitutionVector: json['substitution_vector'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'name': name,
      'target_muscle_group': targetMuscleGroup,
      'sets': sets,
      'reps': reps,
      'rest_seconds': restSeconds,
      'notes': notes,
      'substitution_vector': substitutionVector,
    };
  }

  ExerciseModel copyWith({
    int? order,
    String? name,
    String? targetMuscleGroup,
    int? sets,
    String? reps,
    int? restSeconds,
    String? notes,
    String? substitutionVector,
  }) {
    return ExerciseModel(
      order: order ?? this.order,
      name: name ?? this.name,
      targetMuscleGroup: targetMuscleGroup ?? this.targetMuscleGroup,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      substitutionVector: substitutionVector ?? this.substitutionVector,
    );
  }
}
