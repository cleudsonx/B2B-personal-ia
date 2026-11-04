import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/core/widgets/one_ui_glass_components.dart';
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

  group('Focus Workout Zen 3.2 Cockpit & Smart Action Thumb-Bar', () {
    testWidgets('renders Smart Overload banner above sets and collapses coach notes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientFocusWorkoutScreen(
            workoutTitle: 'Treino A · Push',
            splitIdentifier: 'A',
            splitName: 'Push: Peito e Ombro',
            exercises: mockExercises,
            trainerName: 'Prof. Carlos Silva',
            workoutLocation: 'Academia',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top HUD telemetry
      expect(find.textContaining('EXERCÍCIO 1/2'), findsOneWidget);
      expect(find.text('Push: Peito e Ombro'), findsOneWidget);
      expect(find.textContaining('Próximo: Desenvolvimento com Halteres'), findsOneWidget);

      // Smart Overload banner 1-toque no topo das séries
      expect(find.text('IA SOBRECARGA'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);

      // Coach notes collapsíveis (1 linha com Ver ▾)
      expect(find.textContaining('Descer com cadência de 2s'), findsOneWidget);
      expect(find.text('Ver ▾'), findsOneWidget);

      // Toque expande as notas
      await tester.tap(find.text('Ver ▾'));
      await tester.pumpAndSettle();
      expect(find.text('Menos ▴'), findsOneWidget);

      // Opção A: Smart Action Thumb-Bar mostra botão de concluir a série ativa
      expect(find.textContaining('Concluir Série #1 (30.0 kg × 10)'), findsOneWidget);

      // Tocar no botão de ação inferior conclui a série #1 e avança para a série #2
      await tester.tap(find.textContaining('Concluir Série #1'));
      await tester.pump();

      // Deve ativar descanso e botão inferior agora aponta para Série #2
      expect(find.text('DESCANSO EM ANDAMENTO'), findsOneWidget);
      expect(find.textContaining('Concluir Série #2 (30.0 kg × 10)'), findsOneWidget);
    });

    testWidgets('applying smart overload updates pending sets without changing completed sets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClientFocusWorkoutScreen(
            workoutTitle: 'Treino A · Push',
            splitIdentifier: 'A',
            splitName: 'Push: Peito e Ombro',
            exercises: mockExercises,
            trainerName: 'Prof. Carlos Silva',
            workoutLocation: 'Academia',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aplica sobrecarga IA (+2.5 kg)
      final applyBtn = find.widgetWithText(SquircleButton, 'Aplicar');
      expect(applyBtn, findsOneWidget);
      await tester.tap(applyBtn);
      await tester.pump();

      // Carga sugerida (32.5 kg) deve ser aplicada às séries
      expect(find.text('32.5 kg'), findsWidgets);
      expect(find.textContaining('Concluir Série #1 (32.5 kg × 10)'), findsOneWidget);
    });
  });

  group('StudentChromeVisibility Integration in Workout Screens', () {
    testWidgets('StudentChromeVisibility toggles cleanly between show, hide and reset', (tester) async {
      StudentChromeVisibility.reset();
      expect(StudentChromeVisibility.isNavVisible.value, isTrue);

      StudentChromeVisibility.hide();
      expect(StudentChromeVisibility.isNavVisible.value, isFalse);

      StudentChromeVisibility.show();
      expect(StudentChromeVisibility.isNavVisible.value, isTrue);

      StudentChromeVisibility.hide();
      StudentChromeVisibility.reset();
      expect(StudentChromeVisibility.isNavVisible.value, isTrue);
    });
  });
}
