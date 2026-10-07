import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/client/active_workout_screen.dart';
import 'package:personal_ia/services/workout_service.dart';
import 'package:personal_ia/services/workout_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSessionGateway implements WorkoutSessionGateway {
  bool failInsert = false;
  final List<Map<String, dynamic>> inserted = [];

  @override
  Future<Map<String, dynamic>> lookupContext(String clientId) async {
    if (failInsert) throw Exception('offline');
    return {'workout_id': 'w-1', 'trainer_id': 't-1'};
  }

  @override
  Future<void> insertSession(Map<String, dynamic> payload) async {
    if (failInsert) throw Exception('offline');
    // Simula ON CONFLICT DO NOTHING pelo id.
    if (!inserted.any((e) => e['id'] == payload['id'])) inserted.add(payload);
  }
}

WorkoutSessionRecord _record({String id = 'sess-1', String client = 'u1'}) =>
    WorkoutSessionRecord(
      id: id,
      clientId: client,
      splitIdentifier: 'A',
      splitName: 'Peito',
      totalExercises: 5,
      completedExercises: 4,
      startedAt: DateTime.utc(2026, 10, 7, 10, 0),
      completedAt: DateTime.utc(2026, 10, 7, 10, 45),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WorkoutSessionService', () {
    test('persistência confirmada => synced, com treino e professor reais',
        () async {
      final g = FakeSessionGateway();
      final s = WorkoutSessionService(gateway: g);
      final st = await s.complete(_record());
      expect(st, SessionSaveStatus.synced);
      expect(g.inserted.single['workout_id'], 'w-1');
      expect(g.inserted.single['trainer_id'], 't-1');
      expect(g.inserted.single['client_id'], 'u1');
      expect(g.inserted.single['completed_exercises'], 4);
      expect(g.inserted.single['duration_seconds'], 45 * 60);
      expect(await s.pending('u1'), isEmpty);
    });

    test('falha de rede => pendingSync (nunca synced) e fica na fila', () async {
      final g = FakeSessionGateway()..failInsert = true;
      final s = WorkoutSessionService(gateway: g);
      final st = await s.complete(_record());
      expect(st, SessionSaveStatus.pendingSync);
      expect(g.inserted, isEmpty);
      expect((await s.pending('u1')).length, 1);
    });

    test('retomada: flush envia pendentes e esvazia a fila (sem duplicar)',
        () async {
      final g = FakeSessionGateway()..failInsert = true;
      final s = WorkoutSessionService(gateway: g);
      await s.complete(_record());
      await s.complete(_record()); // mesma sessão tentada de novo
      expect((await s.pending('u1')).length, 1);

      expect(await s.flushPending('u1'), 1); // ainda offline
      g.failInsert = false;
      expect(await s.flushPending('u1'), 0);
      expect(g.inserted.length, 1);
      expect(await s.pending('u1'), isEmpty);
    });

    test('fila é isolada por aluno', () async {
      final g = FakeSessionGateway()..failInsert = true;
      final s = WorkoutSessionService(gateway: g);
      await s.complete(_record(client: 'u1'));
      expect(await s.pending('u2'), isEmpty);
    });

    test('record sobrevive a serialização (retomada após fechar o app)', () {
      final r = _record();
      final back = WorkoutSessionRecord.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.id, r.id);
      expect(back.durationSeconds, r.durationSeconds);
      expect(back.completedExercises, 4);
    });

    test('newId gera UUID v4 válido e único', () {
      final a = WorkoutSessionRecord.newId();
      final b = WorkoutSessionRecord.newId();
      expect(a, matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(b));
    });
  });

  group('Cache offline do treino', () {
    final planJson = jsonEncode({
      'workout_plan_title': 'Plano da Maria',
      'notes_for_trainer': '',
      'splits': [],
    });

    test('não vaza o treino em cache de outra conta', () async {
      SharedPreferences.setMockInitialValues({
        'b2b_offline_active_workout_userA': planJson,
        'b2b_offline_active_workout_last_active': planJson,
      });
      expect(await WorkoutService.getOfflineCachedWorkout(clientId: 'userB'),
          isNull);
      final a = await WorkoutService.getOfflineCachedWorkout(clientId: 'userA');
      expect(a?.workoutPlanTitle, 'Plano da Maria');
    });

    test('clearOfflineCachedWorkout remove cache obsoleto', () async {
      SharedPreferences.setMockInitialValues({
        'b2b_offline_active_workout_userA': planJson,
        'b2b_offline_active_workout_last_active': planJson,
      });
      await WorkoutService.clearOfflineCachedWorkout('userA');
      expect(await WorkoutService.getOfflineCachedWorkout(clientId: 'userA'),
          isNull);
    });
  });

  group('ActiveWorkoutScreen', () {
    testWidgets('sem ficha real nem cache: estado vazio, sem exercícios fictícios',
        (t) async {
      await t.pumpWidget(const MaterialApp(home: ActiveWorkoutScreen()));
      await t.pumpAndSettle();
      expect(find.text('Nenhuma ficha ativa'), findsOneWidget);
      expect(find.text('Supino Inclinado com Halteres'), findsNothing);
      expect(find.text('Finalizar Treino'), findsNothing);
      expect(find.text('Atualizar'), findsOneWidget);
    });
  });
}
