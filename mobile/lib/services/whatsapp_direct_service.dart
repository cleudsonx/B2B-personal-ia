import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../core/widgets/meta_components.dart';

/// Resultado do disparo de mensagem WhatsApp em 1 clique.
class WhatsAppDispatchResult {
  final bool sentInApp;
  final bool openedExternalWa;
  final bool copiedToClipboard;
  final String channel;

  const WhatsAppDispatchResult({
    required this.sentInApp,
    this.openedExternalWa = false,
    this.copiedToClipboard = false,
    this.channel = 'in_app_api',
  });
}

/// Serviço unificado de disparo WhatsApp In-App em 1 Clique (Evolution API / Meta Cloud API).
///
/// Envia mensagens (parabenizar ofensiva, incentivar aluno, responder alerta do Live Student Pulse,
/// lembrar convite) diretamente pelo backend sem precisar abrir a interface externa do WhatsApp.
/// Registra automaticamente a interação na telemetria e no Live Student Pulse 3.0.
class WhatsAppDirectService {
  WhatsAppDirectService._();

  static String normalizePhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if ((digits.length == 10 || digits.length == 11) && !digits.startsWith('55')) {
      return '55$digits';
    }
    return digits;
  }

  /// Dispara mensagem via API do WhatsApp em 1 clique dentro do app.
  /// Só recorre ao link externo `wa.me` se [allowExternalFallback] for `true` e o servidor não puder entregar.
  static Future<WhatsAppDispatchResult> sendOneClick({
    required BuildContext context,
    required String message,
    String? phone,
    String? studentId,
    String studentName = 'Aluno',
    String category = 'trainer_one_click',
    String? actionType,
    bool showFeedback = true,
    bool allowExternalFallback = true,
  }) async {
    if (actionType != null && actionType.isNotEmpty) {
      category = actionType;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final firstName = studentName.trim().split(' ').first;
    String cleanPhone = normalizePhone(phone);

    // Se não veio telefone mas temos studentId, tenta buscar no Supabase
    if (cleanPhone.isEmpty && studentId != null && studentId.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('phone, whatsapp, public_whatsapp')
            .eq('id', studentId)
            .maybeSingle();
        if (res != null) {
          cleanPhone = normalizePhone(
            (res['whatsapp'] ?? res['phone'] ?? res['public_whatsapp'])?.toString(),
          );
        }
      } catch (_) {}
    }

    if (cleanPhone.isEmpty) {
      await Clipboard.setData(ClipboardData(text: message));
      if (showFeedback && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Text(
              'Telefone de $firstName não cadastrado. Mensagem copiada para a área de transferência!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
      return const WhatsAppDispatchResult(
        sentInApp: false,
        copiedToClipboard: true,
        channel: 'clipboard',
      );
    }

    // 1. Tenta disparo In-App 1-Clique via Backend API (/whatsapp/send-direct)
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null && token.isNotEmpty) {
        final res = await http
            .post(
              Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/send-direct'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'phone': cleanPhone,
                'message': message,
                if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
                'student_name': studentName,
                'category': category,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final sentViaApi = data['sent_via_api'] == true || data['status'] == 'sent';
          if (sentViaApi) {
            await _recordPulseAndContactedInSupabase(
              studentId: studentId,
              studentName: studentName,
              phone: cleanPhone,
              message: message,
              category: category,
            );
            if (showFeedback && messenger != null) {
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: MetaColors.emerald,
                  behavior: SnackBarBehavior.floating,
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mensagem enviada para $firstName no WhatsApp com 1 clique!',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return WhatsAppDispatchResult(
              sentInApp: true,
              channel: (data['channel'] ?? 'in_app_api').toString(),
            );
          }
        }
      }
    } catch (_) {}

    // 2. Contingência: Registra a interação e abre WhatsApp externo (ou copia) caso a instância não esteja ativa
    await _recordPulseAndContactedInSupabase(
      studentId: studentId,
      studentName: studentName,
      phone: cleanPhone,
      message: message,
      category: category,
    );

    if (allowExternalFallback) {
      final encoded = Uri.encodeComponent(message);
      final waUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
      try {
        final launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (launched) {
          return const WhatsAppDispatchResult(
            sentInApp: false,
            openedExternalWa: true,
            channel: 'wa_me_fallback',
          );
        }
      } catch (_) {}
    }

    await Clipboard.setData(ClipboardData(text: message));
    if (showFeedback && messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.emerald,
          content: Text(
            'Mensagem para $firstName preparada e copiada!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    return const WhatsAppDispatchResult(
      sentInApp: false,
      copiedToClipboard: true,
      channel: 'clipboard_fallback',
    );
  }

  static Future<void> _recordPulseAndContactedInSupabase({
    String? studentId,
    required String studentName,
    required String phone,
    required String message,
    required String category,
  }) async {
    try {
      final client = Supabase.instance.client;
      final trainerId = client.auth.currentUser?.id;
      if (trainerId == null) return;

      if (studentId != null && studentId.isNotEmpty) {
        try {
          await client
              .from('profiles')
              .update({'last_contacted_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', studentId);
        } catch (_) {}
      }

      try {
        await client.from('trainer_whatsapp_logs').insert({
          'trainer_id': trainerId,
          if (studentId != null && studentId.isNotEmpty) 'student_id': studentId,
          'student_name': studentName,
          'student_phone': phone,
          'channel': 'whatsapp_$category',
          'message_in': '[Disparo 1-Clique In-App: $category]',
          'message_out': message,
          'cost_type': 'free',
          'tokens_used': 0,
        });
      } catch (_) {}
    } catch (_) {}
  }
}
