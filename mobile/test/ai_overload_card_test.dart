import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/ai_overload_card.dart';

void main() {
  group('ProgressiveOverloadEngine Tests', () {
    test('computes weight overload for compound exercise with RPE <= 8', () {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Supino Reto com Barra',
        targetMuscleGroup: 'Peitoral Maior',
        currentWeight: 30.0,
        currentReps: 10,
        previousWeight: 30.0,
        lastRpe: 8,
      );

      expect(suggestion.strategy, OverloadStrategy.weight);
      expect(suggestion.suggestedWeightKg, 32.5);
      expect(suggestion.suggestedReps, 10);
      expect(suggestion.badge, '+2.5 KG');
      expect(suggestion.deltaWeight, 2.5);
      expect(suggestion.rationale, contains('Último RPE 8/10'));
    });

    test('computes heavier increment for heavy compound exercises (>=60kg)', () {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Agachamento Livre com Barra',
        targetMuscleGroup: 'Quadríceps',
        currentWeight: 80.0,
        currentReps: 8,
        previousWeight: 80.0,
        lastRpe: 7,
      );

      expect(suggestion.strategy, OverloadStrategy.weight);
      expect(suggestion.suggestedWeightKg, 85.0);
      expect(suggestion.suggestedReps, 8);
      expect(suggestion.badge, '+5 KG');
      expect(suggestion.deltaWeight, 5.0);
    });

    test('computes micro-load for isolations (e.g. Deltoides/Bíceps < 20kg)', () {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Elevação Lateral com Halteres',
        targetMuscleGroup: 'Deltoides',
        currentWeight: 10.0,
        currentReps: 12,
        previousWeight: 10.0,
        lastRpe: 8,
      );

      expect(suggestion.strategy, OverloadStrategy.weight);
      expect(suggestion.suggestedWeightKg, 11.0);
      expect(suggestion.badge, '+1 KG');
    });

    test('computes volume/reps overload when RPE is 9', () {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Leg Press 45',
        targetMuscleGroup: 'Quadríceps',
        currentWeight: 140.0,
        currentReps: 10,
        previousWeight: 140.0,
        lastRpe: 9,
      );

      expect(suggestion.strategy, OverloadStrategy.reps);
      expect(suggestion.suggestedWeightKg, 140.0);
      expect(suggestion.suggestedReps, 11);
      expect(suggestion.badge, '+1 REP');
      expect(suggestion.rationale, contains('desafiadora (RPE 9)'));
    });

    test('computes technical consolidation when RPE is 10 (falha total)', () {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Puxada Frontal na Polia',
        targetMuscleGroup: 'Costas / Dorsal',
        currentWeight: 50.0,
        currentReps: 10,
        previousWeight: 50.0,
        lastRpe: 10,
      );

      expect(suggestion.strategy, OverloadStrategy.consolidate);
      expect(suggestion.suggestedWeightKg, 50.0);
      expect(suggestion.suggestedReps, 10);
      expect(suggestion.badge, 'CONSOLIDAÇÃO');
      expect(suggestion.rationale, contains('falha total (RPE 10)'));
    });
  });

  group('AiOverloadCard Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      );
    }

    testWidgets('AiOverloadCard renders suggestion details and triggers onApply',
        (tester) async {
      final suggestion = ProgressiveOverloadEngine.computeSuggestion(
        exerciseName: 'Supino Reto com Barra',
        targetMuscleGroup: 'Peitoral Maior',
        currentWeight: 40.0,
        currentReps: 10,
        previousWeight: 40.0,
        lastRpe: 8,
      );

      var applied = false;
      var dismissed = false;

      await tester.pumpWidget(
        buildTestApp(
          AiOverloadCard(
            suggestion: suggestion,
            onApply: () => applied = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      // Verify Header and Badges
      expect(find.text('PROGRESSÃO INTELIGENTE IA'), findsOneWidget);
      expect(find.text('+2.5 KG'), findsOneWidget);
      expect(find.text('42.5 kg'), findsOneWidget);
      expect(find.text('× 10 reps'), findsOneWidget);
      expect(find.text('(vs. 40 kg)'), findsOneWidget);

      // Verify Action Button
      final applyButton = find.text('Aplicar Sobrecarga na Ficha');
      expect(applyButton, findsOneWidget);

      // Tap Apply
      await tester.tap(applyButton);
      await tester.pump();

      expect(applied, isTrue);
      expect(find.text('Sugestão Aplicada nas Séries!'), findsOneWidget);

      // Verify dismiss button works
      final dismissIcon = find.byIcon(Icons.close_rounded);
      expect(dismissIcon, findsOneWidget);
      await tester.tap(dismissIcon);
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });
}

