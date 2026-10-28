import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/shaipados_loaders.dart';
import 'package:personal_ia/core/widgets/ai_generation_stepper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ShaipadosLoaderContainer.enableAutoAnimate = false;
  });

  tearDown(() {
    ShaipadosLoaderContainer.enableAutoAnimate = true;
  });

  group('ShaipadosLoaderContainer Tests', () {
    testWidgets('renders mrCoachEvolution loader in Dark Mode with default messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.mrCoachEvolution,
              customTitle: 'Gerando Periodização',
            ),
          ),
        ),
      );

      expect(find.text('SHAIPADOS LABS • MR. COACH'), findsOneWidget);
      expect(find.text('Gerando Periodização'), findsOneWidget);
      expect(find.textContaining('Fase 1: Analisando'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders labShakerDna loader in Light Mode with custom messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.labShakerDna,
              customTitle: 'Sincronizando Labs',
              loadingMessages: ['Mensagem customizada 1'],
            ),
          ),
        ),
      );

      expect(find.text('SHAIPADOS LABS • MR. COACH'), findsOneWidget);
      expect(find.text('Sincronizando Labs'), findsOneWidget);
      expect(find.text('Mensagem customizada 1'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders barbellPlates loader with progressOverride and onCancel', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.barbellPlates,
              customTitle: 'Adaptando Exercício',
              progressOverride: 0.75,
              onCancel: () {
                cancelled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Adaptando Exercício'), findsOneWidget);
      expect(find.text('Cancelar operação'), findsOneWidget);

      await tester.tap(find.text('Cancelar operação'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('renders standalone loader when isOverlay is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.mrCoachEvolution,
              isOverlay: false,
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('SHAIPADOS LABS • MR. COACH'), findsOneWidget);
    });

    testWidgets('renders all 6 approved contextual loaders cleanly', (tester) async {
      for (final type in [
        ShaipadosLoaderType.activityRings,
        ShaipadosLoaderType.bioPulseEcg,
        ShaipadosLoaderType.neuralAiOrb,
        ShaipadosLoaderType.kineticHexCore,
        ShaipadosLoaderType.executiveShimmer,
        ShaipadosLoaderType.chronoBar,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: ShaipadosLoaderContainer(
                type: type,
                customTitle: 'Teste ${type.name}',
              ),
            ),
          ),
        );

        expect(find.text('SHAIPADOS LABS • MR. COACH'), findsOneWidget);
        expect(find.text('Teste ${type.name}'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('AIGenerationStepper renders MrCoachEvolutionPainter integrated smoothly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AIGenerationStepper(),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Considerando sua avaliação'), findsOneWidget);
    });
  });
}
