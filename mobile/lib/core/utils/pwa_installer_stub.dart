bool isPwaInstalled() => false;
bool canPromptInstall() => false;
void promptInstall() {}
bool isIosWeb() => false;
bool isAndroidWeb() => false;
bool hasPendingUpdate() => false;
void triggerPwaReload() {}
Future<bool> isWebBiometricsAvailable() async => false;
Future<bool> authenticateWithWebBiometrics() async => false;

