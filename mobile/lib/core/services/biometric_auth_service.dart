import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../utils/pwa_installer.dart';

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });

  factory BiometricAuthResult.ok() => const BiometricAuthResult(success: true);
  factory BiometricAuthResult.fail(String message) => BiometricAuthResult(success: false, errorMessage: message);
}

/// Serviço Unificado de Autenticação Biométrica e Retorno com 1 Toque
///
/// Suporta nativamente:
/// - iOS e Android Nativo via `local_auth` (Face ID, Touch ID, Biometria Android)
/// - PWA / Web no iOS (Safari Face ID/Touch ID) e Android (Chrome WebAuthn / Sensor de Digital)
///   sem lançar `MissingPluginException`.
class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Verifica se o dispositivo atual possui suporte a biometria
  static Future<bool> isBiometricsAvailable() async {
    if (kIsWeb) {
      try {
        final webSupported = await PwaInstaller.isWebBiometricsAvailable();
        // Em Web/PWA no iOS ou Android, se houver suporte a WebAuthn ou for dispositivo móvel
        return webSupported || PwaInstaller.isIosWeb || PwaInstaller.isAndroidWeb;
      } catch (_) {
        return false;
      }
    }

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Autentica o usuário com a biometria nativa do aparelho ou folha WebAuthn
  static Future<BiometricAuthResult> authenticate({
    String localizedReason = 'Autentique-se com biometria para acessar sua conta',
  }) async {
    // 1. Fluxo Web / PWA (iOS Safari / Android Chrome)
    if (kIsWeb) {
      try {
        final webSuccess = await PwaInstaller.authenticateWithWebBiometrics();
        if (webSuccess) {
          return BiometricAuthResult.ok();
        }
        return BiometricAuthResult.fail(
          'Autenticação biométrica cancelada ou não reconhecida.',
        );
      } catch (e) {
        return BiometricAuthResult.fail(
          'Não foi possível concluir a biometria no navegador. Digite sua senha ou entre via WhatsApp.',
        );
      }
    }

    // 2. Fluxo Nativo (APK Android / IPA iOS)
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        return BiometricAuthResult.fail(
          'Autenticação biométrica não configurada neste dispositivo.',
        );
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );

      if (didAuth) {
        return BiometricAuthResult.ok();
      } else {
        return BiometricAuthResult.fail('Autenticação cancelada.');
      }
    } catch (e) {
      return BiometricAuthResult.fail(
        'Falha no leitor biométrico. Por favor, use sua senha.',
      );
    }
  }
}

