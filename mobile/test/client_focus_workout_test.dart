import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/client/client_focus_workout_screen.dart';
import 'package:personal_ia/models/exercise_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<ExerciseModel> mockExercises = [
    const ExerciseModel(
      name: 'Supino Reto com Barra',
      targetMuscleGroup: 'Peitoral Maior',
      order: 1,
      sets: 3,
      reps: '10',
      restSeconds: 60,
      notes: 'Descer com cadência de 2s. Carga: 30kg',
      substitutionVector: 'peitoral_maior_supino',
    ),
    const ExerciseModel(
      name: 'Desenvolvimento com Halteres',
      targetMuscleGroup: 'Deltoides',
      order: 2,
      sets: 3,
      reps: '12',
      restSeconds: 60,
      notes: 'Manter cotovelos fechados. Carga: 14kg',
      substitutionVector: 'deltoide_anterior_desenvolvimento',
    ),
  ];

  testWidgets('ClientFocusWorkoutScreen renders exercise and increments weight without keyboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientFocusWorkoutScreen(
          workoutTitle: 'Treino A · Peito e Ombros',
          splitIdentifier: 'A',
          splitName: 'Superior',
          exercises: mockExercises,
          trainerName: 'Prof. Cleudson',
          workoutLocation: 'Academia Completa',
        ),
      ),
    );

    // Verifica que o primeiro exercício é exibido
    expect(find.text('Supino Reto com Barra'), findsOneWidget);
    expect(find.text('A · EXERCÍCIO 1/2'), findsOneWidget);

    // Verifica o seletor de carga inicial (extraído das notas: 30kg)
    expect(find.text('30.0 kg'), findsWidgets);

    // Toca no botão [+] para incrementar a carga
    final plusButton = find.byIcon(Icons.add).first;
    await tester.tap(plusButton);
    await tester.pump();

    // Carga deve ir para 32.5 kg sem abrir nenhum teclado
    expect(find.text('32.5 kg'), findsOneWidget);

    // Toca no check da série
    final checkButtons = find.byIcon(Icons.check_rounded);
    await tester.tap(checkButtons.first);
    await tester.pump();

    // Auto-Rest Timer deve iniciar
    expect(find.text('DESCANSO EM ANDAMENTO'), findsOneWidget);
  });
}
