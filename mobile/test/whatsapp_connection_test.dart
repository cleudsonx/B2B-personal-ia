import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/trainer/presentation/screens/whatsapp_connection_screen.dart';

void main() {
  testWidgets('WhatsappConnectionScreen renders cleanly under Light mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        themeMode: ThemeMode.light,
        home: const WhatsappConnectionScreen(
          key: ValueKey('light'),
          initialPhone: '11999998888',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conectar WhatsApp'), findsWidgets);
    expect(find.text('AUTOMAÇÕES ATIVAS NO SEU NÚMERO'), findsOneWidget);

    final titleFinder = find.text('Conectar WhatsApp').first;
    final titleWidget = tester.widget<Text>(titleFinder);
    expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
  });

  testWidgets('WhatsappConnectionScreen renders cleanly under Dark mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: const WhatsappConnectionScreen(
          key: ValueKey('dark'),
          initialPhone: '11999998888',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Conectar WhatsApp'), findsWidgets);
    final darkTitleFinder = find.text('Conectar WhatsApp').first;
    final darkTitleWidget = tester.widget<Text>(darkTitleFinder);
    expect(darkTitleWidget.style?.color, equals(MetaColors.textPrimary));
  });

  testWidgets('WhatsappConnectionScreen shows RADAR DO ROBÔ header and empty state message cleanly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: WhatsappConnectionScreen(
          key: ValueKey('radar-empty'),
          initialPhone: '11999998888',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('RADAR DO ROBÔ • ATENDIMENTOS'), findsOneWidget);
    expect(find.textContaining('Nenhum atendimento registrado ainda'), findsOneWidget);
  });
}
