import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/models/biohub_model.dart';
import 'package:personal_ia/features/client/widgets/readiness_gauge_card.dart';
import 'package:personal_ia/features/client/widgets/muscle_recovery_heatmap_widget.dart';
import 'package:personal_ia/features/trainer/widgets/deload_radar_banner.dart';

void main() {
  group('Bio-Hub 3.0 & Telemetria Fisiológica Flow Tests', () {
    test('Modelos Bio-Hub: parsing, serialização e cálculos de prontidão', () {
      final jsonReadiness = {
        'score': 92,
        'level': 'high',
        'headline': '🚀 Prontidão Neuromuscular Máxima!',
        'recommendation': 'SNC recuperado. Excelente dia para buscar carga máxima.',
        'sleep_factor': 5.0,
        'fatigue_factor': 0.0,
        'joint_factor': 0.0,
        'streak_factor': 0.0,
      };

      final readiness = ReadinessScoreModel.fromJson(jsonReadiness);
      expect(readiness.score, 92);
      expect(readiness.isHigh, isTrue);
      expect(readiness.isCritical, isFalse);
      expect(readiness.levelLabel, 'Alta Prontidão');
      expect(readiness.scoreColor, const Color(0xFF10B981));
      expect(readiness.toJson()['score'], 92);

      // Score crítico (<40)
      final criticalReadiness = ReadinessScoreModel.fromJson({
        'score': 35,
        'level': 'critical',
        'headline': '🛑 Fadiga Aguda Acumulada',
        'recommendation': 'Repouso ativo recomendado.',
      });
      expect(criticalReadiness.isCritical, isTrue);
      expect(criticalReadiness.levelLabel, 'Crítica / Deload');
      expect(criticalReadiness.scoreColor, const Color(0xFFEF4444));
    });

    test('Modelos Bio-Hub: Cinética de Recuperação Muscular (6 grupamentos)', () {
      final jsonRecovery = {
        'overall_recovery_percentage': 82,
        'ready_muscles_count': 4,
        'fatigued_muscles_count': 1,
        'summary': 'Corpo em boa resposta adaptativa.',
        'muscles': [
          {
            'muscle_group': 'chest',
            'label': 'Peitoral',
            'recovery_percentage': 40,
            'status': 'fatigued',
            'hours_until_recovered': 28,
            'last_trained_hours_ago': 20.0,
          },
          {
            'muscle_group': 'back',
            'label': 'Dorsais / Costas',
            'recovery_percentage': 100,
            'status': 'recovered',
            'hours_until_recovered': 0,
            'last_trained_hours_ago': 72.0,
          },
          {
            'muscle_group': 'quadriceps',
            'label': 'Quadríceps',
            'recovery_percentage': 100,
            'status': 'recovered',
            'hours_until_recovered': 0,
          },
          {
            'muscle_group': 'hamstrings_glutes',
            'label': 'Posterior & Glúteos',
            'recovery_percentage': 75,
            'status': 'recovering',
            'hours_until_recovered': 18,
          },
          {
            'muscle_group': 'shoulders',
            'label': 'Ombros / Deltoides',
            'recovery_percentage': 100,
            'status': 'recovered',
            'hours_until_recovered': 0,
          },
          {
            'muscle_group': 'arms_core',
            'label': 'Braços & Core',
            'recovery_percentage': 100,
            'status': 'recovered',
            'hours_until_recovered': 0,
          },
        ],
      };

      final report = MuscleRecoveryReportModel.fromJson(jsonRecovery);
      expect(report.overallRecoveryPercentage, 82);
      expect(report.readyMusclesCount, 4);
      expect(report.fatiguedMusclesCount, 1);
      expect(report.muscles.length, 6);

      final chest = report.muscles.first;
      expect(chest.isFatigued, isTrue);
      expect(chest.isRecovered, isFalse);
      expect(chest.hoursUntilRecovered, 28);
      expect(chest.statusColor, const Color(0xFFEF4444));

      final back = report.muscles[1];
      expect(back.isRecovered, isTrue);
      expect(back.statusColor, const Color(0xFF10B981));
    });

    test('Modelos Bio-Hub: Evolução de Força, PRs e 1RM', () {
      final jsonEvolution = {
        'student_id': 'student-123',
        'total_volume_7d_kg': 14850.0,
        'prs_count': 3,
        'recent_prs': [
          {
            'exercise_name': 'Supino Reto com Barra',
            'weight_kg': 100.0,
            'reps': 6,
            'estimated_1rm': 116.1,
            'formula_used': 'brzycki',
            'volume_load_kg': 600.0,
            'achieved_at': '2026-11-07T10:00:00Z',
            'previous_1rm': 108.0,
            'gain_percent': 7.5,
          }
        ],
        'key_lifts': {
          'supino': {
            'exercise_name': 'Supino Reto com Barra',
            'weight_kg': 100.0,
            'reps': 6,
            'estimated_1rm': 116.1,
            'formula_used': 'brzycki',
            'volume_load_kg': 600.0,
            'achieved_at': '2026-11-07T10:00:00Z',
          }
        }
      };

      final evolution = StrengthEvolutionReportModel.fromJson(jsonEvolution);
      expect(evolution.totalVolume7dKg, 14850.0);
      expect(evolution.prsCount, 3);
      expect(evolution.recentPrs.length, 1);
      expect(evolution.recentPrs.first.estimated1rm, 116.1);
      expect(evolution.recentPrs.first.gainPercent, 7.5);
      expect(evolution.keyLifts.containsKey('supino'), isTrue);
    });

    testWidgets('Fluxo visual integrado: Readiness, Modal de Biometria e Radar de Deload',
        (tester) async {
      DailyBiometricLogModel? loggedBiometrics;
      String? selectedStudentId;

      const readiness = ReadinessScoreModel(
        score: 72,
        level: 'moderate',
        headline: '⚡ Prontidão Estável e Equilibrada',
        recommendation: 'Execute a planilha programada com boa cadência.',
        sleepFactor: 2.0,
        fatigueFactor: 0.0,
        jointFactor: 0.0,
        streakFactor: 0.0,
      );

      const radar = TrainerFatigueRadarModel(
        trainerId: 'coach-01',
        totalStudents: 12,
        highReadinessCount: 8,
        moderateReadinessCount: 2,
        lowReadinessCount: 1,
        criticalReadinessCount: 1,
        studentsNeedingDeload: [
          {
            'student_id': 'aluno-sobrecarga-01',
            'student_name': 'Renato Carioca',
            'readiness_score': 38,
            'urgency': 'high',
            'reasons': ['Fadiga acumulada em 3 sessões consecutivas'],
          }
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ReadinessGaugeCard(
                    readiness: readiness,
                    onLogBiometrics: (log) => loggedBiometrics = log,
                  ),
                  DeloadRadarBanner(
                    radar: radar,
                    onSelectStudent: (id) => selectedStudentId = id,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1. Verifica renderização do card de prontidão
      expect(find.text('72'), findsOneWidget);
      expect(find.text('Prontidão Estável'), findsOneWidget);
      expect(find.text('⚡ Prontidão Estável e Equilibrada'), findsOneWidget);

      // 2. Abre modal e submete biometria
      await tester.tap(find.text('Registrar Sono & Prontidão'));
      await tester.pumpAndSettle();

      expect(find.text('Calibrar Prontidão Diária'), findsOneWidget);
      await tester.tap(find.text('Salvar e Atualizar Score'));
      await tester.pumpAndSettle();

      expect(loggedBiometrics, isNotNull);
      expect(loggedBiometrics!.sleepHours, isNotNull);

      // 3. Verifica renderização do DeloadRadarBanner
      expect(find.text('Alerta de Fadiga & Deload (1)'), findsOneWidget);
      expect(find.text('Renato Carioca'), findsOneWidget);
      expect(find.text('Score: 38'), findsOneWidget);

      // Clica no aluno para acionar callback
      await tester.tap(find.text('Renato Carioca'));
      await tester.pump();
      expect(selectedStudentId, 'aluno-sobrecarga-01');
    });
  });
}
