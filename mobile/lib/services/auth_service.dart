import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import 'device_session_service.dart';
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
  /// Inclui retry automático com backoff exponencial para `AuthRetryableFetchException` / cold start
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    const int maxAttempts = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        if (response.user != null) {
          await _ensureProfileUpserted(response.user!);
          DeviceSessionService.registerCurrentSession();
        }
        return response;
      } catch (e) {
        final isRetryable = _isRetryableNetworkError(e);
        if (isRetryable && attempt < maxAttempts) {
          debugPrint('[AuthService] Falha transitória de rede ($attempt/$maxAttempts): $e. Tentando novamente...');
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        throw Exception('Falha ao autenticar: ${_formatAuthError(e)}');
      }
    }
  }

  static bool _isRetryableNetworkError(Object error) {
    if (error is AuthRetryableFetchException) return true;
    final str = error.toString().toLowerCase();
    return str.contains('clientload failed') ||
        str.contains('authretryablefetchexception') ||
        str.contains('failed host lookup') ||
        str.contains('socketexception') ||
        str.contains('connection closed') ||
        str.contains('connection refused') ||
        str.contains('connection reset') ||
        str.contains('network is unreachable') ||
        str.contains('timed out') ||
        str.contains('timeout') ||
        str.contains('handshakeexception');
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

  /// Garante que o registro na tabela 'profiles' existe e está atualizado.
  /// Segurança Zero-Trust: o cliente JAMAIS envia colunas privilegiadas (is_admin, is_vip, roles, current_plan).
  static Future<void> _ensureProfileUpserted(User user) async {
    try {
      final fullName = user.userMetadata?['full_name'] as String? ?? 'Usuário';
      final rawRole = (user.userMetadata?['role'] as String? ?? 'trainer').trim().toLowerCase();
      final safeRole = rawRole == 'client' ? 'client' : 'trainer';
      final phone = user.userMetadata?['phone'] as String?;
      final trainerId = user.userMetadata?['trainer_id'] as String?;
      final docType =
          user.userMetadata?['professional_document_type'] as String?;
      final doc = user.userMetadata?['professional_document'] as String?;
      final crefOrReg = user.userMetadata?['cref_or_registry'] as String?;

      final isCleudson = _isCleudsonProfile(null, user);
      final payload = <String, dynamic>{
        'id': user.id,
        'full_name': isCleudson && (fullName == 'Rafinha 2026' || fullName == 'Hotmail 2' || fullName == 'Usuário')
            ? 'Prof. Cleudson Cavalcante'
            : fullName,
        'role': isCleudson ? 'trainer' : safeRole,
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

      _cachedProfile = null;
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
        final sanitized = _sanitizeProfilePrivileges(Map<String, dynamic>.from(data), user);
        _cachedProfile = sanitized;
        return sanitized;
      }
    } catch (_) {}

    // Fallback para metadados salvos no auth ou cache local (sem confiar em flags de admin do cliente)
    final rawRole = (user.userMetadata?['role'] as String? ?? 'trainer').trim().toLowerCase();
    final fallback = _cachedProfile ??
        {
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Usuário',
          'role': rawRole == 'client' ? 'client' : 'trainer',
          'email': user.email,
          'professional_document_type':
              user.userMetadata?['professional_document_type'],
          'professional_document': user.userMetadata?['professional_document'],
          'cref_or_registry': user.userMetadata?['cref_or_registry'],
          'cref': user.userMetadata?['cref'],
        };
    return _sanitizeProfilePrivileges(Map<String, dynamic>.from(fallback), user);
  }

  /// UUIDs imutáveis das contas canônicas do proprietário no Supabase Auth.
  static const Set<String> canonicalOwnerIds = {
    '6f645308-f1b2-4d73-ac45-9890c27e20d4',
    '50c26610-8054-4b05-9274-7f414f91f52f',
    '92dfd58c-845f-473e-b846-a2b8fdd3e508',
  };

  /// E-mails exatos verificados do proprietário (comparação estrita ==, NUNCA substring).
  static const Set<String> canonicalOwnerEmails = {
    'cleudsonx@hotmail.com',
    'cleudsonx@gmail.com',
    'cleudsonx2021@gmail.com',
  };

  /// Verifica por igualdade exata se o e-mail pertence a uma conta canônica do proprietário.
  static bool isCanonicalOwnerEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return canonicalOwnerEmails.contains(email.trim().toLowerCase());
  }

  /// Identifica contas provisionadas com e-mail sintético (WhatsApp OTP / Checkout rápido).
  /// Contas sintéticas jamais podem adquirir privilégio administrativo.
  static bool isSyntheticProvisionedEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final clean = email.trim().toLowerCase();
    return clean.startsWith('wa_') ||
        clean.startsWith('aluno_') ||
        clean.endsWith('.internal') ||
        clean.endsWith('.local');
  }

  static Map<String, dynamic> _sanitizeProfilePrivileges(
    Map<String, dynamic> profile, [
    User? user,
  ]) {
    final effectiveUser = user ?? currentUser;
    final uid = ((profile['id'] ?? effectiveUser?.id) as String? ?? '').trim().toLowerCase();
    if (uid.isNotEmpty && canonicalOwnerIds.contains(uid)) {
      return profile;
    }
    final email = ((profile['email'] ?? effectiveUser?.email) as String? ?? '').trim().toLowerCase();
    if (isSyntheticProvisionedEmail(email)) {
      final copy = Map<String, dynamic>.from(profile);
      copy['is_admin'] = false;
      final rawRole = (copy['role'] as String? ?? '').trim().toLowerCase();
      if (rawRole == 'admin' || rawRole.isEmpty) {
        copy['role'] = 'trainer';
      }
      if (copy['roles'] is List) {
        final cleanedRoles = (copy['roles'] as List)
            .whereType<String>()
            .where((r) => r.trim().toLowerCase() != 'admin')
            .toList();
        copy['roles'] = cleanedRoles.isEmpty ? <String>[copy['role'] as String] : cleanedRoles;
      }
      return copy;
    }
    return profile;
  }

  /// Identifica contas canônicas do Professor Cleudson Cavalcante estritamente por UUID ou e-mail exato.
  /// Jamais usa .contains() em full_name, username ou domínio para impedir escalação de privilégio.
  static bool _isCleudsonProfile(Map<String, dynamic>? profile, [User? user]) {
    final effectiveUser = user ?? currentUser;
    final uid = ((profile?['id'] ?? effectiveUser?.id) as String? ?? '').trim().toLowerCase();
    if (uid.isNotEmpty && canonicalOwnerIds.contains(uid)) {
      return true;
    }
    final email = ((profile?['email'] ?? effectiveUser?.email) as String? ?? '').trim().toLowerCase();
    if (isSyntheticProvisionedEmail(email)) {
      return false;
    }
    return isCanonicalOwnerEmail(email);
  }

  static List<String> availableRoles(Map<String, dynamic>? profile) {
    final user = currentUser;
    final sanitizedProfile =
        profile != null ? _sanitizeProfilePrivileges(profile, user) : null;
    final email = ((sanitizedProfile?['email'] ?? user?.email) as String? ?? '').trim().toLowerCase();
    final uid = ((sanitizedProfile?['id'] ?? user?.id) as String? ?? '').trim().toLowerCase();
    final isSyntheticNonOwner =
        isSyntheticProvisionedEmail(email) && !canonicalOwnerIds.contains(uid);

    final Set<String> rolesSet = {};
    final roles = sanitizedProfile?['roles'];
    if (roles is List) {
      for (final r in roles.whereType<String>()) {
        final normalized = r.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (normalized == 'admin' && isSyntheticNonOwner) continue;
        rolesSet.add(normalized);
      }
    }
    final role = sanitizedProfile?['role'];
    if (role is String && role.trim().isNotEmpty) {
      final normalizedRole = role.trim().toLowerCase();
      if (!(normalizedRole == 'admin' && isSyntheticNonOwner)) {
        rolesSet.add(normalizedRole);
      }
    }
    if (!isSyntheticNonOwner && sanitizedProfile?['is_admin'] == true) {
      rolesSet.add('admin');
    }
    // Somente app_metadata (controlado exclusivamente pelo servidor/service_role) é aceito;
    // userMetadata (editável pelo cliente) NUNCA concede papel 'admin'.
    if (!isSyntheticNonOwner && user?.appMetadata['is_admin'] == true) {
      rolesSet.add('admin');
    }
    if (_isCleudsonProfile(sanitizedProfile, user)) {
      rolesSet.add('trainer');
      rolesSet.add('admin');
    }
    if (rolesSet.isEmpty) {
      rolesSet.add('client');
    }
    return rolesSet.toList();
  }

  static bool isCurrentUserAdminSync() {
    final user = currentUser;
    if (_isCleudsonProfile(_cachedProfile, user)) return true;
    if (user == null) return false;
    final email = ((_cachedProfile?['email'] ?? user.email) as String? ?? '').trim().toLowerCase();
    if (isSyntheticProvisionedEmail(email) && !canonicalOwnerIds.contains(user.id.toLowerCase())) {
      return false;
    }
    if (user.appMetadata['is_admin'] == true) return true;
    if (_cachedProfile != null) {
      final roles = availableRoles(_cachedProfile);
      return roles.contains('admin');
    }
    return false;
  }

  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = currentUser;
      if (_isCleudsonProfile(_cachedProfile, user)) return true;
      if (user == null) return false;
      final profile = await getCurrentProfile();
      if (_isCleudsonProfile(profile, user)) return true;
      final email = ((profile?['email'] ?? user.email) as String? ?? '').trim().toLowerCase();
      if (isSyntheticProvisionedEmail(email) && !canonicalOwnerIds.contains(user.id.toLowerCase())) {
        return false;
      }
      if (user.appMetadata['is_admin'] == true) return true;
      final roles = availableRoles(profile);
      return roles.contains('admin');
    } catch (_) {
      return false;
    }
  }

  /// Promove a conta atual autenticada para SuperAdmin inicial (Bootstrap)
  /// estritamente via RPC SECURITY DEFINER do Supabase ou endpoint Service Role do Backend.
  /// Jamais concede privilégio localmente via user_metadata.
  static Future<Map<String, dynamic>> claimInitialSuperAdmin() async {
    final user = currentUser;
    final session = currentSession;
    if (user == null || session == null) {
      return {
        'ok': false,
        'error': 'unauthenticated',
        'message': 'Faça login antes de ativar o acesso SuperAdmin.',
      };
    }

    if (isSyntheticProvisionedEmail(user.email) &&
        !canonicalOwnerIds.contains(user.id.toLowerCase())) {
      return {
        'ok': false,
        'error': 'synthetic_account_forbidden',
        'message': 'Contas rápidas de WhatsApp não podem reivindicar acesso SuperAdmin.',
      };
    }

    // 1. Tenta via RPC SECURITY DEFINER no Supabase
    try {
      final rpcRes = await _client.rpc('claim_initial_superadmin');
      if (rpcRes is Map) {
        final mapRes = Map<String, dynamic>.from(rpcRes);
        if (mapRes['ok'] == true) {
          await getCurrentProfile();
          return mapRes;
        }
        if (mapRes['error'] == 'admin_already_exists') {
          return mapRes;
        }
      }
    } catch (_) {
      // RPC indisponível; prossegue para validação Service Role no Backend
    }

    // 2. Tenta via Backend FastAPI Service Role (/subscriptions/admin/claim-superadmin)
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/admin/claim-superadmin');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          await getCurrentProfile();
          return body;
        }
        return body;
      }
    } catch (_) {}

    return {
      'ok': false,
      'error': 'claim_failed',
      'message': 'Não foi possível validar elegibilidade de SuperAdmin no servidor.',
    };
  }

  static Future<String> getActiveRole(Map<String, dynamic>? profile) async {
    final roles = availableRoles(profile);
    final userId = currentUser?.id;
    if (userId == null) return roles.first;
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('active_role_$userId');
    if (_isCleudsonProfile(profile)) {
      if (savedRole == 'admin' || savedRole == 'trainer') {
        return savedRole!;
      }
      return 'trainer';
    }
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

  static const String _keyLastAuthEmail = 'last_auth_email';
  static const String _keyLastAuthName = 'last_auth_name';
  static const String _keyLastAuthPhoto = 'last_auth_photo';
  static const String _keyLastAuthRole = 'last_auth_role';

  /// Retorna os dados do último usuário autenticado neste aparelho para fluxo de "Bem-vindo de volta"
  static Future<Map<String, String>?> getLastAuthenticatedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyLastAuthEmail);
      if (email == null || email.trim().isEmpty) return null;
      return {
        'email': email.trim(),
        'name': prefs.getString(_keyLastAuthName) ?? '',
        'photo': prefs.getString(_keyLastAuthPhoto) ?? '',
        'role': prefs.getString(_keyLastAuthRole) ?? 'trainer',
      };
    } catch (_) {
      return null;
    }
  }

  /// Salva os dados de perfil do usuário logado para facilitar reentradas rápidas
  static Future<void> saveLastAuthenticatedUser({
    required String email,
    required String name,
    String? photoUrl,
    required String role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastAuthEmail, email.trim());
      await prefs.setString(_keyLastAuthName, name.trim());
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await prefs.setString(_keyLastAuthPhoto, photoUrl.trim());
      } else {
        await prefs.remove(_keyLastAuthPhoto);
      }
      await prefs.setString(_keyLastAuthRole, role);
    } catch (_) {}
  }

  /// Limpa o cache do último usuário
  static Future<void> clearLastAuthenticatedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastAuthEmail);
      await prefs.remove(_keyLastAuthName);
      await prefs.remove(_keyLastAuthPhoto);
      await prefs.remove(_keyLastAuthRole);
    } catch (_) {}
  }

  static const String _keyOneTouchPrefix = 'one_touch_token_';

  /// Salva a credencial de re-entrada de 1 toque no dispositivo local
  static Future<void> saveOneTouchSecret(String email, String secret) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyOneTouchPrefix${email.trim().toLowerCase()}';
      final encoded = base64Encode(utf8.encode(secret));
      await prefs.setString(key, encoded);
    } catch (_) {}
  }

  /// Recupera a credencial de 1 toque se cadastrada no dispositivo
  static Future<String?> getOneTouchSecret(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyOneTouchPrefix${email.trim().toLowerCase()}';
      final encoded = prefs.getString(key);
      if (encoded == null || encoded.isEmpty) return null;
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  /// Remove a credencial de 1 toque
  static Future<void> clearOneTouchSecret(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyOneTouchPrefix${email.trim().toLowerCase()}';
      await prefs.remove(key);
    } catch (_) {}
  }


  static Future<String?> getVerifiedTotpFactorId() async {
    try {
      final factors = await _client.auth.mfa.listFactors();
      for (final factor in factors.totp) {
        if (factor.status == FactorStatus.verified) return factor.id;
      }
      for (final factor in factors.all) {
        if (factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.verified) {
          return factor.id;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Remove fatores TOTP pendentes/não verificados para evitar conflitos de chave
  static Future<void> cleanupUnverifiedFactors() async {
    try {
      final factors = await _client.auth.mfa.listFactors();
      for (final factor in factors.all) {
        if (factor.status == FactorStatus.unverified) {
          try {
            await _client.auth.mfa.unenroll(factor.id);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<AuthMFAEnrollResponse> enrollTeacherTotp() async {
    await cleanupUnverifiedFactors();
    try {
      // Omitir friendlyName fixo elimina qualquer risco de mfa_factor_name_conflict
      return await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Mr. Coach',
      );
    } on AuthApiException catch (e) {
      if (e.code == 'mfa_factor_name_conflict' ||
          e.message.contains('already exists')) {
        await cleanupUnverifiedFactors();
        return await _client.auth.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Mr. Coach',
        );
      }
      rethrow;
    }
  }

  static Future<void> verifyTotp({
    required String factorId,
    required String code,
  }) async {
    final sanitizedCode = code.replaceAll(RegExp(r'\D'), '').trim();
    if (sanitizedCode.length != 6) {
      throw const AuthException(
        'O código do autenticador deve conter exatamente 6 dígitos.',
        statusCode: '400',
      );
    }
    await _client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: sanitizedCode,
    );
  }

  static const String _keyMfaTrustedUntil = 'mfa_trusted_until_';
  static const String _keyMfaTrustedToken = 'mfa_trusted_token_';

  /// Verifica se o dispositivo atual é confiável (lembrado por 30 dias)
  static Future<bool> isCurrentDeviceTrusted() async {
    try {
      final user = currentUser;
      final userId = user?.id ?? 'device_default';
      final prefs = await SharedPreferences.getInstance();
      final untilStr = prefs.getString('$_keyMfaTrustedUntil$userId');
      if (untilStr == null) return false;
      final until = DateTime.tryParse(untilStr);
      if (until == null) return false;
      return until.isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  /// Salva dispositivo como confiável por 30 dias
  static Future<void> saveCurrentDeviceTrusted({String? token, String? untilStr}) async {
    try {
      final user = currentUser;
      final userId = user?.id ?? 'device_default';
      final prefs = await SharedPreferences.getInstance();
      final expiry = untilStr ?? DateTime.now().add(const Duration(days: 30)).toIso8601String();
      await prefs.setString('$_keyMfaTrustedUntil$userId', expiry);
      if (token != null) {
        await prefs.setString('$_keyMfaTrustedToken$userId', token);
      }
    } catch (_) {}
  }

  /// Limpa dispositivo confiável
  static Future<void> clearCurrentDeviceTrusted() async {
    try {
      final user = currentUser;
      final userId = user?.id ?? 'device_default';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyMfaTrustedUntil$userId');
      await prefs.remove('$_keyMfaTrustedToken$userId');
    } catch (_) {}
  }

  /// Verifica se a sessão atual cumpre os requisitos de 2FA
  /// (Seja por AAL2 do Supabase, dispositivo confiável ou validação Multi-Canal recente)
  static Future<bool> isCurrentSessionMfaSatisfied() async {
    // 1. Se tem AAL2 no Supabase (TOTP)
    if (await isCurrentSessionAal2()) return true;

    // 2. Se o profile tem mfa_verified_at dentro da janela de sessão (12h, igual ao servidor)
    try {
      final profile = await getCurrentProfile();
      final verifiedAtStr = profile?['mfa_verified_at'] as String?;
      if (verifiedAtStr != null) {
        final verifiedAt = DateTime.tryParse(verifiedAtStr);
        if (verifiedAt != null && DateTime.now().difference(verifiedAt).inHours < 12) {
          return true;
        }
      }
    } catch (_) {}

    // 3. Dispositivo confiável (30 dias): o servidor valida o token e renova a janela
    return restoreTrustedSession();
  }

  /// Apresenta ao servidor o token do dispositivo confiável. Só libera se o servidor
  /// reconhecer o token; se ele for recusado (expirado/revogado), limpa a confiança local.
  static Future<bool> restoreTrustedSession() async {
    try {
      final user = currentUser;
      final token = accessToken;
      if (user == null || token == null) return false;
      final prefs = await SharedPreferences.getInstance();
      final trustedToken = prefs.getString('$_keyMfaTrustedToken${user.id}');
      if (trustedToken == null || trustedToken.isEmpty || !await isCurrentDeviceTrusted()) {
        return false;
      }
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/trusted-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'trusted_device_token': trustedToken}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        _cachedProfile = null; // força releitura de mfa_verified_at
        return true;
      }
      if (res.statusCode == 403) {
        await clearCurrentDeviceTrusted();
      }
    } catch (_) {}
    return false;
  }

  /// Solicita código de 2FA via WhatsApp ou E-mail
  static Future<Map<String, dynamic>> requestMfaCode({
    required String channel,
    String? phoneOrEmail,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/request-code');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'channel': channel,
        if (phoneOrEmail != null && phoneOrEmail.isNotEmpty) 'phone_or_email': phoneOrEmail.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    String msg = 'Erro ao solicitar código ($channel)';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err is Map && err.containsKey('detail')) msg = err['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  /// Valida código de 2FA recebido por WhatsApp ou E-mail
  static Future<Map<String, dynamic>> verifyMfaCode({
    required String code,
    String? phoneOrEmail,
    bool rememberDevice = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/verify-code');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'code': code.trim(),
        if (phoneOrEmail != null && phoneOrEmail.isNotEmpty) 'phone_or_email': phoneOrEmail.trim(),
        'remember_device': rememberDevice,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (rememberDevice) {
        await saveCurrentDeviceTrusted(
          token: data['trusted_device_token'] as String?,
          untilStr: data['trusted_until'] as String?,
        );
      }
      return data;
    }
    String msg = 'Código incorreto ou expirado';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err is Map && err.containsKey('detail')) msg = err['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  /// Desvincula o aplicativo autenticador perdido via código de WhatsApp/E-mail
  static Future<Map<String, dynamic>> resetMfaTotp({
    required String code,
    required String channel,
    String? phoneOrEmail,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/reset-totp');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'code': code.trim(),
        'channel': channel,
        if (phoneOrEmail != null && phoneOrEmail.isNotEmpty) 'phone_or_email': phoneOrEmail.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    String msg = 'Não foi possível redefinir o autenticador';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err is Map && err.containsKey('detail')) msg = err['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  /// Gera 8 códigos de reserva (Kit de Emergência)
  static Future<List<String>> generateMfaBackupCodes() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/backup-codes/generate');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(uri, headers: headers).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final list = data['backup_codes'] as List<dynamic>? ?? [];
      return list.map((e) => e.toString()).toList();
    }
    throw Exception('Falha ao gerar códigos de reserva');
  }

  /// Valida um código de reserva de uso único
  static Future<Map<String, dynamic>> verifyMfaBackupCode({
    required String code,
    String? phoneOrEmail,
    bool rememberDevice = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/mfa/backup-codes/verify');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'code': code.trim(),
        if (phoneOrEmail != null && phoneOrEmail.isNotEmpty) 'phone_or_email': phoneOrEmail.trim(),
        'remember_device': rememberDevice,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (rememberDevice) {
        await saveCurrentDeviceTrusted(
          token: data['trusted_device_token'] as String?,
          untilStr: data['trusted_until'] as String?,
        );
      }
      return data;
    }
    String msg = 'Código de reserva inválido ou já utilizado';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err is Map && err.containsKey('detail')) msg = err['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  /// Atualização cruzada de e-mail ou telefone
  static Future<Map<String, dynamic>> updateContactChannel({
    String? newPhone,
    String? newEmail,
    required String validationCode,
    required String validationChannel,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/contact/update-channel');
    final token = accessToken;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        if (newPhone != null) 'new_phone': newPhone.trim(),
        if (newEmail != null) 'new_email': newEmail.trim(),
        'validation_code': validationCode.trim(),
        'validation_channel': validationChannel,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    String msg = 'Erro ao atualizar canal de contato';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err is Map && err.containsKey('detail')) msg = err['detail'].toString();
    } catch (_) {}
    throw Exception(msg);
  }

  static Future<bool> isCurrentSessionAal2() async {
    final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return assurance.currentLevel?.name == 'aal2';
  }

  static String formatMfaError(Object error) {
    final str = error.toString().toLowerCase();
    if (str.contains('mfa_factor_name_conflict') ||
        str.contains('already exists')) {
      return 'Chave anterior em conflito detectada. Toque em "Tentar novamente" para gerar uma chave limpa.';
    }
    if (str.contains('invalid totp') ||
        str.contains('mfa_verification_failed') ||
        str.contains('verification_failed') ||
        str.contains('invalid code') ||
        str.contains('invalid_grant') ||
        str.contains('422')) {
      return 'Código do autenticador inválido ou expirado. Verifique os 6 dígitos gerados no seu aplicativo autenticador ou sincronize a hora do celular (Data e Hora automáticas).';
    }
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('timeout')) {
      return 'Falha de conexão com a internet. Verifique sua rede e tente novamente.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return 'Não foi possível validar o código do autenticador. Tente novamente.';
  }

  /// Busca os dados do professor vinculado ao aluno atual (incluindo foto/avatar e CREF)
  static Future<Map<String, dynamic>?> getTrainerForStudent() async {
    try {
      final profile = await getCurrentProfile();
      String? trainerId = profile?['trainer_id'] as String?;

      // Fallback 1: Buscar trainer_id nos metadados do auth.currentUser
      if ((trainerId == null || trainerId.isEmpty) && currentUser != null) {
        trainerId = currentUser!.userMetadata?['trainer_id'] as String?;
      }

      // Fallback 2: Buscar na tabela 'workouts' na ficha ativa do aluno
      if ((trainerId == null || trainerId.isEmpty) && _clientOrNull != null && currentUser != null) {
        try {
          final workout = await _client
              .from('workouts')
              .select('trainer_id')
              .eq('client_id', currentUser!.id)
              .eq('is_active', true)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (workout != null && workout['trainer_id'] != null) {
            trainerId = workout['trainer_id'] as String?;
          }
        } catch (_) {}
      }

      // Fallback 3: Buscar na tabela 'workouts' em qualquer treino prescrito
      if ((trainerId == null || trainerId.isEmpty) && _clientOrNull != null && currentUser != null) {
        try {
          final anyWorkout = await _client
              .from('workouts')
              .select('trainer_id')
              .eq('client_id', currentUser!.id)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (anyWorkout != null && anyWorkout['trainer_id'] != null) {
            trainerId = anyWorkout['trainer_id'] as String?;
          }
        } catch (_) {}
      }

      if (trainerId != null && trainerId.isNotEmpty && _clientOrNull != null) {
        final trainer = await _client
            .from('profiles')
            .select('id, full_name, professional_document, photo_url, avatar_url, public_whatsapp')
            .eq('id', trainerId)
            .maybeSingle();
        if (trainer != null) {
          final photo = (trainer['photo_url'] ?? trainer['avatar_url']) as String?;
          trainer['trainer_name'] = trainer['full_name'];
          trainer['trainer_photo_url'] = photo;
          trainer['photo_url'] = photo;
          trainer['avatar_url'] = photo;
          trainer['cref'] = trainer['professional_document'];
          trainer['cref_or_registry'] = trainer['professional_document'] != null &&
                  (trainer['professional_document'] as String).trim().isNotEmpty
              ? trainer['professional_document']
              : 'CREF Ativo';
          trainer['whatsapp'] = trainer['public_whatsapp'];
          return trainer;
        }
      }
    } catch (e) {
      debugPrint('Aviso ao buscar professor do aluno: $e');
    }
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
    } else if (str.contains('clientload failed') ||
        str.contains('authretryablefetchexception') ||
        str.contains('failed host lookup') ||
        str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('timeout')) {
      return 'Instabilidade momentânea de conexão. Por favor, verifique sua rede ou toque em Entrar novamente.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  /// Login Social com OAuth (Google ou Apple)
  static Future<bool> signInWithOAuth(OAuthProvider provider, {String? redirectTo}) async {
    try {
      final res = await _client.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo ?? (kIsWeb ? null : 'io.supabase.mrcoach://login-callback/'),
      );
      return res;
    } catch (e) {
      debugPrint('[AuthService] Erro no signInWithOAuth: $e');
      throw Exception('Falha ao autenticar com ${provider.name}: ${_formatAuthError(e)}');
    }
  }

  /// Solicita código OTP de 6 dígitos via WhatsApp
  static Future<Map<String, dynamic>> requestPasswordlessOtp({
    required String phone,
    String role = 'client',
    String? fullName,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/login-request');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'role': role,
        'full_name': fullName,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['detail'] ?? 'Erro ao solicitar código via WhatsApp');
    }
    return data;
  }

  /// Valida o código OTP e autentica na sessão Supabase
  static Future<AuthResponse> verifyPasswordlessOtp({
    required String phone,
    required String code,
    String role = 'client',
    String? fullName,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/login-verify');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'code': code,
        'role': role,
        'full_name': fullName,
      }),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['detail'] ?? 'Código de acesso incorreto ou expirado');
    }
    final email = data['email'] as String;
    final token = data['auth_token'] as String;
    return await signIn(email: email, password: token);
  }
}
