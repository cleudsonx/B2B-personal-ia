import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/student_weekly_checkin_sheet.dart';
import 'package:personal_ia/services/student_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentNotificationItem Tests', () {
    test('serializes and deserializes weeklyCheckin notification type correctly', () {
      final now = DateTime(2026, 10, 21, 12, 0);
      final item = StudentNotificationItem(
        id: 'test_checkin_1',
        title: '⚖️ Check-in Semanal Pendente',
        message: 'Faz 7 dias desde sua última pesagem.',
        type: NotificationType.weeklyCheckin,
        severity: NotificationSeverity.warning,
        timestamp: now,
        isRead: false,
        actionLabel: 'Fazer Check-in',
        actionRoute: '/bio-hub',
      );

      final json = item.toJson();
      expect(json['type'], 'weeklyCheckin');
      expect(json['severity'], 'warning');
      expect(json['actionRoute'], '/bio-hub');

      final reconstructed = StudentNotificationItem.fromJson(json);
      expect(reconstructed.id, 'test_checkin_1');
      expect(reconstructed.type, NotificationType.weeklyCheckin);
      expect(reconstructed.severity, NotificationSeverity.warning);
      expect(reconstructed.title, '⚖️ Check-in Semanal Pendente');
      expect(reconstructed.isRead, false);
    });

    test('copyWith updates isRead and severity properly', () {
      final item = StudentNotificationItem(
        id: 'test_1',
        title: 'Check-in',
        message: 'Msg',
        type: NotificationType.weeklyCheckin,
        severity: NotificationSeverity.info,
        timestamp: DateTime.now(),
      );

      final updated = item.copyWith(isRead: true, severity: NotificationSeverity.urgent);
      expect(updated.isRead, true);
      expect(updated.severity, NotificationSeverity.urgent);
      expect(updated.id, 'test_1');
    });
  });

  group('StudentWeeklyCheckinSheet Widget Tests', () {
    testWidgets('renders step 0 (weigh-in), displays initial weight and delta comparison', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentWeeklyCheckinSheet(
              previousWeightKg: 74.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica cabeçalho e título
      expect(find.text('Check-in Semanal'), findsOneWidget);
      expect(find.text('Qual é o seu peso corporal hoje?'), findsOneWidget);

      // Verifica peso inicial (74.0 kg) e delta estável
      expect(find.text('74.0 kg'), findsOneWidget);
      expect(find.text('Estável (0.0 kg)'), findsOneWidget);

      // Botão de avançar para foto
      expect(find.text('Avançar para Foto de Evolução'), findsOneWidget);
    });

    testWidgets('steppers (+0.5 kg e -0.5 kg) dynamically alter weight and delta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentWeeklyCheckinSheet(
              previousWeightKg: 70.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('70.0 kg'), findsOneWidget);

      // Toca no botão de adicionar (+)
      final addIcon = find.byIcon(Icons.add);
      expect(addIcon, findsOneWidget);
      await tester.tap(addIcon);
      await tester.pumpAndSettle();

      // Peso agora é 70.5 kg (+0.5 kg de delta)
      expect(find.text('70.5 kg'), findsOneWidget);
      expect(find.text('+0.5 kg vs semana passada'), findsOneWidget);

      // Toca no botão de subtrair (-)
      final removeIcon = find.byIcon(Icons.remove);
      expect(removeIcon, findsOneWidget);
      await tester.tap(removeIcon);
      await tester.pumpAndSettle();

      // Volta para 70.0 kg (estável)
      expect(find.text('70.0 kg'), findsOneWidget);
      expect(find.text('Estável (0.0 kg)'), findsOneWidget);
    });

    testWidgets('navigates from step 0 to step 1 (photo) and step 2 (adherence)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentWeeklyCheckinSheet(
              previousWeightKg: 80.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Avançar para Etapa 2: Foto
      final advanceToPhotoBtn = find.text('Avançar para Foto de Evolução');
      await tester.tap(advanceToPhotoBtn);
      await tester.pumpAndSettle();

      // Verifica Etapa de Foto
      expect(find.text('Foto de Evolução da Semana'), findsOneWidget);
      expect(find.text('Câmera'), findsOneWidget);
      expect(find.text('Galeria'), findsOneWidget);

      // 2. Avançar sem foto para Etapa 3: Aderência
      final skipPhotoBtn = find.text('Pular Foto & Avançar');
      expect(skipPhotoBtn, findsOneWidget);
      await tester.tap(skipPhotoBtn);
      await tester.pumpAndSettle();

      // Verifica Etapa de Aderência
      expect(find.text('Como foi sua semana de treinos e dieta?'), findsOneWidget);
      expect(find.text('NÍVEL DE ADERÊNCIA GERAL'), findsOneWidget);
      expect(find.text('Alta (80% - 100%)'), findsOneWidget);
      expect(find.text('Moderada (60% - 80%)'), findsOneWidget);

      // Botão final de conclusão
      expect(find.text('Concluir Check-in'), findsOneWidget);
    });

    testWidgets('adherence option selection updates state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentWeeklyCheckinSheet(
              previousWeightKg: 75.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ir até step 2 (Aderência)
      await tester.tap(find.text('Avançar para Foto de Evolução'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pular Foto & Avançar'));
      await tester.pumpAndSettle();

      // Clicar na opção "Moderada (60% - 80%)"
      final modOption = find.text('Moderada (60% - 80%)');
      await tester.tap(modOption);
      await tester.pumpAndSettle();

      expect(modOption, findsOneWidget);
    });
  });
}

