import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/workout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutService Students Refresh & Propagation Tests', () {
    test('studentsRefreshNotifier updates value on trigger', () {
      final initialVal = WorkoutService.studentsRefreshNotifier.value;
      var notified = false;

      void listener() {
        notified = true;
      }

      WorkoutService.studentsRefreshNotifier.addListener(listener);
      WorkoutService.studentsRefreshNotifier.value++;

      expect(WorkoutService.studentsRefreshNotifier.value, equals(initialVal + 1));
      expect(notified, isTrue);

      WorkoutService.studentsRefreshNotifier.removeListener(listener);
    });
  });
}
