import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/workout_plan_model.dart';
import '../models/adaptation_model.dart';
import 'auth_service.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client();

  Map<String, String> _buildHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final activeToken = (token != null && token.isNotEmpty)
        ? token
        : AuthService.accessToken;
    if (activeToken != null && activeToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $activeToken';
    }
    return headers;
  }

  /// Gera a periodização completa chamando o endpoint do backend
  Future<WorkoutPlanModel> generateWorkoutPlan({
    required String objective,
    required String trainingLevel,
    required int daysPerWeek,
    required String workoutLocation,
    required String injuriesOrRestrictions,
    String splitType = 'Automático (IA Sugere)',
    String? targetFocus,
    String? additionalNotes,
    String? authToken,
  }) async {
    final payload = <String, dynamic>{
      'objective': objective,
      'training_level': trainingLevel,
      'days_per_week': daysPerWeek,
      'workout_location': workoutLocation,
      'injuries_or_restrictions': injuriesOrRestrictions,
      'split_type': splitType,
    };
    if (targetFocus != null && targetFocus.isNotEmpty) {
      payload['target_focus'] = targetFocus;
    }
    if (additionalNotes != null && additionalNotes.isNotEmpty) {
      payload['additional_notes'] = additionalNotes;
    }
    final body = jsonEncode(payload);
    final uri = Uri.parse('$baseUrl/workouts/generate-plan');

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: authToken),
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return WorkoutPlanModel.fromJson(data);
    } else {
      String errorMessage = 'Falha ao gerar treino (Status ${response.statusCode})';
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorJson['detail'] != null) {
          errorMessage = errorJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  /// Substitui um exercício em tempo real no salão de musculação
  Future<AdaptationModel> adaptExercise({
    required String currentExercise,
    required String reason,
    required String workoutLocation,
    String? injuriesOrRestrictions,
    String? authToken,
  }) async {
    final uri = Uri.parse('$baseUrl/adaptations/adapt-exercise');
    final body = jsonEncode({
      'current_exercise': currentExercise,
      'reason': reason,
      'workout_location': workoutLocation,
      'injuries_or_restrictions': injuriesOrRestrictions ?? 'Nenhuma',
    });

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: authToken),
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AdaptationModel.fromJson(data);
    } else {
      String errorMessage = 'Falha ao adaptar exercício (Status ${response.statusCode})';
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorJson['detail'] != null) {
          errorMessage = errorJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}
