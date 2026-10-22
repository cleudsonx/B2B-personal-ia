import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/interactive_tour_guide_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourGuideModal.enableAutoTour = true;
  });

  testWidgets(
      'InteractiveTourGuideModal exibe passos do Personal, navega entre etapas e conclui',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => InteractiveTourGuideModal.show(
                  context,
                  role: 'trainer',
                  onCompleted: () => completedCalled = true,
                ),
                child: const Text('Abrir Tour Personal'),
              ),
            ),
          ),
        ),
      ),
    );

    // Abre o modal de tour para Treinador
    await tester.tap(find.text('Abrir Tour Personal'));
    await tester.pumpAndSettle();

    // 1. Passo 1: Prescrição Inteligente
    expect(find.text('Mr. Coach • Guia do Personal'), findsOneWidget);
    expect(find.text('PASSO 1 DE 3 • PRESCRIÇÃO INTELIGENTE'), findsOneWidget);
    expect(find.text('Gestão de Alunos & Fichas com IA'), findsOneWidget);
    expect(find.text('Avançar para Vendas'), findsOneWidget);

    // Avança para o Passo 2
    await tester.tap(find.text('Avançar para Vendas'));
    await tester.pumpAndSettle();

    // 2. Passo 2: Máquina de Vendas & Vitrine
    expect(find.text('PASSO 2 DE 3 • MÁQUINA DE VENDAS'), findsOneWidget);
    expect(find.text('Vitrine Pública /r/{slug} & Cupons'), findsOneWidget);
    expect(find.text('Avançar para Automação'), findsOneWidget);

    // Testa botão Voltar
    expect(find.text('Voltar'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Gestão de Alunos & Fichas com IA'), findsOneWidget);

    // Salta diretamente para o Passo 3 via Step Pill
    await tester.tap(find.text('Passo 3'));
    await tester.pumpAndSettle();

    // 3. Passo 3: Atendimento & WhatsApp
    expect(find.text('PASSO 3 DE 3 • ESCALABILIDADE'), findsOneWidget);
    expect(find.text('Atendimento 24h & WhatsApp VIP'), findsOneWidget);
    expect(find.text('Concluir Tour & Começar! 🚀'), findsOneWidget);

    // Finaliza o tour
    await tester.tap(find.text('Concluir Tour & Começar! 🚀'));
    await tester.pumpAndSettle();

    // Verifica que o modal fechou e gravou a persistência
    expect(find.text('Gestão de Alunos & Fichas com IA'), findsNothing);
    expect(completedCalled, isTrue);

    final isDone = await InteractiveTourGuideModal.isCompleted(role: 'trainer');
    expect(isDone, isTrue);
  });

  testWidgets(
      'InteractiveTourGuideModal exibe passos do Aluno e suporta pular tour',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool dismissedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => InteractiveTourGuideModal.show(
                  context,
                  role: 'student',
                  onDismiss: () => dismissedCalled = true,
                ),
                child: const Text('Abrir Tour Aluno'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Tour Aluno'));
    await tester.pumpAndSettle();

    // 1. Passo 1 do Aluno
    expect(find.text('Mr. Coach • Guia do Aluno'), findsOneWidget);
    expect(find.text('PASSO 1 DE 3 • SALÃO DE TREINO'), findsOneWidget);
    expect(find.text('Treino Imersivo Edge-to-Edge'), findsOneWidget);
    expect(find.text('Avançar para Performance'), findsOneWidget);

    // Avança para o Passo 2
    await tester.tap(find.text('Avançar para Performance'));
    await tester.pumpAndSettle();

    // 2. Passo 2 do Aluno
    expect(find.text('PASSO 2 DE 3 • EVOLUÇÃO CIENTÍFICA'), findsOneWidget);
    expect(find.text('Cronômetro 3-2-1 & Sobrecarga IA'), findsOneWidget);
    expect(find.text('Avançar para Conquistas'), findsOneWidget);

    // Avança para o Passo 3
    await tester.tap(find.text('Avançar para Conquistas'));
    await tester.pumpAndSettle();

    // 3. Passo 3 do Aluno
    expect(find.text('PASSO 3 DE 3 • PROVA SOCIAL'), findsOneWidget);
    expect(find.text('Cards de Triunfo & Viral Loop'), findsOneWidget);
    expect(find.text('Bora Treinar! 🚀'), findsOneWidget);

    // Toca em 'Pular'
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    expect(find.text('Treino Imersivo Edge-to-Edge'), findsNothing);
    expect(dismissedCalled, isTrue);

    final isDone = await InteractiveTourGuideModal.isCompleted(role: 'student');
    expect(isDone, isTrue);
  });

  testWidgets(
      'InteractiveTourGuideModal persiste e pode ser resetado corretamente',
      (tester) async {
    expect(await InteractiveTourGuideModal.isCompleted(role: 'trainer'), isFalse);

    await InteractiveTourGuideModal.markCompleted(role: 'trainer');
    expect(await InteractiveTourGuideModal.isCompleted(role: 'trainer'), isTrue);

    await InteractiveTourGuideModal.resetTour(role: 'trainer');
    expect(await InteractiveTourGuideModal.isCompleted(role: 'trainer'), isFalse);
  });
}

