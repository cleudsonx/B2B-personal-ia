import 'dart:convert';
import 'package:http/http.dart' as http;

/// Serviço para comunicação com o Assistente de Inteligência Artificial B2B
/// Pode se conectar diretamente ao gateway em nuvem ou ao backend local.
class GeminiService {
  // URL padrão do gateway em nuvem fornecido para o projeto
  static const String _defaultGatewayUrl =
      'https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app/api/generate';

  /// Envia um prompt B2B para o modelo Gemini e retorna o texto gerado
  static Future<String> askB2BAssistant({
    required String prompt,
    String systemInstruction =
        'Você é um assistente de IA pessoal para treinadores, focado em negócios fitness B2B, consultorias e biomecânica.',
    double temperature = 0.7,
    String? customGatewayUrl,
  }) async {
    final url = customGatewayUrl ?? _defaultGatewayUrl;

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt,
              'systemInstruction': systemInstruction,
              'temperature': temperature,
              'model': 'gemini-3.8-flash',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['text'] as String? ?? 'Sem resposta';
      } else {
        String errorMsg = 'Falha HTTP ${response.statusCode}';
        try {
          final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorJson is Map && errorJson.containsKey('error')) {
            errorMsg = errorJson['error'].toString();
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Erro ao conectar ao Gemini Assistant: $e');
    }
  }
}
