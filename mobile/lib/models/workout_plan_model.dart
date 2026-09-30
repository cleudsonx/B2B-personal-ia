import 'split_model.dart';

class WorkoutPlanModel {
  final String workoutPlanTitle;
  final String notesForTrainer;
  final List<SplitModel> splits;

  const WorkoutPlanModel({
    required this.workoutPlanTitle,
    required this.notesForTrainer,
    required this.splits,
  });

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    var rawSplits = json['splits'] as List<dynamic>? ?? [];
    List<SplitModel> parsedSplits = rawSplits
        .map((s) => SplitModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return WorkoutPlanModel(
      workoutPlanTitle: json['workout_plan_title'] as String? ?? 'Periodização',
      notesForTrainer: json['notes_for_trainer'] as String? ?? '',
      splits: parsedSplits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workout_plan_title': workoutPlanTitle,
      'notes_for_trainer': notesForTrainer,
      'splits': splits.map((s) => s.toJson()).toList(),
    };
  }

  WorkoutPlanModel copyWith({
    String? workoutPlanTitle,
    String? notesForTrainer,
    List<SplitModel>? splits,
  }) {
    return WorkoutPlanModel(
      workoutPlanTitle: workoutPlanTitle ?? this.workoutPlanTitle,
      notesForTrainer: notesForTrainer ?? this.notesForTrainer,
      splits: splits ?? this.splits,
    );
  }
}
