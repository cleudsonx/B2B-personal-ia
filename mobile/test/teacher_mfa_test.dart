import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:personal_ia/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
