import 'package:flutter/foundation.dart';

class AppConfig {
  static String _customApiBaseUrl = '';

  static String get apiBaseUrl {
    if (_customApiBaseUrl.isNotEmpty) {
      return _customApiBaseUrl;
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    // IP padrão da sua máquina na rede local Wi-Fi para celular físico
    return 'http://192.168.1.100:8000/api/v1';
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

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_GM85tixsI7l1WTU3jhEmoQ_s_pv_F6C',
  );
}
