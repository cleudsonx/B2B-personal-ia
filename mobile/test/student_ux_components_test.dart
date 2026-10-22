import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/student_ux_components.dart';

void main() {
  group('StudentUXComponents', () {
    testWidgets('StudentSectionHeader renderiza título, subtítulo e botão de ação',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentSectionHeader(
              title: 'Biometria e evolução',
              subtitle: 'Dados usados para calibrar suas cargas',
              icon: Icons.monitor_weight_rounded,
              actionLabel: 'Editar',
              onActionTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Biometria e evolução'), findsOneWidget);
      expect(find.text('Dados usados para calibrar suas cargas'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);

      await tester.tap(find.text('Editar'));
      expect(tapped, isTrue);
    });

    testWidgets('ProgressRing e StatTile renderizam métricas com tabular figures',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ProgressRing(
                  progress: 0.75,
                  size: 64,
                  center: Text('75%'),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Peso atual',
                    value: '72.4',
                    unit: 'kg',
                    badgeText: '-0.8 kg',
                    icon: Icons.monitor_weight_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Peso atual'), findsOneWidget);
      expect(find.text('72.4'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('-0.8 kg'), findsOneWidget);
    });

    testWidgets('TrainerCompactPill renderiza estado ativo e botão de WhatsApp',
        (tester) async {
      var whatsappTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerCompactPill(
              trainerName: 'Prof. Cleudson',
              trainerCref: '012345-G/SP',
              hasWhatsApp: true,
              onWhatsAppTap: () => whatsappTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Prof. Cleudson'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);
      expect(find.text('CREF 012345-G/SP'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      await tester.tap(find.text('WhatsApp'));
      expect(whatsappTapped, isTrue);
    });

    testWidgets('SettingsGroup e SettingsTile renderizam linhas agrupadas',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Aparência',
                  trailingText: 'Escuro',
                  onTap: () => tapped = true,
                ),
                const SettingsTile(
                  icon: Icons.public_rounded,
                  title: 'Fuso horário',
                  trailingText: 'São Paulo',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Aparência'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      expect(find.text('Fuso horário'), findsOneWidget);
      expect(find.text('São Paulo'), findsOneWidget);

      await tester.tap(find.text('Aparência'));
      expect(tapped, isTrue);
    });
  });
}

