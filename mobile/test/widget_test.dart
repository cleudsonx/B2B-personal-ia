import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/main.dart';
import 'package:personal_ia/models/workout_plan_model.dart';
import 'package:personal_ia/models/split_model.dart';
import 'package:personal_ia/models/exercise_model.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_main_layout.dart';

void main() {
  testWidgets('B2BPersonalIaApp loads LoginScreen without overflow', (WidgetTester tester) async {
    await tester.pumpWidget(const B2BPersonalIaApp());
    await tester.pumpAndSettle();

    expect(find.text('SHAIPADOS'), findsOneWidget);
    expect(find.text('Treinador Pro'), findsOneWidget);
    expect(find.text('Aluno no Salão'), findsOneWidget);
    expect(find.text('Lembrar acesso'), findsOneWidget);
  });

  testWidgets('trainer shell navigates across all five tabs', (WidgetTester tester) async {
    const tabs = ['Alunos', 'Treinos', 'Social', 'Vitrine'];
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerMainLayout(
          screens: [
            for (final tab in tabs)
              Scaffold(body: Center(child: Text('$tab body'))),
          ],
        ),
      ),
    );

    expect(find.text('Alunos body'), findsOneWidget);
    for (final tab in tabs.skip(1)) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('$tab body'), findsOneWidget);
    }

    await tester.tap(find.text('Conta').last);
    await tester.pumpAndSettle();
    expect(find.text('Verificação em duas etapas'), findsOneWidget);
  });

  testWidgets('legacy trainer entry resolves to the canonical shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen(activeRole: 'trainer')),
    );
    await tester.pump();

    expect(find.text('Alunos'), findsOneWidget);
    expect(find.text('Treinos'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Vitrine'), findsOneWidget);
    expect(find.text('Prescrição IA'), findsNothing);
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
