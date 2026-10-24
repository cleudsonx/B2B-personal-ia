import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:personal_ia/features/auth/teacher_mfa_screen.dart';
import 'package:personal_ia/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Teacher MFA & Error Formatting Tests', () {
    test('formatMfaError converts raw AuthApiException to friendly message', () {
      const error = AuthApiException(
        'Invalid TOTP code entered',
        statusCode: '422',
        code: 'mfa_verification_failed',
      );

      final formatted = AuthService.formatMfaError(error);
      expect(formatted, contains('Código do autenticador inválido ou expirado'));
      expect(formatted, contains('sincronize a hora'));
    });

    test('formatMfaError converts mfa_factor_name_conflict to clear recovery message', () {
      const error = AuthApiException(
        'A factor with the friendly name "Mr. Coach Trainer" for this user already exists',
        statusCode: '422',
        code: 'mfa_factor_name_conflict',
      );

      final formatted = AuthService.formatMfaError(error);
      expect(formatted, contains('Chave anterior em conflito detectada'));
      expect(formatted, contains('Tentar novamente'));
    });

    test('formatMfaError converts string exceptions with TOTP failure to friendly message', () {
      final error = Exception('AuthApiException(message: Invalid TOTP code entered, statusCode: 422, code: mfa_verification_failed)');
      final formatted = AuthService.formatMfaError(error);
      expect(formatted, contains('Código do autenticador inválido ou expirado'));
    });

    test('formatMfaError converts network failures gracefully', () {
      final error = Exception('SocketException: Failed host lookup');
      final formatted = AuthService.formatMfaError(error);
      expect(formatted, contains('Falha de conexão com a internet'));
    });

    test('formatMfaError handles fallback gracefully', () {
      final error = Exception('Unexpected unknown error');
      final formatted = AuthService.formatMfaError(error);
      expect(formatted, contains('Não foi possível validar o código do autenticador'));
    });
  });

  group('Trusted Device (30 Dias) Local Storage Tests', () {
    test('isCurrentDeviceTrusted returns false when no trusted token is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final isTrusted = await AuthService.isCurrentDeviceTrusted();
      expect(isTrusted, isFalse);
    });

    test('saveCurrentDeviceTrusted stores token and future timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.saveCurrentDeviceTrusted(
        token: 'test_token_abc_123',
        untilStr: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );

      final isTrusted = await AuthService.isCurrentDeviceTrusted();
      expect(isTrusted, isTrue);

      await AuthService.clearCurrentDeviceTrusted();
      final isTrustedAfterClear = await AuthService.isCurrentDeviceTrusted();
      expect(isTrustedAfterClear, isFalse);
    });

    test('isCurrentDeviceTrusted returns false when trusted timestamp is in the past', () async {
      SharedPreferences.setMockInitialValues({
        'mfa_trusted_until_device_default': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'mfa_trusted_token_device_default': 'expired_token',
      });

      final isTrusted = await AuthService.isCurrentDeviceTrusted();
      expect(isTrusted, isFalse);
    });
  });

  group('TeacherMfaScreen Widget & Multi-channel UI Tests', () {
    testWidgets('renders screen with trusted device checkbox and alternative methods button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TeacherMfaScreen(
            allowEnrollment: false,
            initialMethod: MfaMethod.backupCode, // Avoid network trigger on init
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Segurança do Treinador'), findsOneWidget);
      expect(find.text('Código de Reserva'), findsOneWidget);
      expect(find.textContaining('Confiar neste dispositivo por 30 dias'), findsOneWidget);
      expect(find.text('Tentar de outro jeito'), findsOneWidget);
      expect(find.text('Verificar código'), findsOneWidget);

      // Tap on "Tentar de outro jeito" to open bottom sheet
      await tester.tap(find.text('Tentar de outro jeito'));
      await tester.pumpAndSettle();

      expect(find.text('Opções de verificação'), findsOneWidget);
      expect(find.text('WhatsApp (Recomendado)'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Aplicativo Autenticador'), findsOneWidget);
      expect(find.text('Código de reserva'), findsOneWidget);
      expect(find.textContaining('Perdeu o autenticador ou trocou de celular?'), findsOneWidget);
    });
  });
}
