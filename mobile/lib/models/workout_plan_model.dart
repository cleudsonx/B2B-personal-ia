import 'split_model.dart';

class WorkoutPlanModel {
  final String? id;
  final String workoutPlanTitle;
  final String notesForTrainer;
  final List<SplitModel> splits;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkoutPlanModel({
    this.id,
    required this.workoutPlanTitle,
    required this.notesForTrainer,
    required this.splits,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    var rawSplits = json['splits'] as List<dynamic>? ?? [];
    List<SplitModel> parsedSplits =
        rawSplits
            .map((s) => SplitModel.fromJson(s as Map<String, dynamic>))
            .toList();

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return WorkoutPlanModel(
      id: json['id'] as String?,
      workoutPlanTitle: json['workout_plan_title'] as String? ?? 'Periodização',
      notesForTrainer: json['notes_for_trainer'] as String? ?? '',
      splits: parsedSplits,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'workout_plan_title': workoutPlanTitle,
      'notes_for_trainer': notesForTrainer,
      'splits': splits.map((s) => s.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  WorkoutPlanModel copyWith({
    String? id,
    String? workoutPlanTitle,
    String? notesForTrainer,
    List<SplitModel>? splits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutPlanModel(
      id: id ?? this.id,
      workoutPlanTitle: workoutPlanTitle ?? this.workoutPlanTitle,
      notesForTrainer: notesForTrainer ?? this.notesForTrainer,
      splits: splits ?? this.splits,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
