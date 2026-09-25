import 'exercise_model.dart';

class SplitModel {
  final String splitIdentifier;
  final String splitName;
  final int estimatedDurationMin;
  final List<ExerciseModel> exercises;

  const SplitModel({
    required this.splitIdentifier,
    required this.splitName,
    required this.estimatedDurationMin,
    required this.exercises,
  });

  factory SplitModel.fromJson(Map<String, dynamic> json) {
    var rawExercises = json['exercises'] as List<dynamic>? ?? [];
    List<ExerciseModel> parsedExercises = rawExercises
        .map((e) => ExerciseModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return SplitModel(
      splitIdentifier: json['split_identifier'] as String? ?? 'A',
      splitName: json['split_name'] as String? ?? 'Divisão de Treino',
      estimatedDurationMin: json['estimated_duration_min'] as int? ?? 50,
      exercises: parsedExercises,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'split_identifier': splitIdentifier,
      'split_name': splitName,
      'estimated_duration_min': estimatedDurationMin,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}
