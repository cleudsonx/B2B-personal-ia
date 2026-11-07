class ClinicalJointRestriction {
  final String joint; // shoulder, lumbar_spine, knee, cervical_spine, hip, wrist_elbow, ankle
  final String severity; // mild, moderate, severe
  final List<String> conditions;
  final List<String> avoidVectors;
  final String? notes;

  const ClinicalJointRestriction({
    required this.joint,
    this.severity = 'moderate',
    this.conditions = const [],
    this.avoidVectors = const [],
    this.notes,
  });

  factory ClinicalJointRestriction.fromJson(Map<String, dynamic> json) {
    return ClinicalJointRestriction(
      joint: json['joint'] as String? ?? 'shoulder',
      severity: json['severity'] as String? ?? 'moderate',
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      avoidVectors: (json['avoid_vectors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'joint': joint,
      'severity': severity,
      'conditions': conditions,
      'avoid_vectors': avoidVectors,
      if (notes != null) 'notes': notes,
    };
  }

  String get jointLabel {
    switch (joint) {
      case 'shoulder':
        return 'Ombro';
      case 'lumbar_spine':
        return 'Coluna Lombar';
      case 'knee':
        return 'Joelho';
      case 'cervical_spine':
        return 'Cervical';
      case 'hip':
        return 'Quadril';
      case 'wrist_elbow':
        return 'Punho / Cotovelo';
      case 'ankle':
        return 'Tornozelo';
      default:
        return joint.replaceAll('_', ' ');
    }
  }

  String get severityLabel {
    switch (severity) {
      case 'mild':
        return 'Leve';
      case 'severe':
        return 'Grave';
      case 'moderate':
      default:
        return 'Moderada';
    }
  }
}

class StudentClinicalProfileModel {
  final String studentId;
  final List<ClinicalJointRestriction> restrictions;
  final String? generalClinicalNotes;
  final String riskLevel;
  final String? lastAssessmentDate;
  final String? updatedAt;

  const StudentClinicalProfileModel({
    required this.studentId,
    this.restrictions = const [],
    this.generalClinicalNotes,
    this.riskLevel = 'low',
    this.lastAssessmentDate,
    this.updatedAt,
  });

  factory StudentClinicalProfileModel.fromJson(Map<String, dynamic> json) {
    final list = json['restrictions'] as List<dynamic>? ?? [];
    return StudentClinicalProfileModel(
      studentId: json['student_id'] as String? ?? '',
      restrictions: list
          .map((e) => ClinicalJointRestriction.fromJson(e as Map<String, dynamic>))
          .toList(),
      generalClinicalNotes: json['general_clinical_notes'] as String?,
      riskLevel: json['risk_level'] as String? ?? 'low',
      lastAssessmentDate: json['last_assessment_date'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'restrictions': restrictions.map((r) => r.toJson()).toList(),
      if (generalClinicalNotes != null) 'general_clinical_notes': generalClinicalNotes,
      'risk_level': riskLevel,
      if (lastAssessmentDate != null) 'last_assessment_date': lastAssessmentDate,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  bool get hasRestrictions => restrictions.isNotEmpty;
}

class ContraindicatedExerciseModel {
  final String exerciseName;
  final String joint;
  final String severity;
  final String reason;
  final String avoidVector;
  final String safeSubstitute;

  const ContraindicatedExerciseModel({
    required this.exerciseName,
    required this.joint,
    required this.severity,
    required this.reason,
    required this.avoidVector,
    required this.safeSubstitute,
  });

  factory ContraindicatedExerciseModel.fromJson(Map<String, dynamic> json) {
    return ContraindicatedExerciseModel(
      exerciseName: json['exercise_name'] as String? ?? '',
      joint: json['joint'] as String? ?? '',
      severity: json['severity'] as String? ?? 'moderate',
      reason: json['reason'] as String? ?? '',
      avoidVector: json['avoid_vector'] as String? ?? '',
      safeSubstitute: json['safe_substitute'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_name': exerciseName,
      'joint': joint,
      'severity': severity,
      'reason': reason,
      'avoid_vector': avoidVector,
      'safe_substitute': safeSubstitute,
    };
  }
}

class BiomechanicalSafetyReportModel {
  final bool isSafe;
  final String overallRisk; // safe, warning, critical_danger
  final int totalExercisesChecked;
  final int contraindicationsCount;
  final List<ContraindicatedExerciseModel> dangerousExercises;
  final String protectiveRecommendation;
  final Map<String, dynamic>? adaptedPlan;

  const BiomechanicalSafetyReportModel({
    required this.isSafe,
    this.overallRisk = 'safe',
    this.totalExercisesChecked = 0,
    this.contraindicationsCount = 0,
    this.dangerousExercises = const [],
    required this.protectiveRecommendation,
    this.adaptedPlan,
  });

  factory BiomechanicalSafetyReportModel.fromJson(Map<String, dynamic> json) {
    final list = json['dangerous_exercises'] as List<dynamic>? ?? [];
    return BiomechanicalSafetyReportModel(
      isSafe: json['is_safe'] as bool? ?? true,
      overallRisk: json['overall_risk'] as String? ?? 'safe',
      totalExercisesChecked: json['total_exercises_checked'] as int? ?? 0,
      contraindicationsCount: json['contraindications_count'] as int? ?? 0,
      dangerousExercises: list
          .map((e) => ContraindicatedExerciseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      protectiveRecommendation: json['protective_recommendation'] as String? ?? '',
      adaptedPlan: json['adapted_plan'] as Map<String, dynamic>?,
    );
  }
}
