import 'dart:async';
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

  /// Notificador reativo disparado sempre que a lista de alunos ou prescrições sofre alterações
  static final ValueNotifier<int> studentsRefreshNotifier = ValueNotifier<int>(0);

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

    // Sincroniza com o backend antes de exibir o convite como criado.
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

      if (res.statusCode != 200 && res.statusCode != 201) {
        final err =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        throw Exception(
          err['detail'] ??
              'Não foi possível criar o convite (${res.statusCode}).',
        );
      }

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      studentData['id'] = data['id'] ?? studentId;
      studentData['status'] = data['status'] ?? studentData['status'];
      studentData['invitation_link'] = data['invitation_link'];
      studentData['whatsapp_url'] = data['whatsapp_url'];
      studentData['email_status'] = data['email_status'];
    } catch (e) {
      _localStudentsCache.removeWhere((s) => s['id'] == studentId);
      rethrow;
    }

    _localStudentsCache.removeWhere((s) => s['email'] == studentData['email']);
    _localStudentsCache.insert(0, studentData);

    // Persiste na tabela 'profiles' do Supabase
    if (_clientOrNull != null) {
      try {
        final payload = <String, dynamic>{
          'id': studentData['id'],
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
    final List<Map<String, dynamic>> rawList = [];

    // 1. Busca do Supabase 'profiles' (Fonte oficial de alunos com conta ativa)
    if (_clientOrNull != null && trainer != null) {
      try {
        final List<dynamic> response = await _client
            .from('profiles')
            .select()
            .eq('trainer_id', trainerId)
            .eq('role', 'client')
            .order('created_at', ascending: false);

        // Coleta todos os client IDs para buscar treinos ativos diretamente
        final List<String> clientIds = response
            .map((r) => (r['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();

        final Map<String, Map<String, dynamic>> activeWorkoutsMap = {};
        if (clientIds.isNotEmpty) {
          try {
            List<dynamic> workoutsRes = [];
            try {
              workoutsRes = await _client
                  .from('workouts')
                  .select('client_id, title, is_active, updated_at')
                  .eq('trainer_id', trainerId)
                  .eq('is_active', true)
                  .order('updated_at', ascending: false);
            } catch (_) {
              workoutsRes = await _client
                  .from('workouts')
                  .select('client_id, title, is_active, updated_at')
                  .inFilter('client_id', clientIds)
                  .eq('is_active', true);
            }
            for (final w in workoutsRes) {
              final cid = w['client_id']?.toString();
              if (cid != null && !activeWorkoutsMap.containsKey(cid)) {
                activeWorkoutsMap[cid] = Map<String, dynamic>.from(w as Map);
              }
            }
          } catch (we) {
            debugPrint('Aviso Supabase busca treinos de alunos: $we');
          }
        }

        for (final row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          final subStatus = map['subscription_status'] as String? ?? 'trial';
          map['status'] = subStatus == 'canceled' ? 'Arquivado' : 'Ativo';
          map['goal'] = map['goal'] ?? 'Consultoria Personalizada';

          final stId = map['id']?.toString() ?? '';
          var activeWorkout = activeWorkoutsMap[stId];
          var hasActive = activeWorkout != null;
          if (!hasActive && stId.isNotEmpty) {
            final cachedPlan = await getOfflineCachedWorkout(clientId: stId);
            if (cachedPlan != null) {
              hasActive = true;
              map['active_split'] = cachedPlan.workoutPlanTitle;
              map['last_session'] = 'Ficha ativa';
            }
          }
          map['has_active_prescription'] = hasActive;
          if (hasActive) {
            map['active_split'] = map['active_split'] ?? (activeWorkout?['title'] ?? 'Ficha ativa');
            map['last_session'] = 'Ficha ativa';
          }
          rawList.add(map);
        }
      } catch (e) {
        debugPrint('Erro ao buscar alunos no Supabase: $e');
      }
    }

    // 2. Busca do Backend /workouts/students (complementa com convites e anamneses)
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/students');
      final res = await http
          .get(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        for (final item in list) {
          rawList.add(Map<String, dynamic>.from(item as Map));
        }
      }
    } catch (_) {}

    // 3. Injeta cache local de novos convites criados nesta sessão
    for (final st in _localStudentsCache) {
      rawList.add(Map<String, dynamic>.from(st));
    }

    // 4. Deduplicação inteligente e unificação de registros
    final Map<String, Map<String, dynamic>> deduplicated = {};
    final Set<String> seenPhones = {};
    final Set<String> seenEmails = {};
    final Set<String> seenNames = {};

    String normalizePhone(dynamic p) {
      if (p == null) return '';
      final digits = p.toString().replaceAll(RegExp(r'\D'), '');
      return digits.startsWith('55') && digits.length > 11 ? digits.substring(2) : digits;
    }

    String normalizeEmail(dynamic e) {
      if (e == null) return '';
      return e.toString().trim().toLowerCase();
    }

    String normalizeName(dynamic n) {
      if (n == null) return '';
      return n.toString().trim().toLowerCase();
    }

    // Ordena priorizando perfis com ID oficial de UUID real (não mockado 11111111-)
    rawList.sort((a, b) {
      final aId = (a['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      final aIsTemp = aId.startsWith('11111111-');
      final bIsTemp = bId.startsWith('11111111-');
      if (aIsTemp && !bIsTemp) return 1;
      if (!aIsTemp && bIsTemp) return -1;
      return 0;
    });

    for (final student in rawList) {
      final id = (student['id'] ?? '').toString();
      final phone = normalizePhone(student['phone']);
      final email = normalizeEmail(student['email']);
      final name = normalizeName(student['full_name']);

      // Se já temos esse aluno por ID, telefone, email ou nome
      bool isDuplicate = false;
      String? matchedKey;

      if (id.isNotEmpty && deduplicated.containsKey(id)) {
        isDuplicate = true;
        matchedKey = id;
      } else {
        for (final entry in deduplicated.entries) {
          final existing = entry.value;
          final exPhone = normalizePhone(existing['phone']);
          final exEmail = normalizeEmail(existing['email']);
          final exName = normalizeName(existing['full_name']);
          if ((phone.isNotEmpty && exPhone == phone) ||
              (email.isNotEmpty && !email.contains('shaipados.com') && exEmail == email) ||
              (name.isNotEmpty && name != 'novo aluno' && exName == name)) {
            isDuplicate = true;
            matchedKey = entry.key;
            break;
          }
        }
      }

      if (!isDuplicate) {
        if (id.isNotEmpty) deduplicated[id] = student;
        if (phone.isNotEmpty) seenPhones.add(phone);
        if (email.isNotEmpty && !email.contains('shaipados.com')) seenEmails.add(email);
        if (name.isNotEmpty && name != 'novo aluno') seenNames.add(name);
      } else if (matchedKey != null && deduplicated.containsKey(matchedKey)) {
        // Fusão inteligente de campos para garantir propagação completa de dados
        final existing = deduplicated[matchedKey]!;
        final hasActive = student['has_active_prescription'] == true || existing['has_active_prescription'] == true;
        existing['has_active_prescription'] = hasActive;

        final stSplit = student['active_split']?.toString();
        final exSplit = existing['active_split']?.toString();
        if (stSplit != null && stSplit.isNotEmpty && (exSplit == null || exSplit.isEmpty || exSplit == 'Ficha ativa')) {
          existing['active_split'] = stSplit;
        }
        if (hasActive && (existing['last_session'] == null || existing['last_session'] == 'Aguardando treino')) {
          existing['last_session'] = 'Ficha ativa';
        }
        if (student['photo_url'] != null && student['photo_url'].toString().isNotEmpty) {
          existing['photo_url'] = student['photo_url'];
        }
        if (student['avatar_url'] != null && student['avatar_url'].toString().isNotEmpty) {
          existing['avatar_url'] = student['avatar_url'];
        }
      }
    }

    // Limpa do _localStudentsCache qualquer item que já esteja sincronizado
    _localStudentsCache.removeWhere((cacheItem) {
      final cachePhone = normalizePhone(cacheItem['phone']);
      final cacheName = normalizeName(cacheItem['full_name']);
      return seenPhones.contains(cachePhone) || seenNames.contains(cacheName);
    });

    return deduplicated.values.toList();
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

        // 1.1 Baixa os alertas de adaptação / pendência de treino para este aluno
        await _client
            .from('adaptation_logs')
            .update({'viewed_by_trainer': true})
            .eq('client_id', clientId);
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

    // 4. Notifica ouvintes reativos de que os alunos/fichas foram atualizados
    studentsRefreshNotifier.value++;

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

  static Future<List<Map<String, dynamic>>>
  getTrainerGamificationRanking() async {
    final client = _clientOrNull;
    final trainerId = AuthService.currentUser?.id;
    if (client == null || trainerId == null) {
      throw StateError('Sessão do treinador indisponível.');
    }

    final profiles = await client
        .from('profiles')
        .select('id, full_name, photo_url, avatar_url, phone')
        .eq('trainer_id', trainerId);
    if (profiles.isEmpty) return [];

    final profilesById = {
      for (final profile in profiles)
        profile['id'] as String: profile,
    };
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(days: 100));
    final sessions = await client
        .from('workout_sessions')
        .select('client_id, completed_at')
        .inFilter('client_id', profilesById.keys.toList())
        .gte('completed_at', cutoff.toIso8601String())
        .order('completed_at', ascending: false)
        .limit(1000);

    final sessionsByClient = {
      for (final clientId in profilesById.keys) clientId: <DateTime>[],
    };
    for (final session in sessions) {
      final clientId = session['client_id'] as String?;
      final completedAt = DateTime.tryParse(
        session['completed_at']?.toString() ?? '',
      )?.toUtc();
      if (clientId == null || completedAt == null) continue;
      sessionsByClient.putIfAbsent(clientId, () => []).add(completedAt);
    }

    final today = DateTime.utc(now.year, now.month, now.day);
    final ranking = <Map<String, dynamic>>[];
    for (final entry in sessionsByClient.entries) {
      final activityDates = entry.value
          .map((date) => DateTime.utc(date.year, date.month, date.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      var streak = 0;
      if (activityDates.isNotEmpty &&
          !activityDates.first.isBefore(today.subtract(const Duration(days: 1)))) {
        var expectedDate = activityDates.first;
        for (final activityDate in activityDates) {
          if (activityDate != expectedDate) break;
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        }
      }
      final prof = profilesById[entry.key] ?? {};
      ranking.add({
        'client_id': entry.key,
        'full_name': (prof['full_name'] as String?) ?? 'Aluno',
        'photo_url': (prof['photo_url'] ?? prof['avatar_url']) as String?,
        'phone': prof['phone'] as String?,
        'current_streak': streak,
        'sessions_in_window': entry.value.length,
        'last_activity_date': activityDates.isEmpty
          ? null
          : activityDates.first.toIso8601String(),
      });
    }
    ranking.sort((a, b) {
      final streakOrder =
          (b['current_streak'] as int).compareTo(a['current_streak'] as int);
      if (streakOrder != 0) return streakOrder;
      return (b['sessions_in_window'] as int)
          .compareTo(a['sessions_in_window'] as int);
    });
    return ranking;
  }

  /// Retorna as últimas sessões concluídas pelos alunos do treinador (Feed de Atualizações Recentes).
  static Future<List<Map<String, dynamic>>> getTrainerRecentCompletedSessions({
    int limit = 15,
  }) async {
    final client = _clientOrNull;
    final trainerId = AuthService.currentUser?.id;
    if (client == null || trainerId == null) return [];

    try {
      final profiles = await client
          .from('profiles')
          .select('id, full_name, photo_url, avatar_url, phone')
          .eq('trainer_id', trainerId);
      if (profiles.isEmpty) return [];

      final profilesById = {
        for (final profile in profiles)
          profile['id'] as String: profile,
      };

      final rows = await client
          .from('workout_sessions')
          .select('id, client_id, split_identifier, split_name, total_exercises, completed_exercises, completed_at, duration_seconds')
          .inFilter('client_id', profilesById.keys.toList())
          .order('completed_at', ascending: false)
          .limit(limit);

      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        final clientId = row['client_id'] as String?;
        final prof = profilesById[clientId] ?? {};
        result.add({
          'session_id': row['id'],
          'client_id': clientId,
          'client_name': (prof['full_name'] as String?) ?? 'Aluno',
          'photo_url': (prof['photo_url'] ?? prof['avatar_url']) as String?,
          'phone': prof['phone'] as String?,
          'split_identifier': row['split_identifier'] ?? 'A',
          'split_name': row['split_name'] ?? 'Treino Prescrito',
          'completed_at': row['completed_at'],
          'duration_seconds': (row['duration_seconds'] as num?)?.toInt() ?? 0,
          'completed_exercises': (row['completed_exercises'] as num?)?.toInt() ?? 0,
          'total_exercises': (row['total_exercises'] as num?)?.toInt() ?? 0,
        });
      }
      return result;
    } catch (e) {
      debugPrint('Erro ao buscar sessões recentes dos alunos: $e');
      return [];
    }
  }

  /// Busca o status / recado publicado pelo treinador.
  static Future<Map<String, dynamic>?> getTrainerStatus() async {
    final client = _clientOrNull;
    final trainerId = AuthService.currentUser?.id;
    if (client == null || trainerId == null) return null;

    try {
      final row = await client
          .from('profiles')
          .select('status_message, status_updated_at, photo_url, avatar_url, full_name')
          .eq('id', trainerId)
          .maybeSingle();
      return row;
    } catch (e) {
      debugPrint('Erro ao carregar status do treinador: $e');
      return null;
    }
  }

  /// Atualiza o status / recado publicado pelo treinador para seus alunos.
  static Future<void> updateTrainerStatus(String message) async {
    final client = _clientOrNull;
    final trainerId = AuthService.currentUser?.id;
    if (client == null || trainerId == null) {
      throw StateError('Sessão do treinador indisponível.');
    }

    await client.from('profiles').update({
      'status_message': message.trim(),
      'status_updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', trainerId);
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
                .select('id, title, notes_for_trainer, plan_json, created_at, updated_at')
                .eq('client_id', targetId)
                .eq('is_active', true)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

        if (data != null && data['plan_json'] != null) {
          final planMap = Map<String, dynamic>.from(data['plan_json']);
          if (data['id'] != null) {
            planMap['id'] = data['id'];
          }
          if (data['title'] != null &&
              (planMap['workout_plan_title'] == null ||
                  planMap['workout_plan_title'] == 'Periodização')) {
            planMap['workout_plan_title'] = data['title'];
          }
          if (data['notes_for_trainer'] != null &&
              (planMap['notes_for_trainer'] == null ||
                  (planMap['notes_for_trainer'] as String).isEmpty)) {
            planMap['notes_for_trainer'] = data['notes_for_trainer'];
          }
          if (data['created_at'] != null) {
            planMap['created_at'] = data['created_at'];
          }
          if (data['updated_at'] != null) {
            planMap['updated_at'] = data['updated_at'];
          }

          final plan = WorkoutPlanModel.fromJson(planMap);
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

  /// Desativa ou exclui a ficha ativa do aluno
  static Future<bool> deleteWorkoutPlan({
    required String clientId,
    String? workoutId,
  }) async {
    var success = false;
    if (_clientOrNull != null) {
      try {
        if (workoutId != null && workoutId.isNotEmpty) {
          await _client
              .from('workouts')
              .update({'is_active': false})
              .eq('id', workoutId);
        } else {
          await _client
              .from('workouts')
              .update({'is_active': false})
              .eq('client_id', clientId)
              .eq('is_active', true);
        }
        success = true;
      } catch (e) {
        debugPrint('Erro ao desativar ficha no Supabase: $e');
      }
    }
    // Limpa cache offline
    await clearOfflineCachedWorkout(clientId);
    studentsRefreshNotifier.value++;
    return success;
  }

  /// Renova o ciclo da ficha ativa do aluno (atualiza timestamp e reinicia ciclo)
  static Future<bool> renewWorkoutPlan({
    required String clientId,
    String? workoutId,
  }) async {
    var success = false;
    final now = DateTime.now().toIso8601String();
    if (_clientOrNull != null) {
      try {
        if (workoutId != null && workoutId.isNotEmpty) {
          await _client
              .from('workouts')
              .update({
                'is_active': true,
                'updated_at': now,
              })
              .eq('id', workoutId);
        } else {
          await _client
              .from('workouts')
              .update({
                'is_active': true,
                'updated_at': now,
              })
              .eq('client_id', clientId)
              .eq('is_active', true);
        }
        success = true;
      } catch (e) {
        debugPrint('Erro ao renovar ficha no Supabase: $e');
      }
    }
    studentsRefreshNotifier.value++;
    return success;
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
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      var message = 'Não foi possível atualizar o aluno (${res.statusCode}).';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is Map<String, dynamic> && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

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

    return true;
  }

  /// Altera o status do aluno (Ativo, Pendente Confirmação, Arquivado)
  static Future<bool> updateStudentStatus({
    required String studentId,
    required String status,
  }) async {
    return updateStudent(studentId: studentId, status: status);
  }

  /// Exclui um aluno do sistema com suporte a convites pendentes e alunos ativos
  static Future<bool> deleteStudent(String studentId) async {
    bool deletedOnSupabase = false;

    // 1. Tenta exclusão direta no Supabase (se cliente disponível)
    if (_clientOrNull != null) {
      try {
        await _client.from('invite_tokens').delete().eq('id', studentId);
        deletedOnSupabase = true;
      } catch (e) {
        debugPrint('Aviso ao excluir invite_token no Supabase: $e');
      }
      try {
        await _client.from('profiles').delete().eq('id', studentId);
        deletedOnSupabase = true;
      } catch (e) {
        debugPrint('Aviso ao excluir profile no Supabase: $e');
      }
    }

    // 2. Chama a API do backend com timeout estendido (15s) para absorver cold starts
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/workouts/students/$studentId',
      );
      final res = await http
          .delete(uri, headers: _apiHeaders)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200 && res.statusCode != 404) {
        var message = 'Não foi possível excluir o aluno (${res.statusCode}).';
        try {
          final body = jsonDecode(utf8.decode(res.bodyBytes));
          if (body is Map<String, dynamic> && body['detail'] != null) {
            message = body['detail'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
    } on TimeoutException {
      debugPrint('Aviso: Timeout no backend ao excluir aluno $studentId.');
      if (!deletedOnSupabase && _clientOrNull == null) {
        throw Exception('Tempo limite esgotado ao contatar o servidor. Tente novamente.');
      }
    } catch (e) {
      if (e.toString().contains('Não foi possível') || e.toString().contains('permissão')) {
        rethrow;
      }
      if (!deletedOnSupabase && _clientOrNull == null) {
        rethrow;
      }
      debugPrint('Aviso HTTP ao excluir aluno: $e');
    }

    _localStudentsCache.removeWhere((s) => s['id'] == studentId);
    return true;
  }

  /// Persiste a anamnese detalhada preenchida pelo próprio aluno
  static Future<bool> saveClientAnamnesis({
    required String clientId,
    required Map<String, dynamic> data,
  }) async {
    if (_clientOrNull == null) {
      throw Exception('Entre na sua conta para salvar sua avaliação.');
    }

    // 1. Atualiza cache de alunos localmente para refletir imediatamente
    final index = _localStudentsCache.indexWhere((s) => s['id'] == clientId);
    if (index != -1) {
      _localStudentsCache[index]['objective'] = data['objective'];
      _localStudentsCache[index]['injuries_or_restrictions'] =
          data['injuries_summary'];
      _localStudentsCache[index]['status'] = 'Ativo';
    }

    // 2. Persiste na tabela 'anamnesis' e atualiza 'profiles' no Supabase
    await _client.from('anamnesis').insert({
      'client_id': clientId,
      'objective': data['objective'] ?? 'Hipertrofia Muscular',
      'training_level': data['training_level'] ?? 'Iniciante',
      'days_per_week': data['weekly_days'] ?? 3,
      'workout_location': data['workout_location'] ?? 'Academia Convencional',
      'injuries_or_restrictions': data['injuries_summary'] ?? 'Nenhuma',
      if (data['trainer_id'] != null) 'trainer_id': data['trainer_id'],
    });

    final profileUpdate = <String, dynamic>{
      'has_completed_anamnesis': true,
      'age': data['age'],
      'weight_kg': data['weight'],
      'height_cm': data['height'],
      'clinical_restrictions': data['injuries_summary'],
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (data['trainer_id'] != null &&
        (data['trainer_id'] as String).isNotEmpty) {
      profileUpdate['trainer_id'] = data['trainer_id'];
    }
    await _client.from('profiles').update(profileUpdate).eq('id', clientId);

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

  static Future<String?> getClientWorkoutLocation() async {
    final client = _clientOrNull;
    final clientId = AuthService.currentUser?.id;
    if (client == null || clientId == null) return null;

    try {
      final anamnesis =
          await client
              .from('anamnesis')
              .select('workout_location')
              .eq('client_id', clientId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
      final location = anamnesis?['workout_location'] as String?;
      return location?.trim().isNotEmpty == true ? location!.trim() : null;
    } catch (e) {
      debugPrint('Aviso ao carregar local de treino do aluno: $e');
      return null;
    }
  }

  /// Notifica o professor imediatamente sobre a conclusão da anamnese do aluno
  static Future<void> notifyTrainerOnboardingCompleted({
    required String clientId,
    required String trainerId,
    required String studentName,
    required String objective,
    String? trainingLevel,
    int? weeklyDays,
    String? injuriesOrRestrictions,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/notify-trainer-onboarding');
      await http.post(
        uri,
        headers: _apiHeaders,
        body: jsonEncode({
          'client_id': clientId,
          'trainer_id': trainerId,
          'student_name': studentName,
          'objective': objective,
          'training_level': trainingLevel ?? 'Intermediário',
          'weekly_days': weeklyDays ?? 4,
          'injuries_or_restrictions': injuriesOrRestrictions,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Aviso ao notificar professor sobre onboarding: $e');
    }
  }
}

