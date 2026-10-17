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

@JS('window._pwaHasPendingUpdate')
external JSBoolean? _jsHasPendingUpdate;

@JS('window.triggerPwaReload')
external JSFunction? _jsTriggerPwaReload;

@JS('window._onPwaUpdateAvailable')
external set _jsOnPwaUpdateAvailable(JSFunction? callback);

@JS('window.location.reload')
external void _jsLocationReload();

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
    if (_jsTriggerPwaReload != null) {
      _jsTriggerPwaReload!.callAsFunction();
    } else {
      _jsLocationReload();
    }
  } catch (_) {
    try {
      _jsLocationReload();
    } catch (_) {}
  }
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

