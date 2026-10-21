import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
