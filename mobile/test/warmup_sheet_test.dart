import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/client/widgets/warmup_sheet.dart';

void main() {
  testWidgets('WarmupSheet exibe timer, foco e conclui com sucesso',
      (tester) async {
    bool? completed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                completed = await WarmupSheet.show(context);
              },
              child: const Text('Abrir Aquecimento'),
            ),
          ),
        ),
      ),
    );

    // Toca no botão para abrir o Sheet
    await tester.tap(find.text('Abrir Aquecimento'));
    await tester.pumpAndSettle();

    // Valida que o modal abriu com os elementos
    expect(find.text('Aquecimento Específico'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    expect(find.text('Em Andamento'), findsOneWidget);
    expect(find.text('🎯 Full Body'), findsOneWidget);
    expect(find.text('Pausar'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);

    // Pausa o timer
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Pausado'), findsOneWidget);

    // Troca de foco para Superiores
    await tester.tap(find.text('🦾 Superiores'));
    await tester.pump();
    expect(find.textContaining('Manguito'), findsWidgets);

    // Conclui o aquecimento
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    // Valida que fechou e retornou true
    expect(find.text('Aquecimento Específico'), findsNothing);
    expect(completed, isTrue);
  });
}
