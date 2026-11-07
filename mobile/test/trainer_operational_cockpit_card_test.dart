import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/trainer/presentation/widgets/trainer_operational_cockpit_card.dart';
import 'package:personal_ia/models/operational_cockpit_model.dart';

void main() {
  testWidgets('TrainerOperationalCockpitCard displays metrics and handles 0 alerts cleanly',
      (tester) async {
    const data = TrainerOperationalCockpitData(
      sessionsCompleted24h: 4,
      exercisesCompleted24h: 24,
      estimatedSets24h: 72,
      pendingPainAlertsCount: 0,
      recentPainAlerts: [],
      inactiveStudentsCount: 1,
      inactiveStudents: [],
      totalStudents: 12,
      activeStudentsThisWeek: 11,
      retentionRate: 92,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerOperationalCockpitCard(data: data),
          ),
        ),
      ),
    );

    expect(find.text('Cockpit Operacional'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('72'), findsOneWidget); // Séries
    expect(find.text('0'), findsOneWidget); // Alertas
    expect(find.text('100% OK'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget); // Retenção
  });

  testWidgets('TrainerOperationalCockpitCard highlights pain alert and triggers callback',
      (tester) async {
    OperationalPainAlertItem? tappedAlert;

    const alert = OperationalPainAlertItem(
      id: 'alt-99',
      studentId: 'st-99',
      studentName: 'Mariana Souza',
      originalExercise: 'Supino Inclinado',
      adaptedExercise: 'Crucifixo Máquina',
      painLocation: 'Ombro esquerdo',
      severity: 'Moderada',
      createdAt: '2026-11-06T19:00:00Z',
    );

    final data = TrainerOperationalCockpitData(
      sessionsCompleted24h: 2,
      exercisesCompleted24h: 12,
      estimatedSets24h: 36,
      pendingPainAlertsCount: 1,
      recentPainAlerts: const [alert],
      inactiveStudentsCount: 0,
      totalStudents: 10,
      activeStudentsThisWeek: 10,
      retentionRate: 100,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerOperationalCockpitCard(
              data: data,
              onAlertTap: (a) => tappedAlert = a,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Requer atenção'), findsOneWidget);
    expect(find.textContaining('Mariana Souza'), findsOneWidget);
    expect(find.text('Ver Adaptação'), findsOneWidget);

    await tester.tap(find.text('Ver Adaptação'));
    await tester.pump();

    expect(tappedAlert, isNotNull);
    expect(tappedAlert!.id, 'alt-99');
  });
}
