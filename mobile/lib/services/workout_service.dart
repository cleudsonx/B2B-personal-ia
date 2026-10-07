import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../models/workout_plan_model.dart';
import 'auth_service.dart';
import 'subscription_service.dart';

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
    final currentSub = SubscriptionService.activeSubscriptionNotifier.value;
    if (currentSub != null) {
      final occupiedCount =
          _localStudentsCache.where((s) {
            final st = (s['status'] as String? ?? '').toLowerCase();
            return !st.contains('arquivado') && !st.contains('inativo');
          }).length;
      if (occupiedCount >= currentSub.maxStudents) {
        throw Exception(
          'Limite de ${currentSub.maxStudents} alunos ativos atingido no plano ${currentSub.planName}. '
          'Faça upgrade do plano ou arquive alunos inativos antes de cadastrar novos.',
        );
      }
    }

    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';
    final trainerName =
        trainer?.userMetadata?['full_name'] as String? ?? 'Personal Trainer';
    final rnd = DateTime.now().millisecondsSinceEpoch.toString();
    final studentId = '11111111-1111-1111-1111-${rnd.padLeft(12, '0').substring(0, 12)}';

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

    // 2. Sincroniza com a API do Backend e dispara convite oficial por e-mail via Resend
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students/invite');
      final res = await http
          .post(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              'full_name': fullName.trim(),
              'email': email.trim().toLowerCase(),
              'phone': phone?.trim(),
              'objective': goal ?? 'Hipertrofia Muscular',
              'send_email': true,
              'send_whatsapp': false,
              'trainer_id': trainerId,
              'trainer_name': trainerName,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 403) {
        _localStudentsCache.removeWhere((s) => s['id'] == studentId);
        final err =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        throw Exception(
          err['detail'] ??
              'Limite de alunos ativos atingido no seu plano atual.',
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        studentData['id'] = data['id'] ?? studentId;
        studentData['invitation_link'] = data['invitation_link'];
        studentData['whatsapp_url'] = data['whatsapp_url'];
        studentData['email_status'] = data['email_status'];
      }
    } catch (e) {
      if (e.toString().contains('Limite de') || e.toString().contains('403')) {
        rethrow;
      }
      debugPrint('Aviso Backend inviteStudent: $e');
    }

    // 3. Persiste na tabela 'profiles' do Supabase
    if (_clientOrNull != null) {
      try {
        final payload = <String, dynamic>{
          'id': studentId,
          'full_name': fullName.trim(),
          'role': 'client',
          'subscription_status': 'trial',
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (phone != null && phone.trim().isNotEmpty) {
          payload['phone'] = phone.trim();
        }
        if (trainerId.isNotEmpty && trainerId != 'current-trainer') {
          payload['trainer_id'] = trainerId;
        }
        await _client.from('profiles').upsert(payload);
      } catch (e) {
        debugPrint('Aviso Supabase createStudent: $e');
      }
    }

    return studentData;
  }

  /// Reenvia o e-mail de convite oficial para o aluno através do backend (Resend API)
  static Future<bool> resendInvitationEmail({
    required String fullName,
    required String email,
    String? phone,
    String? goal,
  }) async {
    try {
      final trainer = AuthService.currentUser;
      final trainerId = trainer?.id ?? 'current-trainer';
      final trainerName =
          trainer?.userMetadata?['full_name'] as String? ?? 'Personal Trainer';

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students/invite');
      final res = await http
          .post(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              'full_name': fullName.trim(),
              'email': email.trim().toLowerCase(),
              'phone': phone?.trim(),
              'objective': goal ?? 'Hipertrofia Muscular',
              'send_email': true,
              'send_whatsapp': false,
              'trainer_id': trainerId,
              'trainer_name': trainerName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Erro ao reenviar convite por e-mail: $e');
      return false;
    }
  }

  /// Busca os alunos vinculados ao personal trainer com dupla checagem (Supabase + Backend + Cache)

  static Future<List<Map<String, dynamic>>> getTrainerWorkouts() async {
    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';

    if (_clientOrNull != null && trainer != null) {
      try {
        final List<dynamic> response = await _client
            .from('workouts')
            .select('*, profiles!workouts_client_id_fkey(full_name, avatar_url)')
            .eq('trainer_id', trainerId)
            .eq('is_active', true)
            .order('updated_at', ascending: false);

        return response.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Aviso Supabase getTrainerWorkouts: $e');
      }
    }
    
    // Fallback para API FastAPI caso exista
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/trainer/$trainerId/workouts');
      final res = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Aviso API getTrainerWorkouts: $e');
    }
    return [];
  }

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
            .select()
            .eq('trainer_id', trainerId)
            .eq('role', 'client')
            .order('created_at', ascending: false);

        for (final row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          final subStatus = map['subscription_status'] as String? ?? 'trial';
          map['status'] = subStatus == 'canceled' ? 'Arquivado' : 'Ativo';
          map['goal'] = 'Consultoria Personalizada';
          aggregated[map['id'] as String] = map;
        }
      } catch (e) {
        debugPrint('Erro ao buscar alunos no Supabase: $e');
      }
    }

    // 3. Busca do Backend /workouts/students
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students');
      final res = await http
          .get(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));
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
        supabaseResult =
            await _client
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
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/save-prescription',
      );
      await http
          .post(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              'client_id': clientId,
              'trainer_id': trainerId,
              'plan': plan.toJson(),
              'notes': plan.notesForTrainer,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Aviso Backend save-prescription: $e');
    }

    // 3. Salva no cache offline persistente do celular para visualização sem internet
    await _saveWorkoutToOfflineCache(clientId, plan);

    return supabaseResult ?? {'status': 'saved', 'client_id': clientId};
  }

  static const String _kOfflineWorkoutPrefix = 'b2b_offline_active_workout_';

  /// Salva a ficha ativa no armazenamento local do dispositivo para uso offline
  static Future<void> _saveWorkoutToOfflineCache(
    String clientId,
    WorkoutPlanModel plan,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kOfflineWorkoutPrefix$clientId',
        jsonEncode(plan.toJson()),
      );
      await prefs.setString(
        '${_kOfflineWorkoutPrefix}last_active',
        jsonEncode(plan.toJson()),
      );
    } catch (e) {
      debugPrint('Aviso ao salvar treino no cache offline: $e');
    }
  }

  /// Remove o treino em cache de um aluno (ex.: ficha desativada no servidor).
  static Future<void> clearOfflineCachedWorkout(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kOfflineWorkoutPrefix$clientId');
      await prefs.remove('${_kOfflineWorkoutPrefix}last_active');
    } catch (e) {
      debugPrint('Aviso ao limpar cache offline: $e');
    }
  }

  /// Recupera a ficha ativa do armazenamento local se o aluno estiver offline
  static Future<WorkoutPlanModel?> getOfflineCachedWorkout({
    String? clientId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final target = clientId ?? AuthService.currentUser?.id;
      String? raw;
      if (target != null) {
        raw = prefs.getString('$_kOfflineWorkoutPrefix$target');
      } else {
        raw = prefs.getString('${_kOfflineWorkoutPrefix}last_active');
      }
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return WorkoutPlanModel.fromJson(map);
      }
    } catch (e) {
      debugPrint('Aviso ao carregar treino do cache offline: $e');
    }
    return null;
  }

  /// Busca a ficha ativa do aluno logado com tolerância a falhas offline
  
  static Future<Map<String, dynamic>?> getGamificationData() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/gamification');
      final res = await http
          .get(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }

      if (res.statusCode == 404) {
        return null;
      }
    } catch (e) {
      debugPrint('Erro ao buscar gamificacao: $e');
      return null;
    }

    return null;
  }

  static Future<WorkoutPlanModel?> getActiveWorkoutForClient({
    String? clientId,
  }) async {
    final targetId = clientId ?? AuthService.currentUser?.id;

    // 1. Tenta carregar do Supabase se houver conexão
    if (_clientOrNull != null && targetId != null) {
      try {
        final data =
            await _client
                .from('workouts')
                .select('plan_json')
                .eq('client_id', targetId)
                .eq('is_active', true)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

        if (data != null && data['plan_json'] != null) {
          final plan = WorkoutPlanModel.fromJson(
            Map<String, dynamic>.from(data['plan_json']),
          );
          await _saveWorkoutToOfflineCache(targetId, plan);
          return plan;
        }
        // Consulta bem-sucedida e sem ficha ativa: o cache está obsoleto.
        await clearOfflineCachedWorkout(targetId);
        return null;
      } catch (e) {
        debugPrint(
          'Aviso Supabase getActiveWorkoutForClient: $e. Tentando cache offline.',
        );
      }
    }

    // 2. Fallback resiliente offline (academia sem sinal ou sem internet)
    final cached = await getOfflineCachedWorkout(clientId: targetId);
    if (cached != null) {
      debugPrint(
        '[WorkoutService] Treino carregado com sucesso do cache offline persistente.',
      );
      return cached;
    }

    return null;
  }

  /// Registra uma substituição de exercício na tabela de auditoria
  static Future<void> logAdaptation({
    required String originalExercise,
    required String adaptedExercise,
    required String reason,
    Map<String, dynamic>? details,
    String? trainerId,
    String? workoutId,
    String? painLocation,
  }) async {
    final client = AuthService.currentUser;
    final clientId = client?.id ?? 'client-demo';
    final studentName =
        client?.userMetadata?['full_name'] as String? ?? 'Aluno em Treino';

    try {
      String? actualTrainerId = trainerId;
      if (actualTrainerId == null && client != null) {
        final profile = await AuthService.getCurrentProfile();
        actualTrainerId = profile?['trainer_id'] as String?;
      }
      actualTrainerId ??= 'current-trainer';

      // 1. Persiste no Supabase se disponível
      if (_clientOrNull != null) {
        final payload = <String, dynamic>{
          'client_id': clientId,
          'original_exercise': originalExercise,
          'adapted_exercise': adaptedExercise,
          'reason': reason,
          'viewed_by_trainer': false,
        };
        payload['trainer_id'] = actualTrainerId;
        if (workoutId != null) payload['workout_id'] = workoutId;
        if (details != null) payload['adaptation_details'] = details;

        await _client.from('adaptation_logs').insert(payload);
      }

      // 2. Dispara alerta biomecânico no backend para acionar painel do treinador
      await registerBiomechanicalAlert(
        studentId: clientId,
        studentName: studentName,
        trainerId: actualTrainerId,
        originalExercise: originalExercise,
        adaptedExercise: adaptedExercise,
        reason: reason,
        painLocation: painLocation,
      );
    } catch (e) {
      debugPrint('Erro ao auditar substituição de exercício: $e');
    }
  }

  /// Dispara alerta biomecânico no backend (painel do treinador e WhatsApp)
  static Future<Map<String, dynamic>?> registerBiomechanicalAlert({
    required String studentId,
    required String studentName,
    String? trainerId,
    required String originalExercise,
    required String adaptedExercise,
    required String reason,
    String? painLocation,
    String severity = 'Moderada',
    Map<String, dynamic>? details,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/adaptations/alert',
      );
      final res = await http
          .post(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              'student_id': studentId,
              'student_name': studentName,
              'trainer_id': trainerId ?? 'current-trainer',
              'original_exercise': originalExercise,
              'adapted_exercise': adaptedExercise,
              'reason': reason,
              'pain_location': painLocation,
              'severity': severity,
              'details': details,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Aviso backend registerBiomechanicalAlert: $e');
    }
    return null;
  }

  /// Busca os alertas ativos para o painel do treinador
  static Future<List<Map<String, dynamic>>> getTrainerAlerts({
    String? trainerId,
  }) async {
    final tid = trainerId ?? AuthService.currentUser?.id ?? 'current-trainer';
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/trainer/$tid/alerts',
      );
      final res = await http
          .get(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('Aviso backend getTrainerAlerts: $e');
    }
    return [];
  }

  /// Marca um alerta como ciente pelo treinador
  static Future<void> acknowledgeAlert(String alertId) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/alerts/$alertId/acknowledge',
      );
      await http
          .patch(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Aviso backend acknowledgeAlert: $e');
    }
  }

  /// Atualiza os dados de um aluno (nome, email, telefone, objetivo, restrições)
  static Future<bool> updateStudent({
    required String studentId,
    String? fullName,
    String? email,
    String? phone,
    String? goal,
    String? injuriesOrRestrictions,
    String? status,
  }) async {
    final idx = _localStudentsCache.indexWhere((s) => s['id'] == studentId);
    final prevStudent =
        idx != -1 ? Map<String, dynamic>.from(_localStudentsCache[idx]) : null;

    // Se estiver tentando alterar o status para ativo/pendente (reativação de aluno):
    if (status != null &&
        !status.toLowerCase().contains('arquivado') &&
        !status.toLowerCase().contains('inativo')) {
      final currentSub = SubscriptionService.activeSubscriptionNotifier.value;
      if (currentSub != null) {
        final currentStudentStatus =
            (prevStudent?['status'] as String? ?? '').toLowerCase();
        final isPreviouslyArchived =
            currentStudentStatus.contains('arquivado') ||
            currentStudentStatus.contains('inativo');
        if (isPreviouslyArchived) {
          final occupied =
              _localStudentsCache.where((s) {
                if (s['id'] == studentId) return false;
                final st = (s['status'] as String? ?? '').toLowerCase();
                return !st.contains('arquivado') && !st.contains('inativo');
              }).length;
          if (occupied >= currentSub.maxStudents) {
            throw Exception(
              'Limite de ${currentSub.maxStudents} alunos ativos atingido no plano ${currentSub.planName}. '
              'Arquive um aluno ou faça upgrade do plano antes de reativar este aluno.',
            );
          }
        }
      }
    }

    // 1. Atualiza no cache local
    if (idx != -1) {
      if (fullName != null) _localStudentsCache[idx]['full_name'] = fullName;
      if (email != null) _localStudentsCache[idx]['email'] = email;
      if (phone != null) _localStudentsCache[idx]['phone'] = phone;
      if (goal != null) _localStudentsCache[idx]['goal'] = goal;
      if (injuriesOrRestrictions != null) {
        _localStudentsCache[idx]['injuries_or_restrictions'] =
            injuriesOrRestrictions;
      }
      if (status != null) _localStudentsCache[idx]['status'] = status;
    }

    // 2. Atualiza no Backend FastAPI
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/students/$studentId',
      );
      final res = await http
          .put(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              if (fullName != null) 'full_name': fullName,
              if (email != null) 'email': email,
              if (phone != null) 'phone': phone,
              if (goal != null) 'goal': goal,
              if (injuriesOrRestrictions != null)
                'injuries_or_restrictions': injuriesOrRestrictions,
              if (status != null) 'status': status,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 403) {
        if (idx != -1 && prevStudent != null) {
          _localStudentsCache[idx] = prevStudent;
        }
        final err =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        throw Exception(
          err['detail'] ?? 'Limite de alunos ativos atingido no plano.',
        );
      }
      if (res.statusCode != 200) {
        debugPrint('Aviso backend updateStudent status: ${res.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('Limite de') || e.toString().contains('403')) {
        rethrow;
      }
      debugPrint('Aviso backend updateStudent: $e');
    }

    // 3. Atualiza no Supabase
    if (_clientOrNull != null) {
      try {
        final updateMap = <String, dynamic>{};
        if (fullName != null) updateMap['full_name'] = fullName;
        if (email != null) updateMap['email'] = email;
        if (phone != null) updateMap['phone'] = phone;
        if (goal != null) updateMap['goal'] = goal;
        if (status != null) updateMap['status'] = status;
        if (updateMap.isNotEmpty) {
          await _client.from('profiles').update(updateMap).eq('id', studentId);
        }
      } catch (e) {
        debugPrint('Aviso Supabase updateStudent: $e');
      }
    }

    return true;
  }

  /// Altera o status do aluno (Ativo, Pendente Confirmação, Arquivado)
  static Future<bool> updateStudentStatus({
    required String studentId,
    required String status,
  }) async {
    return updateStudent(studentId: studentId, status: status);
  }

  /// Exclui um aluno do sistema
  static Future<bool> deleteStudent(String studentId) async {
    // 1. Remove do cache local
    _localStudentsCache.removeWhere((s) => s['id'] == studentId);

    // 2. Remove do Supabase
    if (_clientOrNull != null) {
      try {
        await _client.from('profiles').delete().eq('id', studentId);
      } catch (e) {
        debugPrint('Aviso Supabase deleteStudent: $e');
      }
    }

    // 3. Remove do Backend FastAPI
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/students/$studentId',
      );
      final res = await http
          .delete(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Aviso backend deleteStudent: $e');
    }
    return true;
  }

  /// Persiste a anamnese detalhada preenchida pelo próprio aluno
  static Future<bool> saveClientAnamnesis({
    required String clientId,
    required Map<String, dynamic> data,
  }) async {
    // 1. Atualiza cache de alunos localmente para refletir imediatamente
    final index = _localStudentsCache.indexWhere((s) => s['id'] == clientId);
    if (index != -1) {
      _localStudentsCache[index]['objective'] = data['objective'];
      _localStudentsCache[index]['injuries_or_restrictions'] =
          data['injuries_summary'];
      _localStudentsCache[index]['status'] = 'Ativo';
    }

    // 2. Persiste na tabela 'anamnesis' e atualiza 'profiles' no Supabase
    if (_clientOrNull != null) {
      try {
        await _client.from('anamnesis').insert({
          'client_id': clientId,
          'objective': data['objective'] ?? 'Hipertrofia Muscular',
          'training_level': data['level'] ?? 'Iniciante',
          'days_per_week': data['days_per_week'] ?? 3,
          'workout_location': data['location'] ?? 'Academia Convencional',
          'injuries_or_restrictions': data['injuries_summary'] ?? 'Nenhuma',
          if (data['trainer_id'] != null) 'trainer_id': data['trainer_id'],
        });
      } catch (e) {
        debugPrint('Aviso Supabase saveClientAnamnesis: $e');
      }

      try {
        final profileUpdate = <String, dynamic>{
          'subscription_status': 'active',
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (data['trainer_id'] != null &&
            (data['trainer_id'] as String).isNotEmpty) {
          profileUpdate['trainer_id'] = data['trainer_id'];
        }
        await _client.from('profiles').update(profileUpdate).eq('id', clientId);
      } catch (e) {
        debugPrint('Aviso Supabase update profile anamnesis: $e');
      }
    }

    // 3. Atualiza no Backend FastAPI
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/students/$clientId',
      );
      await http
          .put(
            uri,
            headers: _apiHeaders,
            body: jsonEncode({
              'objective': data['objective'],
              'injuries_or_restrictions': data['injuries_summary'],
              'status': 'Ativo',
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Aviso backend saveClientAnamnesis: $e');
    }

    return true;
  }
}




