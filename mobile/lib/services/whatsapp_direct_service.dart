import 'dart:convert';
import 'package:flutter/foundation.dart';
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

/// Serviço unificado de disparo WhatsApp In-App em 1 Clique (Evolution API / Meta Cloud API)
/// e Ponte Direta Aluno <-> Professor anti-tela-branca no iOS PWA.
class WhatsAppDirectService {
  WhatsAppDirectService._();

  static const String platformMasterPhone = '5561991497852';

  static String normalizePhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if ((digits.length == 10 || digits.length == 11) && !digits.startsWith('55')) {
      return '55$digits';
    }
    return digits;
  }

  /// Abre o aplicativo nativo do WhatsApp evitando a tela branca do SFSafariViewController
  /// em PWAs instalados na Tela de Início do iOS (usa esquema `whatsapp://send` com `_self` no mobile).
  static Future<bool> launchExternalWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = normalizePhone(phone);
    if (cleanPhone.isEmpty) return false;

    // Copia preventivamente a mensagem para a área de transferência
    try {
      await Clipboard.setData(ClipboardData(text: message));
    } catch (_) {}

    final encoded = Uri.encodeComponent(message);
    final isMobilePlatform = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    // No iOS/Android (especialmente PWA Standalone no iPhone), window.open('https://wa.me/...', '_blank')
    // abre um modal SFSafariViewController em branco ("OK"). O esquema nativo `whatsapp://send`
    // disparado em `_self` aciona o app do WhatsApp diretamente sem abrir aba em branco!
    if (isMobilePlatform) {
      final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
      try {
        final launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
        if (launched) return true;
      } catch (_) {}
    }

    // Fallback Desktop / Navegadores sem protocolo customizado
    final waUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    try {
      return await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: isMobilePlatform ? '_self' : '_blank',
      );
    } catch (_) {
      return false;
    }
  }

  /// Dispara mensagem via API do WhatsApp em 1 clique dentro do app.
  /// Só recorre ao link externo se [allowExternalFallback] for `true` e o servidor não puder entregar.
  static Future<WhatsAppDispatchResult> sendOneClick({
    required BuildContext context,
    required String message,
    String? phone,
    String? studentId,
    String? trainerId,
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
                if (trainerId != null && trainerId.isNotEmpty) 'trainer_id': trainerId,
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
              trainerId: trainerId,
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

    // 2. Contingência: Registra a interação e abre WhatsApp externo (sem tela branca no iOS PWA)
    await _recordPulseAndContactedInSupabase(
      studentId: studentId,
      trainerId: trainerId,
      studentName: studentName,
      phone: cleanPhone,
      message: message,
      category: category,
    );

    if (allowExternalFallback) {
      final launched = await launchExternalWhatsApp(
        phone: cleanPhone,
        message: message,
      );
      if (launched) {
        return const WhatsAppDispatchResult(
          sentInApp: false,
          openedExternalWa: true,
          channel: 'wa_native_fallback',
        );
      }
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

  /// Abre a Ponte Direta Aluno -> Professor (ou Copiloto 24h) dentro do app:
  /// Permite enviar a mensagem diretamente pelo servidor (sem sair da tela de treino)
  /// ou abrir o app nativo do WhatsApp usando deep-link anti-tela-branca no iOS.
  static Future<void> openStudentTrainerBridge({
    required BuildContext context,
    required String trainerName,
    String? trainerPhone,
    String? trainerId,
    String? initialMessage,
    String category = 'student_to_trainer',
    bool fallbackToPlatformMaster = false,
  }) async {
    String cleanPhone = normalizePhone(trainerPhone);

    // Se o telefone do treinador não veio em memória, tenta buscar no Supabase
    if (cleanPhone.isEmpty && trainerId != null && trainerId.isNotEmpty) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('phone, whatsapp, public_whatsapp')
            .eq('id', trainerId)
            .maybeSingle();
        if (row != null) {
          cleanPhone = normalizePhone(
            (row['public_whatsapp'] ?? row['whatsapp'] ?? row['phone'])?.toString(),
          );
        }
      } catch (_) {}
    }

    if (cleanPhone.isEmpty && fallbackToPlatformMaster) {
      cleanPhone = platformMasterPhone;
    }

    if (!context.mounted) return;

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          content: Text(
            'Seu treinador ($trainerName) ainda não cadastrou o WhatsApp profissional.',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
      return;
    }

    final defaultMsg = initialMessage ??
        'Olá professor(a) $trainerName! Estou no app Mr. Coach e gostaria de tirar uma dúvida sobre meu treino.';
    final msgCtrl = TextEditingController(text: defaultMsg);
    bool isSendingDirect = false;

    final topics = <Map<String, String>>[
      {
        'label': '🏋️ Dúvida na execução/carga',
        'text': 'Olá professor(a) $trainerName! Estou com uma dúvida na execução/carga do meu treino de hoje.',
      },
      {
        'label': '🔄 Aparelho ocupado',
        'text': 'Olá professor(a) $trainerName! O aparelho está ocupado aqui na academia, qual variação você recomenda?',
      },
      {
        'label': '⚡ Senti desconforto',
        'text': 'Olá professor(a) $trainerName! Senti um leve desconforto durante a série e gostaria da sua orientação.',
      },
      {
        'label': '📊 Avaliar minha evolução',
        'text': 'Olá professor(a) $trainerName! Pode dar uma olhada na minha evolução e prontidão no Bio-Hub?',
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = MetaColors.isDark(ctx);
            final bg = isDark ? const Color(0xFF111827) : Colors.white;
            final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
            final textCol = MetaColors.text(ctx);
            final subCol = MetaColors.subtext(ctx);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: subCol.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Color(0xFF25D366),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Falar com $trainerName',
                                  style: TextStyle(
                                    color: textCol,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 14,
                                      color: Color(0xFF25D366),
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Ponte Direta WhatsApp 24h • Sem sair do treino',
                                        style: TextStyle(
                                          color: Color(0xFF25D366),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: Icon(Icons.close_rounded, color: subCol, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: topics.map((t) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                backgroundColor: cardBg,
                                side: BorderSide(
                                  color: subCol.withValues(alpha: 0.2),
                                ),
                                label: Text(
                                  t['label']!,
                                  style: TextStyle(
                                    color: textCol,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  msgCtrl.text = t['text']!;
                                  msgCtrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: msgCtrl.text.length),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: msgCtrl,
                        maxLines: 3,
                        minLines: 2,
                        style: TextStyle(color: textCol, fontSize: 13.5, height: 1.35),
                        decoration: InputDecoration(
                          hintText: 'Escreva sua dúvida ou aviso para o professor...',
                          hintStyle: TextStyle(color: subCol, fontSize: 13),
                          filled: true,
                          fillColor: cardBg,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: isSendingDirect
                              ? null
                              : () async {
                                  final text = msgCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  setSheetState(() => isSendingDirect = true);

                                  final currentUser = Supabase.instance.client.auth.currentUser;
                                  final studentName = (currentUser?.userMetadata?['full_name'] as String?)?.trim() ??
                                      'Seu Aluno';
                                  final formattedDirect =
                                      '📩 *[Mensagem de $studentName no App Mr. Coach]:*\n$text';

                                  final res = await sendOneClick(
                                    context: context,
                                    phone: cleanPhone,
                                    trainerId: trainerId,
                                    studentId: currentUser?.id,
                                    studentName: trainerName,
                                    message: formattedDirect,
                                    category: category,
                                    showFeedback: false,
                                    allowExternalFallback: false,
                                  );

                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                  }

                                  if (res.sentInApp) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF25D366),
                                          behavior: SnackBarBehavior.floating,
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Enviado direto para o WhatsApp de $trainerName sem sair do treino!',
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
                                  } else {
                                    // Se a instância Evolution do servidor não estiver ativa, abre o WhatsApp nativo sem tela branca
                                    await launchExternalWhatsApp(
                                      phone: cleanPhone,
                                      message: text,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: isSendingDirect
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded, size: 20),
                          label: Text(
                            isSendingDirect
                                ? 'Enviando direto ao WhatsApp...'
                                : 'Enviar Direto daqui (Sem sair do app)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final text = msgCtrl.text.trim();
                                Navigator.pop(sheetCtx);
                                await launchExternalWhatsApp(
                                  phone: cleanPhone,
                                  message: text.isNotEmpty ? text : defaultMsg,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textCol,
                                side: BorderSide(color: subCol.withValues(alpha: 0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                                color: Color(0xFF25D366),
                              ),
                              label: const Text(
                                'Abrir no App WhatsApp',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final text = msgCtrl.text.trim();
                              await Clipboard.setData(
                                ClipboardData(text: text.isNotEmpty ? text : defaultMsg),
                              );
                              if (sheetCtx.mounted) {
                                Navigator.pop(sheetCtx);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF1E293B),
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      'Mensagem copiada para a área de transferência!',
                                      style: TextStyle(color: Colors.white, fontSize: 12.5),
                                    ),
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: subCol,
                              side: BorderSide(color: subCol.withValues(alpha: 0.25)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 15),
                            label: const Text(
                              'Copiar',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _recordPulseAndContactedInSupabase({
    String? studentId,
    String? trainerId,
    required String studentName,
    required String phone,
    required String message,
    required String category,
  }) async {
    try {
      final client = Supabase.instance.client;
      final resolvedTrainerId = trainerId ?? client.auth.currentUser?.id;
      if (resolvedTrainerId == null) return;

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
          'trainer_id': resolvedTrainerId,
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
