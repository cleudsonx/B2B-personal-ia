import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/trainer/widgets/clinical_joint_matrix_selector.dart';
import 'package:personal_ia/models/clinical_profile_model.dart';

void main() {
  testWidgets('ClinicalJointMatrixSelector renderiza matriz e permite seleção de articulações',
      (tester) async {
    List<ClinicalJointRestriction> changedList = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClinicalJointMatrixSelector(
              initialRestrictions: const [],
              onChanged: (list) {
                changedList = list;
              },
            ),
          ),
        ),
      ),
    );

    // 1. Verifica renderização inicial
    expect(find.text('MATRIZ ARTICULAR & LESÕES'), findsOneWidget);
    expect(find.text('100% Saudável'), findsOneWidget);
    expect(find.text('Ombro'), findsOneWidget);
    expect(find.text('Coluna Lombar'), findsOneWidget);
    expect(find.text('Joelho'), findsOneWidget);

    // 2. Toca em "Ombro"
    await tester.tap(find.text('Ombro'));
    await tester.pumpAndSettle();

    expect(changedList.length, 1);
    expect(changedList.first.joint, 'shoulder');
    expect(changedList.first.severity, 'moderate');

    // 3. Painel de blindagem ativa deve ter aparecido
    expect(find.text('BLINDAGEM BIOMECÂNICA ATIVA (1)'), findsOneWidget);
    expect(find.text('Manguito'), findsOneWidget);

    // 4. Toca no chip "Manguito"
    await tester.tap(find.text('Manguito'));
    await tester.pumpAndSettle();

    expect(changedList.first.conditions.contains('Manguito'), isTrue);

    // 5. Altera severidade para "Grave"
    await tester.tap(find.text('Grave'));
    await tester.pumpAndSettle();

    expect(changedList.first.severity, 'severe');

    // 6. Toca em "100% Saudável" para limpar tudo
    await tester.tap(find.text('100% Saudável'));
    await tester.pumpAndSettle();

    expect(changedList.isEmpty, isTrue);
    expect(find.text('BLINDAGEM BIOMECÂNICA ATIVA (1)'), findsNothing);
  });
}
