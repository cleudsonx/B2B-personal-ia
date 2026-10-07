import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sessão de treino concluída pelo aluno.
class WorkoutSessionRecord {
  final String id;
  final String clientId;
  final String? splitIdentifier;
  final String? splitName;
  final int totalExercises;
  final int completedExercises;
  final DateTime startedAt;
  final DateTime completedAt;

  const WorkoutSessionRecord({
    required this.id,
    required this.clientId,
    this.splitIdentifier,
    this.splitName,
    required this.totalExercises,
    required this.completedExercises,
    required this.startedAt,
    required this.completedAt,
  });

  int get durationSeconds {
    final s = completedAt.difference(startedAt).inSeconds;
    return s < 0 ? 0 : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_id': clientId,
        'split_identifier': splitIdentifier,
        'split_name': splitName,
        'total_exercises': totalExercises,
        'completed_exercises': completedExercises,
        'started_at': startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'duration_seconds': durationSeconds,
      };

  factory WorkoutSessionRecord.fromJson(Map<String, dynamic> j) =>
      WorkoutSessionRecord(
        id: j['id'] as String,
        clientId: j['client_id'] as String,
        splitIdentifier: j['split_identifier'] as String?,
        splitName: j['split_name'] as String?,
        totalExercises: j['total_exercises'] as int,
        completedExercises: j['completed_exercises'] as int,
        startedAt: DateTime.parse(j['started_at'] as String),
        completedAt: DateTime.parse(j['completed_at'] as String),
      );

  /// UUID v4 gerado no cliente; torna o reenvio idempotente.
  static String newId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}

enum SessionSaveStatus {
  /// Confirmado pelo banco.
  synced,

  /// Guardado no aparelho; será enviado quando houver conexão. NÃO está no banco.
  pendingSync,
}

/// Acesso a dados; abstrato para permitir testes sem rede.
abstract class WorkoutSessionGateway {
  /// {workout_id, trainer_id} atuais do aluno (valores podem ser nulos).
  Future<Map<String, dynamic>> lookupContext(String clientId);

  /// Deve lançar exceção se a sessão não foi gravada. Duplicata (mesmo id) é ok.
  Future<void> insertSession(Map<String, dynamic> payload);
}

class SupabaseWorkoutSessionGateway implements WorkoutSessionGateway {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> lookupContext(String clientId) async {
    final w = await _c
        .from('workouts')
        .select('id')
        .eq('client_id', clientId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final p = await _c
        .from('profiles')
        .select('trainer_id')
        .eq('id', clientId)
        .maybeSingle();
    return {'workout_id': w?['id'], 'trainer_id': p?['trainer_id']};
  }

  @override
  Future<void> insertSession(Map<String, dynamic> payload) async {
    await _c
        .from('workout_sessions')
        .upsert(payload, onConflict: 'id', ignoreDuplicates: true);
  }
}

class WorkoutSessionService {
  final WorkoutSessionGateway gateway;
  WorkoutSessionService({WorkoutSessionGateway? gateway})
      : gateway = gateway ?? SupabaseWorkoutSessionGateway();

  static String _key(String clientId) => 'b2b_pending_sessions_$clientId';

  Future<void> _push(WorkoutSessionRecord r) async {
    final ctx = await gateway.lookupContext(r.clientId);
    await gateway.insertSession({
      ...r.toJson(),
      'workout_id': ctx['workout_id'],
      'trainer_id': ctx['trainer_id'],
    });
  }

  Future<List<WorkoutSessionRecord>> pending(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(clientId)) ?? const [];
    return raw
        .map((e) =>
            WorkoutSessionRecord.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _savePending(
      String clientId, List<WorkoutSessionRecord> list) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setStringList(
        _key(clientId), list.map((e) => jsonEncode(e.toJson())).toList());
    if (!ok) throw Exception('Não foi possível guardar a sessão no aparelho.');
  }

  /// Persiste a sessão. `synced` só se o banco confirmou. Se a rede/banco
  /// falhar, guarda localmente (`pendingSync`). Lança exceção se nem isso for
  /// possível — a UI deve oferecer nova tentativa.
  Future<SessionSaveStatus> complete(WorkoutSessionRecord record) async {
    try {
      await _push(record);
      return SessionSaveStatus.synced;
    } catch (_) {
      final list = await pending(record.clientId);
      if (!list.any((e) => e.id == record.id)) list.add(record);
      await _savePending(record.clientId, list);
      return SessionSaveStatus.pendingSync;
    }
  }

  /// Reenvia sessões pendentes. Retorna quantas continuam pendentes.
  Future<int> flushPending(String clientId) async {
    final list = await pending(clientId);
    if (list.isEmpty) return 0;
    final remaining = <WorkoutSessionRecord>[];
    for (final r in list) {
      try {
        await _push(r);
      } catch (_) {
        remaining.add(r);
      }
    }
    await _savePending(clientId, remaining);
    return remaining.length;
  }
}

