import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/models/operational_cockpit_model.dart';

void main() {
  group('OperationalCockpit Models Test Suite', () {
    test('InactiveStudentCard parses from JSON correctly with safe defaults', () {
      final json = {
        'id': 'st-101',
        'full_name': 'Rodrigo Santana',
        'phone': '11999998888',
        'days_inactive': 5,
        'streak_days': 4,
        'last_contacted_at': '2026-11-05T12:00:00Z',
        'recently_contacted_48h': false,
        'suggested_whatsapp_message':
            'Fala Rodrigo! Notei que faz 5 dias que não treinamos.',
        'contact_whatsapp_url': 'https://wa.me/5511999998888?text=teste',
      };

      final card = InactiveStudentCard.fromJson(json);

      expect(card.id, 'st-101');
      expect(card.fullName, 'Rodrigo Santana');
      expect(card.daysInactive, 5);
      expect(card.streakDays, 4);
      expect(card.recentlyContacted48h, false);
      expect(card.suggestedWhatsappMessage, contains('Rodrigo'));
      expect(card.contactWhatsappUrl, contains('wa.me'));

      // Test copyWith
      final updated = card.copyWith(recentlyContacted48h: true);
      expect(updated.recentlyContacted48h, true);
      expect(updated.fullName, 'Rodrigo Santana');
    });

    test('OperationalPainAlertItem parses from JSON properly', () {
      final json = {
        'id': 'alt-55',
        'student_id': 'st-101',
        'student_name': 'Rodrigo Santana',
        'original_exercise': 'Desenvolvimento Militar',
        'adapted_exercise': 'Elevação Lateral na Polia',
        'pain_location': 'Ombro direito',
        'severity': 'Moderada',
        'created_at': '2026-11-06T15:30:00Z',
      };

      final alert = OperationalPainAlertItem.fromJson(json);

      expect(alert.id, 'alt-55');
      expect(alert.studentName, 'Rodrigo Santana');
      expect(alert.originalExercise, 'Desenvolvimento Militar');
      expect(alert.adaptedExercise, 'Elevação Lateral na Polia');
      expect(alert.painLocation, 'Ombro direito');
      expect(alert.severity, 'Moderada');

      final serialized = alert.toJson();
      expect(serialized['id'], 'alt-55');
      expect(serialized['pain_location'], 'Ombro direito');
    });

    test('TrainerOperationalCockpitData handles full payload and empty fallbacks', () {
      final json = {
        'sessions_completed_24h': 3,
        'exercises_completed_24h': 18,
        'estimated_sets_24h': 54,
        'pending_pain_alerts_count': 1,
        'recent_pain_alerts': [
          {
            'id': 'alt-1',
            'student_id': 'st-1',
            'student_name': 'Juliana Costa',
            'original_exercise': 'Agachamento',
            'adapted_exercise': 'Leg Press',
            'pain_location': 'Lombar',
            'severity': 'Alta',
            'created_at': '2026-11-06T18:00:00Z',
          }
        ],
        'inactive_students_count': 2,
        'inactive_students': [
          {
            'id': 'st-2',
            'full_name': 'Carlos Lima',
            'phone': '11988887777',
            'days_inactive': 6,
            'streak_days': 0,
            'recently_contacted_48h': false,
            'suggested_whatsapp_message': 'Bora treinar Carlos!',
          }
        ],
        'total_students': 15,
        'active_students_this_week': 13,
        'retention_rate': 87,
      };

      final cockpit = TrainerOperationalCockpitData.fromJson(json);

      expect(cockpit.sessionsCompleted24h, 3);
      expect(cockpit.exercisesCompleted24h, 18);
      expect(cockpit.estimatedSets24h, 54);
      expect(cockpit.pendingPainAlertsCount, 1);
      expect(cockpit.recentPainAlerts.length, 1);
      expect(cockpit.recentPainAlerts.first.originalExercise, 'Agachamento');
      expect(cockpit.inactiveStudentsCount, 2);
      expect(cockpit.inactiveStudents.length, 1);
      expect(cockpit.inactiveStudents.first.fullName, 'Carlos Lima');
      expect(cockpit.retentionRate, 87);

      // Test empty payload fallback
      final emptyCockpit = TrainerOperationalCockpitData.fromJson({});
      expect(emptyCockpit.sessionsCompleted24h, 0);
      expect(emptyCockpit.estimatedSets24h, 0);
      expect(emptyCockpit.recentPainAlerts, isEmpty);
      expect(emptyCockpit.inactiveStudents, isEmpty);
      expect(emptyCockpit.retentionRate, 100);
    });
  });
}
