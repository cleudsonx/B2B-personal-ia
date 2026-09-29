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
    if (c == null) throw Exception('Serviço de autenticação temporariamente indisponível.');
    return c;
  }

  static Map<String, dynamic>? _cachedProfile;

  /// Retorna o usuário logado atualmente (ou null)
  static User? get currentUser => _clientOrNull?.auth.currentUser;

  /// Retorna a sessão ativa com o token JWT
  static Session? get currentSession => _clientOrNull?.auth.currentSession;

  /// Retorna o Access Token JWT para enviar nos headers do backend FastAPI
  static String? get accessToken => _clientOrNull?.auth.currentSession?.accessToken;

  /// Stream reativo para observar mudanças no estado de login/logout
  static Stream<AuthState> get onAuthStateChange =>
      _clientOrNull?.auth.onAuthStateChange ?? const Stream.empty();

  /// Realiza login com e-mail e senha e garante integridade do perfil
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      return response;
    } catch (e) {
      throw Exception('Falha ao autenticar: ${_formatAuthError(e)}');
    }
  }

  /// Cadastro de novo usuário (Personal Trainer ou Aluno) com persistência imediata
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
      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      return response;
    } catch (e) {
      throw Exception('Falha ao criar conta: ${_formatAuthError(e)}');
    }
  }

  /// Garante que o registro na tabela 'profiles' existe e está atualizado
  static Future<void> _ensureProfileUpserted(User user) async {
    try {
      final fullName = user.userMetadata?['full_name'] as String? ?? 'Usuário';
      final role = user.userMetadata?['role'] as String? ?? 'trainer';
      final phone = user.userMetadata?['phone'] as String?;
      final trainerId = user.userMetadata?['trainer_id'] as String?;

      final payload = <String, dynamic>{
        'id': user.id,
        'full_name': fullName,
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (user.email != null) payload['email'] = user.email;
      if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
      if (trainerId != null && trainerId.isNotEmpty) payload['trainer_id'] = trainerId;

      _cachedProfile = Map<String, dynamic>.from(payload);
      await _client.from('profiles').upsert(payload);
    } catch (_) {
      // Ignora erro se RLS restringir upsert direto sem alterar funcionalidade
    }
  }

  /// Busca os dados do perfil na tabela 'profiles' com fallback seguro
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        _cachedProfile = Map<String, dynamic>.from(data);
        return data;
      }
    } catch (_) {}

    // Fallback para metadados salvos no auth ou cache local
    return _cachedProfile ?? {
      'id': user.id,
      'full_name': user.userMetadata?['full_name'] ?? 'Usuário',
      'role': user.userMetadata?['role'] ?? 'trainer',
      'email': user.email,
    };
  }

  /// Busca os dados do professor vinculado ao aluno atual
  static Future<Map<String, dynamic>?> getTrainerForStudent() async {
    try {
      final profile = await getCurrentProfile();
      final trainerId = profile?['trainer_id'] as String?;
      if (trainerId != null && trainerId.isNotEmpty && _clientOrNull != null) {
        final trainer = await _client
            .from('profiles')
            .select('id, full_name, email, phone')
            .eq('id', trainerId)
            .maybeSingle();
        return trainer;
      }
    } catch (_) {}
    return null;
  }

  /// Desconectar a sessão e limpar caches
  static Future<void> signOut() async {
    _cachedProfile = null;
    try {
      await _clientOrNull?.auth.signOut();
    } catch (_) {}
  }

  static String _formatAuthError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    } else if (str.contains('email not confirmed')) {
      return 'E-mail não confirmado. Verifique a confirmação na sua caixa de entrada.';
    } else if (str.contains('email already in use') || str.contains('user already registered')) {
      return 'Este e-mail já está cadastrado.';
    } else if (str.contains('password should be at least')) {
      return 'A senha deve ter no mínimo 6 caracteres.';
    }
    return error.toString();
  }
}
