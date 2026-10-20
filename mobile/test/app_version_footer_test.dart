import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/config/app_changelog.dart';
import 'package:personal_ia/core/config/app_config.dart';
import 'package:personal_ia/core/widgets/app_version_footer.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AppVersionFooter exibe versão formatada e abre notas ao tocar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(),
        ),
      ),
    );

    // Verifica que exibe a versão formatada
    expect(find.text(AppConfig.fullVersionString), findsOneWidget);
    expect(find.text('Mr. Coach AI'), findsOneWidget);

    // Toca no componente para abrir as notas de versão
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Verifica que o BottomSheet com o changelog abriu
    expect(find.text('NOVIDADES DESTA VERSÃO'), findsOneWidget);

    // Aluno (visão padrão deslogada): valida destaques direcionados ao aluno
    final studentHighlights = AppChangelog.current.highlights
        .where((item) => item.targetRoles.contains('student'))
        .toList();
    expect(find.text(studentHighlights.first.title), findsOneWidget);
    expect(find.text(studentHighlights[1].title), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);

    // Fecha o modal garantindo visibilidade no scroll
    await tester.ensureVisible(find.text('Entendido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.text('NOVIDADES DESTA VERSÃO'), findsNothing);
  });

  testWidgets('AppVersionFooter exibe notas direcionadas ao professor quando papel trainer',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(userRole: 'trainer'),
        ),
      ),
    );

    // Toca no componente para abrir as notas de versão
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Verifica que o BottomSheet com o changelog abriu
    expect(find.text('NOVIDADES DESTA VERSÃO'), findsOneWidget);

    // Professor: visualiza as novidades do professor
    final trainerHighlights = AppChangelog.current.highlights
        .where((item) => item.targetRoles.contains('trainer'))
        .toList();
    expect(find.text(trainerHighlights.first.title), findsOneWidget);
    expect(find.text(trainerHighlights[1].title), findsOneWidget);
  });
}
