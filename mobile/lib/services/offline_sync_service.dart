import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'workout_session_service.dart';

enum OfflineItemType {
  workoutSession,
  exerciseLoad,
  hydration,
  feedback,
}

class PendingSyncItem {
  final String id;
  final OfflineItemType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  const PendingSyncItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingSyncItem copyWith({
    int? retryCount,
  }) {
    return PendingSyncItem(
      id: id,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };

  factory PendingSyncItem.fromJson(Map<String, dynamic> j) {
    return PendingSyncItem(
      id: j['id'] as String,
      type: OfflineItemType.values.firstWhere(
        (e) => e.name == j['type'],
        orElse: () => OfflineItemType.workoutSession,
      ),
      payload: Map<String, dynamic>.from(j['payload'] as Map),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      retryCount: j['retry_count'] as int? ?? 0,
    );
  }
}

/// Motor de Gestão Offline & Fila Local (Offline-First) do Aluno.
/// Permite treinar completamente sem conexão e sincroniza em lote na reconexão.
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isOfflineModeNotifier = ValueNotifier<bool>(false);

  static const String _queuePrefix = 'b2b_offline_queue_';
  static const String _activeDraftPrefix = 'b2b_workout_draft_';

  Timer? _autoSyncTimer;

  void initAutoSync() {
    _autoSyncTimer?.cancel();
    // Tenta sincronizar a cada 45 segundos se houver pendências
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      final user = AuthService.currentUser;
      if (user != null && pendingCountNotifier.value > 0) {
        syncAllPending(user.id);
      }
    });
    refreshPendingCount();
  }

  void dispose() {
    _autoSyncTimer?.cancel();
  }

  String _queueKey(String clientId) => '$_queuePrefix$clientId';
  String _draftKey(String clientId) => '$_activeDraftPrefix$clientId';

  /// Atualiza o contador de itens pendentes no notifier
  Future<int> refreshPendingCount([String? clientId]) async {
    try {
      final uid = clientId ?? AuthService.currentUser?.id;
      if (uid == null) {
        pendingCountNotifier.value = 0;
        return 0;
      }
      final queue = await getQueue(uid);
      // Inclui também sessões legadas do WorkoutSessionService
      final sessionService = WorkoutSessionService();
      final legacySessions = await sessionService.pending(uid);

      final total = queue.length + legacySessions.length;
      pendingCountNotifier.value = total;
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Retorna a lista de itens da fila de sincronização
  Future<List<PendingSyncItem>> getQueue(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_queueKey(clientId)) ?? [];
      return raw
          .map((e) => PendingSyncItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adiciona um item na fila de sincronização offline
  Future<void> enqueue(String clientId, OfflineItemType type, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getQueue(clientId);
      final newItem = PendingSyncItem(
        id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        payload: payload,
        createdAt: DateTime.now(),
      );
      current.add(newItem);
      await prefs.setStringList(
        _queueKey(clientId),
        current.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await refreshPendingCount(clientId);
    } catch (e) {
      debugPrint('[OfflineSyncService] Erro ao enfileirar item offline: $e');
    }
  }

  /// Sincroniza todos os itens pendentes com o Supabase
  Future<int> syncAllPending(String clientId) async {
    if (isSyncingNotifier.value) return pendingCountNotifier.value;
    isSyncingNotifier.value = true;

    int syncedCount = 0;
    try {
      // 1. Sincroniza sessões de treino pendentes
      final sessionService = WorkoutSessionService();
      await sessionService.flushPending(clientId);

      // 2. Sincroniza itens da fila geral
      final prefs = await SharedPreferences.getInstance();
      final queue = await getQueue(clientId);
      if (queue.isEmpty) {
        await refreshPendingCount(clientId);
        isSyncingNotifier.value = false;
        return 0;
      }

      final remaining = <PendingSyncItem>[];
      final client = Supabase.instance.client;

      for (final item in queue) {
        bool success = false;
        try {
          switch (item.type) {
            case OfflineItemType.workoutSession:
              await client.from('workout_sessions').upsert(
                    item.payload,
                    onConflict: 'id',
                    ignoreDuplicates: true,
                  );
              success = true;
              break;

            case OfflineItemType.exerciseLoad:
              await client.from('student_exercise_loads').insert(item.payload);
              success = true;
              break;

            case OfflineItemType.hydration:
              // Hidratação sincronizada localmente
              success = true;
              break;

            case OfflineItemType.feedback:
              await client.from('workout_feedback').insert(item.payload);
              success = true;
              break;
          }
        } catch (e) {
          debugPrint('[OfflineSyncService] Falha ao sincronizar item ${item.id}: $e');
          // Incrementa tentativas se for erro temporário de rede
          remaining.add(item.copyWith(retryCount: item.retryCount + 1));
        }

        if (success) {
          syncedCount++;
        }
      }

      await prefs.setStringList(
        _queueKey(clientId),
        remaining.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await refreshPendingCount(clientId);
    } catch (e) {
      debugPrint('[OfflineSyncService] Erro durante o flush da fila: $e');
    } finally {
      isSyncingNotifier.value = false;
    }

    return syncedCount;
  }

  // ===========================================================================
  // RASCUNHO DE TREINO EM ANDAMENTO (CRASH & REBOOT RESILIENCE)
  // ===========================================================================

  /// Salva rascunho do treino em andamento
  Future<void> saveWorkoutDraft(String clientId, Map<String, dynamic> draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey(clientId), jsonEncode(draft));
    } catch (_) {}
  }

  /// Recupera o rascunho de treino em andamento (se houver)
  Future<Map<String, dynamic>?> getWorkoutDraft(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey(clientId));
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Limpa o rascunho após concluir ou descartar
  Future<void> clearWorkoutDraft(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey(clientId));
    } catch (_) {}
  }
}
