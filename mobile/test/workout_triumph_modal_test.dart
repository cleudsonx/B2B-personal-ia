import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/workout_triumph_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('WorkoutTriumphModal renders core workout metrics and title',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var dismissed = false;

    await tester.pumpWidget(
      buildTestApp(
        WorkoutTriumphModal(
          workoutTitle: 'Treino A - Peito e Tríceps',
          trainerName: 'Rodrigo Silva',
          studentName: 'Carlos Eduardo',
          durationMin: 52,
          totalVolumeKg: 4250.0,
          completedSets: 18,
          totalSets: 18,
          currentStreak: 5,
          newPrCount: 2,
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    // Pump frames for entrance animations without pumpAndSettle (due to repeating pulse)
    await tester.pump(const Duration(milliseconds: 700));

    // Verify Title and Headline
    expect(find.text('TREINO CONCLUÍDO!'), findsOneWidget);
    expect(find.text('Treino A - Peito e Tríceps'), findsOneWidget);

    // Verify Metric numbers
    expect(find.text('52'), findsOneWidget);
    expect(find.text('MINUTOS'), findsOneWidget);
    expect(find.text('4.3t'), findsOneWidget); // 4250kg -> 4.3t
    expect(find.text('18/18'), findsOneWidget);
    expect(find.text('SÉRIES'), findsOneWidget);

    // Verify PR and Streak Badges
    expect(find.text('2 Novo(s) Recorde(s) de Carga Batido(s)!'), findsOneWidget);
    expect(find.text('5º Dia Consecutivo de Treino!'), findsOneWidget);

    // Verify default RPE 8/10
    expect(find.text('8 / 10'), findsOneWidget);
    expect(find.text('Intenso • Próximo à Falha (Ideal)'), findsOneWidget);

    // Verify Share Button
    expect(find.text('Ver Card de Conquista (Stories / Redes)'), findsOneWidget);
  });

  testWidgets('WorkoutTriumphModal allows selecting RPE and updates label tactilely',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        WorkoutTriumphModal(
          workoutTitle: 'Leg Day Pesado',
          trainerName: 'Mariana Lima',
          durationMin: 65,
          totalVolumeKg: 850.0,
          completedSets: 15,
          totalSets: 16,
          onDismiss: () {},
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));

    // Initially 8/10
    expect(find.text('8 / 10'), findsOneWidget);

    // Tap on RPE '10' button
    final rpe10Finder = find.widgetWithText(InkWell, '10');
    expect(rpe10Finder, findsOneWidget);
    await tester.tap(rpe10Finder);
    await tester.pump(const Duration(milliseconds: 300));

    // Expect label updated to 10/10
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('Máximo Absoluto • Até a Falha Total'), findsOneWidget);
  });

  testWidgets('Tapping Ver Card de Conquista opens WorkoutShareCardDialog with stories styling',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        WorkoutTriumphModal(
          workoutTitle: 'Costas e Bíceps Brutal',
          trainerName: 'Lucas Personal',
          studentName: 'Gabriel Santos',
          trainerPhone: '11999998888',
          durationMin: 48,
          totalVolumeKg: 3200.0,
          completedSets: 16,
          totalSets: 16,
          currentStreak: 3,
          newPrCount: 1,
          onDismiss: () {},
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));

    // Tap 'Ver Card de Conquista (Stories / Redes)'
    final shareCardBtn = find.text('Ver Card de Conquista (Stories / Redes)');
    expect(shareCardBtn, findsOneWidget);
    await tester.tap(shareCardBtn);
    await tester.pump(const Duration(milliseconds: 500));

    // WorkoutShareCardDialog is now displayed
    expect(find.text('MR. COACH AI'), findsOneWidget);
    expect(find.text('SESSÃO CONCLUÍDA'), findsOneWidget);
    expect(find.text('COSTAS E BÍCEPS BRUTAL'), findsOneWidget);
    expect(find.text('Atleta: Gabriel Santos'), findsOneWidget);
    expect(find.text('Prof. Lucas Personal'), findsOneWidget);
    expect(find.text('app.sheipados.com'), findsOneWidget);
    expect(find.text('1 NOVO(S) RECORDE(S) DE CARGA (PR)!'), findsOneWidget);
    expect(find.text('3º DIA SEGUIDO DE TREINO!'), findsOneWidget);
    expect(find.text('Tire um print para postar no Instagram Stories!'), findsOneWidget);

    // Verify Action buttons in dialog
    expect(find.text('Copiar Texto'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);

    // Tap Copiar Texto
    await tester.tap(find.text('Copiar Texto'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Resumo do treino copiado para colar no Stories ou WhatsApp!'),
      findsOneWidget,
    );

    // Tap close button to dismiss dialog
    final closeBtn = find.byTooltip('Fechar');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Dialog dismissed
    expect(find.text('MR. COACH AI'), findsNothing);
  });

  testWidgets('WorkoutShareCardDialog can be rendered standalone',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        const WorkoutShareCardDialog(
          workoutTitle: 'Superior Completo',
          trainerName: 'Felipe Treinador',
          studentName: 'Ana Clara',
          durationMin: 45,
          totalVolumeKg: 780.0,
          completedSets: 12,
          totalSets: 12,
          currentStreak: 7,
          newPrCount: 0,
          rpe: 8,
          rpeLabel: 'Intenso • Próximo à Falha (Ideal)',
          rpeColor: Colors.amber,
          summaryText: 'Resumo teste para stories',
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('SUPERIOR COMPLETO'), findsOneWidget);
    expect(find.text('Atleta: Ana Clara'), findsOneWidget);
    expect(find.text('Prof. Felipe Treinador'), findsOneWidget);
    expect(find.text('7º DIA SEGUIDO DE TREINO!'), findsOneWidget);
    expect(find.text('780'), findsOneWidget);
    expect(find.text('VOLUME KG'), findsOneWidget);
  });
}

