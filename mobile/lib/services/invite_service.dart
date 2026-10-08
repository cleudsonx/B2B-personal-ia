import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'auth_service.dart';

class InviteService {
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = AuthService.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Gera um convite único e intransferível no backend (com token de 32 bytes e validade de 24h)
  static Future<Map<String, dynamic>> createInvite({
    required String channel, // 'email' ou 'whatsapp'
    String? targetEmail,
    String? targetPhone,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/invites/create');
    final payload = {
      'channel': channel,
      if (targetEmail != null && targetEmail.isNotEmpty) 'target_email': targetEmail.trim(),
      if (targetPhone != null && targetPhone.isNotEmpty) 'target_phone': targetPhone.trim(),
    };

    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Erro ao gerar convite (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('[InviteService] Erro ao criar convite: $e');
      rethrow;
    }
  }

  /// Valida o token de convite no backend (verifica se não expirou ou foi usado)
  static Future<Map<String, dynamic>> validateInvite(String token) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/invites/validate/$token');
    
    try {
      final res = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Convite inválido ou expirado.');
      }
    } catch (e) {
      debugPrint('[InviteService] Erro ao validar convite: $e');
      rethrow;
    }
  }
  /// Consome e valida o token de convite quando o aluno abre o link
  static Future<Map<String, dynamic>> consumeInvite(String token) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/invites/consume');
    final payload = {'token': token.trim()};

    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['detail'] ?? 'Convite inválido ou expirado.');
      }
    } catch (e) {
      debugPrint('[InviteService] Erro ao consumir convite: $e');
      rethrow;
    }
  }
}
