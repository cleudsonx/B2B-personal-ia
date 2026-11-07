import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/models/clinical_profile_model.dart';
import 'package:personal_ia/models/exercise_model.dart';
import 'package:personal_ia/models/split_model.dart';
import 'package:personal_ia/models/workout_plan_model.dart';

void main() {
  group('Hub de Anamnese Clínica & Inteligência de Lesões', () {
    test('Modelos clínicos: parsing JSON e geração de JSON', () {
      final jsonRestriction = {
        'joint': 'knee',
        'severity': 'severe',
        'conditions': ['Condromalácia', 'Menisco'],
        'avoid_vectors': ['Flexão profunda > 90°'],
        'notes': 'Evitar agachamento profundo',
      };

      final restriction = ClinicalJointRestriction.fromJson(jsonRestriction);
      expect(restriction.joint, 'knee');
      expect(restriction.jointLabel, 'Joelho');
      expect(restriction.severity, 'severe');
      expect(restriction.severityLabel, 'Grave');
      expect(restriction.conditions.length, 2);
      expect(restriction.toJson()['joint'], 'knee');

      final jsonReport = {
        'is_safe': false,
        'overall_risk': 'critical_danger',
        'total_exercises_checked': 5,
        'contraindications_count': 1,
        'dangerous_exercises': [
          {
            'exercise_name': 'Cadeira Extensora',
            'joint': 'knee',
            'severity': 'severe',
            'reason': 'Pico de cisalhamento patelofemoral nos últimos 30° de extensão',
            'avoid_vector': 'Cadeia aberta com braço de alavanca longo terminal',
            'safe_substitute': 'Leg Press 45° com Pés Altos e Amplitude Protegida',
          }
        ],
        'protective_recommendation': 'Adaptação cinesiológica recomendada.',
      };

      final report = BiomechanicalSafetyReportModel.fromJson(jsonReport);
      expect(report.isSafe, isFalse);
      expect(report.overallRisk, 'critical_danger');
      expect(report.contraindicationsCount, 1);
      expect(report.dangerousExercises.first.exerciseName, 'Cadeira Extensora');
      expect(report.dangerousExercises.first.safeSubstitute,
          'Leg Press 45° com Pés Altos e Amplitude Protegida');
    });

    test('Mecanismo de Substituição Protetora 1-Toque em WorkoutPlanModel', () {
      // 1. Cria um plano com exercício contraindicado
      final originalPlan = WorkoutPlanModel(
        workoutPlanTitle: 'Treino A/B Hipertrofia',
        notesForTrainer: 'Foco inicial',
        splits: [
          SplitModel(
            splitIdentifier: 'A',
            splitName: 'Inferiores',
            estimatedDurationMin: 50,
            exercises: [
              const ExerciseModel(
                order: 1,
                name: 'Leg Press 45°',
                targetMuscleGroup: 'Quadríceps',
                sets: 4,
                reps: '10-12',
                restSeconds: 60,
                notes: 'Base dos pés confortável',
                substitutionVector: '',
              ),
              const ExerciseModel(
                order: 2,
                name: 'Cadeira Extensora',
                targetMuscleGroup: 'Quadríceps',
                sets: 3,
                reps: '12-15',
                restSeconds: 45,
                notes: 'Amplitude total',
                substitutionVector: '',
              ),
            ],
          ),
        ],
      );

      final dangerous = [
        const ContraindicatedExerciseModel(
          exerciseName: 'Cadeira Extensora',
          joint: 'knee',
          severity: 'severe',
          reason: 'Cisalhamento patelofemoral nos últimos 30° de extensão',
          avoidVector: 'Cadeia aberta terminal',
          safeSubstitute: 'Agachamento Búlgaro com Apoio e Tronco Inclinado',
        ),
      ];

      // 2. Simula o algoritmo de substituição protetora
      final replacements = <String, ContraindicatedExerciseModel>{};
      for (final d in dangerous) {
        replacements[d.exerciseName.toLowerCase().trim()] = d;
      }

      int appliedCount = 0;
      final updatedSplits = originalPlan.splits.map((split) {
        final updatedExercises = split.exercises.map((ex) {
          final exLower = ex.name.toLowerCase().trim();
          ContraindicatedExerciseModel? match;
          for (final entry in replacements.entries) {
            if (exLower.contains(entry.key) || entry.key.contains(exLower)) {
              match = entry.value;
              break;
            }
          }

          if (match != null && match.safeSubstitute.isNotEmpty) {
            appliedCount++;
            return ex.copyWith(
              name: match.safeSubstitute,
              notes: 'Substituição protetora (Blindagem Cinesiológica - ${match.joint}): ${match.reason}',
            );
          }
          return ex;
        }).toList();

        return split.copyWith(exercises: updatedExercises);
      }).toList();

      final safePlan = originalPlan.copyWith(splits: updatedSplits);

      // 3. Validações
      expect(appliedCount, 1);
      expect(safePlan.splits.first.exercises[1].name,
          'Agachamento Búlgaro com Apoio e Tronco Inclinado');
      expect(safePlan.splits.first.exercises[1].notes,
          contains('Blindagem Cinesiológica - knee'));
      expect(safePlan.splits.first.exercises[0].name, 'Leg Press 45°');
    });

    testWidgets('Widget de Alerta Biomecânico renderiza aviso e substituto',
        (tester) async {
      final report = BiomechanicalSafetyReportModel(
        isSafe: false,
        overallRisk: 'warning',
        totalExercisesChecked: 4,
        contraindicationsCount: 1,
        dangerousExercises: const [
          ContraindicatedExerciseModel(
            exerciseName: 'Desenvolvimento Militar Barra',
            joint: 'shoulder',
            severity: 'moderate',
            reason: 'Impacto no manguito rotador em overhead press',
            avoidVector: 'Press vertical',
            safeSubstitute: 'Elevação Lateral na Polia em Plano Escapular',
          ),
        ],
        protectiveRecommendation: 'Substituição indicada.',
      );

      bool clickedApply = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Container(
                key: const Key('clinical_safety_alert_banner'),
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text('Alerta Biomecânico: ${report.contraindicationsCount} Contraindicação(ões)'),
                    ...report.dangerousExercises.map((d) => Column(
                          children: [
                            Text(d.exerciseName),
                            Text('Motivo: ${d.reason}'),
                            Text('Substituto sugerido: ${d.safeSubstitute}'),
                          ],
                        )),
                    ElevatedButton(
                      key: const Key('btn_apply_protective_substitutes'),
                      onPressed: () {
                        clickedApply = true;
                      },
                      child: const Text('Aplicar Substituições Seguras (1-Toque)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alerta Biomecânico: 1 Contraindicação(ões)'), findsOneWidget);
      expect(find.text('Desenvolvimento Militar Barra'), findsOneWidget);
      expect(find.text('Substituto sugerido: Elevação Lateral na Polia em Plano Escapular'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_apply_protective_substitutes')));
      await tester.pump();
      expect(clickedApply, isTrue);
    });
  });
}
