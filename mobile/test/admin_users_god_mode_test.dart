import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_users_screen.dart';
import 'package:personal_ia/features/admin/services/admin_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Users & Personals ("God Mode") Service Tests', () {
    test('getUsers returns enriched user list and respects role filter', () async {
      final allUsers = await AdminDataService.getUsers(roleFilter: 'all');
      expect(allUsers, isNotEmpty);
      expect(allUsers.any((u) => u.role == 'trainer'), isTrue);
      expect(allUsers.any((u) => u.role == 'client'), isTrue);
      expect(allUsers.any((u) => u.isAdmin), isTrue);

      final trainersOnly = await AdminDataService.getUsers(roleFilter: 'trainer');
      expect(trainersOnly.every((u) => u.role == 'trainer' || u.roles.contains('trainer')), isTrue);
    });

    test('getUsers filters by plan and search query', () async {
      final eliteTrainers = await AdminDataService.getUsers(planFilter: 'elite coach');
      expect(eliteTrainers, isNotEmpty);
      expect(eliteTrainers.first.plan, 'Elite Coach');

      final searchResults = await AdminDataService.getUsers(searchQuery: 'Cariani');
      expect(searchResults.length, 1);
      expect(searchResults.first.name, contains('Cariani'));
      expect(searchResults.first.isVip, isTrue);
    });

    test('updateTrainerPlanAndQuota updates commercial quota and VIP status', () async {
      final success = await AdminDataService.updateTrainerPlanAndQuota(
        userId: 'usr_faro_1',
        planName: 'Elite Coach',
        maxStudents: 80,
        isVip: true,
        adminNotes: 'Upgrade promocional aprovado pela diretoria',
      );
      expect(success, isTrue);
    });

    test('updateUserCref updates and verifies document', () async {
      final success = await AdminDataService.updateUserCref(
        userId: 'usr_juliana_4',
        cref: '093211-G/PR',
        isVerified: true,
      );
      expect(success, isTrue);
    });

    test('reassignStudent updates trainer link', () async {
      final success = await AdminDataService.reassignStudent(
        studentId: 'usr_lucas_5',
        newTrainerId: 'usr_camilo_2',
        newTrainerName: 'Camilo Santana',
      );
      expect(success, isTrue);
    });

    test('revokeUserSessions triggers successfully', () async {
      final success = await AdminDataService.revokeUserSessions('usr_faro_1');
      expect(success, isTrue);
    });
  });

  group('AdminUsersScreen Widget Tests', () {
    testWidgets('renders KPI cards, search bar and role/plan filter chips', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminUsersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // KPIs
      expect(find.text('TOTAL USUÁRIOS'), findsOneWidget);
      expect(find.text('TREINADORES'), findsOneWidget);
      expect(find.text('ALUNOS'), findsOneWidget);
      expect(find.text('VIP / OVERRIDE'), findsOneWidget);

      // Search bar
      expect(find.byType(TextField), findsOneWidget);

      // Filter chips
      expect(find.textContaining('Todos ('), findsOneWidget);
      expect(find.textContaining('Treinadores ('), findsOneWidget);
      expect(find.textContaining('Alunos ('), findsOneWidget);
      expect(find.text('Todos Planos'), findsOneWidget);
    });

    testWidgets('opens God Mode modal for trainer and displays override options', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminUsersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Localiza o botão de superpoderes do primeiro trainer (usr_faro_1)
      final actionBtn = find.byKey(const Key('admin_user_action_usr_faro_1'));
      expect(actionBtn, findsOneWidget);

      await tester.tap(actionBtn);
      await tester.pumpAndSettle();

      // Confirma abertura do BottomSheet "God Mode"
      expect(find.text('PLANO SAAS & COTA DE VAGAS (OVERRIDE)'), findsOneWidget);
      expect(find.text('CREF PROFISSIONAL & COMPLIANCE'), findsOneWidget);
      expect(find.text('SEGURANÇA & GOVERNANÇA DE CONTA'), findsOneWidget);

      // Toca em Alterar Plano & Cota Livre
      expect(find.text('Alterar Plano & Cota Livre'), findsOneWidget);
      await tester.tap(find.text('Alterar Plano & Cota Livre'));
      await tester.pumpAndSettle();

      // Confirma que abriu o diálogo de Override
      expect(find.text('Override de Plano & Cota'), findsOneWidget);
      expect(find.text('Salvar Override'), findsOneWidget);

      // Cancela o diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });
}
