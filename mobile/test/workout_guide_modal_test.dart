import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/workout_guide_modal.dart';

void main() {
  testWidgets('WorkoutGuideModal exibe os 4 passos e fecha ao tocar no botao',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => WorkoutGuideModal.show(context),
              child: const Text('Abrir Guia'),
            ),
          ),
        ),
      ),
    );

    // Abre o modal
    await tester.tap(find.text('Abrir Guia'));
    await tester.pumpAndSettle();

    // Valida o cabeçalho e passos
    expect(find.text('Como treinar com o App ⚡'), findsOneWidget);
    expect(find.textContaining('divisão do dia'), findsOneWidget);
    expect(find.textContaining('Modo Salão'), findsOneWidget);
    expect(find.textContaining('Aparelho ocupado'), findsOneWidget);
    expect(find.textContaining('salvar sua evolução'), findsOneWidget);
    expect(find.text('Entendi, vamos treinar!'), findsOneWidget);

    // Fecha o modal garantindo visibilidade na rolagem
    await tester.ensureVisible(find.text('Entendi, vamos treinar!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendi, vamos treinar!'));
    await tester.pumpAndSettle();

    expect(find.text('Como treinar com o App ⚡'), findsNothing);
  });
}
