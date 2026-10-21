import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

enum NotificationType {
  frequency,
  hydration,
  workoutPlan,
  trainerMessage,
  system,
}

enum NotificationSeverity {
  info,
  success,
  warning,
  urgent,
}

class StudentNotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationSeverity severity;
  final DateTime timestamp;
  final bool isRead;
  final String? actionLabel;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

  const StudentNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.timestamp,
    this.isRead = false,
    this.actionLabel,
    this.actionRoute,
    this.metadata,
  });

  StudentNotificationItem copyWith({
    bool? isRead,
    String? title,
    String? message,
    NotificationSeverity? severity,
  }) {
    return StudentNotificationItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type,
      severity: severity ?? this.severity,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.name,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'actionLabel': actionLabel,
        'actionRoute': actionRoute,
        'metadata': metadata,
      };

  factory StudentNotificationItem.fromJson(Map<String, dynamic> j) {
    return StudentNotificationItem(
      id: j['id'] as String,
      title: j['title'] as String,
      message: j['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => NotificationType.system,
      ),
      severity: NotificationSeverity.values.firstWhere(
        (e) => e.name == j['severity'],
        orElse: () => NotificationSeverity.info,
      ),
      timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: j['isRead'] as bool? ?? false,
      actionLabel: j['actionLabel'] as String?,
      actionRoute: j['actionRoute'] as String?,
      metadata: j['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Serviço inteligente de notificações e gatilhos de engajamento do aluno.
/// Monitora frequência de treinos (>48h sem treinar), hidratação diária e atualizações de ficha.
class StudentNotificationService {
  StudentNotificationService._();
  static final StudentNotificationService instance = StudentNotificationService._();

  static final ValueNotifier<List<StudentNotificationItem>> notificationsNotifier =
      ValueNotifier<List<StudentNotificationItem>>([]);

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> todayHydrationNotifier = ValueNotifier<int>(0);

  static const String _dismissedPrefix = 'b2b_notif_dismissed_';
  static const String _readPrefix = 'b2b_notif_read_';
  static const String _customGoalPrefix = 'b2b_water_goal_';
  static const String _intakePrefix = 'b2b_water_intake_';

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Inicializa e avalia os gatilhos em tempo real para o aluno logado.
  Future<void> refreshNotifications() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final studentId = user.id;

      // 1. Atualizar hidratação do dia no notifier
      final currentIntake = await getTodayHydration(studentId);
      todayHydrationNotifier.value = currentIntake;

      // 2. Gerar / avaliar notificações automáticas de engajamento
      final List<StudentNotificationItem> items = [];

      // A. Gatilho de Inatividade / Frequência (>48h sem treinar)
      final freqItem = await _checkFrequencyTrigger(studentId);
      if (freqItem != null) items.add(freqItem);

      // B. Gatilho de Hidratação Inteligente
      final waterItem = await _checkHydrationTrigger(studentId, currentIntake);
      if (waterItem != null) items.add(waterItem);

      // C. Gatilho de Atualização de Ficha / Rotina
      final workoutItem = await _checkWorkoutRoutineTrigger(studentId);
      if (workoutItem != null) items.add(workoutItem);

      // D. Notificações do sistema salvas localmente
      final localItems = await _loadSavedNotifications(studentId);
      for (final loc in localItems) {
        if (!items.any((e) => e.id == loc.id)) {
          items.add(loc);
        }
      }

      // Ordenar: não lidas primeiro, depois por timestamp decrescente
      items.sort((a, b) {
        if (a.isRead != b.isRead) {
          return a.isRead ? 1 : -1;
        }
        return b.timestamp.compareTo(a.timestamp);
      });

      notificationsNotifier.value = items;
      unreadCountNotifier.value = items.where((e) => !e.isRead).length;
    } catch (e) {
      debugPrint('[StudentNotificationService] Erro ao atualizar notificações: $e');
    }
  }

  // ===========================================================================
  // MOTOR DE HIDRATAÇÃO
  // ===========================================================================

  /// Retorna a meta diária de água em ML (calculada com 35ml/kg ou padrão de 2500ml).
  Future<int> getDailyHydrationGoal(String studentId, [double? weightKg]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getInt('$_customGoalPrefix$studentId');
      if (custom != null && custom > 0) return custom;

      if (weightKg != null && weightKg > 30) {
        final calculated = (weightKg * 35).round();
        // Arredondar para múltiplos de 50ml, limitando entre 1500 e 4500
        final rounded = ((calculated / 50).round() * 50).clamp(1500, 4500);
        return rounded;
      }
    } catch (_) {}
    return 2500; // Padrão recomendado
  }

  /// Retorna o consumo de água registrado hoje (em ML).
  Future<int> getTodayHydration(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_intakePrefix${studentId}_${_dateKey(DateTime.now())}';
      return prefs.getInt(key) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Adiciona uma porção de água (ex: +250ml, +500ml) ao dia de hoje.
  Future<int> addWaterIntake(String studentId, int ml) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_intakePrefix${studentId}_${_dateKey(DateTime.now())}';
      final current = prefs.getInt(key) ?? 0;
      final updated = (current + ml).clamp(0, 10000);
      await prefs.setInt(key, updated);
      todayHydrationNotifier.value = updated;
      await refreshNotifications();
      return updated;
    } catch (_) {
      return 0;
    }
  }

  /// Reseta a hidratação de hoje para 0 ML.
  Future<void> resetTodayHydration(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_intakePrefix${studentId}_${_dateKey(DateTime.now())}';
      await prefs.remove(key);
      todayHydrationNotifier.value = 0;
      await refreshNotifications();
    } catch (_) {}
  }

  /// Salva uma meta personalizada de água.
  Future<void> setCustomHydrationGoal(String studentId, int goalMl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_customGoalPrefix$studentId', goalMl);
      await refreshNotifications();
    } catch (_) {}
  }

  // ===========================================================================
  // AVALIAÇÃO DE GATILHOS (TRIGGERS)
  // ===========================================================================

  /// Avalia inatividade (>48h sem treinar).
  Future<StudentNotificationItem?> _checkFrequencyTrigger(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _dateKey(DateTime.now());
    final notifId = 'freq_inactivity_${studentId}_$todayStr';

    if (prefs.getBool('$_dismissedPrefix$notifId') == true) return null;
    final isRead = prefs.getBool('$_readPrefix$notifId') ?? false;

    DateTime? lastWorkoutTime;
    try {
      final res = await Supabase.instance.client
          .from('workout_sessions')
          .select('completed_at')
          .eq('client_id', studentId)
          .order('completed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null && res['completed_at'] != null) {
        lastWorkoutTime = DateTime.tryParse(res['completed_at'] as String);
      }
    } catch (_) {}

    // Fallback para cache local se offline
    if (lastWorkoutTime == null) {
      final cachedStr = prefs.getString('b2b_last_session_time_$studentId');
      if (cachedStr != null) {
        lastWorkoutTime = DateTime.tryParse(cachedStr);
      }
    }

    final now = DateTime.now();
    if (lastWorkoutTime != null) {
      final diff = now.difference(lastWorkoutTime);
      final hours = diff.inHours;

      if (hours >= 96) {
        return StudentNotificationItem(
          id: notifId,
          title: '🚨 4 dias sem treinar! Hora de reagir',
          message:
              'A consistência é o segredo dos seus resultados. Seu corpo já se recuperou e precisa de estímulo. Que tal um treino rápido hoje?',
          type: NotificationType.frequency,
          severity: NotificationSeverity.urgent,
          timestamp: lastWorkoutTime,
          isRead: isRead,
          actionLabel: 'Iniciar Treino',
        );
      } else if (hours >= 48) {
        return StudentNotificationItem(
          id: notifId,
          title: '⚡ Faz 48h desde seu último treino',
          message:
              'Manter o ritmo agora evita recomeçar do zero. Seu treino de hoje já está pronto te esperando na aba de treinos!',
          type: NotificationType.frequency,
          severity: NotificationSeverity.warning,
          timestamp: lastWorkoutTime,
          isRead: isRead,
          actionLabel: 'Ver Treino',
        );
      }
    } else {
      // Aluno novo sem treinos concluídos
      return StudentNotificationItem(
        id: notifId,
        title: '🎯 Dê o primeiro passo hoje!',
        message:
            'Você ainda não registrou nenhum treino nesta semana. Abra sua ficha e conclua seu primeiro treino para iniciar sua ofensiva 🔥.',
        type: NotificationType.frequency,
        severity: NotificationSeverity.info,
        timestamp: now,
        isRead: isRead,
        actionLabel: 'Bora Treinar',
      );
    }

    return null;
  }

  /// Avalia lembrete de hidratação inteligente.
  Future<StudentNotificationItem?> _checkHydrationTrigger(
    String studentId,
    int currentIntake,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _dateKey(DateTime.now());
    final notifId = 'hydration_alert_${studentId}_$todayStr';

    if (prefs.getBool('$_dismissedPrefix$notifId') == true) return null;
    final isRead = prefs.getBool('$_readPrefix$notifId') ?? false;

    final goal = await getDailyHydrationGoal(studentId);
    final now = DateTime.now();
    final hour = now.hour;

    // Se já bateu a meta hoje
    if (currentIntake >= goal) {
      return StudentNotificationItem(
        id: notifId,
        title: '💧 Meta de Hidratação Atingida!',
        message:
            'Parabéns! Você já bebeu ${currentIntake}ml de água hoje (100% da meta). Seus músculos agradecem a recuperação!',
        type: NotificationType.hydration,
        severity: NotificationSeverity.success,
        timestamp: now,
        isRead: isRead,
        actionLabel: '+250ml',
      );
    }

    // Se passou das 14h e bebeu menos de 40% da meta
    if (hour >= 14 && currentIntake < (goal * 0.4).round()) {
      return StudentNotificationItem(
        id: notifId,
        title: '💧 Lembrete de Água: Apenas ${currentIntake}ml hoje',
        message:
            'A hidratação afeta diretamente seu rendimento e queima calórica. Faltam ${(goal - currentIntake)}ml para bater sua meta de ${goal}ml.',
        type: NotificationType.hydration,
        severity: NotificationSeverity.warning,
        timestamp: now,
        isRead: isRead,
        actionLabel: '+350ml de Água',
      );
    }

    // Alerta matinal padrão se não bebeu nada até 11h
    if (hour >= 11 && currentIntake == 0) {
      return StudentNotificationItem(
        id: notifId,
        title: '💧 Beba seu primeiro copo de água',
        message:
            'Comece seu dia hidratando as células. Beba pelo menos 300ml de água para ativar o metabolismo.',
        type: NotificationType.hydration,
        severity: NotificationSeverity.info,
        timestamp: now,
        isRead: isRead,
        actionLabel: '+250ml',
      );
    }

    return null;
  }

  /// Avalia atualização de rotina de treino pelo Personal.
  Future<StudentNotificationItem?> _checkWorkoutRoutineTrigger(String studentId) async {
    final prefs = await SharedPreferences.getInstance();
    final notifId = 'workout_routine_check_$studentId';

    if (prefs.getBool('$_dismissedPrefix$notifId') == true) return null;
    final isRead = prefs.getBool('$_readPrefix$notifId') ?? false;

    try {
      final res = await Supabase.instance.client
          .from('workouts')
          .select('id, name, updated_at, created_at')
          .eq('client_id', studentId)
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        final updatedAt = DateTime.tryParse(
          (res['updated_at'] ?? res['created_at']) as String? ?? '',
        );

        if (updatedAt != null) {
          final diff = DateTime.now().difference(updatedAt);
          // Se foi atualizado nos últimos 4 dias
          if (diff.inDays <= 4) {
            final workoutName = res['name'] as String? ?? 'Rotina de Treinos';
            return StudentNotificationItem(
              id: '${notifId}_${updatedAt.millisecondsSinceEpoch}',
              title: '📋 Ficha Atualizada pelo Treinador',
              message:
                  'Seu personal atualizou sua rotina "$workoutName". Novos exercícios, cargas ou repetições foram ajustados.',
              type: NotificationType.workoutPlan,
              severity: NotificationSeverity.info,
              timestamp: updatedAt,
              isRead: isRead,
              actionLabel: 'Ver Ficha',
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // GERENCIAMENTO DE ESTADO E PERSISTÊNCIA
  // ===========================================================================

  /// Marca uma notificação como lida.
  Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_readPrefix$id', true);

      final current = List<StudentNotificationItem>.from(notificationsNotifier.value);
      final idx = current.indexWhere((e) => e.id == id);
      if (idx != -1) {
        current[idx] = current[idx].copyWith(isRead: true);
        notificationsNotifier.value = current;
        unreadCountNotifier.value = current.where((e) => !e.isRead).length;
      }
    } catch (_) {}
  }

  /// Marca todas as notificações como lidas.
  Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<StudentNotificationItem>.from(notificationsNotifier.value);
      for (int i = 0; i < current.length; i++) {
        await prefs.setBool('$_readPrefix${current[i].id}', true);
        current[i] = current[i].copyWith(isRead: true);
      }
      notificationsNotifier.value = current;
      unreadCountNotifier.value = 0;
    } catch (_) {}
  }

  /// Dispensa (descarta) uma notificação para não reaparecer hoje.
  Future<void> dismiss(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_dismissedPrefix$id', true);

      final current = List<StudentNotificationItem>.from(notificationsNotifier.value);
      current.removeWhere((e) => e.id == id);
      notificationsNotifier.value = current;
      unreadCountNotifier.value = current.where((e) => !e.isRead).length;
    } catch (_) {}
  }

  /// Limpa todas as notificações lidas da lista.
  Future<void> clearReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<StudentNotificationItem>.from(notificationsNotifier.value);
      for (final item in current.where((e) => e.isRead)) {
        await prefs.setBool('$_dismissedPrefix${item.id}', true);
      }
      current.removeWhere((e) => e.isRead);
      notificationsNotifier.value = current;
      unreadCountNotifier.value = current.length;
    } catch (_) {}
  }

  Future<List<StudentNotificationItem>> _loadSavedNotifications(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('b2b_custom_notifs_$studentId') ?? [];
      return rawList
          .map((e) => StudentNotificationItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
