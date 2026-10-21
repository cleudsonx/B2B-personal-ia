import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/core/widgets/offline_sync_banner.dart';
import 'package:personal_ia/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineSyncService.pendingCountNotifier.value = 0;
    OfflineSyncService.isSyncingNotifier.value = false;
  });

  test('OfflineSyncService enqueues items and updates pending counter', () async {
    final service = OfflineSyncService.instance;
    const studentId = 'test_student_offline_1';

    expect(await service.refreshPendingCount(studentId), 0);

    await service.enqueue(studentId, OfflineItemType.exerciseLoad, {
      'exercise_name': 'Supino Reto',
      'load_kg': 40.0,
      'reps': 10,
    });

    final queue = await service.getQueue(studentId);
    expect(queue.length, 1);
    expect(queue.first.type, OfflineItemType.exerciseLoad);
    expect(queue.first.payload['exercise_name'], 'Supino Reto');
    expect(OfflineSyncService.pendingCountNotifier.value, 1);

    // Salvar rascunho de treino
    await service.saveWorkoutDraft(studentId, {
      'splitIdentifier': 'A',
      'currentPage': 1,
    });

    final draft = await service.getWorkoutDraft(studentId);
    expect(draft, isNotNull);
    expect(draft!['splitIdentifier'], 'A');

    await service.clearWorkoutDraft(studentId);
    expect(await service.getWorkoutDraft(studentId), isNull);
  });

  testWidgets('OfflineSyncBanner is hidden when 0 pending, and renders pill when items exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineSyncBanner(),
        ),
      ),
    );

    // Quando contador é 0, banner não exibe texto de pendência
    expect(find.text('1 treino/registro salvo offline'), findsNothing);

    // Simula 1 item pendente
    OfflineSyncService.pendingCountNotifier.value = 1;
    await tester.pumpAndSettle();

    expect(find.text('1 treino/registro salvo offline'), findsOneWidget);
    expect(find.text('Sincronizar'), findsOneWidget);

    // Simula 3 itens pendentes
    OfflineSyncService.pendingCountNotifier.value = 3;
    await tester.pumpAndSettle();

    expect(find.text('3 treinos/registros salvos offline'), findsOneWidget);
  });
}
