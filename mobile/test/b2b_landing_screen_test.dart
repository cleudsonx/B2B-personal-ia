import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/features/landing/b2b_landing_screen.dart';

void main() {
  testWidgets('B2BLandingScreen renders hero, ROI calculator, test drive, and comparison', (tester) async {
    tester.view.physicalSize = const Size(1280, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: B2BLandingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Hero and Title
    expect(find.text('MR. COACH PRO • PLATAFORMA PARA PERSONAL TRAINERS'), findsOneWidget);
    expect(find.text('Prescreva em 30 segundos com IA. Escale sua consultoria online.'), findsOneWidget);

    // 2. Verify ROI Calculator Section
    expect(find.text('SIMULADOR DE FATURAMENTO & ESCALABILIDADE'), findsOneWidget);
    expect(find.text('Quanto você pode faturar e quanto tempo vai economizar?'), findsOneWidget);
    expect(find.text('Alunos na consultoria'), findsOneWidget);
    expect(find.text('Mensalidade média do aluno'), findsOneWidget);
    expect(find.text('FATURAMENTO BRUTO ESTIMADO'), findsOneWidget);
    expect(find.text('Criar Minha Vitrine Grátis no Starter'), findsOneWidget);

    // 3. Verify Biomechanical Test Drive Section
    expect(find.text('TEST-DRIVE DE IA EM TEMPO REAL • 0 CADASTRO • RESPOSTA EM 3S'), findsOneWidget);
    expect(find.text('MOTOR BIOMECÂNICO CLÍNICO MR. COACH AI'), findsOneWidget);
    expect(find.text('Agachamento Livre'), findsOneWidget);
    expect(find.text('Supino Reto com Barra'), findsOneWidget);
    expect(find.text('DIAGNÓSTICO DO VETOR DE FORÇA'), findsOneWidget);
    expect(find.text('AJUSTE IMEDIATO RECOMENDADO AO ALUNO'), findsOneWidget);
    expect(find.text('Encontrar Personal'), findsWidgets);
    expect(find.text('Prescrever com essa IA'), findsOneWidget);

    // 4. Verify Comparison Section (Old vs New)
    expect(find.text('O FIM DA CONSULTORIA EM PDF'), findsOneWidget);
    expect(find.text('Por que as consultorias antigas perdem alunos e o Mr. Coach retém'), findsOneWidget);
    expect(find.text('Aparelho Ocupado na Academia'), findsOneWidget);
    expect(find.text('Dor Articular ou Queixa Inesperada'), findsOneWidget);
    expect(find.text('Controle de Cargas e Cálculo de 1RM'), findsOneWidget);
  });

  testWidgets('B2BLandingScreen test-drive switches scenarios when chips are tapped', (tester) async {
    tester.view.physicalSize = const Size(1280, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: B2BLandingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Select "Supino Reto com Barra"
    final supinoChip = find.text('Supino Reto com Barra');
    expect(supinoChip, findsOneWidget);
    await tester.tap(supinoChip);
    await tester.pumpAndSettle();

    // Check that chest-related anatomical target or diagnosis is displayed
    expect(find.text('Articulação Glenoumeral'), findsOneWidget);
    expect(find.text('Supino Reto com Halteres em pegada semi-pronada / neutra'), findsOneWidget);
  });
}
