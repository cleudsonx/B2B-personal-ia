import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/batch_prescription_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MesocycleCloneConfig & BatchPrescriptionService Tests', () {
    test('executeClone returns failure when targetStudentIds is empty', () async {
      const config = MesocycleCloneConfig(
        sourceWorkoutId: 'w_1',
        sourceWorkoutTitle: 'Treino A',
        newCycleTitle: 'Treino A (Mesociclo 2)',
        durationWeeks: 4,
        loadProgressionKg: 2.5,
        repProgression: 1,
        targetStudentIds: [],
        targetStudentNames: [],
      );

      final result = await BatchPrescriptionService.executeClone(config: config);
      expect(result.success, isFalse);
      expect(result.totalCloned, 0);
      expect(result.message, contains('Nenhum aluno selecionado'));
    });

    test('executeClone clones successfully for selected students and formats message',
        () async {
      const config = MesocycleCloneConfig(
        sourceWorkoutId: 'w_1',
        sourceWorkoutTitle: 'Treino A',
        newCycleTitle: 'Treino A (Mesociclo 2)',
        durationWeeks: 6,
        loadProgressionKg: 5.0,
        repProgression: 2,
        targetStudentIds: ['std_1', 'std_2'],
        targetStudentNames: ['Carlos Silva', 'Ana Julia'],
      );

      final result = await BatchPrescriptionService.executeClone(config: config);
      expect(result.success, isTrue);
      expect(result.totalCloned, 2);
      expect(result.affectedStudents, ['Carlos Silva', 'Ana Julia']);
      expect(result.message, contains('2 mesociclos clonados'));
      expect(result.message, contains('+5.0kg / +2 rep'));
    });
  });

  group('BatchPrescriptionModalSheet Widget Tests', () {
    testWidgets('renders modal sheet, adjusts duration, sliders and triggers clone',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      BatchPrescriptionResult? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final res = await BatchPrescriptionModalSheet.show(
                      context,
                      initialWorkoutId: 'w_src_10',
                      initialWorkoutTitle: 'Hipertrofia ABC',
                      initialStudentId: 'std_alpha',
                      initialStudentName: 'Juliana Paes',
                      availableStudents: [
                        {'id': 'std_alpha', 'name': 'Juliana Paes'},
                        {'id': 'std_beta', 'name': 'Carlos Magno'},
                      ],
                    );
                    returnedResult = res;
                  },
                  child: const Text('Abrir Clonagem'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Clonagem'));
      await tester.pumpAndSettle();

      // Verifica Cabeçalho
      expect(find.text('Clonagem & Prescrição em Bloco'), findsOneWidget);
      expect(find.text('Duplicação de mesociclo com progressão automática'), findsOneWidget);

      // Verifica Duração e Clica em '6s'
      expect(find.text('6s'), findsOneWidget);
      await tester.tap(find.text('6s'));
      await tester.pumpAndSettle();
      expect(find.text('DURAÇÃO DO CICLO: 6 SEMANAS'), findsOneWidget);

      // Verifica Seleção de Alunos
      expect(find.text('Juliana Paes'), findsOneWidget);
      expect(find.text('Carlos Magno'), findsOneWidget);

      // Seleciona também Carlos Magno
      await tester.tap(find.text('Carlos Magno'));
      await tester.pumpAndSettle();

      // Clica em 'Clonar & Aplicar (2 Alunos)'
      expect(find.textContaining('Clonar & Aplicar'), findsOneWidget);
      await tester.tap(find.textContaining('Clonar & Aplicar'));
      await tester.pumpAndSettle();

      expect(returnedResult, isNotNull);
      expect(returnedResult!.success, isTrue);
      expect(returnedResult!.totalCloned, 2);
    });
  });
}
