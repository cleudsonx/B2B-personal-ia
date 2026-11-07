import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/trainer/presentation/widgets/trainer_retention_radar.dart';
import 'package:personal_ia/models/operational_cockpit_model.dart';

void main() {
  testWidgets('TrainerRetentionRadar renders nothing when inactiveStudents is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerRetentionRadar(
            inactiveStudents: const [],
            onContactStudent: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Radar Anti-Evasão'), findsNothing);
  });

  testWidgets(
      'TrainerRetentionRadar renders at-risk students, displays 48h lock, and triggers WhatsApp callback',
      (tester) async {
    InactiveStudentCard? contactedStudent;

    final students = [
      const InactiveStudentCard(
        id: 'st-1',
        fullName: 'Lucas Pereira',
        phone: '11999998888',
        daysInactive: 5,
        streakDays: 0,
        recentlyContacted48h: false,
        suggestedWhatsappMessage: 'Fala Lucas! Bora treinar!',
      ),
      const InactiveStudentCard(
        id: 'st-2',
        fullName: 'Beatriz Lima',
        phone: '11988887777',
        daysInactive: 6,
        streakDays: 1,
        recentlyContacted48h: true,
        suggestedWhatsappMessage: 'Fala Beatriz! Bora treinar!',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrainerRetentionRadar(
              inactiveStudents: students,
              onContactStudent: (s) => contactedStudent = s,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Radar Anti-Evasão'), findsOneWidget);
    expect(find.text('2 em risco'), findsOneWidget);
    expect(find.text('>4 dias sem treino'), findsOneWidget);

    // Aluno 1: ativo para reengajamento
    expect(find.text('Lucas Pereira'), findsOneWidget);
    expect(find.text('Ausente há 5 dias'), findsOneWidget);
    expect(find.text('Reengajar WhatsApp (1-Toque)'), findsOneWidget);

    // Aluno 2: com trava anti-spam de 48h
    expect(find.text('Beatriz Lima'), findsOneWidget);
    expect(find.text('Ausente há 6 dias'), findsOneWidget);
    expect(find.text('Contatado (trava 48h)'), findsOneWidget);

    // Toca no reengajamento do Lucas
    await tester.tap(find.text('Reengajar WhatsApp (1-Toque)'));
    await tester.pump();

    expect(contactedStudent, isNotNull);
    expect(contactedStudent!.id, 'st-1');
    expect(contactedStudent!.fullName, 'Lucas Pereira');
  });
}
