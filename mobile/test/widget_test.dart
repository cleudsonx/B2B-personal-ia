import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/main.dart';

void main() {
  testWidgets('B2BPersonalIaApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const B2BPersonalIaApp());
    expect(find.text('Treino A - Peito e Tríceps'), findsOneWidget);
    expect(find.text('Salão (Aluno)'), findsOneWidget);
    expect(find.text('Prescrição (Treinador)'), findsOneWidget);
  });
}
