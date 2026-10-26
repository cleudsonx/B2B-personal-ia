import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/ai_news_screen.dart';

void main() {
  testWidgets('AiNewsScreen renders 1RM calculator and switches tabs correctly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AiNewsScreen(initialTab: '1rm'),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header & Title checks
    expect(find.text('META SCIENCE HUB'), findsOneWidget);
    expect(find.text('Calculadora Aberta de 1RM & Zonas de Hipertrofia'), findsOneWidget);
    expect(find.text('Epley (1985)'), findsOneWidget);
    expect(find.text('Brzycki (1993)'), findsOneWidget);
    expect(find.text('Lombardi (1989)'), findsOneWidget);

    // Initial state: 80kg x 8 reps
    expect(find.text('80.0 kg'), findsWidgets);
    expect(find.text('8 reps'), findsWidgets);
    expect(find.text('Faixa de Ouro Hipertrofia ⭐'), findsOneWidget);

    // 2. Select different reps chip
    expect(find.text('10 reps'), findsWidgets);
    await tester.tap(find.text('10 reps').first);
    await tester.pumpAndSettle();

    // 3. Switch to Volume tab
    final volumeTab = find.text('Volume Semanal (MEV/MAV/MRV)');
    expect(volumeTab, findsOneWidget);
    await tester.tap(volumeTab);
    await tester.pumpAndSettle();

    expect(find.text('Auditório de Volume Semanal (MEV / MAV / MRV)'), findsOneWidget);
    expect(find.text('Peitoral'), findsWidgets);
    expect(find.text('Costas / Dorsais'), findsOneWidget);
    expect(find.text('Quadríceps'), findsOneWidget);

    // 4. Switch to Articles tab
    final articlesTab = find.text('Artigos & Notícias de IA');
    expect(articlesTab, findsOneWidget);
    await tester.tap(articlesTab);
    await tester.pumpAndSettle();

    expect(find.text('Guias Técnicos de Biomecânica & Notícias de IA'), findsOneWidget);
    expect(
      find.text('Substituição Biomecânica de Exercícios com Mesmo Vetor Muscular'),
      findsOneWidget,
    );
    expect(
      find.text('Periodização Ondulatória Diária (DUP) vs. Linear para Hipertrofia'),
      findsOneWidget,
    );
  });
}
