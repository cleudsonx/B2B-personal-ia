/// Modelos para o Cockpit Operacional do Treinador Zen & Radar Proativo de Evasão (UX B2B).
library;

class InactiveStudentCard {
  final String id;
  final String fullName;
  final String phone;
  final int daysInactive;
  final int streakDays;
  final String? lastContactedAt;
  final bool recentlyContacted48h;
  final String suggestedWhatsappMessage;
  final String? contactWhatsappUrl;

  const InactiveStudentCard({
    required this.id,
    required this.fullName,
    this.phone = '',
    required this.daysInactive,
    this.streakDays = 0,
    this.lastContactedAt,
    this.recentlyContacted48h = false,
    this.suggestedWhatsappMessage = '',
    this.contactWhatsappUrl,
  });

  factory InactiveStudentCard.fromJson(Map<String, dynamic> json) {
    return InactiveStudentCard(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Aluno',
      phone: json['phone'] as String? ?? '',
      daysInactive: (json['days_inactive'] as num?)?.toInt() ?? 4,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      lastContactedAt: json['last_contacted_at'] as String?,
      recentlyContacted48h: json['recently_contacted_48h'] as bool? ?? false,
      suggestedWhatsappMessage:
          json['suggested_whatsapp_message'] as String? ?? '',
      contactWhatsappUrl: json['contact_whatsapp_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'days_inactive': daysInactive,
        'streak_days': streakDays,
        'last_contacted_at': lastContactedAt,
        'recently_contacted_48h': recentlyContacted48h,
        'suggested_whatsapp_message': suggestedWhatsappMessage,
        'contact_whatsapp_url': contactWhatsappUrl,
      };

  InactiveStudentCard copyWith({
    bool? recentlyContacted48h,
    String? lastContactedAt,
  }) {
    return InactiveStudentCard(
      id: id,
      fullName: fullName,
      phone: phone,
      daysInactive: daysInactive,
      streakDays: streakDays,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      recentlyContacted48h: recentlyContacted48h ?? this.recentlyContacted48h,
      suggestedWhatsappMessage: suggestedWhatsappMessage,
      contactWhatsappUrl: contactWhatsappUrl,
    );
  }
}

class OperationalPainAlertItem {
  final String id;
  final String studentId;
  final String studentName;
  final String originalExercise;
  final String adaptedExercise;
  final String? painLocation;
  final String severity;
  final String createdAt;

  const OperationalPainAlertItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.originalExercise,
    required this.adaptedExercise,
    this.painLocation,
    this.severity = 'Moderada',
    required this.createdAt,
  });

  factory OperationalPainAlertItem.fromJson(Map<String, dynamic> json) {
    return OperationalPainAlertItem(
      id: json['id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? 'Aluno',
      originalExercise: json['original_exercise'] as String? ?? '',
      adaptedExercise: json['adapted_exercise'] as String? ?? '',
      painLocation: json['pain_location'] as String?,
      severity: json['severity'] as String? ?? 'Moderada',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'student_name': studentName,
        'original_exercise': originalExercise,
        'adapted_exercise': adaptedExercise,
        'pain_location': painLocation,
        'severity': severity,
        'created_at': createdAt,
      };
}

class TrainerOperationalCockpitData {
  final int sessionsCompleted24h;
  final int exercisesCompleted24h;
  final int estimatedSets24h;
  final int pendingPainAlertsCount;
  final List<OperationalPainAlertItem> recentPainAlerts;
  final int inactiveStudentsCount;
  final List<InactiveStudentCard> inactiveStudents;
  final int totalStudents;
  final int activeStudentsThisWeek;
  final int retentionRate;

  const TrainerOperationalCockpitData({
    required this.sessionsCompleted24h,
    required this.exercisesCompleted24h,
    required this.estimatedSets24h,
    required this.pendingPainAlertsCount,
    this.recentPainAlerts = const [],
    required this.inactiveStudentsCount,
    this.inactiveStudents = const [],
    required this.totalStudents,
    required this.activeStudentsThisWeek,
    required this.retentionRate,
  });

  factory TrainerOperationalCockpitData.fromJson(Map<String, dynamic> json) {
    final rawPainAlerts = json['recent_pain_alerts'] as List<dynamic>? ?? [];
    final rawInactive = json['inactive_students'] as List<dynamic>? ?? [];

    return TrainerOperationalCockpitData(
      sessionsCompleted24h:
          (json['sessions_completed_24h'] as num?)?.toInt() ?? 0,
      exercisesCompleted24h:
          (json['exercises_completed_24h'] as num?)?.toInt() ?? 0,
      estimatedSets24h: (json['estimated_sets_24h'] as num?)?.toInt() ?? 0,
      pendingPainAlertsCount:
          (json['pending_pain_alerts_count'] as num?)?.toInt() ?? 0,
      recentPainAlerts: rawPainAlerts
          .map((item) => OperationalPainAlertItem.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      inactiveStudentsCount:
          (json['inactive_students_count'] as num?)?.toInt() ?? 0,
      inactiveStudents: rawInactive
          .map((item) => InactiveStudentCard.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      activeStudentsThisWeek:
          (json['active_students_this_week'] as num?)?.toInt() ?? 0,
      retentionRate: (json['retention_rate'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessions_completed_24h': sessionsCompleted24h,
        'exercises_completed_24h': exercisesCompleted24h,
        'estimated_sets_24h': estimatedSets24h,
        'pending_pain_alerts_count': pendingPainAlertsCount,
        'recent_pain_alerts':
            recentPainAlerts.map((a) => a.toJson()).toList(),
        'inactive_students_count': inactiveStudentsCount,
        'inactive_students':
            inactiveStudents.map((s) => s.toJson()).toList(),
        'total_students': totalStudents,
        'active_students_this_week': activeStudentsThisWeek,
        'retention_rate': retentionRate,
      };

  TrainerOperationalCockpitData copyWith({
    int? sessionsCompleted24h,
    int? exercisesCompleted24h,
    int? estimatedSets24h,
    int? pendingPainAlertsCount,
    List<OperationalPainAlertItem>? recentPainAlerts,
    int? inactiveStudentsCount,
    List<InactiveStudentCard>? inactiveStudents,
    int? totalStudents,
    int? activeStudentsThisWeek,
    int? retentionRate,
  }) {
    return TrainerOperationalCockpitData(
      sessionsCompleted24h: sessionsCompleted24h ?? this.sessionsCompleted24h,
      exercisesCompleted24h:
          exercisesCompleted24h ?? this.exercisesCompleted24h,
      estimatedSets24h: estimatedSets24h ?? this.estimatedSets24h,
      pendingPainAlertsCount:
          pendingPainAlertsCount ?? this.pendingPainAlertsCount,
      recentPainAlerts: recentPainAlerts ?? this.recentPainAlerts,
      inactiveStudentsCount:
          inactiveStudentsCount ?? this.inactiveStudentsCount,
      inactiveStudents: inactiveStudents ?? this.inactiveStudents,
      totalStudents: totalStudents ?? this.totalStudents,
      activeStudentsThisWeek:
          activeStudentsThisWeek ?? this.activeStudentsThisWeek,
      retentionRate: retentionRate ?? this.retentionRate,
    );
  }
}
