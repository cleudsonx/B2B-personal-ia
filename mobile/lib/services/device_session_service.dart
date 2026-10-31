import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

class DeviceSession {
  final String id;
  final String deviceId;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final String location;
  final String userAgent;
  final DateTime lastActiveAt;
  final bool isCurrent;
  final bool isRevoked;

  DeviceSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.location,
    required this.userAgent,
    required this.lastActiveAt,
    required this.isCurrent,
    required this.isRevoked,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json, {String? currentDeviceId}) {
    final devId = json['device_id']?.toString() ?? '';
    final isCurr = (currentDeviceId != null && currentDeviceId.isNotEmpty && devId == currentDeviceId);
    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceId: devId,
      deviceName: json['device_name']?.toString() ?? 'Aparelho Conectado',
      platform: json['platform']?.toString() ?? 'Mobile',
      ipAddress: json['ip_address']?.toString() ?? 'IP Protegido',
      location: json['location']?.toString() ?? 'Localização Segura',
      userAgent: json['user_agent']?.toString() ?? '',
      lastActiveAt: DateTime.tryParse(json['last_active_at']?.toString() ?? '') ?? DateTime.now(),
      isCurrent: isCurr || json['is_current'] == true,
      isRevoked: json['is_revoked'] == true,
    );
  }
}

class DeviceSessionsOverview {
  final List<DeviceSession> sessions;
  final int allowedConcurrentDevices;
  final int activeDevicesCount;
  final bool isLimitExceeded;
  final String? warningMessage;

  DeviceSessionsOverview({
    required this.sessions,
    required this.allowedConcurrentDevices,
    required this.activeDevicesCount,
    required this.isLimitExceeded,
    this.warningMessage,
  });
}

