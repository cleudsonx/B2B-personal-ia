import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/widgets/admin_database_explorer_modal.dart';
import 'package:personal_ia/features/admin/widgets/admin_webhook_reprocess_modal.dart';
import 'package:personal_ia/features/admin/widgets/admin_omni_search_modal.dart';

void main() {
  group('AdminDatabaseExplorerModal', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminDatabaseExplorerModal(key: ValueKey('light_db_modal')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Explorador Seguro de Banco de Dados'), findsOneWidget);
      final titleLight = tester.widget<Text>(find.text('Explorador Seguro de Banco de Dados'));
      expect(titleLight.style?.color, equals(const Color(0xFF0F172A)));
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminDatabaseExplorerModal(key: ValueKey('dark_db_modal')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Explorador Seguro de Banco de Dados'), findsOneWidget);
      final titleDark = tester.widget<Text>(find.text('Explorador Seguro de Banco de Dados'));
      expect(titleDark.style?.color, equals(Colors.white));
    });
  });

  group('AdminWebhookReprocessModal', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: AdminWebhookReprocessModal(key: ValueKey('light_webhook_modal')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reprocessamento de Webhook Asaas'), findsOneWidget);
      final titleLight = tester.widget<Text>(find.text('Reprocessamento de Webhook Asaas'));
      expect(titleLight.style?.color, equals(const Color(0xFF0F172A)));
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AdminWebhookReprocessModal(key: ValueKey('dark_webhook_modal')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reprocessamento de Webhook Asaas'), findsOneWidget);
      final titleDark = tester.widget<Text>(find.text('Reprocessamento de Webhook Asaas'));
      expect(titleDark.style?.color, equals(Colors.white));
    });
  });

  group('AdminOmniSearchModal', () {
    testWidgets('renders cleanly under Light mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: Scaffold(
            body: AdminOmniSearchModal(
              key: const ValueKey('light_omni_modal'),
              onNavigateToSection: (_) {},
              onOpenDatabaseExplorer: () {},
              onOpenWebhookReprocess: () {},
              onViewAsRole: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ctrl + K'), findsOneWidget);
      final ctrlLight = tester.widget<Text>(find.text('Ctrl + K'));
      expect(ctrlLight.style?.color, equals(const Color(0xFF4F46E5)));
    });

    testWidgets('renders cleanly under Dark mode with high contrast', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: AdminOmniSearchModal(
              key: const ValueKey('dark_omni_modal'),
              onNavigateToSection: (_) {},
              onOpenDatabaseExplorer: () {},
              onOpenWebhookReprocess: () {},
              onViewAsRole: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ctrl + K'), findsOneWidget);
      final ctrlDark = tester.widget<Text>(find.text('Ctrl + K'));
      expect(ctrlDark.style?.color, equals(const Color(0xFF818CF8)));
    });
  });
}
