import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/student_achievements_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StudentBadge Model & StudentAchievementsService Tests', () {
    test('canonicalBadges has valid tiers, icons and progress factors', () {
      final badges = StudentAchievementsService.canonicalBadges;
      expect(badges.isNotEmpty, isTrue);
      expect(badges.any((b) => b.id == 'first_triumph'), isTrue);
      expect(badges.any((b) => b.id == 'club_100_bench'), isTrue);

      final bench = badges.firstWhere((b) => b.id == 'club_100_bench');
      expect(bench.tier, BadgeTier.gold);
      expect(bench.progressFactor, 1.0);
      expect(bench.isUnlocked, isTrue);

      final streak = badges.firstWhere((b) => b.id == 'streak_10');
      expect(streak.progressFactor, 0.7);
      expect(streak.isUnlocked, isFalse);
    });

    test('loadBadges returns canonical and handles custom persistence', () async {
      final badges = await StudentAchievementsService.loadBadges(userId: 'test_user_1');
      expect(badges.length, StudentAchievementsService.canonicalBadges.length);

      // Atualiza um badge e salva
      final updated = badges.map((b) {
        if (b.id == 'streak_10') {
          return b.copyWith(
            isUnlocked: true,
            currentProgress: 10,
            progressLabel: '10 / 10 treinos',
          );
        }
        return b;
      }).toList();

      await StudentAchievementsService.saveBadges(updated, userId: 'test_user_1');

      final reloaded = await StudentAchievementsService.loadBadges(userId: 'test_user_1');
      final reloadedStreak = reloaded.firstWhere((b) => b.id == 'streak_10');
      expect(reloadedStreak.isUnlocked, isTrue);
      expect(reloadedStreak.currentProgress, 10.0);
    });
  });

  group('StudentAchievementsModalSheet Widget Tests', () {
    testWidgets('renders gallery, summary card, filter chips and opens badge details',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => StudentAchievementsModalSheet.show(
                    context,
                    userId: 'tester_1',
                    trainerName: 'Professor Bruno',
                  ),
                  child: const Text('Abrir Conquistas'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Conquistas'));
      await tester.pumpAndSettle();

      // Verifica cabeçalho
      expect(find.text('Galeria de Conquistas & Badges'), findsOneWidget);
      expect(find.text('Desbloqueie selos de força e consistência'), findsOneWidget);

      // Verifica Card Hero de resumo
      expect(find.text('STATUS DE CONQUISTAS'), findsOneWidget);
      expect(find.textContaining('Concluídas'), findsOneWidget);

      // Verifica filtros
      expect(find.textContaining('Todas'), findsOneWidget);
      expect(find.textContaining('Conquistadas'), findsOneWidget);
      expect(find.textContaining('Bloqueadas'), findsOneWidget);

      // Filtra por 'Conquistadas'
      await tester.tap(find.textContaining('Conquistadas'));
      await tester.pumpAndSettle();
      expect(find.text('Primeiro Triunfo'), findsOneWidget);

      // Clica em um badge para abrir o modal de detalhes
      await tester.tap(find.text('Primeiro Triunfo'));
      await tester.pumpAndSettle();

      expect(find.text('TIER BRONZE'), findsOneWidget);
      expect(find.text('Compartilhar Conquista'), findsOneWidget);

      // Toca em Compartilhar Conquista
      await tester.tap(find.text('Compartilhar Conquista'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Story de conquista gerado!'), findsOneWidget);

      // Fecha o modal de conquistas
      await tester.tap(find.text('Continuar Focado nos Treinos'));
      await tester.pumpAndSettle();

      expect(find.text('Galeria de Conquistas & Badges'), findsNothing);
    });
  });
}

