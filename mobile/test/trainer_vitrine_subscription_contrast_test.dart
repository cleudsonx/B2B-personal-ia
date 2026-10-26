import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/features/subscription/presentation/screens/pix_payment_screen.dart';
import 'package:personal_ia/features/trainer/presentation/screens/trainer_business_screen.dart';
import 'package:personal_ia/features/subscription/subscription_screen.dart';

void main() {
  group('Trainer Vitrine & Subscription Contrast Tests (Light & Dark Mode)', () {
    testWidgets('PixPaymentScreen renders cleanly in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const PixPaymentScreen(
            pixCode: '00020126580014br.gov.bcb.pix1234567890',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica botão de retorno no AppBar
      expect(find.text('Voltar ao checkout'), findsOneWidget);

      // Verifica status de cópia do Pix
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Pix') ?? false),
        ),
        findsWidgets,
      );

      // Verifica botões de atalho dos bancos
      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Caixa'), findsOneWidget);
      expect(find.text('B. Brasil'), findsOneWidget);
      expect(find.text('Itaú'), findsOneWidget);
      expect(find.text('Bradesco'), findsOneWidget);
      expect(find.text('Santander'), findsOneWidget);
      expect(find.text('C6 Bank'), findsOneWidget);
    });

    testWidgets('PixPaymentScreen renders cleanly in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const PixPaymentScreen(
            pixCode: '00020126580014br.gov.bcb.pix1234567890',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voltar ao checkout'), findsOneWidget);
      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Caixa'), findsOneWidget);
      expect(find.text('C6 Bank'), findsOneWidget);
    });

    testWidgets('TrainerBusinessScreen renders Vitrine B2B cleanly in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: TrainerBusinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Topo
      expect(find.text('Ferramentas do Personal'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Ferramentas do Personal'));
      expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));

      // Seções e Cards B2B
      expect(find.text('Como'), findsOneWidget);
      expect(find.text('Expanda sua empresa'), findsOneWidget);
      expect(find.text('Link Direto da sua Vitrine B2B'), findsOneWidget);
      expect(find.text('Planos de Consultoria & Preços'), findsOneWidget);
      expect(find.text('Assinatura Mr. Coach'), findsOneWidget);
      expect(find.text('Minha Vitrine Pública'), findsOneWidget);
      expect(find.text('Conexão WhatsApp'), findsOneWidget);
    });

    testWidgets('TrainerBusinessScreen renders Vitrine B2B cleanly in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: TrainerBusinessScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Topo
      expect(find.text('Ferramentas do Personal'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Ferramentas do Personal'));
      expect(titleWidget.style?.color, equals(MetaColors.textPrimary));

      // Seções e Cards B2B
      expect(find.text('Como'), findsOneWidget);
      expect(find.text('Expanda sua empresa'), findsOneWidget);
      expect(find.text('Link Direto da sua Vitrine B2B'), findsOneWidget);
      expect(find.text('Planos de Consultoria & Preços'), findsOneWidget);
      expect(find.text('Assinatura Mr. Coach'), findsOneWidget);
      expect(find.text('Minha Vitrine Pública'), findsOneWidget);
      expect(find.text('Conexão WhatsApp'), findsOneWidget);
    });

    testWidgets('SubscriptionScreen renders AppBar and state cleanly in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: SubscriptionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planos & Assinatura'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Planos & Assinatura'));
      expect(titleWidget.style?.color, equals(const Color(0xFF0F172A)));
      expect(find.byTooltip('Atualizar'), findsOneWidget);
    });

    testWidgets('SubscriptionScreen renders AppBar and state cleanly in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: SubscriptionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planos & Assinatura'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Planos & Assinatura'));
      expect(titleWidget.style?.color, equals(MetaColors.textPrimary));
      expect(find.byTooltip('Atualizar'), findsOneWidget);
    });
  });
}
