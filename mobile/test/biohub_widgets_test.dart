import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/models/biohub_model.dart';
import 'package:personal_ia/features/client/widgets/readiness_gauge_card.dart';
import 'package:personal_ia/features/client/widgets/muscle_recovery_heatmap_widget.dart';
import 'package:personal_ia/features/trainer/widgets/deload_radar_banner.dart';

void main() {
  group('Bio-Hub 3.0 Widget Tests', () {
    testWidgets('ReadinessGaugeCard renderiza score, headline e fatores', (tester) async {
      const readiness = ReadinessScoreModel(
        score: 88,
        level: 'high',
        headline: '🚀 Prontidão Neuromuscular Máxima!',
        recommendation: 'Corpo pronto para bater recorde hoje.',
        sleepFactor: 5.0,
        fatigueFactor: 0.0,
        jointFactor: 0.0,
        streakFactor: 0.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadinessGaugeCard(readiness: readiness),
          ),
        ),
      );

      expect(find.text('88'), findsOneWidget);
      expect(find.text('READINESS'), findsOneWidget);
      expect(find.text('Alta Prontidão'), findsOneWidget);
      expect(find.text('🚀 Prontidão Neuromuscular Máxima!'), findsOneWidget);
      expect(find.text('Corpo pronto para bater recorde hoje.'), findsOneWidget);
      expect(find.text('Sono'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('Registrar Sono & Prontidão'), findsOneWidget);

      // Clica no botão para abrir modal
      await tester.tap(find.text('Registrar Sono & Prontidão'));
      await tester.pumpAndSettle();

      expect(find.text('Calibrar Prontidão Diária'), findsOneWidget);
      expect(find.text('Salvar e Atualizar Score'), findsOneWidget);
    });

    testWidgets('MuscleRecoveryHeatmapWidget renderiza 6 grupamentos anatômicos', (tester) async {
      final report = MuscleRecoveryReportModel(
        overallRecoveryPercentage: 78,
        readyMusclesCount: 4,
        fatiguedMusclesCount: 1,
        summary: 'Boa recuperação geral. Peito ainda em reparo.',
        muscles: const [
          MuscleRecoveryItemModel(
            muscleGroup: 'chest',
            label: 'Peitoral',
            recoveryPercentage: 35,
            status: 'fatigued',
            hoursUntilRecovered: 31,
          ),
          MuscleRecoveryItemModel(
            muscleGroup: 'back',
            label: 'Dorsais / Costas',
            recoveryPercentage: 100,
            status: 'recovered',
            hoursUntilRecovered: 0,
          ),
          MuscleRecoveryItemModel(
            muscleGroup: 'quadriceps',
            label: 'Quadríceps',
            recoveryPercentage: 100,
            status: 'recovered',
            hoursUntilRecovered: 0,
          ),
          MuscleRecoveryItemModel(
            muscleGroup: 'hamstrings_glutes',
            label: 'Posterior & Glúteos',
            recoveryPercentage: 80,
            status: 'recovering',
            hoursUntilRecovered: 14,
          ),
          MuscleRecoveryItemModel(
            muscleGroup: 'shoulders',
            label: 'Ombros / Deltoides',
            recoveryPercentage: 100,
            status: 'recovered',
            hoursUntilRecovered: 0,
          ),
          MuscleRecoveryItemModel(
            muscleGroup: 'arms_core',
            label: 'Braços & Core',
            recoveryPercentage: 100,
            status: 'recovered',
            hoursUntilRecovered: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MuscleRecoveryHeatmapWidget(report: report),
          ),
        ),
      );

      expect(find.text('Recuperação Muscular'), findsOneWidget);
      expect(find.text('78% Total'), findsOneWidget);
      expect(find.text('Peitoral'), findsOneWidget);
      expect(find.text('Dorsais / Costas'), findsOneWidget);
      expect(find.text('Faltam 31h'), findsOneWidget);
      expect(find.text('Pronto'), findsNWidgets(4));
    });

    testWidgets('DeloadRadarBanner renderiza alertas de alunos em risco', (tester) async {
      const radar = TrainerFatigueRadarModel(
        trainerId: 'trainer-01',
        totalStudents: 10,
        highReadinessCount: 7,
        moderateReadinessCount: 1,
        lowReadinessCount: 1,
        criticalReadinessCount: 1,
        studentsNeedingDeload: [
          {
            'student_id': 'student-1',
            'student_name': 'Lucas Fadiga',
            'readiness_score': 32,
            'urgency': 'high',
            'reasons': ['3 sessões consecutivas com RPE >= 9.0'],
          }
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeloadRadarBanner(radar: radar),
          ),
        ),
      );

      expect(find.text('Alerta de Fadiga & Deload (1)'), findsOneWidget);
      expect(find.text('Lucas Fadiga'), findsOneWidget);
      expect(find.text('3 sessões consecutivas com RPE >= 9.0'), findsOneWidget);
      expect(find.text('Score: 32'), findsOneWidget);
    });
  });
}
