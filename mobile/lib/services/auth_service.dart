import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import 'invite_service.dart';

class AuthService {
  static Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      debugPrint('UpdatePassword error: ');
      rethrow;
    }
  }
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
    String? inviteToken,
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
          if (inviteToken != null && inviteToken.isNotEmpty)
            'invite_token': inviteToken,
        },
      );
      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      if (response.session != null && response.user != null) {
        try {
          await _consumePendingInvite(response.user!);
        } catch (e) {
          debugPrint('Convite pendente será tentado novamente no onboarding: $e');
        }
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
            inviteToken: inviteToken,
            professionalDocumentType: professionalDocumentType,
            professionalDocument: professionalDocument,
          );
          final authRes = await signIn(email: email, password: password);
          return authRes;
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
    String? inviteToken,
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
            if (inviteToken != null && inviteToken.isNotEmpty)
              'invite_token': inviteToken,
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

  static Future<void> _consumePendingInvite(User user) async {
    final token = user.userMetadata?['invite_token'] as String?;
    if (token == null || token.isEmpty) return;

    await InviteService.consumeInvite(token);
    final updatedMetadata = Map<String, dynamic>.from(user.userMetadata ?? {});
    updatedMetadata.remove('invite_token');
    await _client.auth.updateUser(UserAttributes(data: updatedMetadata));
    _cachedProfile = null;
  }

  static Future<void> completePendingInvite() async {
    final user = currentUser;
    if (user != null) await _consumePendingInvite(user);
  }

  static Future<void> consumeInviteToken(String token) async {
    await InviteService.consumeInvite(token);
    _cachedProfile = null;
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

  static List<String> availableRoles(Map<String, dynamic>? profile) {
    final roles = profile?['roles'];
    if (roles is List) {
      final normalized = roles.whereType<String>().toSet().toList();
      if (normalized.isNotEmpty) return normalized;
    }
    final role = profile?['role'];
    return role is String && role.isNotEmpty ? [role] : ['client'];
  }

  static Future<String> getActiveRole(Map<String, dynamic>? profile) async {
    final roles = availableRoles(profile);
    final userId = currentUser?.id;
    if (userId == null) return roles.first;
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('active_role_$userId');
    return roles.contains(savedRole) ? savedRole! : roles.first;
  }

  static Future<void> setActiveRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final profile = await getCurrentProfile();
    if (!availableRoles(profile).contains(role)) {
      throw StateError('Este perfil não possui acesso ao contexto selecionado.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_role_$userId', role);
  }

  static Future<String?> getVerifiedTotpFactorId() async {
    final factors = await _client.auth.mfa.listFactors();
    for (final factor in factors.totp) {
      if (factor.status == FactorStatus.verified) return factor.id;
    }
    return null;
  }

  static Future<AuthMFAEnrollResponse> enrollTeacherTotp() {
    return _client.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Mr. Coach',
      friendlyName: 'Mr. Coach Trainer',
    );
  }

  static Future<void> verifyTotp({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _client.auth.mfa.challenge(factorId: factorId);
    await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code.trim(),
    );
  }

  static Future<bool> isCurrentSessionAal2() async {
    final assurance = await _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return assurance.currentLevel?.name == 'aal2';
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
            .select('id, full_name, professional_document')
                .eq('id', trainerId)
                .maybeSingle();
        return trainer;
      }
    } catch (_) {}
    return null;
  }

  /// Desconectar a sessão e limpar caches
  
  static Future<void> requestRecoveryOtp(String identifier, String channel) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/recovery/request-otp');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'phone_or_email': identifier.trim(),
        'channel': channel,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String msg = 'Erro ao solicitar recuperação (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> verifyRecoveryOtp(String identifier, String otpCode, String newPassword) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/recovery/verify-otp');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'phone_or_email': identifier.trim(),
        'otp_code': otpCode.trim(),
        'new_password': newPassword,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String msg = 'Erro ao verificar código (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static Future<void> signOut({bool allDevices = false}) async {
    _cachedProfile = null;
    final client = _clientOrNull;
    if (client == null) return;
    if (allDevices) {
      final token = client.auth.currentSession?.accessToken;
      if (token == null) throw StateError('Não há sessão autenticada.');
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/auth/revoke-sessions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Não foi possível revogar as sessões da conta.');
      }
      await client.auth.signOut(scope: SignOutScope.global);
      return;
    }
    await client.auth.signOut(scope: SignOutScope.local);
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
