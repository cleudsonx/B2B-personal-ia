import 'package:flutter/foundation.dart';
import 'pwa_installer_stub.dart'
    if (dart.library.js_interop) 'pwa_installer_web.dart'
    as impl;

class PwaInstaller {
  /// Retorna true se o app já estiver instalado e rodando em modo standalone.
  static bool get isPwaInstalled {
    if (!kIsWeb) return false;
    return impl.isPwaInstalled();
  }

  /// Retorna true se houver suporte a disparar o prompt nativo (ex: Chrome no Android/Desktop).
  static bool get canPromptInstall {
    if (!kIsWeb) return false;
    return impl.canPromptInstall();
  }

  /// Dispara o prompt nativo de instalação do navegador.
  static void promptInstall() {
    if (!kIsWeb) return;
    impl.promptInstall();
  }

  /// Retorna true se o usuário estiver acessando via navegador no iOS (Safari/Chrome no iPhone/iPad).
  static bool get isIosWeb {
    if (!kIsWeb) return false;
    return impl.isIosWeb();
  }

  /// Retorna true se o usuário estiver acessando via navegador no Android.
  static bool get isAndroidWeb {
    if (!kIsWeb) return false;
    return impl.isAndroidWeb();
  }
}

