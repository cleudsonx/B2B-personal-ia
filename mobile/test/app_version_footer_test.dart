import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/config/app_config.dart';
import 'package:personal_ia/core/widgets/app_version_footer.dart';

void main() {
  testWidgets('AppVersionFooter exibe versão formatada e abre notas ao tocar',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVersionFooter(),
        ),
      ),
    );

    // Verifica que exibe a versão formatada
    expect(find.text(AppConfig.fullVersionString), findsOneWidget);
    expect(find.text('Mr. Coach AI'), findsOneWidget);

    // Toca no componente para abrir as notas de versão
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Verifica que o BottomSheet com o changelog abriu
    expect(find.text('NOVIDADES DESTA VERSÃO'), findsOneWidget);
    expect(find.text('Smart Re-entry PWA'), findsOneWidget);
    expect(find.text('Mr. Coach AI Biomecânico'), findsOneWidget);
    expect(find.text('Entendido'), findsOneWidget);

    // Fecha o modal
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.text('NOVIDADES DESTA VERSÃO'), findsNothing);
  });
}
