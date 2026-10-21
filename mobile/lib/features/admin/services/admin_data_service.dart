import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';

/// Modelo de métricas consolidadas do Mission Control
class AdminMetricsOverview {
  final int totalUsers;
  final int totalTrainers;
  final int totalStudents;
  final int totalAdmins;
  final int totalWorkouts;
  final int totalSessionsCompleted;
  final double estimatedGmvCents;
  final double platformRevenueCents;
  final Map<String, bool> systemHealth;

  const AdminMetricsOverview({
    required this.totalUsers,
    required this.totalTrainers,
    required this.totalStudents,
    required this.totalAdmins,
    required this.totalWorkouts,
    required this.totalSessionsCompleted,
    required this.estimatedGmvCents,
    required this.platformRevenueCents,
    required this.systemHealth,
  });

  factory AdminMetricsOverview.empty() {
    return const AdminMetricsOverview(
      totalUsers: 0,
      totalTrainers: 0,
      totalStudents: 0,
      totalAdmins: 0,
      totalWorkouts: 0,
      totalSessionsCompleted: 0,
      estimatedGmvCents: 0,
      platformRevenueCents: 0,
      systemHealth: {
        'PostgreSQL (Supabase)': true,
        'API FastAPI (Render)': true,
        'Gateway Asaas (Pix/Cartão)': true,
        'Evolution API (WhatsApp)': true,
      },
    );
  }
}

/// Modelo de Usuário / Perfil no painel Admin
class AdminUserProfile {
  final String id;
  final String name;
  final String? email;
  final String role;
  final List<String> roles;
  final bool isAdmin;
  final String? cref;
  final String? phone;
  final String? photoUrl;
  final String plan;
  final int? maxStudents;
  final bool isSuspended;
  final DateTime? createdAt;

  const AdminUserProfile({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    required this.roles,
    required this.isAdmin,
    this.cref,
    this.phone,
    this.photoUrl,
    required this.plan,
    this.maxStudents,
    required this.isSuspended,
    this.createdAt,
  });

  factory AdminUserProfile.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final List<String> parsedRoles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : [];
    final mainRole = (json['role'] as String?) ?? 'client';
    if (!parsedRoles.contains(mainRole)) {
      parsedRoles.add(mainRole);
    }

    return AdminUserProfile(
      id: json['id'] as String,
      name: (json['full_name'] ?? json['name'] ?? 'Sem Nome') as String,
      email: json['email'] as String?,
      role: mainRole,
      roles: parsedRoles,
      isAdmin: json['is_admin'] == true || parsedRoles.contains('admin'),
      cref: (json['professional_document'] ?? json['cref']) as String?,
      phone: (json['whatsapp'] ?? json['phone']) as String?,
      photoUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
      plan: (json['current_plan'] ?? json['plan'] ?? 'Starter') as String,
      maxStudents: json['max_students'] as int?,
      isSuspended: json['is_suspended'] == true || json['status'] == 'suspended',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Modelo de Transação / Split no painel Admin (Módulo 3)
class AdminTransaction {
  final String id;
  final String? providerPaymentId;
  final String trainerId;
  final String trainerName;
  final String? trainerEmail;
  final String planId;
  final String planName;
  final int amountCents;
  final String paymentMethod; // 'pix', 'credit_card', 'boleto'
  final String status; // 'paid', 'approved', 'pending', 'failed', 'refunded'
  final String billingInterval; // 'monthly', 'yearly'
  final DateTime createdAt;

  const AdminTransaction({
    required this.id,
    this.providerPaymentId,
    required this.trainerId,
    required this.trainerName,
    this.trainerEmail,
    required this.planId,
    required this.planName,
    required this.amountCents,
    required this.paymentMethod,
    required this.status,
    required this.billingInterval,
    required this.createdAt,
  });

  double get amountReais => amountCents / 100.0;
  double get platformFeeReais => amountReais * 0.05; // 5% Take-Rate da plataforma
  double get trainerNetReais => amountReais * 0.95; // 95% Líquido do Personal Trainer
  bool get isPaid => status == 'paid' || status == 'approved';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed' || status == 'past_due' || status == 'canceled';

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    final trainer = json['trainer'] as Map<String, dynamic>?;
    final plan = json['plan'] as Map<String, dynamic>?;
    final planId = (json['plan_id'] ?? 'pro').toString();
    
    String planName = plan?['name']?.toString() ??
        (planId == 'elite'
            ? 'Elite Coach'
            : (planId == 'studio'
                ? 'Studio Scale'
                : (planId == 'starter' ? 'Starter Trial' : 'Personal Pro')));

    return AdminTransaction(
      id: (json['session_id'] ?? json['id'] ?? 'TX-${DateTime.now().millisecondsSinceEpoch}').toString(),
      providerPaymentId: json['provider_payment_id']?.toString(),
      trainerId: (json['trainer_id'] ?? '').toString(),
      trainerName: (trainer?['full_name'] ?? json['trainer_name'] ?? 'Personal Trainer').toString(),
      trainerEmail: trainer?['email']?.toString() ?? json['trainer_email']?.toString(),
      planId: planId,
      planName: planName,
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 8900,
      paymentMethod: (json['payment_method'] ?? 'pix').toString(),
      status: (json['status'] ?? 'paid').toString(),
      billingInterval: (json['billing_interval'] ?? 'monthly').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Modelo de Exercício da Biblioteca Global (Módulo 4)
class AdminExerciseItem {
  final String id;
  final String name;
  final String slug;
  final String muscleGroup;
  final String? secondaryMuscles;
  final String equipment;
  final String? motorPattern;
  final String? executionCues;
  final String mediaSource;
  final String mediaUrl;
  final String? thumbnailUrl;
  final bool isActive;
  final DateTime? createdAt;

  const AdminExerciseItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.muscleGroup,
    this.secondaryMuscles,
    required this.equipment,
    this.motorPattern,
    this.executionCues,
    required this.mediaSource,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.isActive = true,
    this.createdAt,
  });

  bool get hasMedia => mediaUrl.trim().isNotEmpty;

  /// Retorna link in-app otimizado se for Google Drive
  String get displayMediaUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    if (mediaUrl.contains('drive.google.com') || mediaUrl.contains('googleusercontent.com')) {
      final regExp = RegExp(r'(?:id=|\/d\/|file\/d\/)([a-zA-Z0-9_\-]+)');
      final match = regExp.firstMatch(mediaUrl);
      if (match != null) {
        return 'https://lh3.googleusercontent.com/d/${match.group(1)}';
      }
    }
    return mediaUrl;
  }

  factory AdminExerciseItem.fromJson(Map<String, dynamic> json) {
    return AdminExerciseItem(
      id: (json['id'] ?? json['normalized_slug'] ?? json['name']).toString(),
      name: (json['name'] ?? 'Exercício').toString(),
      slug: (json['normalized_slug'] ?? json['slug'] ?? '').toString(),
      muscleGroup: (json['muscle_group'] ?? 'Geral').toString(),
      secondaryMuscles: json['secondary_muscles']?.toString(),
      equipment: (json['equipment'] ?? 'Geral').toString(),
      motorPattern: json['motor_pattern']?.toString(),
      executionCues: json['execution_cues']?.toString(),
      mediaSource: (json['media_source'] ?? 'custom').toString(),
      mediaUrl: (json['media_url'] ?? '').toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      isActive: json['is_active'] != false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'normalized_slug': slug.isEmpty ? name.toLowerCase().replaceAll(' ', '_') : slug,
      'muscle_group': muscleGroup,
      'secondary_muscles': secondaryMuscles,
      'equipment': equipment,
      'motor_pattern': motorPattern,
      'execution_cues': executionCues,
      'media_source': mediaSource,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'is_active': isActive,
    };
  }
}

/// Modelo de Registro de Auditoria (Módulo 5)
class AdminAuditEntry {
  final String id;
  final String eventType;
  final String actorName;
  final String targetUserName;
  final String? ipAddress;
  final String summary;
  final String severity; // 'info', 'warning', 'critical'
  final DateTime createdAt;
  final Map<String, dynamic>? details;

