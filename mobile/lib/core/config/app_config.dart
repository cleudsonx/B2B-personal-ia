class AppConfig {
  static String _customApiBaseUrl = '';

  static String get apiBaseUrl {
    if (_customApiBaseUrl.isNotEmpty) {
      return _customApiBaseUrl;
    }
    const envUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://b2b-personal-ia-backend.onrender.com/api/v1',
    );
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return 'https://b2b-personal-ia-backend.onrender.com/api/v1';
  }

  static set apiBaseUrl(String url) {
    String clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.endsWith('/api/v1')) {
      clean = '$clean/api/v1';
    }
    _customApiBaseUrl = clean;
  }

  /// Endpoint do assistente Gemini B2B via backend oficial
  static String get assistantChatUrl => '$apiBaseUrl/assistant/chat';

  // Configurações do Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rgbyfiulomxpqkuufdtg.supabase.co',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_GM85tixsI7l1WTU3jhEmoQ_s_pv_F6C',
    ),
  );

  static const String supabaseAnonKey = supabasePublishableKey;

  // Informações Oficiais de Versionamento (SemVer) & Build
  static const String appVersion = '1.2.0';
  static const int buildNumber = 2026102701;
  static const String buildDate = '14 de Outubro, 2026';
  static const String releaseNotes =
      'Bio-Hub, Smart Re-entry PWA e Biomecânica 3D Loop com Raio-X Muscular';

  static String get fullVersionString => 'v$appVersion (Build $buildNumber)';
}