class DeviceSessionService {
  static const String _deviceIdKey = '_mrcoach_persistent_device_id';
  static String? _cachedDeviceId;

  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Retorna ou gera identificador único persistente para este aparelho/navegador
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString(_deviceIdKey);
      if (id == null || id.isEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final rand = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000)).toString();
        id = 'dev_${now}_$rand';
        await prefs.setString(_deviceIdKey, id);
      }
      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return 'dev_fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Retorna a plataforma operacional do dispositivo
  static String getPlatformName() {
    if (kIsWeb) return 'Web Browser';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {}
    return 'Mobile';
  }

  /// Retorna nome legível padrão do dispositivo
  static String getDeviceDefaultName() {
    if (kIsWeb) return 'Navegador Web';
    try {
      if (Platform.isAndroid) return 'Smartphone Android';
      if (Platform.isIOS) return 'iPhone / iPad';
      if (Platform.isWindows) return 'Desktop Windows';
      if (Platform.isMacOS) return 'Apple Mac';
      if (Platform.isLinux) return 'Computador Linux';
    } catch (_) {}
    return 'Aparelho do Treinador';
  }

  /// Registra ou atualiza o heartbeat desta sessão de dispositivo no Supabase e Backend
  static Future<void> registerCurrentSession() async {
    final client = _clientOrNull;
    final user = client?.auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await getDeviceId();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // 1. Grava diretamente no Supabase com RLS (Instantâneo, sem delay de deploy)
      await client!.from('user_device_sessions').upsert({
        'user_id': user.id,
        'device_id': deviceId,
        'device_name': getDeviceDefaultName(),
        'platform': getPlatformName(),
        'last_active_at': nowIso,
        'is_revoked': false,
        'revoked_at': null,
      }, onConflict: 'user_id,device_id');
    } catch (e) {
      debugPrint('[DeviceSessionService] Falha ao upsert de sessão no Supabase: $e');
    }

    // 2. Notifica o backend em segundo plano (para disparar alerta de WhatsApp e geolocalização por IP)
    try {
      final session = client?.auth.currentSession;
      if (session != null) {
        final deviceId = await getDeviceId();
        final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-session/register');
        http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'device_id': deviceId,
            'device_name': getDeviceDefaultName(),
            'platform': getPlatformName(),
            'app_version': AppConfig.appVersion,
          }),
        ).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500));
      }
    } catch (_) {}
  }

  /// Busca todos os aparelhos ativos na conta do treinador
  static Future<DeviceSessionsOverview?> fetchSessions() async {
    final client = _clientOrNull;
    final user = client?.auth.currentUser;
    if (user == null) return null;

    try {
      final currentDeviceId = await getDeviceId();

      // 1. Tenta sincronizar sessões do auth.sessions via função RPC
      try {
        await client!.rpc('sync_my_device_sessions');
      } catch (_) {}

      // 2. Busca diretamente do Supabase
      final res = await client!
          .from('user_device_sessions')
          .select('*')
          .eq('user_id', user.id)
          .eq('is_revoked', false)
          .order('last_active_at', ascending: false);

      final rawList = (res as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      final sessions = rawList
          .map((row) => DeviceSession.fromJson(row, currentDeviceId: currentDeviceId))
          .toList();

      // 3. Determina o limite de concorrência com base no perfil / plano
      int allowed = 2; // Padrão Starter/Pro: 1 celular + 1 PC
      try {
        final prof = await client
            .from('profiles')
            .select('current_plan, is_vip, is_admin, roles')
            .eq('id', user.id)
            .maybeSingle();
        if (prof != null) {
          final isVipOrAdmin = prof['is_vip'] == true ||
              prof['is_admin'] == true ||
              (prof['roles'] as List?)?.contains('admin') == true;
          final plan = (prof['current_plan'] as String? ?? '').toLowerCase();
          if (isVipOrAdmin) {
            allowed = 10;
          } else if (plan.contains('studio')) {
            allowed = 5;
          } else if (plan.contains('elite')) {
            allowed = 3;
          } else {
            allowed = 2;
          }
        }
      } catch (_) {}

      final activeCount = sessions.length;
      final isExceeded = activeCount > allowed;
      String? warning;
      if (isExceeded) {
        warning = 'Atenção: Você possui $activeCount aparelhos conectados simultaneamente (o recomendado no seu plano é até $allowed).';
      }

      return DeviceSessionsOverview(
        sessions: sessions,
        allowedConcurrentDevices: allowed,
        activeDevicesCount: activeCount,
        isLimitExceeded: isExceeded,
        warningMessage: warning,
      );
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao buscar sessões: $e');
    }
    return null;
  }

  /// Desconecta / revoga uma sessão específica
  static Future<bool> revokeSession({String? sessionId, String? deviceId}) async {
    final client = _clientOrNull;
    final user = client?.auth.currentUser;
    if (user == null) return false;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      var query = client!.from('user_device_sessions').update({
        'is_revoked': true,
        'revoked_at': nowIso,
      }).eq('user_id', user.id);

      if (deviceId != null) {
        query = query.eq('device_id', deviceId);
      } else if (sessionId != null) {
        query = query.eq('id', sessionId);
      }

      await query;

      // Dispara backend em segundo plano caso necessário
      final session = client.auth.currentSession;
      if (session != null) {
        final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-sessions/revoke');
        http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            if (sessionId != null) 'session_id': sessionId,
            if (deviceId != null) 'device_id': deviceId,
          }),
        ).catchError((_) => http.Response('', 500));
      }

      return true;
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao revogar sessão: $e');
      return false;
    }
  }

  /// Desconecta todos os outros aparelhos com botão de emergência / kill switch
  static Future<bool> revokeAllOtherSessions() async {
    final client = _clientOrNull;
    final user = client?.auth.currentUser;
    if (user == null) return false;

    try {
      final currentDeviceId = await getDeviceId();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Revoga no Supabase
      await client!.from('user_device_sessions').update({
        'is_revoked': true,
        'revoked_at': nowIso,
      }).eq('user_id', user.id).neq('device_id', currentDeviceId);

      // Marca session_revoked_at no profile
      try {
        await client.from('profiles').update({
          'session_revoked_at': nowIso,
        }).eq('id', user.id);
      } catch (_) {}

      // Dispara backend em segundo plano
      final session = client.auth.currentSession;
      if (session != null) {
        final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-sessions/revoke-others');
        http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'current_device_id': currentDeviceId,
          }),
        ).catchError((_) => http.Response('', 500));
      }

      return true;
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao revogar outros aparelhos: $e');
      return false;
    }
  }
}