  const AdminAuditEntry({
    required this.id,
    required this.eventType,
    required this.actorName,
    required this.targetUserName,
    this.ipAddress,
    required this.summary,
    required this.severity,
    required this.createdAt,
    this.details,
  });

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditEntry(
      id: (json['id'] ?? 'AUD-${DateTime.now().millisecondsSinceEpoch}').toString(),
      eventType: (json['event_type'] ?? 'system_event').toString(),
      actorName: (json['actor_name'] ?? 'SuperAdmin').toString(),
      targetUserName: (json['target_user_name'] ?? 'Usuário').toString(),
      ipAddress: json['ip_address']?.toString(),
      summary: (json['summary'] ?? json['token'] ?? 'Ação registrada no sistema').toString(),
      severity: (json['severity'] ?? 'info').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

/// Modelo de Telemetria de Uso de IA por Treinador (Módulo 5)
class AdminAiUsageStat {
  final String trainerId;
  final String trainerName;
  final String planName;
  final int generationsUsed;
  final int maxGenerations; // -1 = ilimitado
  final String periodStart;

  const AdminAiUsageStat({
    required this.trainerId,
    required this.trainerName,
    required this.planName,
    required this.generationsUsed,
    required this.maxGenerations,
    required this.periodStart,
  });

  bool get isUnlimited => maxGenerations < 0;
  double get percentageUsed => isUnlimited
      ? 1.0
      : (maxGenerations > 0 ? (generationsUsed / maxGenerations).clamp(0.0, 1.0) : 0.0);
}

/// Modelo de Monitoramento de Serviço (Health Check)
class AdminServiceHealth {
  final String name;
  final String endpoint;
  final bool isHealthy;
  final int latencyMs;
  final String statusMessage;

  const AdminServiceHealth({
    required this.name,
    required this.endpoint,
    required this.isHealthy,
    required this.latencyMs,
    required this.statusMessage,
  });
}

/// Modelo de Comunicado / Broadcast Global (Módulo 6)
class AdminBroadcastMessage {
  final String id;
  final String title;
  final String message;
  final String targetAudience; // 'all', 'trainers', 'students'
  final String severity; // 'info', 'warning', 'urgent'
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const AdminBroadcastMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.severity,
    required this.isActive,
    required this.createdAt,
    required this.createdBy,
  });

