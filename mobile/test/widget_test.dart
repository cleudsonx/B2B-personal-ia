import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/main.dart';
import 'package:personal_ia/features/auth/login_screen.dart';

void main() {
  testWidgets('MainShellScreen renders all navigation tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainShellScreen(onSignOut: () {}),
      ),
    );
    expect(find.text('Treino A - Peito e Tríceps'), findsOneWidget);
    expect(find.text('Salão (Aluno)'), findsOneWidget);
    expect(find.text('Prescrição (Treinador)'), findsOneWidget);
    expect(find.text('Assistente B2B'), findsOneWidget);
  });

  testWidgets('LoginScreen renders login form and bypass option', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onLoginSuccess: () {}, onBypassDev: () {}),
      ),
    );
    expect(find.text('B2B Personal IA'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Modo Demonstração (Sem Login)'), findsOneWidget);
  });
}
