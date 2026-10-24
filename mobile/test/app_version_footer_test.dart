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

  testWidgets('AppVersionFooter exibe preview remoto com botão de Atualizar quando há remoteReleaseData',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRemoteData = {
      'version': '2.0.0',
      'build': 2026110101,
      'notes': 'Nova grande atualização de sistema',
      'changelog': {
        'student': [
          {
            'title': 'Novo Modo Treino Offline',
            'description': 'Acesse seus treinos sem internet em qualquer lugar.',
            'badge': 'NOVO',
          }
        ],
        'trainer': [
          {
            'title': 'Dashboard Financeiro com Projeção Anual',
            'description': 'Gráfico avançado de faturamento e churn rate.',
            'badge': 'MÉTRICAS',
          }
        ],
      }
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AppVersionFooter.showReleaseNotesModal(
                      context,
                      roleOverride: 'student',
                      remoteReleaseData: fakeRemoteData,
                    );
                  },
                  child: const Text('Abrir Preview Remoto'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Preview Remoto'));
    await tester.pumpAndSettle();

    // Valida cabeçalho de atualização disponível
    expect(find.text('O QUE VEM NA NOVA VERSÃO'), findsOneWidget);
    expect(find.text('v2.0.0 (Build 2026110101)'), findsOneWidget);
    expect(find.text('• Atualização Disponível'), findsOneWidget);

    // Valida que o aluno vê apenas a novidade de aluno do payload remoto
    expect(find.text('Novo Modo Treino Offline'), findsOneWidget);
    expect(find.text('Acesse seus treinos sem internet em qualquer lugar.'), findsOneWidget);
    expect(find.text('Dashboard Financeiro com Projeção Anual'), findsNothing);

    // Valida botão de recarga imediata
    expect(find.text('Atualizar e Recarregar Agora'), findsOneWidget);
    expect(find.text('Lembrar mais tarde'), findsOneWidget);
  });

  testWidgets('AppVersionFooter filtra destaques das versões anteriores conforme perfil do aluno',
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

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Localiza e expande histórico anterior
    final verAnterioresFinder = find.textContaining('Ver versões anteriores');
    expect(verAnterioresFinder, findsOneWidget);
    await tester.ensureVisible(verAnterioresFinder);
    await tester.pumpAndSettle();
    await tester.tap(verAnterioresFinder);
    await tester.pumpAndSettle();

    expect(find.text('Ocultar versões anteriores'), findsOneWidget);

    // Versões anteriores foram renderizadas
    final previous = AppChangelog.previousReleases.first;
    expect(find.text(previous.fullTitle), findsOneWidget);
  });

  testWidgets('checkAndShowAutoModal respeita versao semantica para prevenir fadiga',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'pwa_last_seen_changelog_version': AppChangelog.current.version,
    });
    AppVersionFooter.enableAutoModal = true;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          return MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (innerContext) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AppVersionFooter.checkAndShowAutoModal(innerContext);
                  });
                  return const SizedBox();
                },
              ),
            ),
          );
        },
      ),
    );

    await tester.pump(const Duration(milliseconds: 2000));
    // Modal não deve ter sido aberto pois a versão já foi vista
    expect(find.text('NOVIDADES DESTA VERSÃO'), findsNothing);
  });

  testWidgets('checkAndShowAutoModal abre automaticamente quando ha novo build compilado',
      (tester) async {
    // Configura como se o usuário já estivesse na versão 1.9.0, mas em um build anterior
    SharedPreferences.setMockInitialValues({
      'pwa_last_seen_changelog_version': AppChangelog.current.version,
      'pwa_last_seen_changelog_build': 2026102801, // build mais antigo que o atual
    });
    AppVersionFooter.enableAutoModal = true;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          return MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (innerContext) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AppVersionFooter.checkAndShowAutoModal(innerContext, roleOverride: 'client');
                  });
                  return const SizedBox();
                },
              ),
            ),
          );
        },
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Modal deve abrir pois o buildNumber atual é maior que o build anterior registrado
    expect(find.text('NOVIDADES DESTA VERSÃO'), findsOneWidget);
  });

  testWidgets('AppVersionFooter exibe banner de contexto de perfil para aluno, professor e admin',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Aluno
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(userRole: 'client'),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Perfil Aluno: Novidades para sua Rotina de Treino e Acesso'), findsOneWidget);
    expect(find.text('Imersão Visual Edge-to-Edge sem Tarjas'), findsOneWidget);
    expect(find.text('Entrada VIP por Links de Parcerias (/r/{slug})'), findsOneWidget);

    // Fecha modal
    await tester.ensureVisible(find.text('Entendido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    // 2. Professor
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(userRole: 'trainer'),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Perfil Personal: Novidades para sua Consultoria e Alunos'), findsOneWidget);
    expect(find.text('Cockpit Edge-to-Edge com Doca Flutuante Translúcida'), findsOneWidget);
    expect(find.text('Landing Pages Públicas (/r/{slug}) & Auto-Cupom'), findsOneWidget);
    expect(find.text('Repasse de Comissões e Parcerias via Pix'), findsOneWidget);

    // Fecha modal
    await tester.ensureVisible(find.text('Entendido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    // 3. Admin
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(userRole: 'admin'),
        ),
      ),
    );
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Visão Executiva: Novidades de Infraestrutura, Finanças e Plataforma'), findsOneWidget);
    expect(find.text('Central de Liquidação Pix (Payout Engine) & Comprovantes'), findsOneWidget);
  });
}
