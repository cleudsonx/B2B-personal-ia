import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Busca os alunos vinculados ao personal trainer logado
  static Future<List<Map<String, dynamic>>> getTrainerStudents() async {
    final trainer = AuthService.currentUser;
    if (trainer == null || _clientOrNull == null) return [];

    try {
      final List<dynamic> response = await _client
          .from('profiles')
          .select('id, full_name, phone')
          .eq('trainer_id', trainer.id)
          .eq('role', 'client')
          .order('full_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao buscar alunos: $e');
      return [];
    }
  }

  /// Salva uma ficha de treino gerada e aprovada pelo treinador no Supabase
  static Future<Map<String, dynamic>?> saveWorkoutPlan({
    required WorkoutPlanModel plan,
    required String clientId,
  }) async {
    final trainer = AuthService.currentUser;
    if (trainer == null) {
      throw Exception('Treinador não autenticado.');
    }

    try {
      // 1. Desativa treinos anteriores do mesmo aluno (mantendo apenas o mais recente ativo)
      await _client
          .from('workouts')
          .update({'is_active': false})
          .eq('client_id', clientId);

      // 2. Insere o novo plano estruturado
      final response = await _client
          .from('workouts')
          .insert({
            'trainer_id': trainer.id,
            'client_id': clientId,
            'title': plan.workoutPlanTitle,
            'notes_for_trainer': plan.notesForTrainer,
            'plan_json': plan.toJson(),
            'is_active': true,
          })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Falha ao salvar ficha no banco: $e');
    }
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
