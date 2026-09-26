
class AppConfig {
  // Ajuste para a URL da sua API backend
  // - Emulador Android: 'http://10.0.2.2:8000/api/v1'
  // - Dispositivo físico / Rede local: 'http://<IP_DO_SEU_PC>:8000/api/v1'
  // - Produção (Render/Fly.io): 'https://sua-api.onrender.com/api/v1'
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  // Configurações do Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );
}
