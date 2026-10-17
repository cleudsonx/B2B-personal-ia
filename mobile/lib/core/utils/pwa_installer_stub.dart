bool isPwaInstalled() => false;
bool canPromptInstall() => false;
void promptInstall() {}
bool isIosWeb() => false;
bool isAndroidWeb() => false;
bool hasPendingUpdate() => false;
void triggerPwaReload() {}
void onPwaUpdateAvailable(void Function() callback) {}
Future<bool> isWebBiometricsAvailable() async => false;
Future<bool> authenticateWithWebBiometrics() async => false;