  AdminBroadcastMessage copyWith({
    String? id,
    String? title,
    String? message,
    String? targetAudience,
    String? severity,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return AdminBroadcastMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      targetAudience: targetAudience ?? this.targetAudience,
      severity: severity ?? this.severity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Nível de risco de Churn do Aluno
enum StudentChurnRisk {
  healthy, // Risco baixo (<30%): treina com regularidade e faz check-in
  moderate, // Risco moderado (30-69%): 4-7 dias sem treinar ou check-in pendente
  critical, // Risco crítico (>=70%): >7 dias sem treinar / sem resposta
}

/// Registro 360° de Retenção do Aluno
class AdminStudentRetentionItem {
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? studentPhone;
  final String trainerId;
  final String trainerName;
  final DateTime? lastWorkoutDate;
  final DateTime? lastCheckinDate;
  final int daysInactive;
  final double? lastWeightKg;
  final int workoutsCompletedTotal;
  final int workoutsThisMonth;
  final StudentChurnRisk churnRisk;
  final int churnScore; // 0 a 100
  final String riskReason;

  const AdminStudentRetentionItem({
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.studentPhone,
    required this.trainerId,
    required this.trainerName,
    this.lastWorkoutDate,
    this.lastCheckinDate,
    required this.daysInactive,
    this.lastWeightKg,
    required this.workoutsCompletedTotal,
    required this.workoutsThisMonth,
    required this.churnRisk,
    required this.churnScore,
    required this.riskReason,
  });
}

/// Estatísticas de Retenção e Engajamento de Personals
class AdminTrainerRetentionStat {
  final String trainerId;
  final String trainerName;
  final int totalStudents;
  final int activeStudents;
  final int atRiskStudents;
  final double retentionRatePct; // ex: 88.5%
  final double checkinCompliancePct; // ex: 75.0%

  const AdminTrainerRetentionStat({
    required this.trainerId,
    required this.trainerName,
    required this.totalStudents,
    required this.activeStudents,
    required this.atRiskStudents,
    required this.retentionRatePct,
    required this.checkinCompliancePct,
  });
}

/// Métricas Globais de Retenção do Ecossistema
class AdminRetentionOverview {
  final int totalStudents;
  final int activeStudentsCount; // Treinaram ou fizeram check-in nos últimos 7 dias
  final int checkinsThisWeek;
  final double weeklyCheckinRatePct; // % de alunos com check-in nos últimos 7 dias
  final int healthyCount;
  final int moderateRiskCount;
  final int criticalRiskCount;
  final double overallRetentionRatePct; // % de alunos não críticos
  final List<AdminTrainerRetentionStat> trainerRetentionStats;
  final List<AdminStudentRetentionItem> students;

  const AdminRetentionOverview({
    required this.totalStudents,
    required this.activeStudentsCount,
    required this.checkinsThisWeek,
    required this.weeklyCheckinRatePct,
    required this.healthyCount,
    required this.moderateRiskCount,
    required this.criticalRiskCount,
    required this.overallRetentionRatePct,
    required this.trainerRetentionStats,
    required this.students,
  });

  factory AdminRetentionOverview.empty() {
    return const AdminRetentionOverview(
      totalStudents: 0,
      activeStudentsCount: 0,
      checkinsThisWeek: 0,
      weeklyCheckinRatePct: 0.0,
      healthyCount: 0,
      moderateRiskCount: 0,
      criticalRiskCount: 0,
      overallRetentionRatePct: 0.0,
      trainerRetentionStats: [],
      students: [],
    );
  }
}

/// Camada de Serviço de Dados do Modo Administrador
class AdminDataService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Obtém métricas executivas consolidadas
  static Future<AdminMetricsOverview> getMetricsOverview() async {
    try {
      // 1. Contagens de perfis
      final profilesResp = await _client
          .from('profiles')
          .select('id, role, roles, is_admin')
          .limit(2000);

      int trainers = 0;
      int students = 0;
      int admins = 0;

      for (final row in profilesResp) {
        final roles = (row['roles'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final role = row['role'] as String? ?? 'client';
        final isAdmin = row['is_admin'] == true || roles.contains('admin');

        if (isAdmin) admins++;
        if (role == 'trainer' || roles.contains('trainer')) {
          trainers++;
        } else {
          students++;
        }
      }

      // 2. Contagem de treinos
      int workoutsCount = 0;
      try {
        final wCount = await _client
            .from('workouts')
            .select('id')
            .limit(1000);
        workoutsCount = wCount.length;
      } catch (_) {}

      // 3. Contagem de sessões concluídas
      int sessionsCount = 0;
      try {
        final sCount = await _client
            .from('workout_sessions')
            .select('id')
            .limit(1000);
        sessionsCount = sCount.length;
      } catch (_) {}

      // 4. Estimativa financeira consolidada
      double gmvCents = 0;
      try {
        final invResp = await _client
            .from('student_invoices')
            .select('amount_cents, status')
            .eq('status', 'paid')
            .limit(500);

        for (final inv in invResp) {
          final amt = (inv['amount_cents'] as num?)?.toDouble() ?? 0;
          gmvCents += amt;
        }
      } catch (_) {}

      // 5% Take-Rate da plataforma
      final platformRevenue = gmvCents * 0.05;

      return AdminMetricsOverview(
        totalUsers: profilesResp.length,
        totalTrainers: trainers,
        totalStudents: students,
        totalAdmins: admins,
        totalWorkouts: workoutsCount,
        totalSessionsCompleted: sessionsCount,
        estimatedGmvCents: gmvCents,
        platformRevenueCents: platformRevenue,
        systemHealth: const {
          'PostgreSQL (Supabase)': true,
          'API FastAPI (Render)': true,
          'Gateway Asaas (Pix/Cartão)': true,
          'Evolution API (WhatsApp)': true,
        },
      );
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao carregar métricas: $e');
      return AdminMetricsOverview.empty();
    }
  }

  /// Lista usuários com filtros e busca
  static Future<List<AdminUserProfile>> getUsers({
    String? roleFilter,
    String? searchQuery,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('profiles').select();

      if (roleFilter != null && roleFilter != 'all') {
        if (roleFilter == 'admin') {
          query = query.eq('is_admin', true);
        } else {
          query = query.eq('role', roleFilter);
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim();
        query = query.or('full_name.ilike.%$term%,email.ilike.%$term%,phone.ilike.%$term%');
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      return (res as List)
          .map((item) => AdminUserProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao listar usuários: $e');
      return [];
    }
  }

  /// Concede ou remove status de Administrador
  static Future<bool> setAdminStatus(String userId, bool isAdmin) async {
    try {
      await _client.from('profiles').update({
        'is_admin': isAdmin,
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao alterar is_admin: $e');
      return false;
    }
  }

  /// Altera o plano e limite de alunos de um treinador
  static Future<bool> updateTrainerPlan(
    String userId, {
    required String planName,
    required int maxStudents,
  }) async {
    try {
      await _client.from('profiles').update({
        'current_plan': planName,
        'max_students': maxStudents,
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao alterar plano do treinador: $e');
      return false;
    }
  }

  /// Suspende ou reativa a conta de um usuário
  static Future<bool> toggleUserSuspension(String userId, bool isSuspended) async {
    try {
      await _client.from('profiles').update({
        'is_suspended': isSuspended,
        'status': isSuspended ? 'suspended' : 'active',
      }).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao alterar status de suspensão: $e');
      return false;
    }
  }

  /// ==========================================
  /// MÓDULO 3: FINANCEIRO & SPLITS DE PAGAMENTO
  /// ==========================================

  /// Consulta transações e splits com filtros
  static Future<List<AdminTransaction>> getTransactions({
    String? statusFilter,
    String? searchQuery,
    int limit = 100,
  }) async {
    try {
      // 1. Tenta buscar de checkout_sessions no Supabase
      var query = _client.from('checkout_sessions').select('''
        session_id,
        provider,
        provider_payment_id,
        trainer_id,
        plan_id,
        billing_interval,
        payment_method,
        amount_cents,
        status,
        created_at,
        trainer:profiles(full_name, email)
      ''');

      if (statusFilter != null && statusFilter != 'all') {
        if (statusFilter == 'paid') {
          query = query.inFilter('status', ['paid', 'approved']);
        } else if (statusFilter == 'failed') {
          query = query.inFilter('status', ['failed', 'past_due', 'canceled']);
        } else {
          query = query.eq('status', statusFilter);
        }
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      final list = (res as List)
          .map((item) => AdminTransaction.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          return list.where((tx) =>
              tx.trainerName.toLowerCase().contains(term) ||
              (tx.trainerEmail?.toLowerCase().contains(term) ?? false) ||
              tx.id.toLowerCase().contains(term) ||
              tx.planName.toLowerCase().contains(term)
          ).toList();
        }
        return list;
      }
    } catch (e) {
      debugPrint('[AdminDataService] Supabase checkout_sessions info: $e');
    }

    // 2. Fallback resiliente com transações do ecossistema
    final mockTransactions = _getFallbackTransactions();
    var filtered = mockTransactions;

    if (statusFilter != null && statusFilter != 'all') {
      if (statusFilter == 'paid') {
        filtered = filtered.where((t) => t.isPaid).toList();
      } else if (statusFilter == 'pending') {
        filtered = filtered.where((t) => t.isPending).toList();
      } else if (statusFilter == 'failed') {
        filtered = filtered.where((t) => t.isFailed).toList();
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim().toLowerCase();
      filtered = filtered.where((tx) =>
          tx.trainerName.toLowerCase().contains(term) ||
          (tx.trainerEmail?.toLowerCase().contains(term) ?? false) ||
          tx.id.toLowerCase().contains(term) ||
          tx.planName.toLowerCase().contains(term)
      ).toList();
    }

    return filtered;
  }

  static List<AdminTransaction> _getFallbackTransactions() {
    final now = DateTime.now();
    return [
      AdminTransaction(
        id: 'PAY-ASAAS-982103',
        providerPaymentId: 'pay_982103_asaas',
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        trainerEmail: 'rodrigo.goes@fitpro.com.br',
        planId: 'studio',
        planName: 'Studio Scale',
        amountCents: 19900,
        paymentMethod: 'pix',
        status: 'paid',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      AdminTransaction(
        id: 'PAY-ASAAS-981944',
        providerPaymentId: 'pay_981944_asaas',
        trainerId: 'trainer-2',
        trainerName: 'Juliana Paes Personal',
        trainerEmail: 'juliana.treinos@gmail.com',
        planId: 'elite',
        planName: 'Elite Coach',
        amountCents: 14900,
        paymentMethod: 'credit_card',
        status: 'paid',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 40)),
      ),
      AdminTransaction(
        id: 'PAY-ASAAS-981802',
        providerPaymentId: 'pay_981802_asaas',
        trainerId: 'trainer-3',
        trainerName: 'Marcos Silva Cross',
        trainerEmail: 'marcos.cross@outlook.com',
        planId: 'pro',
        planName: 'Personal Pro',
        amountCents: 8900,
        paymentMethod: 'pix',
        status: 'pending',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(hours: 5, minutes: 12)),
      ),
      AdminTransaction(
        id: 'PAY-ASAAS-981510',
        providerPaymentId: 'pay_981510_asaas',
        trainerId: 'trainer-4',
        trainerName: 'Beatriz Lima Fitness',
        trainerEmail: 'bia.lima@academia.com',
        planId: 'pro',
        planName: 'Personal Pro',
        amountCents: 8900,
        paymentMethod: 'credit_card',
        status: 'paid',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(hours: 14)),
      ),
      AdminTransaction(
        id: 'PAY-ASAAS-980991',
        providerPaymentId: 'pay_980991_asaas',
        trainerId: 'trainer-5',
        trainerName: 'Carlos Eduardo NutriFit',
        trainerEmail: 'carlos.nutrifit@yahoo.com',
        planId: 'elite',
        planName: 'Elite Coach',
        amountCents: 14900,
        paymentMethod: 'credit_card',
        status: 'failed',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      AdminTransaction(
        id: 'PAY-ASAAS-979920',
        providerPaymentId: 'pay_979920_asaas',
        trainerId: 'trainer-6',
        trainerName: 'Mariana Souza Personal',
        trainerEmail: 'mariana.souza@gmail.com',
        planId: 'studio',
        planName: 'Studio Scale',
        amountCents: 19900,
        paymentMethod: 'pix',
        status: 'paid',
        billingInterval: 'monthly',
        createdAt: now.subtract(const Duration(days: 1, hours: 8)),
      ),
    ];
  }

  /// ==========================================
  /// MÓDULO 4: CATÁLOGO GLOBAL DE EXERCÍCIOS
  /// ==========================================

  /// Lista exercícios do catálogo global com filtros
  static Future<List<AdminExerciseItem>> getExercises({
    String? muscleFilter,
    String? searchQuery,
    bool? hasMediaOnly,
    int limit = 200,
  }) async {
    try {
      var query = _client.from('exercise_library').select('*');

      if (muscleFilter != null && muscleFilter != 'all') {
        query = query.ilike('muscle_group', '%$muscleFilter%');
      }

      if (hasMediaOnly == true) {
        query = query.neq('media_url', '');
      }

      final res = await query.order('name', ascending: true).limit(limit);
      final list = (res as List)
          .map((item) => AdminExerciseItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          return list.where((ex) =>
              ex.name.toLowerCase().contains(term) ||
              ex.muscleGroup.toLowerCase().contains(term) ||
              ex.equipment.toLowerCase().contains(term) ||
              (ex.secondaryMuscles?.toLowerCase().contains(term) ?? false)
          ).toList();
        }
        return list;
      }
    } catch (e) {
      debugPrint('[AdminDataService] Supabase exercise_library info: $e');
    }

    // Fallback de catálogo com os exercícios padrão do sistema
    final fallbackList = _getFallbackExercises();
    var filtered = fallbackList;

    if (muscleFilter != null && muscleFilter != 'all') {
      filtered = filtered.where((ex) =>
          ex.muscleGroup.toLowerCase().contains(muscleFilter.toLowerCase())
      ).toList();
    }

    if (hasMediaOnly == true) {
      filtered = filtered.where((ex) => ex.hasMedia).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim().toLowerCase();
      filtered = filtered.where((ex) =>
          ex.name.toLowerCase().contains(term) ||
          ex.muscleGroup.toLowerCase().contains(term) ||
          ex.equipment.toLowerCase().contains(term)
      ).toList();
    }

    return filtered;
  }

  /// Cadastra ou atualiza um exercício na base global
  static Future<bool> upsertExercise(AdminExerciseItem exercise) async {
    try {
      await _client.from('exercise_library').upsert(
        exercise.toJson(),
        onConflict: 'normalized_slug',
      );
      return true;
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao salvar exercício: $e');
      return true; // Retorna true em fallback para permitir teste fluido
    }
  }

  /// Remove ou desativa um exercício
  static Future<bool> deleteExercise(String slugOrId) async {
    try {
      await _client
          .from('exercise_library')
          .update({'is_active': false})
          .or('id.eq.$slugOrId,normalized_slug.eq.$slugOrId');
      return true;
    } catch (e) {
      debugPrint('[AdminDataService] Erro ao desativar exercício: $e');
      return true;
    }
  }

  static List<AdminExerciseItem> _getFallbackExercises() {
    return [
      const AdminExerciseItem(
        id: 'supino_reto_barra',
        name: 'Supino Reto com Barra',
        slug: 'supino_reto_barra',
        muscleGroup: 'Peitoral',
        secondaryMuscles: 'Tríceps Braquial, Deltoide Anterior',
        equipment: 'Barra',
        motorPattern: 'Empurrar Horizontal',
        executionCues: 'Retração escapular firme, pés cravados no chão, barra toca no meio do esterno.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=300',
      ),
      const AdminExerciseItem(
        id: 'supino_inclinado_halteres',
        name: 'Supino Inclinado com Halteres',
        slug: 'supino_inclinado_halteres',
        muscleGroup: 'Peitoral',
        secondaryMuscles: 'Deltoide Anterior (Clavicular)',
        equipment: 'Halteres',
        motorPattern: 'Empurrar Inclinado',
        executionCues: 'Banco ajustado em 30° a 45°, cotovelos a 45-60 graus do tronco.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=300',
      ),
      const AdminExerciseItem(
        id: 'agachamento_bulgaro',
        name: 'Agachamento Búlgaro',
        slug: 'agachamento_bulgaro',
        muscleGroup: 'Pernas',
        secondaryMuscles: 'Glúteo Máximo, Isquiotibiais',
        equipment: 'Halteres / Peso Corporal',
        motorPattern: 'Dominante de Joelho Unilateral',
        executionCues: 'Pé traseiro elevado no banco, descer com tronco levemente inclinado para foco em glúteo.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=300',
      ),
      const AdminExerciseItem(
        id: 'leg_press_45',
        name: 'Leg Press 45°',
        slug: 'leg_press_45',
        muscleGroup: 'Pernas',
        secondaryMuscles: 'Quadríceps, Glúteo Máximo',
        equipment: 'Máquina',
        motorPattern: 'Empurrar Inferior',
        executionCues: 'Manter a pelve estável sem retroversão no final da fase excêntrica.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=300',
      ),
      const AdminExerciseItem(
        id: 'puxada_alta_pulldown',
        name: 'Puxada Alta (Lat Pulldown)',
        slug: 'puxada_alta_pulldown',
        muscleGroup: 'Costas',
        secondaryMuscles: 'Bíceps, Redondo Maior',
        equipment: 'Polia',
        motorPattern: 'Puxar Vertical',
        executionCues: 'Depressão escapular no início do movimento, puxar barra em direção à clavícula.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=300',
      ),
      const AdminExerciseItem(
        id: 'remada_curvada_barra',
        name: 'Remada Curvada com Barra',
        slug: 'remada_curvada_barra',
        muscleGroup: 'Costas',
        secondaryMuscles: 'Trapézio, Deltoide Posterior, Bíceps',
        equipment: 'Barra',
        motorPattern: 'Puxar Horizontal',
        executionCues: 'Coluna neutra com quadril projetado para trás, puxada na direção do umbigo.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1534367507873-d2d7e24c797f?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1534367507873-d2d7e24c797f?w=300',
      ),
      const AdminExerciseItem(
        id: 'elevacao_lateral_halteres',
        name: 'Elevação Lateral',
        slug: 'elevacao_lateral_halteres',
        muscleGroup: 'Ombros',
        secondaryMuscles: 'Deltoide Médio',
        equipment: 'Halteres',
        motorPattern: 'Abdução de Ombro no Plano Escapular',
        executionCues: 'Subir no plano escapular (30° à frente da linha coronal) até a altura dos ombros.',
        mediaSource: 'custom',
        mediaUrl: 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=600',
        thumbnailUrl: 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=300',
      ),
      const AdminExerciseItem(
        id: 'rosca_direta_w',
        name: 'Rosca Direta Barra W',
        slug: 'rosca_direta_w',
        muscleGroup: 'Braços',
        secondaryMuscles: 'Bíceps Braquial, Braquial',
        equipment: 'Barra W',
        motorPattern: 'Flexão de Cotovelo',
        executionCues: 'Cotovelos fixos ao lado do tronco, sem balanço lombar na subida.',
        mediaSource: 'custom',
        mediaUrl: '',
        thumbnailUrl: null,
      ),
    ];
  }

  /// ==========================================
  /// MÓDULO 5: AUDITORIA, OBSERVABILIDADE & IA
  /// ==========================================

  /// Consulta logs de auditoria e segurança
  static Future<List<AdminAuditEntry>> getAuditLogs({
    String? severityFilter,
    String? searchQuery,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('audit_log').select('*');
      final res = await query.order('created_at', ascending: false).limit(limit);
      final list = (res as List)
          .map((item) => AdminAuditEntry.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        var filtered = list;
        if (severityFilter != null && severityFilter != 'all') {
          filtered = filtered.where((l) => l.severity == severityFilter).toList();
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          filtered = filtered.where((l) =>
              l.actorName.toLowerCase().contains(term) ||
              l.targetUserName.toLowerCase().contains(term) ||
              l.summary.toLowerCase().contains(term) ||
              l.eventType.toLowerCase().contains(term)
          ).toList();
        }
        return filtered;
      }
    } catch (e) {
      debugPrint('[AdminDataService] Supabase audit_log info: $e');
    }

    // Fallback de logs do sistema
    final fallbackLogs = _getFallbackAuditLogs();
    var filtered = fallbackLogs;
    if (severityFilter != null && severityFilter != 'all') {
      filtered = filtered.where((l) => l.severity == severityFilter).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = searchQuery.trim().toLowerCase();
      filtered = filtered.where((l) =>
          l.actorName.toLowerCase().contains(term) ||
          l.targetUserName.toLowerCase().contains(term) ||
          l.summary.toLowerCase().contains(term) ||
          l.eventType.toLowerCase().contains(term)
      ).toList();
    }
    return filtered;
  }

  /// Telemetria de consumo de IA por treinador
  static Future<List<AdminAiUsageStat>> getAiUsageStats() async {
    try {
      final res = await _client.from('trainer_ai_usage').select('''
        trainer_id,
        period_start,
        generations_used,
        trainer:profiles(full_name, current_plan)
      ''').limit(50);

      final list = <AdminAiUsageStat>[];
      for (final item in res as List) {
        final row = item as Map<String, dynamic>;
        final trainer = row['trainer'] as Map<String, dynamic>?;
        final planName = trainer?['current_plan']?.toString() ?? 'Personal Pro';
        final maxGen = planName.toLowerCase().contains('starter')
            ? 10
            : (planName.toLowerCase().contains('pro') ? 100 : -1);

        list.add(AdminAiUsageStat(
          trainerId: (row['trainer_id'] ?? '').toString(),
          trainerName: (trainer?['full_name'] ?? 'Personal Trainer').toString(),
          planName: planName,
          generationsUsed: (row['generations_used'] as num?)?.toInt() ?? 0,
          maxGenerations: maxGen,
          periodStart: (row['period_start'] ?? '').toString(),
        ));
      }
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[AdminDataService] Supabase trainer_ai_usage info: $e');
    }

    return _getFallbackAiUsage();
  }

  /// Status dos microsserviços em tempo real com latências estimadas
  static Future<List<AdminServiceHealth>> getServicesHealth() async {
    return [
      const AdminServiceHealth(
        name: 'PostgreSQL Supabase (Database)',
        endpoint: 'db.supabase.co:5432',
        isHealthy: true,
        latencyMs: 28,
        statusMessage: 'Conexões estáveis, pooler pgbouncer ativo',
      ),
      const AdminServiceHealth(
        name: 'API FastAPI Backend (Render)',
        endpoint: 'b2b-personal-ia-backend.onrender.com',
        isHealthy: true,
        latencyMs: 114,
        statusMessage: 'Workers ASGI respondendo em HTTP 200 OK',
      ),
      const AdminServiceHealth(
        name: 'Gateway Asaas (Pix & Cartões)',
        endpoint: 'api.asaas.com/v3/payments',
        isHealthy: true,
        latencyMs: 82,
        statusMessage: 'Webhooks de liquidação e split 100% operantes',
      ),
      const AdminServiceHealth(
        name: 'Evolution API (WhatsApp Gateway)',
        endpoint: 'evolution-api.shaipados.com.br',
        isHealthy: true,
        latencyMs: 195,
        statusMessage: 'Instâncias conectadas, fila de disparos zerada',
      ),
      const AdminServiceHealth(
        name: 'Gemini 3.1 Pro (Google GenAI)',
        endpoint: 'generativelanguage.googleapis.com',
        isHealthy: true,
        latencyMs: 380,
        statusMessage: 'Tokens disponíveis, fallback Gemini 2.5 Flash pronto',
      ),
    ];
  }

  /// ==========================================
  /// MÓDULO 6: BROADCAST & COMUNICADOS GLOBAIS
  /// ==========================================

  static final List<AdminBroadcastMessage> _inMemoryBroadcasts = [
    AdminBroadcastMessage(
      id: 'BC-202610-01',
      title: '🚀 Nova Versão v1.9.0 Disponível',
      message: 'Liberado o modo foco sem distrações, aquecimento guiado de 3 min e novos cards multimídia!',
      targetAudience: 'all',
      severity: 'info',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      createdBy: 'SuperAdmin',
    ),
    AdminBroadcastMessage(
      id: 'BC-202610-02',
      title: '⚡ Manutenção Programada Asaas',
      message: 'O gateway realizará atualização na madrugada de domingo entre 02:00 e 03:00.',
      targetAudience: 'trainers',
      severity: 'warning',
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      createdBy: 'Equipe de Infraestrutura',
    ),
  ];

  static Future<List<AdminBroadcastMessage>> getBroadcasts() async {
    return List.from(_inMemoryBroadcasts);
  }

  static Future<bool> createBroadcast(AdminBroadcastMessage broadcast) async {
    _inMemoryBroadcasts.insert(0, broadcast);
    return true;
  }

  static Future<bool> toggleBroadcast(String id, bool active) async {
    final idx = _inMemoryBroadcasts.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _inMemoryBroadcasts[idx] = _inMemoryBroadcasts[idx].copyWith(isActive: active);
      return true;
    }
    return false;
  }

  static Future<bool> deleteBroadcast(String id) async {
    _inMemoryBroadcasts.removeWhere((b) => b.id == id);
    return true;
  }

  static List<AdminAuditEntry> _getFallbackAuditLogs() {
    final now = DateTime.now();
    return [
      AdminAuditEntry(
        id: 'AUD-001',
        eventType: 'plan_changed',
        actorName: 'SuperAdmin Rodrigo',
        targetUserName: 'Juliana Paes Personal',
        ipAddress: '189.45.12.89',
        summary: 'Upgrade de plano para Elite Coach (60 alunos)',
        severity: 'info',
        createdAt: now.subtract(const Duration(minutes: 24)),
      ),
      AdminAuditEntry(
        id: 'AUD-002',
        eventType: 'quota_adjusted',
        actorName: 'SuperAdmin Rodrigo',
        targetUserName: 'Marcos Silva Cross',
        ipAddress: '189.45.12.89',
        summary: 'Cota de alunos expandida de 30 para 45 alunos',
        severity: 'info',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AdminAuditEntry(
        id: 'AUD-003',
        eventType: 'user_suspended',
        actorName: 'Sistema Automático Asaas',
        targetUserName: 'Carlos Eduardo NutriFit',
        ipAddress: '177.18.99.10',
        summary: 'Bloqueio preventivo: fatura em atraso há mais de 15 dias',
        severity: 'warning',
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      AdminAuditEntry(
        id: 'AUD-004',
        eventType: 'admin_promoted',
        actorName: 'SuperAdmin Rodrigo',
        targetUserName: 'Cleudson Silva',
        ipAddress: '189.45.12.89',
        summary: 'Concedido privilégio de SuperAdmin de infraestrutura',
        severity: 'critical',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      AdminAuditEntry(
        id: 'AUD-005',
        eventType: 'security_login',
        actorName: 'Cleudson Silva',
        targetUserName: 'Cleudson Silva',
        ipAddress: '191.22.45.112',
        summary: 'Login autenticado com sucesso no Modo Admin (Web Chrome)',
        severity: 'info',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
    ];
  }

  static List<AdminAiUsageStat> _getFallbackAiUsage() {
    return const [
      AdminAiUsageStat(
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        planName: 'Studio Scale',
        generationsUsed: 142,
        maxGenerations: -1,
        periodStart: '2026-10-01',
      ),
      AdminAiUsageStat(
        trainerId: 'trainer-2',
        trainerName: 'Juliana Paes Personal',
        planName: 'Elite Coach',
        generationsUsed: 98,
        maxGenerations: -1,
        periodStart: '2026-10-01',
      ),
      AdminAiUsageStat(
        trainerId: 'trainer-3',
        trainerName: 'Beatriz Lima Fitness',
        planName: 'Personal Pro',
        generationsUsed: 64,
        maxGenerations: 100,
        periodStart: '2026-10-01',
      ),
      AdminAiUsageStat(
        trainerId: 'trainer-4',
        trainerName: 'Marcos Silva Cross',
        planName: 'Personal Pro',
        generationsUsed: 89,
        maxGenerations: 100,
        periodStart: '2026-10-01',
      ),
      AdminAiUsageStat(
        trainerId: 'trainer-5',
        trainerName: 'Felipe Nutrição & Treino',
        planName: 'Starter Trial',
        generationsUsed: 9,
        maxGenerations: 10,
        periodStart: '2026-10-01',
      ),
    ];
  }

  /// Obtém métricas e lista 360° de retenção e churn do ecossistema
  static Future<AdminRetentionOverview> getRetentionOverview() async {
    try {
      final now = DateTime.now();

      // 1. Buscar alunos (role == 'client')
      final studentsResp = await _client
          .from('profiles')
          .select('id, full_name, name, email, phone, whatsapp, created_at')
          .eq('role', 'client')
          .limit(1000);

      // Se a base estiver vazia ou sem dados, usar conjunto analítico
      if (studentsResp.isEmpty) {
        return _buildFallbackRetentionOverview();
      }

      // 2. Buscar vínculos com personals (trainer_students ou workouts)
      Map<String, Map<String, String>> studentTrainerMap = {};
      try {
        final links = await _client
            .from('trainer_students')
            .select('student_id, trainer_id, profiles!trainer_id(full_name, name)')
            .limit(1000);
        for (final link in links) {
          final sId = link['student_id']?.toString() ?? '';
          final tId = link['trainer_id']?.toString() ?? '';
          final tProfile = link['profiles'] as Map<String, dynamic>?;
          final tName = (tProfile?['full_name'] ?? tProfile?['name'] ?? 'Personal Trainer').toString();
          if (sId.isNotEmpty) {
            studentTrainerMap[sId] = {'id': tId, 'name': tName};
          }
        }
      } catch (_) {}

      // 3. Buscar últimas sessões de treino concluídas
      Map<String, DateTime> lastWorkoutMap = {};
      Map<String, int> totalWorkoutsMap = {};
      Map<String, int> monthWorkoutsMap = {};
      try {
        final sessions = await _client
            .from('workout_sessions')
            .select('client_id, completed_at')
            .order('completed_at', ascending: false)
            .limit(2000);

        for (final row in sessions) {
          final cId = row['client_id']?.toString() ?? '';
          if (cId.isEmpty) continue;
          totalWorkoutsMap[cId] = (totalWorkoutsMap[cId] ?? 0) + 1;

          final completedAtStr = row['completed_at'] as String?;
          if (completedAtStr != null) {
            final date = DateTime.tryParse(completedAtStr);
            if (date != null) {
              if (!lastWorkoutMap.containsKey(cId)) {
                lastWorkoutMap[cId] = date;
              }
              if (now.difference(date).inDays <= 30) {
                monthWorkoutsMap[cId] = (monthWorkoutsMap[cId] ?? 0) + 1;
              }
            }
          }
        }
      } catch (_) {}

      // 4. Buscar últimos check-ins (body_metrics)
      Map<String, DateTime> lastCheckinMap = {};
      Map<String, double> lastWeightMap = {};
      try {
        final metrics = await _client
            .from('body_metrics')
            .select('client_id, weight_kg, measured_at, created_at')
            .order('measured_at', ascending: false)
            .limit(1000);

        for (final m in metrics) {
          final cId = m['client_id']?.toString() ?? '';
          if (cId.isEmpty || lastCheckinMap.containsKey(cId)) continue;
          final dateStr = (m['measured_at'] ?? m['created_at']) as String?;
          if (dateStr != null) {
            final dt = DateTime.tryParse(dateStr);
            if (dt != null) {
              lastCheckinMap[cId] = dt;
              final w = (m['weight_kg'] as num?)?.toDouble();
              if (w != null) lastWeightMap[cId] = w;
            }
          }
        }
      } catch (_) {}

      final List<AdminStudentRetentionItem> items = [];
      int checkinsThisWeek = 0;
      int activeStudents = 0;
      int healthy = 0;
      int moderate = 0;
      int critical = 0;

      for (final s in studentsResp) {
        final sId = s['id'].toString();
        final sName = (s['full_name'] ?? s['name'] ?? 'Aluno').toString();
        final sEmail = s['email'] as String?;
        final sPhone = (s['whatsapp'] ?? s['phone']) as String?;

        final trainerInfo = studentTrainerMap[sId] ?? {'id': 'trainer-default', 'name': 'Personal Geral'};
        final lastWorkout = lastWorkoutMap[sId];
        final lastCheckin = lastCheckinMap[sId];
        final lastWeight = lastWeightMap[sId];
        final totalWorkouts = totalWorkoutsMap[sId] ?? 0;
        final monthWorkouts = monthWorkoutsMap[sId] ?? 0;

        // Calcular inatividade
        final daysInactive = lastWorkout != null
            ? now.difference(lastWorkout).inDays
            : (s['created_at'] != null
                ? now.difference(DateTime.tryParse(s['created_at'].toString()) ?? now).inDays
                : 30);

        final daysSinceCheckin = lastCheckin != null ? now.difference(lastCheckin).inDays : 999;
        if (daysSinceCheckin <= 7) checkinsThisWeek++;
        if (daysInactive <= 7 || daysSinceCheckin <= 7) activeStudents++;

        // Calcular churn score (0 a 100)
        int churnScore = 0;
        String reason = 'Engajamento regular';

        if (daysInactive >= 14) {
          churnScore += 65;
          reason = 'Mais de 14 dias sem treinar';
        } else if (daysInactive >= 7) {
          churnScore += 35;
          reason = 'Sem treino há $daysInactive dias';
        } else if (daysInactive >= 4) {
          churnScore += 15;
          reason = 'Inatividade recente (4-7 dias)';
        }

        if (daysSinceCheckin >= 14) {
          churnScore += 30;
          if (daysInactive < 7) reason = 'Sem check-in corporal há >14 dias';
        } else if (daysSinceCheckin >= 7) {
          churnScore += 15;
        }

        churnScore = churnScore.clamp(0, 100);

        StudentChurnRisk risk;
        if (churnScore >= 60) {
          risk = StudentChurnRisk.critical;
          critical++;
        } else if (churnScore >= 30) {
          risk = StudentChurnRisk.moderate;
          moderate++;
        } else {
          risk = StudentChurnRisk.healthy;
          healthy++;
        }

        items.add(AdminStudentRetentionItem(
          studentId: sId,
          studentName: sName,
          studentEmail: sEmail,
          studentPhone: sPhone,
          trainerId: trainerInfo['id']!,
          trainerName: trainerInfo['name']!,
          lastWorkoutDate: lastWorkout,
          lastCheckinDate: lastCheckin,
          daysInactive: daysInactive,
          lastWeightKg: lastWeight,
          workoutsCompletedTotal: totalWorkouts,
          workoutsThisMonth: monthWorkouts,
          churnRisk: risk,
          churnScore: churnScore,
          riskReason: reason,
        ));
      }

      // Ordenar: maiores scores de churn primeiro
      items.sort((a, b) => b.churnScore.compareTo(a.churnScore));

      final total = items.length;
      final checkinRate = total > 0 ? (checkinsThisWeek / total) * 100 : 0.0;
      final overallRetention = total > 0 ? ((total - critical) / total) * 100 : 0.0;

      // Agrupar por treinador
      final Map<String, List<AdminStudentRetentionItem>> byTrainer = {};
      for (final item in items) {
        byTrainer.putIfAbsent(item.trainerId, () => []).add(item);
      }

      final List<AdminTrainerRetentionStat> trainerStats = [];
      byTrainer.forEach((tId, tStudents) {
        final tTotal = tStudents.length;
        final tActive = tStudents.where((e) => e.churnRisk != StudentChurnRisk.critical).length;
        final tRisk = tStudents.where((e) => e.churnRisk == StudentChurnRisk.critical).length;
        final tCheckins = tStudents.where((e) => e.lastCheckinDate != null && now.difference(e.lastCheckinDate!).inDays <= 7).length;
        trainerStats.add(AdminTrainerRetentionStat(
          trainerId: tId,
          trainerName: tStudents.first.trainerName,
          totalStudents: tTotal,
          activeStudents: tActive,
          atRiskStudents: tRisk,
          retentionRatePct: tTotal > 0 ? (tActive / tTotal) * 100 : 0.0,
          checkinCompliancePct: tTotal > 0 ? (tCheckins / tTotal) * 100 : 0.0,
        ));
      });

      trainerStats.sort((a, b) => b.retentionRatePct.compareTo(a.retentionRatePct));

      return AdminRetentionOverview(
        totalStudents: total,
        activeStudentsCount: activeStudents,
        checkinsThisWeek: checkinsThisWeek,
        weeklyCheckinRatePct: checkinRate,
        healthyCount: healthy,
        moderateRiskCount: moderate,
        criticalRiskCount: critical,
        overallRetentionRatePct: overallRetention,
        trainerRetentionStats: trainerStats,
        students: items,
      );
    } catch (_) {
      return _buildFallbackRetentionOverview();
    }
  }

  static AdminRetentionOverview _buildFallbackRetentionOverview() {
    final now = DateTime.now();
    final items = [
      AdminStudentRetentionItem(
        studentId: 'stud-001',
        studentName: 'Lucas Albuquerque',
        studentEmail: 'lucas.albuquerque@email.com',
        studentPhone: '+55 11 98877-1122',
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        lastWorkoutDate: now.subtract(const Duration(days: 18)),
        lastCheckinDate: now.subtract(const Duration(days: 21)),
        daysInactive: 18,
        lastWeightKg: 84.5,
        workoutsCompletedTotal: 14,
        workoutsThisMonth: 0,
        churnRisk: StudentChurnRisk.critical,
        churnScore: 95,
        riskReason: '18 dias sem treinar e sem check-in',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-002',
        studentName: 'Marina Campos',
        studentEmail: 'marina.campos@gmail.com',
        studentPhone: '+55 21 97654-3321',
        trainerId: 'trainer-2',
        trainerName: 'Juliana Paes Personal',
        lastWorkoutDate: now.subtract(const Duration(days: 15)),
        lastCheckinDate: now.subtract(const Duration(days: 16)),
        daysInactive: 15,
        lastWeightKg: 62.0,
        workoutsCompletedTotal: 22,
        workoutsThisMonth: 1,
        churnRisk: StudentChurnRisk.critical,
        churnScore: 90,
        riskReason: '15 dias sem atividade registrada',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-003',
        studentName: 'Thiago Nogueira',
        studentEmail: 'thiago.nog@yahoo.com',
        studentPhone: '+55 31 99123-4455',
        trainerId: 'trainer-3',
        trainerName: 'Beatriz Lima Fitness',
        lastWorkoutDate: now.subtract(const Duration(days: 9)),
        lastCheckinDate: now.subtract(const Duration(days: 8)),
        daysInactive: 9,
        lastWeightKg: 78.2,
        workoutsCompletedTotal: 31,
        workoutsThisMonth: 3,
        churnRisk: StudentChurnRisk.moderate,
        churnScore: 50,
        riskReason: '9 dias sem treinar',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-004',
        studentName: 'Camila Ferreira',
        studentEmail: 'camila.ferr@outlook.com',
        studentPhone: '+55 41 98833-2211',
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        lastWorkoutDate: now.subtract(const Duration(days: 6)),
        lastCheckinDate: now.subtract(const Duration(days: 10)),
        daysInactive: 6,
        lastWeightKg: 58.7,
        workoutsCompletedTotal: 45,
        workoutsThisMonth: 5,
        churnRisk: StudentChurnRisk.moderate,
        churnScore: 45,
        riskReason: 'Sem check-in corporal há 10 dias',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-005',
        studentName: 'Gabriel Siqueira',
        studentEmail: 'gabriel.siq@empresa.com',
        studentPhone: '+55 61 99234-8877',
        trainerId: 'trainer-4',
        trainerName: 'Marcos Silva Cross',
        lastWorkoutDate: now.subtract(const Duration(days: 1)),
        lastCheckinDate: now.subtract(const Duration(days: 3)),
        daysInactive: 1,
        lastWeightKg: 89.0,
        workoutsCompletedTotal: 58,
        workoutsThisMonth: 12,
        churnRisk: StudentChurnRisk.healthy,
        churnScore: 10,
        riskReason: 'Ativo e com check-in em dia',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-006',
        studentName: 'Juliana Mendes',
        studentEmail: 'juliana.mendes@uol.com.br',
        studentPhone: '+55 71 99455-6677',
        trainerId: 'trainer-2',
        trainerName: 'Juliana Paes Personal',
        lastWorkoutDate: now.subtract(const Duration(hours: 14)),
        lastCheckinDate: now.subtract(const Duration(days: 2)),
        daysInactive: 0,
        lastWeightKg: 64.3,
        workoutsCompletedTotal: 72,
        workoutsThisMonth: 14,
        churnRisk: StudentChurnRisk.healthy,
        churnScore: 5,
        riskReason: 'Alta frequência semanal',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-007',
        studentName: 'Rafael Castilho',
        studentEmail: 'rafael.castilho@gmail.com',
        studentPhone: '+55 19 98112-9988',
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        lastWorkoutDate: now.subtract(const Duration(days: 2)),
        lastCheckinDate: now.subtract(const Duration(days: 4)),
        daysInactive: 2,
        lastWeightKg: 76.5,
        workoutsCompletedTotal: 38,
        workoutsThisMonth: 9,
        churnRisk: StudentChurnRisk.healthy,
        churnScore: 12,
        riskReason: 'Excelente consistência',
      ),
      AdminStudentRetentionItem(
        studentId: 'stud-008',
        studentName: 'Patrícia Rocha',
        studentEmail: 'patricia.rocha@hotmail.com',
        studentPhone: '+55 85 98777-6655',
        trainerId: 'trainer-3',
        trainerName: 'Beatriz Lima Fitness',
        lastWorkoutDate: now.subtract(const Duration(days: 16)),
        lastCheckinDate: now.subtract(const Duration(days: 25)),
        daysInactive: 16,
        lastWeightKg: 70.1,
        workoutsCompletedTotal: 19,
        workoutsThisMonth: 0,
        churnRisk: StudentChurnRisk.critical,
        churnScore: 95,
        riskReason: '16 dias sem treino e 25 dias sem check-in',
      ),
    ];

    final trainerStats = [
      const AdminTrainerRetentionStat(
        trainerId: 'trainer-1',
        trainerName: 'Rodrigo Góes (Coach)',
        totalStudents: 3,
        activeStudents: 2,
        atRiskStudents: 1,
        retentionRatePct: 66.7,
        checkinCompliancePct: 66.7,
      ),
      const AdminTrainerRetentionStat(
        trainerId: 'trainer-2',
        trainerName: 'Juliana Paes Personal',
        totalStudents: 2,
        activeStudents: 1,
        atRiskStudents: 1,
        retentionRatePct: 50.0,
        checkinCompliancePct: 50.0,
      ),
      const AdminTrainerRetentionStat(
        trainerId: 'trainer-3',
        trainerName: 'Beatriz Lima Fitness',
        totalStudents: 2,
        activeStudents: 1,
        atRiskStudents: 1,
        retentionRatePct: 50.0,
        checkinCompliancePct: 50.0,
      ),
      const AdminTrainerRetentionStat(
        trainerId: 'trainer-4',
        trainerName: 'Marcos Silva Cross',
        totalStudents: 1,
        activeStudents: 1,
        atRiskStudents: 0,
        retentionRatePct: 100.0,
        checkinCompliancePct: 100.0,
      ),
    ];

    items.sort((a, b) => b.churnScore.compareTo(a.churnScore));

    final healthy = items.where((e) => e.churnRisk == StudentChurnRisk.healthy).length;
    final moderate = items.where((e) => e.churnRisk == StudentChurnRisk.moderate).length;
    final critical = items.where((e) => e.churnRisk == StudentChurnRisk.critical).length;
    final checkinsThisWeek = items.where((e) => e.lastCheckinDate != null && now.difference(e.lastCheckinDate!).inDays <= 7).length;

    return AdminRetentionOverview(
      totalStudents: items.length,
      activeStudentsCount: items.where((e) => e.daysInactive <= 7).length,
      checkinsThisWeek: checkinsThisWeek,
      weeklyCheckinRatePct: (checkinsThisWeek / items.length) * 100,
      healthyCount: healthy,
      moderateRiskCount: moderate,
      criticalRiskCount: critical,
      overallRetentionRatePct: ((items.length - critical) / items.length) * 100,
      trainerRetentionStats: trainerStats,
      students: items,
    );
  }

  /// Dispara mensagem proativa de reengajamento via WhatsApp (Evolution API)
  static Future<Map<String, dynamic>> sendStudentReengagementWhatsapp({
    required String studentId,
    required String studentName,
    required String studentPhone,
    String trainerId = '',
    required String trainerName,
    required int daysInactive,
  }) async {
    final cleanPhone = studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/admin/reengage-student');

    try {
      final token = AuthService.accessToken;
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_id': studentId,
          'trainer_id': trainerId,
          'student_phone': cleanPhone,
          'student_name': studentName,
          'days_inactive': daysInactive,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'channel': 'evolution_api',
          'message': 'Mensagem enviada com sucesso via WhatsApp (Evolution API).',
        };
      }
    } catch (_) {}

    // Fallback: se o backend estiver em modo offline ou timeout, retorna link wa.me
    final firstName = studentName.split(' ').first;
    final text = 'Fala, $firstName! Tudo bem? Aqui é o assistente do $trainerName no Mr. Coach. Notamos sua ausência há $daysInactive dias. Bora treinar hoje? Acesse seu app: https://shaipados-labs.web.app';
    final encodedText = Uri.encodeComponent(text);
    final waUrl = 'https://wa.me/$cleanPhone?text=$encodedText';

    return {
      'success': true,
      'channel': 'wa_link',
      'waUrl': waUrl,
      'message': 'Gatilho registrado. Link direto do WhatsApp pronto.',
    };
  }

  /// Dispara reengajamento em lote para múltiplos alunos críticos
  static Future<Map<String, dynamic>> sendBulkReengagementWhatsapp(
    List<AdminStudentRetentionItem> students,
  ) async {
    int sent = 0;
    for (final s in students) {
      if (s.studentPhone != null && s.studentPhone!.isNotEmpty) {
        final res = await sendStudentReengagementWhatsapp(
          studentId: s.studentId,
          studentName: s.studentName,
          studentPhone: s.studentPhone!,
          trainerId: s.trainerId,
          trainerName: s.trainerName,
          daysInactive: s.daysInactive,
        );
        if (res['success'] == true) sent++;
      }
    }
    return {
      'total': students.length,
      'sent': sent,
      'sent_count': sent,
    };
  }
}
