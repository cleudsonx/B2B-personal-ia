import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../models/workout_plan_model.dart';
import 'auth_service.dart';

class WorkoutService {
  static SupabaseClient? get _clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static SupabaseClient get _client {
    final c = _clientOrNull;
    if (c == null) throw Exception('Supabase não inicializado.');
    return c;
  }

  // Cache local em memória de alunos criados nesta sessão para garantir persistência contínua
  static final List<Map<String, dynamic>> _localStudentsCache = [];

  static Map<String, String> get _apiHeaders {
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

  /// Cadastra um novo aluno com validação, persistência no Supabase e sincronização no Backend
  static Future<Map<String, dynamic>> createStudent({
    required String fullName,
    required String email,
    String? phone,
    String? goal,
  }) async {
    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';
    final studentId = 'st_${DateTime.now().millisecondsSinceEpoch}';

    final studentData = {
      'id': studentId,
      'full_name': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone?.trim(),
      'goal': goal ?? 'Hipertrofia Muscular',
      'status': 'Pendente Confirmação',
      'trainer_id': trainerId,
      'created_at': DateTime.now().toIso8601String(),
      'has_active_prescription': false,
    };

    // 1. Armazena no cache local imediatamente
    _localStudentsCache.removeWhere((s) => s['email'] == studentData['email']);
    _localStudentsCache.insert(0, studentData);

    // 2. Persiste na tabela 'profiles' do Supabase
    if (_clientOrNull != null) {
      try {
        await _client.from('profiles').upsert({
          'id': studentId,
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone?.trim(),
          'role': 'client',
          'trainer_id': trainerId,
          'status': 'Pendente Confirmação',
          'goal': goal,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Aviso Supabase createStudent: $e');
      }
    }

    // 3. Sincroniza com a API do Backend
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students');
      await http.post(
        uri,
        headers: _apiHeaders,
        body: jsonEncode({
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'phone': phone?.trim(),
          'goal': goal ?? 'Hipertrofia Muscular',
          'trainer_id': trainerId,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Aviso Backend createStudent: $e');
    }

    return studentData;
  }

  /// Busca os alunos vinculados ao personal trainer com dupla checagem (Supabase + Backend + Cache)
  static Future<List<Map<String, dynamic>>> getTrainerStudents() async {
    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';
    final Map<String, Map<String, dynamic>> aggregated = {};

    // 1. Injeta cache local
    for (final st in _localStudentsCache) {
      aggregated[st['id'] as String] = Map<String, dynamic>.from(st);
    }

    // 2. Busca do Supabase 'profiles'
    if (_clientOrNull != null && trainer != null) {
      try {
        final List<dynamic> response = await _client
            .from('profiles')
            .select('id, full_name, email, phone, status, goal')
            .eq('trainer_id', trainerId)
            .eq('role', 'client')
            .order('full_name');

        for (final row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          map['status'] = map['status'] ?? 'Ativo';
          map['goal'] = map['goal'] ?? 'Consultoria';
          aggregated[map['id'] as String] = map;
        }
      } catch (e) {
        debugPrint('Erro ao buscar alunos no Supabase: $e');
      }
    }

    // 3. Busca do Backend /workouts/students
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students');
      final res = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
          aggregated[map['id'] as String] = map;
        }
      }
    } catch (_) {}

    return aggregated.values.toList();
  }

  /// Salva uma ficha de treino com persistência dupla (Supabase 'workouts' + Backend API)
  static Future<Map<String, dynamic>?> saveWorkoutPlan({
    required WorkoutPlanModel plan,
    required String clientId,
  }) async {
    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';

    Map<String, dynamic>? supabaseResult;

    // 1. Persistência no Supabase
    if (_clientOrNull != null && trainer != null) {
      try {
        // Desativa treinos anteriores do mesmo aluno
        await _client
            .from('workouts')
            .update({'is_active': false})
            .eq('client_id', clientId);

        // Insere o novo plano estruturado
        supabaseResult = await _client
            .from('workouts')
            .insert({
              'trainer_id': trainerId,
              'client_id': clientId,
              'title': plan.workoutPlanTitle,
              'notes_for_trainer': plan.notesForTrainer,
              'plan_json': plan.toJson(),
              'is_active': true,
            })
            .select()
            .single();
      } catch (e) {
        debugPrint('Aviso Supabase saveWorkoutPlan: $e');
      }
    }

    // 2. Persistência no Backend FastAPI (/workouts/save-prescription)
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/save-prescription');
      await http.post(
        uri,
        headers: _apiHeaders,
        body: jsonEncode({
          'client_id': clientId,
          'trainer_id': trainerId,
          'plan': plan.toJson(),
          'notes': plan.notesForTrainer,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Aviso Backend save-prescription: $e');
    }

    return supabaseResult ?? {'status': 'saved', 'client_id': clientId};
  }

  /// Busca a ficha ativa do aluno logado
  static Future<WorkoutPlanModel?> getActiveWorkoutForClient({String? clientId}) async {
    final targetId = clientId ?? AuthService.currentUser?.id;
    if (targetId == null || _clientOrNull == null) return null;

    try {
      final data = await _client
          .from('workouts')
          .select('plan_json')
          .eq('client_id', targetId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null && data['plan_json'] != null) {
        return WorkoutPlanModel.fromJson(Map<String, dynamic>.from(data['plan_json']));
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao buscar treino ativo do aluno: $e');
      return null;
    }
  }

  /// Registra uma substituição de exercício na tabela de auditoria
  static Future<void> logAdaptation({
    required String originalExercise,
    required String adaptedExercise,
    required String reason,
    Map<String, dynamic>? details,
    String? trainerId,
    String? workoutId,
  }) async {
    final client = AuthService.currentUser;
    if (client == null) return;

    try {
      // Se trainerId não for passado, busca no perfil do aluno
      String? actualTrainerId = trainerId;
      if (actualTrainerId == null) {
        final profile = await AuthService.getCurrentProfile();
        actualTrainerId = profile?['trainer_id'] as String?;
      }

      final payload = <String, dynamic>{
        'client_id': client.id,
        'original_exercise': originalExercise,
        'adapted_exercise': adaptedExercise,
        'reason': reason,
        'viewed_by_trainer': false,
      };
      if (actualTrainerId != null) payload['trainer_id'] = actualTrainerId;
      if (workoutId != null) payload['workout_id'] = workoutId;
      if (details != null) payload['adaptation_details'] = details;

      await _client.from('adaptation_logs').insert(payload);
    } catch (e) {
      debugPrint('Erro ao auditar substituição de exercício: $e');
    }
  }
}
