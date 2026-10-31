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

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? 'Aparelho Desconhecido',
      platform: json['platform']?.toString() ?? 'Desconhecido',
      ipAddress: json['ip_address']?.toString() ?? 'IP Protegido',
      location: json['location']?.toString() ?? 'Localização Segura',
      userAgent: json['user_agent']?.toString() ?? '',
      lastActiveAt: DateTime.tryParse(json['last_active_at']?.toString() ?? '') ?? DateTime.now(),
      isCurrent: json['is_current'] == true,
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

  static Session? get _currentSessionOrNull {
    try {
      return Supabase.instance.client.auth.currentSession;
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

  /// Registra ou atualiza o heartbeat desta sessão de dispositivo no backend
  static Future<void> registerCurrentSession() async {
    try {
      final session = _currentSessionOrNull;
      if (session == null) return;
      final deviceId = await getDeviceId();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-session/register');
      await http.post(
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
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[DeviceSessionService] Falha ao registrar sessão de dispositivo: $e');
    }
  }

  /// Busca todos os aparelhos ativos na conta do treinador
  static Future<DeviceSessionsOverview?> fetchSessions() async {
    try {
      final session = _currentSessionOrNull;
      if (session == null) return null;
      final deviceId = await getDeviceId();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-sessions?current_device_id=$deviceId');
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawSessions = (data['sessions'] as List<dynamic>? ?? []);
        final sessions = rawSessions
            .map((item) => DeviceSession.fromJson(item as Map<String, dynamic>))
            .toList();
        return DeviceSessionsOverview(
          sessions: sessions,
          allowedConcurrentDevices: (data['allowed_concurrent_devices'] as num?)?.toInt() ?? 2,
          activeDevicesCount: (data['active_devices_count'] as num?)?.toInt() ?? sessions.length,
          isLimitExceeded: data['is_limit_exceeded'] == true,
          warningMessage: data['warning_message'] as String?,
        );
      }
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao buscar sessões: $e');
    }
    return null;
  }

  /// Desconecta / revoga uma sessão específica
  static Future<bool> revokeSession({String? sessionId, String? deviceId}) async {
    try {
      final session = _currentSessionOrNull;
      if (session == null) return false;
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-sessions/revoke');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          if (sessionId != null) 'session_id': sessionId,
          if (deviceId != null) 'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao revogar sessão: $e');
      return false;
    }
  }

  /// Desconecta todos os outros aparelhos com botão de emergência / kill switch
  static Future<bool> revokeAllOtherSessions() async {
    try {
      final session = _currentSessionOrNull;
      if (session == null) return false;
      final currentDeviceId = await getDeviceId();
      final url = Uri.parse('${AppConfig.apiBaseUrl}/auth/device-sessions/revoke-others');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'current_device_id': currentDeviceId,
        }),
      ).timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[DeviceSessionService] Erro ao revogar outros aparelhos: $e');
      return false;
    }
  }
}
