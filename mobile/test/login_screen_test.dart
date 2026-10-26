import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/auth/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LoginScreen renders cleanly under Light mode with proper theme tokens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: LoginScreen(key: ValueKey('light_login')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MR. COACH'), findsOneWidget);
    expect(find.text('Treinador Pro'), findsOneWidget);
    expect(find.text('Aluno no Salão'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.text('MR. COACH'));
    expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
  });

  testWidgets('LoginScreen renders cleanly under Dark mode with proper theme tokens', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const LoginScreen(key: ValueKey('dark_login')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MR. COACH'), findsOneWidget);
    expect(find.text('Treinador Pro'), findsOneWidget);
    expect(find.text('Aluno no Salão'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);

    final titleWidget = tester.widget<Text>(find.text('MR. COACH'));
    expect(titleWidget.style?.color, equals(MetaColors.textPrimary));
  });
}

