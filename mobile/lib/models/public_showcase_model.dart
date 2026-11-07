class PublicTrainerProfile {
  final String id;
  final String fullName;
  final String? bio;
  final List<String> specialties;
  final String? publicWhatsapp;
  final String? photoUrl;
  final String? username;
  final String? cref;
  final bool acceptsNewStudents;
  final String? cityState;
  final double? startingPrice;
  final int studentsCount;
  final double ratingAvg;
  final int ratingCount;
  final String activeStudentsRange;
  final bool crefVerified;
  final List<String> showcaseBadges;
  final int transformationStoriesCount;

  const PublicTrainerProfile({
    required this.id,
    required this.fullName,
    this.bio,
    this.specialties = const [],
    this.publicWhatsapp,
    this.photoUrl,
    this.username,
    this.cref,
    this.acceptsNewStudents = true,
    this.cityState,
    this.startingPrice,
    this.studentsCount = 24,
    this.ratingAvg = 4.9,
    this.ratingCount = 24,
    this.activeStudentsRange = '15-30 alunos ativos',
    this.crefVerified = true,
    this.showcaseBadges = const [
      'CREF Verificado',
      'Metodologia Individualizada',
      'Atendimento WhatsApp',
      'Suporte Contínuo',
    ],
    this.transformationStoriesCount = 12,
  });

  factory PublicTrainerProfile.fromJson(Map<String, dynamic> json) {
    final rawSpecialties = json['specialties'];
    final List<String> parsedSpecialties = rawSpecialties is List
        ? rawSpecialties.map((e) => e.toString()).toList()
        : const [];

    final rawBadges = json['showcase_badges'];
    final List<String> parsedBadges = rawBadges is List
        ? rawBadges.map((e) => e.toString()).toList()
        : const [
            'CREF Verificado',
            'Metodologia Individualizada',
            'Atendimento WhatsApp',
            'Suporte Contínuo',
          ];

    return PublicTrainerProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 'Treinador Oficial',
      bio: json['bio']?.toString(),
      specialties: parsedSpecialties,
      publicWhatsapp: json['public_whatsapp']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      username: json['username']?.toString(),
      cref: json['cref']?.toString(),
      acceptsNewStudents: json['accepts_new_students'] as bool? ?? true,
      cityState: json['city_state']?.toString(),
      startingPrice: (json['starting_price'] as num?)?.toDouble(),
      studentsCount: (json['students_count'] as num?)?.toInt() ?? 24,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          4.9,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 24,
      activeStudentsRange: json['active_students_range']?.toString() ?? '15-30 alunos ativos',
      crefVerified: json['cref_verified'] as bool? ?? (json['cref'] != null && json['cref'].toString().isNotEmpty),
      showcaseBadges: parsedBadges,
      transformationStoriesCount: (json['transformation_stories_count'] as num?)?.toInt() ?? 12,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'bio': bio,
      'specialties': specialties,
      'public_whatsapp': publicWhatsapp,
      'photo_url': photoUrl,
      'username': username,
      'cref': cref,
      'accepts_new_students': acceptsNewStudents,
      'city_state': cityState,
      'starting_price': startingPrice,
      'students_count': studentsCount,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'active_students_range': activeStudentsRange,
      'cref_verified': crefVerified,
      'showcase_badges': showcaseBadges,
      'transformation_stories_count': transformationStoriesCount,
    };
  }
}

class LeadScreeningRequest {
  final String leadName;
  final String leadPhone;
  final String goal;
  final List<String> jointPains;
  final int trainingFrequencyWeekly;
  final String currentActivityLevel;
  final String? notes;

  const LeadScreeningRequest({
    required this.leadName,
    required this.leadPhone,
    required this.goal,
    this.jointPains = const [],
    this.trainingFrequencyWeekly = 3,
    this.currentActivityLevel = 'iniciante',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'lead_name': leadName,
      'lead_phone': leadPhone,
      'goal': goal,
      'joint_pains': jointPains,
      'training_frequency_weekly': trainingFrequencyWeekly,
      'current_activity_level': currentActivityLevel,
      if (notes != null) 'notes': notes,
    };
  }
}

class LeadScreeningResponse {
  final String leadId;
  final String trainerId;
  final String trainerName;
  final String? trainerWhatsapp;
  final String biomechanicalInsight;
  final String whatsappDirectUrl;
  final String createdAt;
  final String status;

  const LeadScreeningResponse({
    required this.leadId,
    required this.trainerId,
    required this.trainerName,
    this.trainerWhatsapp,
    required this.biomechanicalInsight,
    required this.whatsappDirectUrl,
    required this.createdAt,
    this.status = 'registered',
  });

  factory LeadScreeningResponse.fromJson(Map<String, dynamic> json) {
    return LeadScreeningResponse(
      leadId: json['lead_id']?.toString() ?? '',
      trainerId: json['trainer_id']?.toString() ?? '',
      trainerName: json['trainer_name']?.toString() ?? '',
      trainerWhatsapp: json['trainer_whatsapp']?.toString(),
      biomechanicalInsight: json['biomechanical_insight']?.toString() ?? '',
      whatsappDirectUrl: json['whatsapp_direct_url']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      status: json['status']?.toString() ?? 'registered',
    );
  }
}
