import 'dart:js_interop';

@JS('isPwaInstalled')
external JSBoolean? _jsIsPwaInstalled();

@JS('promptPwaInstall')
external void _jsPromptPwaInstall();

@JS('pwaDeferredPrompt')
external JSAny? _jsPwaDeferredPrompt;

@JS('navigator.userAgent')
external JSString? _jsUserAgent;

bool isPwaInstalled() {
  try {
    return _jsIsPwaInstalled()?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

bool canPromptInstall() {
  try {
    return _jsPwaDeferredPrompt != null;
  } catch (_) {
    return false;
  }
}

void promptInstall() {
  try {
    _jsPromptPwaInstall();
  } catch (_) {}
}

bool isIosWeb() {
  try {
    final ua = _jsUserAgent?.toDart.toLowerCase() ?? '';
    return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  } catch (_) {
    return false;
  }
}

bool isAndroidWeb() {
  try {
    final ua = _jsUserAgent?.toDart.toLowerCase() ?? '';
    return ua.contains('android');
  } catch (_) {
    return false;
  }
}

@JS('_pwaHasPendingUpdate')
external JSBoolean? _jsHasPendingUpdate;

@JS('triggerPwaReload')
external void _jsTriggerPwaReload();

@JS('hardReloadApp')
external void _jsHardReloadApp();

@JS('forceAppReload')
external void _jsForceAppReload();

@JS('_onPwaUpdateAvailable')
external set _jsOnPwaUpdateAvailable(JSFunction? callback);

bool hasPendingUpdate() {
  try {
    return _jsHasPendingUpdate?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

void onPwaUpdateAvailable(void Function() callback) {
  try {
    _jsOnPwaUpdateAvailable = (() {
      callback();
    }).toJS;
  } catch (_) {}
}

void triggerPwaReload() {
  try {
    _jsTriggerPwaReload();
    return;
  } catch (_) {}

  try {
    _jsHardReloadApp();
    return;
  } catch (_) {}

  try {
    _jsForceAppReload();
    return;
  } catch (_) {}
}

@JS('isWebBiometricsAvailable')
external JSPromise<JSBoolean> _jsIsWebBiometricsAvailable();

@JS('authenticateWithWebBiometrics')
external JSPromise<JSBoolean> _jsAuthenticateWithWebBiometrics();

Future<bool> isWebBiometricsAvailable() async {
  try {
    final res = await _jsIsWebBiometricsAvailable().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateWithWebBiometrics() async {
  try {
    final res = await _jsAuthenticateWithWebBiometrics().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}

@JS('unlockAudioContext')
external void _jsUnlockAudioContext();

@JS('triggerRestTimerCue')
external void _jsTriggerRestTimerCue(
  JSNumber secondsRemaining,
  JSBoolean soundEnabled,
  JSBoolean hapticEnabled,
);

void unlockAudioContext() {
  try {
    _jsUnlockAudioContext();
  } catch (_) {}
}

void triggerRestTimerCue(
  int secondsRemaining,
  bool soundEnabled,
  bool hapticEnabled,
) {
  try {
    _jsTriggerRestTimerCue(
      secondsRemaining.toJS,
      soundEnabled.toJS,
      hapticEnabled.toJS,
    );
  } catch (_) {}
}
