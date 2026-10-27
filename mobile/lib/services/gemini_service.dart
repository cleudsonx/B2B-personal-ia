import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import 'auth_service.dart';

/// Serviço para comunicação com o Assistente de Inteligência Artificial B2B
/// Roteado pelo backend FastAPI oficial que utiliza o modelo Gemini 2.5 Flash
class GeminiService {
  /// Envia um prompt B2B para o modelo Gemini e retorna o texto gerado
  static Future<String> askB2BAssistant({
    required String prompt,
    String systemInstruction =
        'Você é o Mr. Coach AI, especialista em biomecânica de precisão, fisiologia neuromuscular, musculação avançada e estratégias de negócios fitness B2B. Inicie sempre com o cabeçalho "### 🤖 Parecer do Mr. Coach".',
    String model = 'gemini-2.5-flash',
    double temperature = 0.7,
    String? customGatewayUrl,
  }) async {
    final url = customGatewayUrl ?? AppConfig.assistantChatUrl;

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final token = AuthService.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode({
              'prompt': prompt,
              'systemInstruction': systemInstruction,
              'model': model,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final replyText = data['text'] as String? ?? 'Sem resposta';
        _logInAppInteractionSilently(prompt: prompt, reply: replyText);
        return replyText;
      } else {
        String errorMsg = 'Falha HTTP ${response.statusCode}';
        try {
          final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorJson is Map) {
            if (errorJson.containsKey('detail')) {
              errorMsg = errorJson['detail'].toString();
            } else if (errorJson.containsKey('error')) {
              errorMsg = errorJson['error'].toString();
            }
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Erro ao conectar ao Gemini Assistant ($url): $e');
    }
  }

  static Future<void> _logInAppInteractionSilently({
    required String prompt,
    required String reply,
  }) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final prof = await client
          .from('profiles')
          .select('id, full_name, role, trainer_id, phone')
          .eq('id', user.id)
          .maybeSingle();
      if (prof == null) return;
      final role = (prof['role'] ?? 'client').toString();
      final trainerId = (role == 'trainer' ? prof['id'] : (prof['trainer_id'] ?? prof['id']))?.toString();
      if (trainerId == null || trainerId.isEmpty) return;

      final studentName = (prof['full_name'] ?? 'Aluno').toString();
      final cleanOut = reply.replaceAll(RegExp(r'[#*`]'), '').replaceAll('\n', ' ').trim();
      final shortOut = cleanOut.length > 130 ? '${cleanOut.substring(0, 127)}...' : cleanOut;
      final shortIn = prompt.length > 80 ? '${prompt.substring(0, 77)}...' : prompt;

      await client.from('student_pulse_events').insert({
        'trainer_id': trainerId,
        'student_id': user.id,
        'event_type': 'ai_doubt',
        'severity': 'info',
        'title': '🧠 Consultoria IA In-App ($studentName)',
        'description': 'Perguntou: "$shortIn" • Resposta: $shortOut',
        'metadata': {
          'student_name': studentName,
          'student_phone': prof['phone'] ?? '',
          'channel': 'in_app_ai',
          'cost_type': 'ai_gemini',
        },
        'viewed_by_trainer': role == 'trainer',
      });
    } catch (_) {}
  }
}
