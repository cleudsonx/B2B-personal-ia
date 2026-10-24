import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/services/offline_sync_service.dart';
import 'package:personal_ia/features/client/client_focus_workout_screen.dart';
import 'package:personal_ia/models/exercise_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('ClientFocusWorkoutScreen restores completed exercises and partial sets across sessions', (tester) async {
    // 1. Pré-salva no OfflineSyncService um progresso onde o Exercício 1 está 100% feito
    // e o Exercício 2 tem 1 de 3 séries feitas (parcial)
    await OfflineSyncService.instance.saveWorkoutDraft('guest', {
      'splitIdentifier': 'A',
      'splits': {
        'A': {
          'splitIdentifier': 'A',
          'currentExerciseIndex': 1,
          'elapsedSeconds': 180,
          'exerciseSets': {
            '0': [
              {'setNumber': 1, 'weightKg': 32.5, 'reps': 10, 'isCompleted': true},
              {'setNumber': 2, 'weightKg': 32.5, 'reps': 10, 'isCompleted': true},
              {'setNumber': 3, 'weightKg': 32.5, 'reps': 10, 'isCompleted': true},
            ],
            '1': [
              {'setNumber': 1, 'weightKg': 16.0, 'reps': 12, 'isCompleted': true},
              {'setNumber': 2, 'weightKg': 16.0, 'reps': 12, 'isCompleted': false},
              {'setNumber': 3, 'weightKg': 16.0, 'reps': 12, 'isCompleted': false},
            ],
          },
        },
      },
    });

    // 2. Abre o Modo Foco no Exercício 1 (índice 0) passando initialCompletedIndices: {0}
    await tester.pumpWidget(
      MaterialApp(
        home: ClientFocusWorkoutScreen(
          workoutTitle: 'Treino A · Peito e Ombros',
          splitIdentifier: 'A',
          splitName: 'Superior',
          exercises: mockExercises,
          trainerName: 'Prof. Cleudson',
          workoutLocation: 'Academia Completa',
          initialExerciseIndex: 0,
          initialCompletedIndices: const {0},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Deve exibir o banner de Exercício Concluído Hoje no Exercício 1 e a carga restaurada
    expect(find.textContaining('EXERCÍCIO CONCLUÍDO HOJE (3/3 séries feitas)'), findsOneWidget);
    expect(find.text('32.5 kg'), findsWidgets);

    // 3. Avança para o Exercício 2 (que possui séries parciais salvas)
    await tester.tap(find.text('Próximo Exercício'));
    await tester.pumpAndSettle();

    expect(find.text('Desenvolvimento com Halteres'), findsOneWidget);
    expect(find.textContaining('SÉRIES PARCIAIS SALVAS (1/3 feitas) • Continue na Série #2'), findsOneWidget);
    expect(find.text('16.0 kg'), findsWidgets);
  });
}
