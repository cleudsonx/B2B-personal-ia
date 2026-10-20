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

  testWidgets('AppVersionFooter exibe versão formatada e abre notas pertinentes ao aluno',
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
          body: AppVersionFooter(userRole: 'client'),
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

    // Aluno: vê apenas novidades do seu treino
    expect(find.text('NOVIDADES NO SEU TREINO'), findsOneWidget);
    expect(find.text('PARA SUA CONSULTORIA & NEGÓCIO'), findsNothing);
    expect(find.text('SISTEMA & INFRAESTRUTURA'), findsNothing);

    // Valida destaques direcionados ao aluno
    final studentHighlights = AppChangelog.current.highlights
        .where((item) => item.targetRoles.contains('student'))
        .toList();
    expect(find.text(studentHighlights.first.title), findsOneWidget);
    expect(find.text(studentHighlights[1].title), findsOneWidget);

    // Valida que itens exclusivos do treinador NÃO aparecem para o aluno
    final trainerExclusive = AppChangelog.current.highlights
        .firstWhere((item) => item.targetRoles.length == 1 && item.targetRoles.contains('trainer'));
    expect(find.text(trainerExclusive.title), findsNothing);

    // Badge de novidades exibe exatamente a contagem pertinente ao aluno
    expect(find.text('${studentHighlights.length} novidades'), findsOneWidget);

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

    // Professor: visualiza novidades de consultoria e também melhorias para seus alunos
    expect(find.text('PARA SUA CONSULTORIA & NEGÓCIO'), findsOneWidget);
    expect(find.text('MELHORIAS PARA OS SEUS ALUNOS'), findsOneWidget);
    expect(find.text('SISTEMA & INFRAESTRUTURA'), findsNothing);

    final trainerHighlights = AppChangelog.current.highlights
        .where((item) => item.targetRoles.contains('trainer'))
        .toList();
    expect(find.text(trainerHighlights.first.title), findsOneWidget);
    expect(find.text(trainerHighlights[1].title), findsOneWidget);

    // Não visualiza itens exclusivos de admin
    final adminExclusive = AppChangelog.current.highlights
        .firstWhere((item) => item.targetRoles.length == 1 && item.targetRoles.contains('admin'));
    expect(find.text(adminExclusive.title), findsNothing);
  });

  testWidgets('AppVersionFooter exibe infraestrutura e visão completa para admin',
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
          body: AppVersionFooter(userRole: 'admin'),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Admin visualiza todas as 3 seções pertinentes
    expect(find.text('SISTEMA & INFRAESTRUTURA'), findsOneWidget);
    expect(find.text('PARA SUA CONSULTORIA & NEGÓCIO'), findsOneWidget);
    expect(find.text('MELHORIAS PARA OS SEUS ALUNOS'), findsOneWidget);

    final adminHighlights = AppChangelog.current.highlights
        .where((item) => item.targetRoles.contains('admin'))
        .toList();
    expect(find.text(adminHighlights.first.title), findsOneWidget);
  });
}
