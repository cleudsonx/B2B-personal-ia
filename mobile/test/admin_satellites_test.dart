import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/screens/admin_users_screen.dart';
import 'package:personal_ia/features/admin/screens/admin_finance_screen.dart';
import 'package:personal_ia/features/admin/screens/admin_whatsapp_screen.dart';
import 'package:personal_ia/features/admin/screens/admin_ai_usage_screen.dart';

void main() {
  group('AdminUsersScreen', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminUsersScreen(key: ValueKey('light_users')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL USUÁRIOS'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminUsersScreen(key: ValueKey('dark_users')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL USUÁRIOS'), findsOneWidget);
    });
  });

  group('AdminFinanceScreen', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminFinanceScreen(key: ValueKey('light_finance')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financeiro & Unit Economics'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminFinanceScreen(key: ValueKey('dark_finance')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financeiro & Unit Economics'), findsOneWidget);
    });
  });

  group('AdminWhatsAppScreen', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminWhatsAppScreen(key: ValueKey('light_whatsapp')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL INSTÂNCIAS'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminWhatsAppScreen(key: ValueKey('dark_whatsapp')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL INSTÂNCIAS'), findsOneWidget);
    });
  });

  group('AdminAiUsageScreen', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminAiUsageScreen(key: ValueKey('light_ai_usage')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inteligência & Custos de IA'), findsOneWidget);
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminAiUsageScreen(key: ValueKey('dark_ai_usage')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inteligência & Custos de IA'), findsOneWidget);
    });
  });
}
