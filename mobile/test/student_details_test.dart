import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/trainer/presentation/screens/student_details_screen.dart';

Map<String, dynamic> _student() => {
      'id': 'student-1',
      'full_name': 'Maria Souza',
      'email': 'maria@example.com',
      'phone': '11999990000',
      'goal': 'Condicionamento Geral',
      'injuries_or_restrictions': 'Nenhuma',
      'status': 'Ativo',
    };

Future<void> _openDetails(
  WidgetTester tester, {
  StudentUpdateAction? onUpdateStudent,
  StudentStatusAction? onUpdateStudentStatus,
  StudentDeleteAction? onDeleteStudent,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute<bool>(
                builder: (_) => StudentDetailsScreen(
                  studentData: _student(),
                  onUpdateStudent: onUpdateStudent,
                  onUpdateStudentStatus: onUpdateStudentStatus,
                  onDeleteStudent: onDeleteStudent,
                  loadActiveWorkout: (_) async => null,
                ),
              ),
            ),
            child: const Text('Abrir aluno'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir aluno'));
  await tester.pumpAndSettle();
}

Future<void> _tapAdministrationAction(WidgetTester tester, String label) async {
  final action = find.text(label).last;
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('edits profile fields and keeps login email read-only', (tester) async {
    String? savedName;
    String? savedGoal;

    await _openDetails(
      tester,
      onUpdateStudent: ({
        required studentId,
        fullName,
        phone,
        goal,
        injuriesOrRestrictions,
      }) async {
        expect(studentId, 'student-1');
        savedName = fullName;
        savedGoal = goal;
        return true;
      },
    );
    await _tapAdministrationAction(tester, 'Editar Perfil do Aluno');

    expect(find.byKey(const Key('student_email_read_only')), findsOneWidget);
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('student_full_name')),
    );
    expect(nameField.readOnly, isFalse);
    final emailField = tester.widget<TextFormField>(
      find.byKey(const Key('student_email_read_only')),
    );
    expect(emailField.readOnly, isTrue);

    await tester.enterText(
      find.byKey(const Key('student_full_name')),
      'Maria Souza Atualizada',
    );
    await tester.enterText(
      find.byKey(const Key('student_goal')),
      'Hipertrofia Muscular',
    );
    await tester.tap(find.byKey(const Key('save_student_profile')));
    await tester.pumpAndSettle();

    expect(savedName, 'Maria Souza Atualizada');
    expect(savedGoal, 'Hipertrofia Muscular');
  });

  testWidgets('archives only after confirmation', (tester) async {
    var archiveCalls = 0;
    await _openDetails(
      tester,
      onUpdateStudentStatus: ({required studentId, required status}) async {
        expect(studentId, 'student-1');
        expect(status, 'Arquivado');
        archiveCalls++;
        return true;
      },
    );

    await _tapAdministrationAction(tester, 'Arquivar Aluno');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(archiveCalls, 0);

    await _tapAdministrationAction(tester, 'Arquivar Aluno');
    await tester.tap(find.byKey(const Key('confirm_archive_student')));
    await tester.pumpAndSettle();
    expect(archiveCalls, 1);
  });

  testWidgets('deletes only after explicit confirmation', (tester) async {
    var deleteCalls = 0;
    await _openDetails(
      tester,
      onDeleteStudent: (studentId) async {
        expect(studentId, 'student-1');
        deleteCalls++;
        return true;
      },
    );

    await _tapAdministrationAction(tester, 'Excluir Definitivamente');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 0);

    await _tapAdministrationAction(tester, 'Excluir Definitivamente');
    await tester.tap(find.byKey(const Key('confirm_delete_student')));
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
  });
}