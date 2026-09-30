import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/main.dart';
import 'package:personal_ia/models/workout_plan_model.dart';
import 'package:personal_ia/models/split_model.dart';
import 'package:personal_ia/models/exercise_model.dart';

void main() {
  testWidgets('B2BPersonalIaApp loads LoginScreen without overflow', (WidgetTester tester) async {
    await tester.pumpWidget(const B2BPersonalIaApp());
    await tester.pumpAndSettle();

    expect(find.text('SHAIPADOS'), findsOneWidget);
    expect(find.text('Treinador Pro'), findsOneWidget);
    expect(find.text('Aluno no Salão'), findsOneWidget);
    expect(find.text('Lembrar acesso'), findsOneWidget);
  });

  test('WorkoutPlanModel JSON serialization for offline caching', () {
    const sample = WorkoutPlanModel(
      workoutPlanTitle: 'Periodização Hipertrofia A/B',
      notesForTrainer: 'Foco em peito e deltoides.',
      splits: [
        SplitModel(
          splitIdentifier: 'A',
          splitName: 'Peito e Tríceps',
          estimatedDurationMin: 50,
          exercises: [
            ExerciseModel(
              order: 1,
              name: 'Supino Reto com Halteres',
              targetMuscleGroup: 'Peitoral Maior',
              sets: 4,
              reps: '8-10',
              restSeconds: 90,
              notes: 'Escápulas aduzidas.',
              substitutionVector: 'Empurrar horizontal livre',
            ),
          ],
        ),
      ],
    );

    final json = sample.toJson();
    final reconstructed = WorkoutPlanModel.fromJson(json);

    expect(reconstructed.workoutPlanTitle, equals('Periodização Hipertrofia A/B'));
    expect(reconstructed.splits.length, equals(1));
    expect(reconstructed.splits.first.exercises.first.name, equals('Supino Reto com Halteres'));
    expect(reconstructed.splits.first.exercises.first.targetMuscleGroup, equals('Peitoral Maior'));
  });
}
