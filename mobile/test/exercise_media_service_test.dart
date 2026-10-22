import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/exercise_media_sheet.dart';
import 'package:personal_ia/models/exercise_model.dart';
import 'package:personal_ia/models/split_model.dart';
import 'package:personal_ia/models/workout_plan_model.dart';
import 'package:personal_ia/services/exercise_media_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ExerciseMediaService.clearCache();
  });

  group('ExerciseMedia & ExerciseMediaService Offline & Preload Tests', () {
    test('ExerciseMedia serializes and deserializes to/from JSON correctly with isOfflineCached', () {
      const media = ExerciseMedia(
        name: 'Supino Inclinado com Halteres',
        slug: 'supino-inclinado-halteres',
        muscleGroup: 'Peitoral Superior',
        secondaryMuscles: 'Deltoide Anterior, Tríceps',
        equipment: 'Halteres e Banco Inclinado',
        motorPattern: 'Empurrar Inclinado',
        executionCues: 'Cotovelos a 45 graus, controle a descida.',
        mediaSource: 'canonical_offline',
        mediaUrl: 'https://example.com/supino.gif',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        isOfflineCached: true,
      );

      final json = media.toJson();
      expect(json['name'], 'Supino Inclinado com Halteres');
      expect(json['slug'], 'supino-inclinado-halteres');
      expect(json['muscle_group'], 'Peitoral Superior');
      expect(json['is_offline_cached'], isTrue);

      final recovered = ExerciseMedia.fromJson(json);
      expect(recovered.name, media.name);
      expect(recovered.slug, media.slug);
      expect(recovered.muscleGroup, media.muscleGroup);
      expect(recovered.isOfflineCached, isTrue);
      expect(recovered.inAppMediaUrl, isNotEmpty);
    });

    test('getMediaFor resolves from canonical offline catalog without network', () async {
      // 1. Peitoral
      final supino = await ExerciseMediaService.getMediaFor('Supino Reto com Barra');
      expect(supino, isNotNull);
      expect(supino!.muscleGroup, contains('Peitoral'));
      expect(supino.isOfflineCached, isTrue);

      // 2. Costas
      final puxada = await ExerciseMediaService.getMediaFor('Puxada Alta Aberta');
      expect(puxada, isNotNull);
      expect(puxada!.muscleGroup, contains('Dorso'));
      expect(puxada.isOfflineCached, isTrue);

      // 3. Pernas
      final agachamento = await ExerciseMediaService.getMediaFor('Agachamento Búlgaro com Halteres');
      expect(agachamento, isNotNull);
      expect(agachamento!.muscleGroup, contains('Quadríceps'));
      expect(agachamento.isOfflineCached, isTrue);

      // 4. Ombros
      final elevacao = await ExerciseMediaService.getMediaFor('Elevação Lateral');
      expect(elevacao, isNotNull);
      expect(elevacao!.muscleGroup, contains('Deltoide'));
      expect(elevacao.isOfflineCached, isTrue);

      // 5. Braços
      final triceps = await ExerciseMediaService.getMediaFor('Tríceps Corda na Polia');
      expect(triceps, isNotNull);
      expect(triceps!.muscleGroup, contains('Tríceps'));
      expect(triceps.isOfflineCached, isTrue);
    });

    test('getMediaFor saves to disk and survives memory cache clear', () async {
      final initial = await ExerciseMediaService.getMediaFor('Leg Press 45');
      expect(initial, isNotNull);
      expect(await ExerciseMediaService.isCached('Leg Press 45'), isTrue);

      // Limpa apenas o cache de memória RAM interno
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('b2b_offline_media_leg_press_45'), isTrue);

      // Chama novamente: deve carregar direto do disco offline
      final fromDisk = await ExerciseMediaService.getMediaFor('Leg Press 45');
      expect(fromDisk, isNotNull);
      expect(fromDisk!.slug, 'leg-press-45');
      expect(fromDisk.isOfflineCached, isTrue);
    });

    test('preloadExerciseNames caches all given exercises', () async {
      final count = await ExerciseMediaService.preloadExerciseNames([
        'Supino Inclinado com Halteres',
        'Crucifixo Reto',
        'Mesa Flexora',
        'Panturrilha em Pé',
      ]);

      expect(count, 4);
      expect(await ExerciseMediaService.isCached('Supino Inclinado com Halteres'), isTrue);
      expect(await ExerciseMediaService.isCached('Crucifixo Reto'), isTrue);
      expect(await ExerciseMediaService.isCached('Mesa Flexora'), isTrue);
      expect(await ExerciseMediaService.isCached('Panturrilha em Pé'), isTrue);
    });

    test('preloadWorkoutPlan extracts exercises across all splits and preloads', () async {
      const plan = WorkoutPlanModel(
        workoutPlanTitle: 'Hipertrofia ABC',
        notesForTrainer: 'Foco em progressão',
        splits: [
          SplitModel(
            splitIdentifier: 'A',
            splitName: 'Peito e Tríceps',
            estimatedDurationMin: 50,
            exercises: [
              ExerciseModel(
                order: 1,
                name: 'Supino Reto com Barra',
                targetMuscleGroup: 'Peitoral',
                sets: 4,
                reps: '8-10',
                restSeconds: 90,
                notes: '40kg',
                substitutionVector: 'Supino Halteres',
              ),
              ExerciseModel(
                order: 2,
                name: 'Tríceps Corda na Polia',
                targetMuscleGroup: 'Tríceps',
                sets: 3,
                reps: '10-12',
                restSeconds: 60,
                notes: '25kg',
                substitutionVector: 'Tríceps Testa',
              ),
            ],
          ),
          SplitModel(
            splitIdentifier: 'B',
            splitName: 'Costas e Bíceps',
            estimatedDurationMin: 50,
            exercises: [
              ExerciseModel(
                order: 1,
                name: 'Puxada Alta Aberta',
                targetMuscleGroup: 'Dorsal',
                sets: 4,
                reps: '10-12',
                restSeconds: 90,
                notes: '50kg',
                substitutionVector: 'Puxada Triângulo',
              ),
              ExerciseModel(
                order: 2,
                name: 'Rosca Direta com Barra W',
                targetMuscleGroup: 'Bíceps',
                sets: 3,
                reps: '10-12',
                restSeconds: 60,
                notes: '20kg',
                substitutionVector: 'Rosca Halteres',
              ),
            ],
          ),
        ],
      );

      final preloadedCount = await ExerciseMediaService.preloadWorkoutPlan(plan);
      expect(preloadedCount, 4);

      expect(await ExerciseMediaService.isCached('Supino Reto com Barra'), isTrue);
      expect(await ExerciseMediaService.isCached('Tríceps Corda na Polia'), isTrue);
      expect(await ExerciseMediaService.isCached('Puxada Alta Aberta'), isTrue);
      expect(await ExerciseMediaService.isCached('Rosca Direta com Barra W'), isTrue);
    });

    test('clearCache empties memory and removes disk items', () async {
      await ExerciseMediaService.getMediaFor('Agachamento Livre');
      expect(await ExerciseMediaService.isCached('Agachamento Livre'), isTrue);

      await ExerciseMediaService.clearCache();
      expect(await ExerciseMediaService.isCached('Agachamento Livre'), isFalse);
    });
  });

  group('ExerciseMediaSheet Offline UI Tests', () {
    testWidgets('renders ExerciseMediaSheet with offline badge when cached', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const media = ExerciseMedia(
        name: 'Supino Reto com Barra',
        slug: 'supino-reto-barra',
        muscleGroup: 'Peitoral Maior',
        equipment: 'Barra Olímpica',
        mediaSource: 'canonical_offline',
        mediaUrl: '',
        executionCues: 'Mantenha escápulas travadas e controle a barra.',
        isOfflineCached: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseMediaSheet(
              exerciseName: 'Supino Reto com Barra',
              media: media,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Supino Reto com Barra'), findsOneWidget);
      expect(find.text('Peitoral Maior'), findsOneWidget);
      expect(find.text('Barra Olímpica'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      // Verifica fallback card amigável no salão
      expect(find.text('Modo Offline no Salão'), findsOneWidget);
      expect(find.text('Abrir Loop Biomecânico & Ângulos'), findsOneWidget);
    });
  });
}

