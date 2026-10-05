import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';

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
    if (c == null) {
      throw Exception('Serviço de autenticação temporariamente indisponível.');
    }
    return c;
  }

  static Map<String, dynamic>? _cachedProfile;

  /// Retorna o usuário logado atualmente (ou null)
  static User? get currentUser => _clientOrNull?.auth.currentUser;

  /// Retorna a sessão ativa com o token JWT
  static Session? get currentSession => _clientOrNull?.auth.currentSession;

  /// Retorna o Access Token JWT para enviar nos headers do backend FastAPI
  static String? get accessToken =>
      _clientOrNull?.auth.currentSession?.accessToken;

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
    String? professionalDocumentType, // 'CREF', 'CBMF', 'CPF'
    String?
    professionalDocument, // Ex: 'CREF 019284-G/SP', 'CBMF-10294', '123.456.789-00'
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          if (trainerId != null && trainerId.isNotEmpty)
            'trainer_id': trainerId,
          if (professionalDocumentType != null)
            'professional_document_type': professionalDocumentType,
          if (professionalDocument != null)
            'professional_document': professionalDocument,
          if (professionalDocument != null)
            'cref_or_registry': professionalDocument,
          if (professionalDocument != null &&
              professionalDocumentType == 'CREF')
            'cref': professionalDocument,
        },
      );
      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      return response;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('confirmation email') ||
          errStr.contains('unexpected_failure') ||
          errStr.contains('statuscode: 500')) {
        try {
          await _registerViaBackend(
            email: email,
            password: password,
            fullName: fullName,
            role: role,
            phone: phone,
            trainerId: trainerId,
            professionalDocumentType: professionalDocumentType,
            professionalDocument: professionalDocument,
          );
          return await signIn(email: email, password: password);
        } catch (backendErr) {
          throw Exception(
            'Falha ao criar conta: ${_formatAuthError(backendErr)}',
          );
        }
      }
      throw Exception('Falha ao criar conta: ${_formatAuthError(e)}');
    }
  }

  /// Cadastro direto via Backend com bypass de SMTP quando o serviço de e-mail do Supabase falha
  static Future<void> _registerViaBackend({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
    String? trainerId,
    String? professionalDocumentType,
    String? professionalDocument,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/register-direct');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'full_name': fullName.trim(),
            'role': role,
            if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
            if (trainerId != null && trainerId.isNotEmpty)
              'trainer_id': trainerId,
            if (professionalDocumentType != null)
              'professional_document_type': professionalDocumentType,
            if (professionalDocument != null)
              'professional_document': professionalDocument,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String msg = 'Erro no servidor ao criar conta (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }

  /// Garante que o registro na tabela 'profiles' existe e está atualizado
  static Future<void> _ensureProfileUpserted(User user) async {
    try {
      final fullName = user.userMetadata?['full_name'] as String? ?? 'Usuário';
      final role = user.userMetadata?['role'] as String? ?? 'trainer';
      final phone = user.userMetadata?['phone'] as String?;
      final trainerId = user.userMetadata?['trainer_id'] as String?;
      final docType =
          user.userMetadata?['professional_document_type'] as String?;
      final doc = user.userMetadata?['professional_document'] as String?;
      final crefOrReg = user.userMetadata?['cref_or_registry'] as String?;

      final payload = <String, dynamic>{
        'id': user.id,
        'full_name': fullName,
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (user.email != null) payload['email'] = user.email;
      if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
      if (trainerId != null && trainerId.isNotEmpty) {
        payload['trainer_id'] = trainerId;
      }
      if (docType != null && docType.isNotEmpty) {
        payload['professional_document_type'] = docType;
      }
      if (doc != null && doc.isNotEmpty) payload['professional_document'] = doc;
      if (crefOrReg != null && crefOrReg.isNotEmpty) {
        payload['cref_or_registry'] = crefOrReg;
      }

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
      final data =
          await _client
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
    return _cachedProfile ??
        {
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Usuário',
          'role': user.userMetadata?['role'] ?? 'trainer',
          'email': user.email,
          'professional_document_type':
              user.userMetadata?['professional_document_type'],
          'professional_document': user.userMetadata?['professional_document'],
          'cref_or_registry': user.userMetadata?['cref_or_registry'],
          'cref': user.userMetadata?['cref'],
        };
  }

  /// Busca os dados do professor vinculado ao aluno atual
  static Future<Map<String, dynamic>?> getTrainerForStudent() async {
    try {
      final profile = await getCurrentProfile();
      final trainerId = profile?['trainer_id'] as String?;
      if (trainerId != null && trainerId.isNotEmpty && _clientOrNull != null) {
        final trainer =
            await _client
                .from('profiles')
                .select()
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
    } else if (str.contains('email already in use') ||
        str.contains('user already registered')) {
      return 'Este e-mail já está cadastrado.';
    } else if (str.contains('password should be at least')) {
      return 'A senha deve ter no mínimo 6 caracteres.';
    }
    return error.toString();
  }
}
