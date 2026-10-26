import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/admin/admin_shell_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdminShellScreen renders Shaipados Studio HQ with Multi-SaaS Switcher & Cockpit Banner', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool exited = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminShellScreen(
          isHqMode: true,
          onExitAdmin: () => exited = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify HQ Branding & Multi-SaaS Elements
    expect(find.text('SHAIPADOS HQ'), findsOneWidget);
    expect(find.text('War Room Multi-SaaS'), findsOneWidget);
    expect(find.text('Visão: Venture Builder HQ'), findsOneWidget);

    // 2. Verify Cockpit Banner & Live Unit Economics in R$ pt-BR
    expect(find.text('MRR CONSOLIDADO: '), findsOneWidget);
    expect(find.text(r'R$ 48.750,00'), findsOneWidget);
    expect(find.text('ARR PROJETADO: '), findsOneWidget);
    expect(find.text(r'R$ 585.000,00'), findsOneWidget);
    expect(find.text('SPLIT 5% TAKE: '), findsOneWidget);
    expect(find.text(r'R$ 2.437,50'), findsOneWidget);

    // 3. Verify Health Check Bar
    expect(find.textContaining('Render: 200 OK'), findsOneWidget);
    expect(find.textContaining('Supabase: 99.98%'), findsOneWidget);

    // 4. Verify RBAC Badge & Multi-SaaS Dropdown
    expect(find.text('CEO_FOUNDER'), findsOneWidget);
    expect(find.text('Mr. Coach AI'), findsWidgets);

    // 5. Toggle view to Operational Mode
    await tester.tap(find.text('Visão: Venture Builder HQ'));
    await tester.pumpAndSettle();

    expect(find.text('MR. COACH'), findsOneWidget);
    expect(find.text('Mission Control • Admin'), findsOneWidget);
    expect(find.text('Visão: Operacional Mr. Coach'), findsOneWidget);

    // 6. Toggle back to HQ View
    await tester.tap(find.text('Visão: Operacional Mr. Coach'));
    await tester.pumpAndSettle();
    expect(find.text('SHAIPADOS HQ'), findsOneWidget);

    // 7. Verify Exit Admin Callback
    final exitBtn = find.text('Voltar ao Modo Padrão');
    expect(exitBtn, findsOneWidget);
    await tester.ensureVisible(exitBtn);
    await tester.tap(exitBtn);
    expect(exited, isTrue);
  });
}
