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

