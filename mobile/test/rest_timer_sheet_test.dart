import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/rest_timer_sheet.dart';
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

  testWidgets('RestTimerSheet renders exercise name, countdown and active controls',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        const RestTimerSheet(
          initialSeconds: 60,
          exerciseName: 'Supino Reto com Barra',
        ),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TEMPO DE DESCANSO ATIVO'), findsOneWidget);
    expect(find.text('Supino Reto com Barra'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);

    // Verify presets are present
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('60s'), findsOneWidget);
    expect(find.text('90s'), findsOneWidget);
    expect(find.text('120s'), findsOneWidget);

    // Verify fine tuning buttons
    expect(find.text('-15s'), findsOneWidget);
    expect(find.text('+15s'), findsOneWidget);
    expect(find.text('+30s'), findsOneWidget);

    // Verify Play/Pause button
    expect(find.text('Pausar'), findsOneWidget);
  });

  testWidgets('RestTimerSheet presets change remaining time and restarts count',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        const RestTimerSheet(
          initialSeconds: 60,
          exerciseName: 'Agachamento Livre',
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // Tap on preset '90s'
    await tester.tap(find.text('90s'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify timer changed to 01:30
    expect(find.text('01:30'), findsOneWidget);
  });

  testWidgets('RestTimerSheet fine adjustment buttons increment and decrement time',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        const RestTimerSheet(
          initialSeconds: 45,
          exerciseName: 'Desenvolvimento Militar',
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('00:45'), findsOneWidget);

    // Tap +15s -> should go to 01:00
    await tester.tap(find.text('+15s'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('01:00'), findsOneWidget);

    // Tap -15s -> should go back to 00:45
    await tester.tap(find.text('-15s'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('00:45'), findsOneWidget);
  });

  testWidgets('RestTimerSheet allows pausing, resuming and toggling sound alerts',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(
        const RestTimerSheet(
          initialSeconds: 30,
          exerciseName: 'Puxada Alta',
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // Tap Pausar
    await tester.tap(find.text('Pausar'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Descanso pausado'), findsOneWidget);

    // Tap Continuar to resume
    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pausar'), findsOneWidget);

    // Toggle sound alert
    final soundToggle = find.byTooltip('Alternar Som');
    expect(soundToggle, findsOneWidget);
    await tester.tap(soundToggle);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify sound was toggled (no exception)
    expect(soundToggle, findsOneWidget);
  });

  test('RestTimerSheet.triggerCadencedFeedback executes safely for countdown steps',
      () {
    expect(
      () {
        RestTimerSheet.triggerCadencedFeedback(3);
        RestTimerSheet.triggerCadencedFeedback(2);
        RestTimerSheet.triggerCadencedFeedback(1);
        RestTimerSheet.triggerCadencedFeedback(0);
      },
      returnsNormally,
    );
  });
}

