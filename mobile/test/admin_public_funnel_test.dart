import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/tabs/public_funnel_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdminPublicFunnelTab renders North Star KPIs, funnel pipeline, and live telemetry', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool navigatedToAffiliates = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPublicFunnelTab(
            onNavigateToAffiliates: () => navigatedToAffiliates = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Header & North Star Badge
    expect(find.text('NORTH STAR KPIS • FUNIL PÚBLICO'), findsOneWidget);
    expect(find.text('Funil de Aquisição, Vitrines & Afiliados'), findsOneWidget);

    // 2. Verify Period Chips
    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('7 Dias'), findsOneWidget);
    expect(find.text('30 Dias'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    // Switch period to '7 Dias'
    await tester.tap(find.text('7 Dias'));
    await tester.pumpAndSettle();

    // 3. Verify 4 North Star KPIs
    expect(find.text('ENGAJAMENTO SIMULADORES'), findsOneWidget);
    expect(find.text('42.0%'), findsOneWidget);
    expect(find.text('META BATIDA +7.0%'), findsOneWidget);

    expect(find.text('PIX -> PRIMEIRO TREINO'), findsOneWidget);
    expect(find.text('2.2 min'), findsOneWidget);
    expect(find.text('ULTRA VELOZ'), findsOneWidget);

    expect(find.text('K-FACTOR STORIES 9:16'), findsOneWidget);
    expect(find.text('22.4%'), findsOneWidget);
    expect(find.text('VIRALIDADE ALTA'), findsOneWidget);

    expect(find.text('EXPANSÃO PLG (STARTER->PRO)'), findsOneWidget);
    expect(find.text('48.5%'), findsOneWidget);
    expect(find.text('CONVERSÃO FORTE'), findsOneWidget);

    // 4. Verify 4 Funnel Stages
    expect(find.text('Jornada de Conversão do Funil Público'), findsOneWidget);
    expect(find.text('Visitantes Únicos no Ecossistema'), findsOneWidget);
    expect(find.text('Engajamento em Simuladores & Test-Drive'), findsOneWidget);
    expect(find.text('Ativações Pix nas Vitrines Públicas (/p/{user})'), findsOneWidget);
    expect(find.text('Expansão PLG para Treinadores Pro'), findsOneWidget);

    // 5. Verify Live Telemetry Feed (public_funnel_events)
    expect(find.text('Feed de Eventos em Tempo Real (public_funnel_events)'), findsOneWidget);
    expect(find.text('Contratação Pix Aprovada (Split 5%)'), findsOneWidget);
    expect(find.text('Simulação de Renda B2B'), findsOneWidget);
    expect(find.text('Exportação Story 9:16 (Instagram)'), findsOneWidget);
    expect(find.text('Test-Drive Biomecânico'), findsOneWidget);
    expect(find.text('Upgrade PLG Starter -> Pro'), findsOneWidget);

    // 6. Verify Affiliates Summary & Navigation Action
    expect(find.text('Motor de Afiliados & Comissões B2B'), findsOneWidget);
    expect(find.text('GMV VIA AFILIADOS'), findsOneWidget);
    expect(find.text('COMISSÕES TOTAIS'), findsOneWidget);
    expect(find.text('LIQUIDAÇÃO PIX'), findsOneWidget);

    final manageBtn = find.text('Gerenciar Afiliados');
    expect(manageBtn, findsOneWidget);
    await tester.ensureVisible(manageBtn);
    await tester.tap(manageBtn);
    expect(navigatedToAffiliates, isTrue);
  });
}
