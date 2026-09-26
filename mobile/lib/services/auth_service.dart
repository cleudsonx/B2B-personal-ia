import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get _client {
    final c = _clientOrNull;
    if (c == null) throw Exception('Supabase não inicializado.');
    return c;
  }

  /// Retorna o usuário logado atualmente (ou null)
  static User? get currentUser => _clientOrNull?.auth.currentUser;

  /// Retorna a sessão ativa com o token JWT
  static Session? get currentSession => _clientOrNull?.auth.currentSession;

  /// Retorna o Access Token JWT para enviar nos headers do backend FastAPI
  static String? get accessToken => _clientOrNull?.auth.currentSession?.accessToken;

  /// Stream reativo para observar mudanças no estado de login/logout
  static Stream<AuthState> get onAuthStateChange =>
      _clientOrNull?.auth.onAuthStateChange ?? const Stream.empty();

  /// Realiza login com e-mail e senha
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Falha ao autenticar: ${_formatAuthError(e)}');
    }
  }

  /// Cadastro de novo usuário (Personal Trainer ou Aluno)
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role, // 'trainer' ou 'client'
    String? phone,
    String? trainerId,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          if (trainerId != null && trainerId.isNotEmpty) 'trainer_id': trainerId,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Falha ao criar conta: ${_formatAuthError(e)}');
    }
  }

  /// Busca os dados do perfil na tabela 'profiles'
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data;
    } catch (_) {
      // Fallback para metadados salvos no auth se tabela ainda não tiver sido sincronizada
      return {
        'id': user.id,
        'full_name': user.userMetadata?['full_name'] ?? 'Usuário',
        'role': user.userMetadata?['role'] ?? 'trainer',
      };
    }
  }

  /// Desconectar a sessão
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static String _formatAuthError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    } else if (str.contains('email already in use') || str.contains('user already registered')) {
      return 'Este e-mail já está cadastrado.';
    } else if (str.contains('password should be at least')) {
      return 'A senha deve ter no mínimo 6 caracteres.';
    }
    return error.toString();
  }
}
