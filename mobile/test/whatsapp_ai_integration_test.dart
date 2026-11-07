import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/services/workout_session_service.dart';
import 'package:personal_ia/services/workout_service.dart';

class MockWorkoutSessionGateway implements WorkoutSessionGateway {
  final List<Map<String, dynamic>> insertedSessions = [];

  @override
  Future<Map<String, dynamic>> lookupContext(String clientId) async {
    return {
      'workout_id': 'wk-test-101',
      'trainer_id': 'tr-test-202',
      'student_name': 'Carlos Aluno',
      'student_phone': '5511999998888',
    };
  }

  @override
  Future<void> insertSession(Map<String, dynamic> payload) async {
    insertedSessions.add(payload);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WhatsApp AI 3.0 Mobile Integration Test Suite', () {
    test('WorkoutSessionRecord duration and json serialization', () {
      final now = DateTime.now();
      final record = WorkoutSessionRecord(
        id: 'sess-001',
        clientId: 'student-100',
        splitIdentifier: 'A',
        splitName: 'Peito e Tríceps',
        totalExercises: 6,
        completedExercises: 6,
        startedAt: now.subtract(const Duration(minutes: 45)),
        completedAt: now,
      );

      expect(record.id, 'sess-001');
      expect(record.clientId, 'student-100');
      expect(record.durationSeconds, greaterThanOrEqualTo(2700));

      final json = record.toJson();
      expect(json['id'], 'sess-001');
      expect(json['split_name'], 'Peito e Tríceps');
      expect(json['completed_exercises'], 6);
    });

    test('WorkoutSessionService completes session and calls gateway properly', () async {
      final mockGateway = MockWorkoutSessionGateway();
      final sessionService = WorkoutSessionService(gateway: mockGateway);

      final now = DateTime.now();
      final record = WorkoutSessionRecord(
        id: 'sess-002',
        clientId: 'student-200',
        splitIdentifier: 'B',
        splitName: 'Pernas e Ombros',
        totalExercises: 5,
        completedExercises: 5,
        startedAt: now.subtract(const Duration(minutes: 50)),
        completedAt: now,
      );

      final status = await sessionService.complete(record);
      expect(status, SessionSaveStatus.synced);
      expect(mockGateway.insertedSessions.length, 1);

      final inserted = mockGateway.insertedSessions.first;
      expect(inserted['client_id'], 'student-200');
      expect(inserted['split_name'], 'Pernas e Ombros');
      expect(inserted['trainer_id'], 'tr-test-202');
    });

    test('WorkoutService helper methods for WhatsApp post-workout checkin and weekly digest exist and handle offline safely', () async {
      // In offline / unit test without mock HTTP server, these methods catch exceptions gracefully and return false / null
      final checkinSuccess = await WorkoutService.triggerPostWorkoutWhatsAppCheckin(
        studentId: 'student-300',
        workoutTitle: 'Treino A',
        workoutSessionId: 'sess-999',
      );
      expect(checkinSuccess, isFalse);

      final digestResult = await WorkoutService.sendWeeklyDigestToTrainer(
        trainerPhone: '5511999998888',
      );
      expect(digestResult, isNull);
    });
  });
}
