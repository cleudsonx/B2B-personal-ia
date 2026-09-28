import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'auth_service.dart';

/// Serviço para comunicação com o Assistente de Inteligência Artificial B2B
/// Roteado pelo backend FastAPI oficial que utiliza o modelo Gemini 3.8 Flash
class GeminiService {
  /// Envia um prompt B2B para o modelo Gemini e retorna o texto gerado
  static Future<String> askB2BAssistant({
    required String prompt,
    String systemInstruction =
        'Você é um assistente de IA pessoal para treinadores, focado em negócios fitness B2B, consultorias e biomecânica.',
    String model = 'gemini-3.6-flash',
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
        return data['text'] as String? ?? 'Sem resposta';
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
}
