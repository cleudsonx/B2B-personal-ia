import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/student_overload_center_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExerciseOverloadData Model & Science Calculations', () {
    test('computes 1RM Epley and Brzycki correctly', () {
      const data = ExerciseOverloadData(
        exerciseName: 'Supino Reto com Barra',
        muscleGroup: 'Peitoral Maior',
        currentWeightKg: 80.0,
        currentReps: 10,
        initialWeightKg: 60.0,
        lastRpe: 8,
        weeklyVolumesKg: [2400, 2600, 2800, 3200],
      );

      // Epley: 80 * (1 + 10/30) = 80 * 1.3333 = 106.7 kg
      expect(data.estimatedOneRmEpley, 106.7);

      // Brzycki: 80 * 36 / (37 - 10) = 80 * 36 / 27 = 106.7 kg
      expect(data.estimatedOneRmBrzycki, 106.7);

      // Ganho de força: ((80 - 60) / 60) * 100 = 33.3%
      expect(data.strengthGainPercent, 33.3);
    });

    test('handles 1 rep boundary as exact weight', () {
      const data = ExerciseOverloadData(
        exerciseName: 'Levantamento Terra',
        muscleGroup: 'Posterior & Costas',
        currentWeightKg: 150.0,
        currentReps: 1,
        initialWeightKg: 120.0,
        lastRpe: 10,
        weeklyVolumesKg: [1200, 1500],
      );

      expect(data.estimatedOneRmEpley, 150.0);
      expect(data.estimatedOneRmBrzycki, 150.0);
      expect(data.strengthGainPercent, 25.0);
    });
  });

  group('StudentOverloadCenterSheet Widget Tests', () {
    testWidgets('renders StudentOverloadCenterSheet with 1RM, zones and volume chart',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => StudentOverloadCenterSheet.show(
                    context,
                    exerciseName: 'Supino Reto com Barra',
                  ),
                  child: const Text('Abrir Central 1RM'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Central 1RM'));
      await tester.pumpAndSettle();

      // Verifica Cabeçalho
      expect(find.text('Central de Sobrecarga & 1RM'), findsOneWidget);
      expect(find.text('Métricas de Força Máxima & Curva de Volume'), findsOneWidget);

      // Verifica 1RM Hero Card e Zonas
      expect(find.text('1RM TEÓRICO (EPLEY)'), findsOneWidget);
      expect(find.text('FORÇA'), findsOneWidget);
      expect(find.text('HIPERTROFIA'), findsOneWidget);
      expect(find.text('RESISTÊNCIA'), findsOneWidget);

      // Verifica Meta de Sobrecarga IA
      expect(find.text('META DE SOBRECARGA IA (PRÓXIMA SESSÃO)'), findsOneWidget);

      // Verifica Volume Acumulado
      expect(find.text('VOLUME TOTAL ACUMULADO (4 SEMANAS)'), findsOneWidget);

      // Verifica Simulador Interativo
      expect(find.text('SIMULADOR DE 1RM'), findsOneWidget);

      // Troca para outro exercício via ChoiceChip
      await tester.tap(find.text('Agachamento Livre'));
      await tester.pumpAndSettle();

      expect(find.text('Agachamento Livre'), findsWidgets);

      // Fecha a folha tocando no botão
      await tester.tap(find.text('Entendido • Focar na Sobrecarga'));
      await tester.pumpAndSettle();

      expect(find.text('Central de Sobrecarga & 1RM'), findsNothing);
    });
  });
}

