import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/utils/pwa_navigation_state.dart';
import '../../../../models/subscription_model.dart';
import '../../../../services/subscription_service.dart';
import '../../../../services/whatsapp_direct_service.dart';
import '../../../subscription/subscription_screen.dart';
import 'whatsapp_connection_screen.dart';
import '../../anamnesis_screen.dart';

/// Cockpit One UI 7 do Consultor Ativo IA 2.0 (Coach Proativo no WhatsApp).
///
/// Interface ergonômica, 100% alinhada ao Design System Meta / One UI 7:
/// - Header polido com badge balanceado sem quebras de linha estranhas
/// - Cartão interativo de status do WhatsApp com chevron de navegação
/// - Resumo Executivo Semanal da Consultoria + Envio 1-Toque para o WhatsApp do Personal
/// - Radar de Retenção Proativa (>4 dias ausentes) com trava anti-spam de 48h e disparo em lote/individual
/// - Lista de comandos de Triagem com alinhamento pixel-perfect (Comandos 1 a 5 a 0 Tokens)
/// - Motor Biomecânico Gemini 2.5 Flash com badges de proteção e guardrails
/// - Telemetria de impacto em cards modulares de alto contraste
class TrainerAiAssistantScreen extends StatefulWidget {
  const TrainerAiAssistantScreen({super.key});

  @override
  State<TrainerAiAssistantScreen> createState() => _TrainerAiAssistantScreenState();
}

class _TrainerAiAssistantScreenState extends State<TrainerAiAssistantScreen> {
  bool _isLoading = true;
  bool _isWhatsAppConnected = false;
  MySubscriptionModel? _subscription;
  Map<String, dynamic>? _telemetry;
  List<Map<String, dynamic>> _inactiveStudents = [];
  Map<String, dynamic>? _weeklyDigest;
  bool _isDispatchingBatch = false;
  String? _dispatchingStudentId;
  bool _isSendingDigest = false;

  List<Map<String, dynamic>> _pulseEvents = [];
  Map<String, dynamic>? _pulseSummary;
  bool _isLoadingPulse = false;
  String _selectedPulseFilter = 'todos';

  final TextEditingController _simulatorController = TextEditingController();
  bool _isSimulating = false;
  Map<String, dynamic>? _simulationResult;

  @override
  void initState() {
    super.initState();
    PwaNavigationState.saveActiveSubscreen('ai_assistant');
    _loadData();
  }

  @override
  void dispose() {
    PwaNavigationState.clearActiveSubscreen();
    _simulatorController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation(String question) async {
    if (question.trim().isEmpty) return;
    setState(() {
      _isSimulating = true;
      _simulatorController.text = question;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/simulate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'question': question}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 && mounted) {
        final simData = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _simulationResult = simData;
          _isSimulating = false;
        });
        // Sincroniza Live Student Pulse 3.0 e Telemetria imediatamente após a simulação
        await Future.wait([
          _fetchTelemetry(),
          _fetchStudentPulse(),
        ]);
      } else {
        if (mounted) {
          setState(() => _isSimulating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao simular: ${res.statusCode}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSimulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão ao simular: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subFuture = SubscriptionService.getMySubscription();
      final statusFuture = _fetchWhatsAppStatus();
      final telemetryFuture = _fetchTelemetry();
      final radarFuture = _fetchProactiveRadar();
      final pulseFuture = _fetchStudentPulse();

      final results = await Future.wait([subFuture, statusFuture, telemetryFuture, radarFuture, pulseFuture]);
      if (mounted) {
        setState(() {
          _subscription = results[0] as MySubscriptionModel?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWhatsAppStatus() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final state = (data['state'] ?? data['status'] ?? '').toString().toLowerCase();
        if (mounted) {
          setState(() {
            _isWhatsAppConnected = state == 'open' || state == 'connected';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchTelemetry() async {
    int apiTotal = 0;
    Map<String, dynamic>? apiTelem;
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token != null) {
        final res = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/telemetry'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          apiTelem = jsonDecode(res.body) as Map<String, dynamic>;
          apiTotal = int.tryParse((apiTelem['total_interactions'] ?? 0).toString()) ?? 0;
        }
      }
    } catch (_) {}

    // Consolida também diretamente do Supabase (trainer_whatsapp_logs + student_pulse_events ai_doubt)
    // para garantir que todas as interações do Robô & IA apareçam mesmo em cold-start
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        final logsRows = await client
            .from('trainer_whatsapp_logs')
            .select('id, student_name, cost_type')
            .eq('trainer_id', uid)
            .limit(200);
        final pulseRows = await client
            .from('student_pulse_events')
            .select('id, metadata')
            .eq('trainer_id', uid)
            .eq('event_type', 'ai_doubt')
            .limit(200);

        final seenIds = <String>{};
        final studentNames = <String>{};
        int freeCount = 0;

        for (final raw in (logsRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = (m['id'] ?? '').toString();
          if (id.isNotEmpty) seenIds.add(id);
          final sname = (m['student_name'] ?? '').toString().trim();
          if (sname.isNotEmpty) studentNames.add(sname);
          if ((m['cost_type'] ?? 'free') == 'free') freeCount++;
        }
        for (final raw in (pulseRows as List)) {
          final m = Map<String, dynamic>.from(raw as Map);
          final meta = (m['metadata'] as Map?) ?? {};
          final logId = (meta['log_id'] ?? m['id'] ?? '').toString();
          if (logId.isNotEmpty && !seenIds.contains(logId)) {
            seenIds.add(logId);
            final sname = (meta['student_name'] ?? '').toString().trim();
            if (sname.isNotEmpty) studentNames.add(sname);
            if ((meta['cost_type'] ?? 'free') == 'free') freeCount++;
          }
        }

        final dbTotal = seenIds.length;
        if (dbTotal > apiTotal) {
          final hoursSaved = ((dbTotal * 4) / 60.0).toStringAsFixed(1);
          apiTelem = {
            'total_interactions': dbTotal,
            'unique_students': studentNames.length,
            'hours_saved': double.tryParse(hoursSaved) ?? 0.0,
            'free_interactions_ratio': dbTotal > 0 ? (freeCount / dbTotal) : 1.0,
          };
        }
      }
    } catch (_) {}

    if (apiTelem != null && mounted) {
      setState(() {
        _telemetry = apiTelem;
      });
    }
  }

  Future<void> _fetchProactiveRadar() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      if (token != null) {
        final res = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/proactive-radar?min_inactive_days=4'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final rawInactive = (data['inactive_students'] as List?) ?? [];
          final rawDigest = data['weekly_digest'] as Map<String, dynamic>?;
          if (mounted) {
            setState(() {
              _inactiveStudents = rawInactive.map((e) => Map<String, dynamic>.from(e as Map)).toList();
              _weeklyDigest = rawDigest;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback direto via Supabase caso o backend esteja acordando
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      final trainerRes = await client
          .from('profiles')
          .select('full_name, phone, public_whatsapp')
          .eq('id', uid)
          .maybeSingle();
      final trainerName = ((trainerRes?['full_name'] ?? 'Personal').toString()).split(' ').first;
      final trainerPhone = (trainerRes?['public_whatsapp'] ?? trainerRes?['phone'] ?? '').toString();

      final rows = await client
          .from('profiles')
          .select('id, full_name, phone, subscription_status, streak_days, last_checkin_date, last_contacted_at, created_at')
          .eq('trainer_id', uid)
          .eq('role', 'client');

      int alertsCount = 0;
      try {
        final alRows = await client
            .from('adaptation_logs')
            .select('id')
            .eq('trainer_id', uid)
            .eq('viewed_by_trainer', false);
        alertsCount = (alRows as List).length;
      } catch (_) {}

      final now = DateTime.now().toUtc();
      final List<Map<String, dynamic>> inactiveList = [];
      final List<Map<String, dynamic>> streakRanking = [];
      int activeTotal = 0;
      int activeThisWeek = 0;

      for (final raw in (rows as List)) {
        final p = Map<String, dynamic>.from(raw as Map);
        final st = (p['subscription_status'] ?? 'active').toString().toLowerCase();
        if (st == 'canceled' || st == 'arquivado' || st == 'suspended' || st == 'inativo') {
          continue;
        }
        activeTotal++;
        final sid = (p['id'] ?? '').toString();
        final sname = (p['full_name'] ?? 'Aluno').toString();
        final sphone = (p['phone'] ?? '').toString();
        final streak = int.tryParse((p['streak_days'] ?? 0).toString()) ?? 0;

        int daysOff = 5;
        final lastCheckinStr = p['last_checkin_date']?.toString();
        final createdStr = p['created_at']?.toString();
        if (lastCheckinStr != null && lastCheckinStr.isNotEmpty) {
          final parsed = DateTime.tryParse(lastCheckinStr)?.toUtc();
          if (parsed != null) {
            daysOff = now.difference(parsed).inDays;
            if (daysOff < 0) daysOff = 0;
          }
          if (daysOff <= 7) activeThisWeek++;
        } else if (createdStr != null && createdStr.isNotEmpty) {
          final parsed = DateTime.tryParse(createdStr)?.toUtc();
          if (parsed != null) {
            daysOff = now.difference(parsed).inDays;
            if (daysOff < 0) daysOff = 0;
          }
        }

        bool recent48h = false;
        final lastContactStr = p['last_contacted_at']?.toString();
        if (lastContactStr != null && lastContactStr.isNotEmpty) {
          final lc = DateTime.tryParse(lastContactStr)?.toUtc();
          if (lc != null && now.difference(lc).inHours < 48) {
            recent48h = true;
          }
        }

        if (streak > 0) {
          streakRanking.add({
            'id': sid,
            'full_name': sname,
            'phone': sphone,
            'streak_days': streak,
          });
        }

        if (daysOff >= 4) {
          inactiveList.add({
            'id': sid,
            'full_name': sname,
            'phone': sphone,
            'days_inactive': daysOff,
            'streak_days': streak,
            'last_contacted_at': lastContactStr,
            'recently_contacted_48h': recent48h,
          });
        }
      }

      inactiveList.sort((a, b) => (b['days_inactive'] as int).compareTo(a['days_inactive'] as int));
      streakRanking.sort((a, b) => (b['streak_days'] as int).compareTo(a['streak_days'] as int));
      final topStreaks = streakRanking.take(3).toList();
      final retentionRate = activeTotal > 0
          ? (((activeTotal - inactiveList.length) / activeTotal) * 100).round()
          : 100;
      final weeklyWorkouts = activeThisWeek * 3;

      final topLines = topStreaks.isNotEmpty
          ? topStreaks
              .asMap()
              .entries
              .map((e) => '  🏆 ${e.key + 1}º ${e.value['full_name']} (${e.value['streak_days']} dias 🔥)')
              .join('\n')
          : '  • Nenhum aluno com ofensiva ativa no momento';

      final riskLines = inactiveList.isNotEmpty
          ? inactiveList
              .take(5)
              .map((e) => '  ⚠️ ${e['full_name']} (${e['days_inactive']} dias ausente)')
              .join('\n')
          : '  ✅ Zero alunos ausentes (>4 dias)!';

      final digestMsg = '📊 *Resumo Executivo Semanal — Mr. Coach*\n'
          'Olá, *$trainerName*! Aqui está o balanço inteligente da sua consultoria:\n\n'
          '👥 *Alunos Ativos:* $activeTotal\n'
          '🏋️ *Treinos na Semana:* $weeklyWorkouts sessões\n'
          '🛡️ *Taxa de Presença:* $retentionRate%\n'
          '🩺 *Alertas Biomecânicos Pendentes:* $alertsCount\n\n'
          '🔥 *Top Consistência (Streaks):*\n$topLines\n\n'
          '🚨 *Radar de Retenção (>4 dias sem treino):*\n$riskLines\n\n'
          '📲 Gerencie e dispare check-ins em 1 toque no painel:\nhttps://shaipados-labs.web.app';

      if (mounted) {
        setState(() {
          _inactiveStudents = inactiveList;
          _weeklyDigest = {
            'total_students': activeTotal,
            'active_this_week': activeThisWeek,
            'weekly_workouts_completed': weeklyWorkouts,
            'retention_rate': retentionRate,
            'inactive_count': inactiveList.length,
            'pending_alerts_count': alertsCount,
            'top_streaks': topStreaks,
            'trainer_phone': trainerPhone,
            'digest_message': digestMsg,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStudentPulse() async {
    setState(() => _isLoadingPulse = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      final trainerId = session?.user.id ?? 'current-trainer';
      final List<Map<String, dynamic>> merged = [];
      final seenKeys = <String>{};

      void addEventIfNew(Map<String, dynamic> ev) {
        final id = (ev['id'] ?? '').toString();
        final meta = (ev['metadata'] as Map?) ?? {};
        final logId = (meta['log_id'] ?? '').toString();
        final alertId = (meta['alert_id'] ?? '').toString();
        final sessionId = (meta['session_id'] ?? '').toString();
        if (id.isNotEmpty && seenKeys.contains(id)) return;
        if (logId.isNotEmpty && seenKeys.contains(logId)) return;
        if (alertId.isNotEmpty && seenKeys.contains(alertId)) return;
        if (sessionId.isNotEmpty && seenKeys.contains(sessionId)) return;
        if (id.isNotEmpty) seenKeys.add(id);
        if (logId.isNotEmpty) seenKeys.add(logId);
        if (alertId.isNotEmpty) seenKeys.add(alertId);
        if (sessionId.isNotEmpty) seenKeys.add(sessionId);
        merged.add(ev);
      }

      // 1. Tenta carregar do backend via API REST
      if (token != null) {
        try {
          final uri = Uri.parse('${AppConfig.apiBaseUrl}/pulse/trainer/$trainerId');
          final res = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 6));

          if (res.statusCode == 200) {
            final list = jsonDecode(res.body) as List<dynamic>;
            for (final e in list) {
              addEventIfNew(Map<String, dynamic>.from(e as Map));
            }

            final sumUri = Uri.parse('${AppConfig.apiBaseUrl}/pulse/trainer/$trainerId/summary');
            final sumRes = await http.get(
              sumUri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            ).timeout(const Duration(seconds: 4));
            if (sumRes.statusCode == 200 && mounted) {
              _pulseSummary = jsonDecode(sumRes.body) as Map<String, dynamic>;
            }
          }
        } catch (_) {}
      }

      // 2. Consolida diretamente do Supabase (student_pulse_events + trainer_whatsapp_logs + adaptation_logs)
      // garantindo que 100% das interações do Robô, IA e Usuários apareçam ao vivo
      try {
        final client = Supabase.instance.client;
        final pulseRows = await client
            .from('student_pulse_events')
            .select('*')
            .order('created_at', ascending: false)
            .limit(40);
        for (final raw in (pulseRows as List)) {
          addEventIfNew(Map<String, dynamic>.from(raw as Map));
        }
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        final wRows = await client
            .from('trainer_whatsapp_logs')
            .select('*')
            .order('created_at', ascending: false)
            .limit(40);
        for (final raw in (wRows as List)) {
          final w = Map<String, dynamic>.from(raw as Map);
          final wId = (w['id'] ?? '').toString();
          final costType = (w['cost_type'] ?? 'free').toString();
          final sName = (w['student_name'] ?? 'Aluno').toString();
          final msgIn = (w['message_in'] ?? '').toString().trim();
          final msgOut = (w['message_out'] ?? '')
              .toString()
              .replaceAll('*', '')
              .replaceAll('\n', ' ')
              .trim();
          final shortOut = msgOut.length > 130 ? '${msgOut.substring(0, 127)}...' : msgOut;
          final isAlert = costType == 'alert';
          addEventIfNew({
            'id': wId,
            'student_id': w['student_id'] ?? trainerId,
            'student_name': sName,
            'trainer_id': w['trainer_id'] ?? trainerId,
            'event_type': isAlert ? 'pain_alert' : 'ai_doubt',
            'severity': isAlert ? 'critical' : 'info',
            'title': isAlert
                ? '🚨 Alerta no WhatsApp: $msgIn'
                : (costType == 'ai_gemini'
                    ? '🧠 Consultoria IA ($sName)'
                    : '🤖 Robô WhatsApp ($sName)'),
            'description': 'Interação: "$msgIn" • Resposta: $shortOut',
            'metadata': {
              'student_name': sName,
              'student_phone': w['student_phone'] ?? '',
              'channel': w['channel'] ?? 'whatsapp',
              'cost_type': costType,
              'tokens_used': w['tokens_used'] ?? 0,
              'log_id': wId,
            },
            'viewed_by_trainer': !isAlert,
            'action_taken': 'auto_replied',
            'created_at': w['created_at'],
          });
        }
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        final aRows = await client
            .from('adaptation_logs')
            .select('*')
            .order('created_at', ascending: false)
            .limit(25);
        for (final raw in (aRows as List)) {
          final a = Map<String, dynamic>.from(raw as Map);
          final aId = (a['id'] ?? '').toString();
          final details = (a['adaptation_details'] as Map?) ?? {};
          final painLoc = details['pain_location']?.toString();
          final reason = (a['reason'] ?? '').toString();
          final isPain = (painLoc != null && painLoc.isNotEmpty) || reason.toLowerCase().contains('dor');
          final sName = (details['student_name'] ?? 'Aluno').toString();
          final origEx = (a['original_exercise'] ?? 'Exercício').toString();
          final adapEx = (a['adapted_exercise'] ?? 'Substituto').toString();
          addEventIfNew({
            'id': aId,
            'student_id': a['client_id'] ?? trainerId,
            'student_name': sName,
            'trainer_id': a['trainer_id'] ?? trainerId,
            'event_type': isPain ? 'pain_alert' : 'exercise_adapted',
            'severity': isPain ? 'critical' : 'warning',
            'title': isPain ? 'Alerta de Dor: ${painLoc ?? origEx}' : 'Adaptação: $origEx',
            'description': '$sName trocou "$origEx" por "$adapEx". Motivo: $reason',
            'metadata': {
              'student_name': sName,
              'original_exercise': origEx,
              'adapted_exercise': adapEx,
              'pain_location': painLoc,
              'alert_id': aId,
            },
            'viewed_by_trainer': a['viewed_by_trainer'] == true,
            'created_at': a['created_at'],
          });
        }
      } catch (_) {}

      merged.sort((a, b) {
        final ca = (a['created_at'] ?? '').toString();
        final cb = (b['created_at'] ?? '').toString();
        return cb.compareTo(ca);
      });

      if (mounted) {
        setState(() {
          _pulseEvents = merged;
        });
      }
    } catch (e) {
      debugPrint('Aviso ao carregar student_pulse: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPulse = false);
    }
  }

  Future<void> _markPulseEventViewed(String eventId, {String? actionTaken}) async {
    setState(() {
      final index = _pulseEvents.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        _pulseEvents[index]['viewed_by_trainer'] = true;
        if (actionTaken != null) {
          _pulseEvents[index]['action_taken'] = actionTaken;
        }
      }
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;
      if (token != null) {
        await http.patch(
          Uri.parse('${AppConfig.apiBaseUrl}/pulse/events/$eventId/view'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'action_taken': actionTaken}),
        ).timeout(const Duration(seconds: 5));
        return;
      }
      await Supabase.instance.client
          .from('student_pulse_events')
          .update({'viewed_by_trainer': true, if (actionTaken != null) 'action_taken': actionTaken})
          .eq('id', eventId);
    } catch (_) {}
  }

  Future<void> _contactStudentFromPulse(Map<String, dynamic> event) async {
    final meta = (event['metadata'] as Map?) ?? {};
    final studentName = (event['student_name'] ?? meta['student_name'] ?? 'Aluno').toString();
    final firstName = studentName.split(' ').first;
    final eventType = event['event_type'] ?? 'info';
    final eventTitle = event['title'] ?? '';
    final studentId = event['student_id']?.toString();
    final phone = (meta['student_phone'] ?? meta['phone'])?.toString();

    String message;
    if (eventType == 'pain_alert') {
      message = 'Olá $firstName! Vi aqui no alerta do Mr. Coach que você sentiu um desconforto/dor em: "$eventTitle". Como você está se sentindo agora? Vamos ajustar seu treino!';
    } else if (eventType == 'workout_completed') {
      message = 'Parabéns pelo treino concluído hoje, $firstName! Vi a finalização aqui no Mr. Coach. Mantenha a constância! 🔥';
    } else if (eventType == 'exercise_adapted') {
      message = 'Olá $firstName! Vi que você fez uma adaptação de exercício hoje no app. Precisando de qualquer ajuste na ficha, conte comigo!';
    } else {
      message = 'Olá $firstName! Sou seu treinador no Mr. Coach. Vi sua interação recente com nosso assistente e estou à disposição para qualquer dúvida biomecânica!';
    }

    await WhatsAppDirectService.sendOneClick(
      context: context,
      message: message,
      phone: phone,
      studentId: studentId,
      studentName: studentName,
      category: 'pulse_$eventType',
    );
    await _markPulseEventViewed(
      event['id']?.toString() ?? '',
      actionTaken: 'whatsapp_contacted_1click',
    );
    await _fetchTelemetry();
  }

  String _formatPulseTime(String? dateStr) {
    if (dateStr == null) return 'Agora';
    final parsed = DateTime.tryParse(dateStr)?.toLocal();
    if (parsed == null) return 'Hoje';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 2) return 'Agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _triggerProactiveCheckin({
    List<String>? studentIds,
    Map<String, dynamic>? singleStudentFallback,
    bool force = false,
  }) async {
    setState(() {
      if (singleStudentFallback != null) {
        _dispatchingStudentId = singleStudentFallback['id']?.toString();
      } else {
        _isDispatchingBatch = true;
      }
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/proactive-checkin'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'student_ids': studentIds,
          'force': force,
          'min_inactive_days': 4,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final sentCount = (data['sent_count'] as int?) ?? 0;
        final skippedCount = (data['skipped_48h_count'] as int?) ?? 0;
        final results = (data['results'] as List?) ?? [];

        // Se for individual e o Evolution API não estiver conectado (fallback_wa), abre wa.me direto
        if (singleStudentFallback != null && sentCount == 0 && results.isNotEmpty) {
          final firstRes = Map<String, dynamic>.from(results.first as Map);
          if (firstRes['status'] == 'fallback_wa') {
            await _openWaFallbackForStudent(
              singleStudentFallback,
              customText: firstRes['message_text']?.toString(),
            );
            await _fetchProactiveRadar();
            return;
          }
        }

        if (mounted) {
          String msg;
          if (sentCount > 0) {
            msg = '✅ $sentCount check-in(s) proativo(s) enviado(s) pelo Robô WhatsApp!';
            if (skippedCount > 0) {
              msg += ' ($skippedCount ignorado(s) pela trava anti-spam de 48h).';
            }
          } else if (skippedCount > 0) {
            msg = '🛡️ $skippedCount aluno(s) já receberam contato nas últimas 48h (trava anti-spam ativa).';
          } else if (singleStudentFallback != null) {
            await _openWaFallbackForStudent(singleStudentFallback);
            await _fetchProactiveRadar();
            return;
          } else {
            msg = 'WhatsApp desconectado para envio em lote. Use o botão individual para abrir no WhatsApp ou conecte o robô.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: sentCount > 0 ? MetaColors.emerald : Colors.amber.shade800,
            ),
          );
        }
        await _fetchProactiveRadar();
        return;
      }
    } catch (_) {}

    // Fallback direto via wa.me se for disparo individual
    if (singleStudentFallback != null) {
      await _openWaFallbackForStudent(singleStudentFallback);
      await _fetchProactiveRadar();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conecte o Robô WhatsApp para disparo em lote ou clique no botão de cada aluno.'),
          backgroundColor: Colors.amber,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isDispatchingBatch = false;
        _dispatchingStudentId = null;
      });
    }
  }

  Future<void> _openWaFallbackForStudent(
    Map<String, dynamic> student, {
    String? customText,
  }) async {
    final sid = (student['id'] ?? '').toString();
    final fullName = (student['full_name'] ?? 'Aluno').toString();
    final firstName = fullName.split(' ').first;
    final daysOff = student['days_inactive'] ?? 4;
    final rawPhone = (student['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final phone = (rawPhone.length == 10 || rawPhone.length == 11) ? '55$rawPhone' : rawPhone;

    final text = customText ??
        '👋 *Fala, $firstName! Tudo bem com você?*\n\n'
            'Vi aqui no Mr. Coach que já faz *$daysOff dias* desde o seu último check-in de treino.\n\n'
            'Aconteceu algum imprevisto na rotina ou sentiu algum desconforto? '
            'Se precisar adaptar o treino de hoje para fazer mais rápido, me avisa aqui!\n\n'
            '📲 Seu treino está pronto em: https://shaipados-labs.web.app 💪';

    try {
      if (sid.isNotEmpty) {
        await Supabase.instance.client
            .from('profiles')
            .update({'last_contacted_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', sid);
      }
    } catch (_) {}

    if (phone.isNotEmpty) {
      final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aluno sem telefone cadastrado. Mensagem para $firstName copiada!'),
            backgroundColor: MetaColors.emerald,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isDispatchingBatch = false;
        _dispatchingStudentId = null;
      });
    }
  }

  Future<void> _sendWeeklyDigestToMyWhatsApp() async {
    setState(() => _isSendingDigest = true);
    final digestMsg = (_weeklyDigest?['digest_message'] ?? '').toString();
    final rawTrainerPhone = (_weeklyDigest?['trainer_phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
    final trainerPhone = (rawTrainerPhone.length == 10 || rawTrainerPhone.length == 11)
        ? '55$rawTrainerPhone'
        : rawTrainerPhone;

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/send-weekly-digest'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'trainer_phone': trainerPhone}),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final sentViaEvo = data['sent_via_evolution'] == true;
        final serverMsg = (data['digest_message'] ?? digestMsg).toString();

        if (sentViaEvo && mounted) {
          setState(() => _isSendingDigest = false);
          AppToast.success(
            context,
            'Resumo Executivo Semanal enviado para o seu WhatsApp via Robô!',
            title: 'Resumo Enviado',
            icon: Icons.mark_chat_read_rounded,
          );
          return;
        }

        if (trainerPhone.isNotEmpty && serverMsg.isNotEmpty) {
          final uri = Uri.parse('https://wa.me/$trainerPhone?text=${Uri.encodeComponent(serverMsg)}');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) setState(() => _isSendingDigest = false);
          return;
        }
      }
    } catch (_) {}

    if (digestMsg.isNotEmpty) {
      if (trainerPhone.isNotEmpty) {
        final uri = Uri.parse('https://wa.me/$trainerPhone?text=${Uri.encodeComponent(digestMsg)}');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: digestMsg));
        if (mounted) {
          AppToast.success(
            context,
            'Resumo Executivo Semanal copiado para a área de transferência!',
            title: 'Copiado',
            icon: Icons.copy_rounded,
          );
        }
      }
    }

    if (mounted) setState(() => _isSendingDigest = false);
  }

  bool get _hasAiActive {
    if (_subscription == null) return false;
    final pid = _subscription!.planId.toLowerCase();
    final name = _subscription!.planName.toLowerCase();
    if (pid == 'starter' || name.contains('starter')) return false;
    return pid.contains('pro') ||
        pid.contains('elite') ||
        pid.contains('studio') ||
        name.contains('pro') ||
        name.contains('elite') ||
        name.contains('studio');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: MetaColors.text(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultor Ativo IA 2.0',
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: MetaColors.text(context), size: 22),
            tooltip: 'Atualizar Diagnóstico',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MetaColors.emerald),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: MetaColors.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Hero Card One UI 7
                    _buildHeroHeader(context),
                    const SizedBox(height: 14),

                    // 2. Status Interativo do WhatsApp (Click-to-Manage)
                    _buildConnectionStatusBar(context),
                    const SizedBox(height: 18),

                    // 2.1 Live Student Pulse 3.0 (Barramento ao Vivo de Alunos)
                    _buildLiveStudentPulseSection(context),
                    const SizedBox(height: 18),

                    // 2.2 Ações Rápidas Executivas de 1 Toque (Fase 2 - Bloco 2.3)
                    _buildExecutiveOneTouchActions(context),
                    const SizedBox(height: 18),

                    // 2.3 Resumo Executivo Semanal do Professor (Fase 7)
                    _buildWeeklyDigestCard(context),
                    const SizedBox(height: 18),

                    // 2.2 Radar de Retenção Proativa (>4 dias sem treinar) (Fase 7)
                    _buildProactiveRetentionRadarCard(context),
                    const SizedBox(height: 18),

                    // 3. Triagem de Custo Zero (Comandos Alinhados 1 a 5)
                    _buildZeroCostSection(context),
                    const SizedBox(height: 18),

                    // 4. Motor Biomecânico Gemini 2.5 Flash
                    _buildAiEngineSection(context),
                    const SizedBox(height: 18),

                    // 4.1 Simulador Interativo do Robô no WhatsApp
                    _buildSimulatorSection(context),
                    const SizedBox(height: 18),

                    // 5. Telemetria Modular em Cards
                    _buildTelemetryCard(context),
                    const SizedBox(height: 24),

                    // 6. Ações Principais
                    SquircleButton(
                      label: _isWhatsAppConnected ? 'Gerenciar Conexão do WhatsApp' : 'Conectar WhatsApp Agora',
                      icon: Icons.chat_rounded,
                      isPrimary: true,
                      height: 52,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WhatsappConnectionScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 10),
                    SquircleButton(
                      label: 'Ver Planos & Upgrades (Elite / Pro)',
                      icon: Icons.workspace_premium_outlined,
                      isPrimary: false,
                      height: 50,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final planName = _subscription?.planName ?? 'Plano Starter';
    final hasAi = _hasAiActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasAi ? MetaColors.emerald.withValues(alpha: 0.35) : MetaColors.cardBorder(context),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAi
                        ? [const Color(0xFF10B981), const Color(0xFF0EA5E9)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Robô WhatsApp 24h',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasAi
                                ? MetaColors.emerald.withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasAi
                                  ? MetaColors.emerald.withValues(alpha: 0.4)
                                  : Colors.amber.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasAi ? Icons.verified_rounded : Icons.shield_outlined,
                                size: 12,
                                color: hasAi ? MetaColors.emerald : Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                planName,
                                style: TextStyle(
                                  color: hasAi ? MetaColors.emerald : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasAi
                                ? MetaColors.accentBlue.withValues(alpha: 0.15)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasAi ? 'IA 24h Liberada' : 'Triagem Gratuita',
                            style: TextStyle(
                              color: hasAi ? MetaColors.accentBlue : MetaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasAi
                ? 'Seus alunos contam com atendimento contínuo para tirar dúvidas de postura, cadência e substituição de aparelhos direto pelo seu WhatsApp.'
                : 'O seu plano Starter inclui todas as automações de custo zero (envio de fichas e streak). Para liberar o consultor biomecânico inteligente 24h, faça upgrade para os planos Pro, Elite Coach ou Studio.',
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBar(BuildContext context) {
    final connected = _isWhatsAppConnected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WhatsappConnectionScreen(),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: connected
                ? MetaColors.emerald.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected
                  ? MetaColors.emerald.withValues(alpha: 0.4)
                  : AppColors.warning.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: connected ? MetaColors.emerald : AppColors.warning,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (connected ? MetaColors.emerald : AppColors.warning).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'WhatsApp Conectado e Operacional' : 'WhatsApp Desconectado',
                      style: TextStyle(
                        color: connected ? MetaColors.emerald : AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      connected ? 'Toque para gerenciar ou disparar teste' : 'Toque para parear seu QR Code / Código',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: connected ? MetaColors.emerald : AppColors.warning,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStudentPulseSection(BuildContext context) {
    final painAlerts = _pulseEvents.where((e) => e['event_type'] == 'pain_alert').toList();
    final workouts = _pulseEvents.where((e) => e['event_type'] == 'workout_completed').toList();
    final adaptations = _pulseEvents.where((e) => e['event_type'] == 'exercise_adapted').toList();
    final doubts = _pulseEvents.where((e) => e['event_type'] == 'ai_doubt').toList();

    final unreadPainCount = painAlerts.where((e) => e['viewed_by_trainer'] != true).length;
    final hasUrgent = unreadPainCount > 0;

    final painCount = _pulseSummary?['pain_alerts_count'] ?? painAlerts.length;
    final workoutCount = _pulseSummary?['workouts_completed_today'] ?? workouts.length;
    final robotAiCount = doubts.length > (_telemetry?['total_interactions'] ?? 0)
        ? doubts.length
        : (_telemetry?['total_interactions'] ?? doubts.length);

    List<Map<String, dynamic>> filteredEvents;
    if (_selectedPulseFilter == 'pain_alert') {
      filteredEvents = painAlerts;
    } else if (_selectedPulseFilter == 'workout_completed') {
      filteredEvents = workouts;
    } else if (_selectedPulseFilter == 'exercise_adapted') {
      filteredEvents = adaptations;
    } else if (_selectedPulseFilter == 'ai_doubt') {
      filteredEvents = doubts;
    } else {
      filteredEvents = _pulseEvents;
    }

    final isDark = MetaColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasUrgent
              ? Colors.redAccent.withValues(alpha: 0.6)
              : MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com indicador Live
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasUrgent ? Colors.redAccent : MetaColors.emerald).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  color: hasUrgent ? Colors.redAccent : MetaColors.emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Live Student Pulse 3.0',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasUrgent ? Colors.redAccent : MetaColors.emerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (hasUrgent ? Colors.redAccent : MetaColors.emerald).withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Alertas clínicos, treinos, trocas e interações do Robô & IA',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingPulse)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MetaColors.emerald,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasUrgent ? Colors.redAccent : MetaColors.emerald).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: hasUrgent ? Colors.redAccent : MetaColors.emerald,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      hasUrgent ? '$unreadPainCount URGENTE' : 'AO VIVO',
                      style: TextStyle(
                        color: hasUrgent ? Colors.redAccent : MetaColors.emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini KPI Dashboard
          Row(
            children: [
              Expanded(
                child: _buildPulseKpiBox(
                  context,
                  label: 'Alertas Dor',
                  value: '$painCount',
                  color: painCount > 0 ? Colors.redAccent : MetaColors.emerald,
                  icon: Icons.healing_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPulseKpiBox(
                  context,
                  label: 'Treinos Hoje',
                  value: '$workoutCount',
                  color: MetaColors.emerald,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPulseKpiBox(
                  context,
                  label: 'Adaptações',
                  value: '${adaptations.length}',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.swap_horiz_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPulseKpiBox(
                  context,
                  label: 'Robô & IA',
                  value: '$robotAiCount',
                  color: const Color(0xFF6366F1),
                  icon: Icons.smart_toy_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chips de Filtro Horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPulseFilterChip('todos', 'Todos (${_pulseEvents.length})'),
                const SizedBox(width: 6),
                _buildPulseFilterChip('pain_alert', '🚨 Dor (${painAlerts.length})'),
                const SizedBox(width: 6),
                _buildPulseFilterChip('workout_completed', '✅ Treinos (${workouts.length})'),
                const SizedBox(width: 6),
                _buildPulseFilterChip('exercise_adapted', '🔄 Trocas (${adaptations.length})'),
                const SizedBox(width: 6),
                _buildPulseFilterChip('ai_doubt', '🤖 Robô & IA (${doubts.length})'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lista de Eventos ou Estado Vazio
          if (filteredEvents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: MetaColors.cardBorder(context).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.done_all_rounded,
                    size: 36,
                    color: MetaColors.emerald.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Salão de treino sem ocorrências',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Conforme seus alunos treinarem, relatarem dores ou tirarem dúvidas com a IA, o feed ao vivo atualizará aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: filteredEvents.take(6).map((event) => _buildPulseEventCard(context, event)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPulseKpiBox(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.cardBorder(context).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPulseFilterChip(String filterKey, String label) {
    final isSelected = _selectedPulseFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedPulseFilter = filterKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.emerald : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : MetaColors.text(context),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPulseEventCard(BuildContext context, Map<String, dynamic> event) {
    final eventType = event['event_type'] ?? 'info';
    final severity = event['severity'] ?? 'info';
    final isUrgent = eventType == 'pain_alert' || severity == 'critical';
    final isViewed = event['viewed_by_trainer'] == true;
    final meta = (event['metadata'] as Map?) ?? {};
    final studentName = event['student_name'] ?? meta['student_name'] ?? 'Aluno';
    final timeStr = _formatPulseTime(event['created_at']);

    Color cardBorder;
    Color iconColor;
    IconData icon;
    String badgeLabel;

    if (eventType == 'pain_alert') {
      cardBorder = Colors.redAccent;
      iconColor = Colors.redAccent;
      icon = Icons.health_and_safety_rounded;
      badgeLabel = '🚨 Alerta Clínico';
    } else if (eventType == 'workout_completed') {
      cardBorder = MetaColors.emerald;
      iconColor = MetaColors.emerald;
      icon = Icons.check_circle_rounded;
      badgeLabel = '✅ Treino Concluído';
    } else if (eventType == 'exercise_adapted') {
      cardBorder = const Color(0xFFF59E0B);
      iconColor = const Color(0xFFF59E0B);
      icon = Icons.swap_horiz_rounded;
      badgeLabel = '🔄 Aparelho Ocupado';
    } else if (eventType == 'ai_doubt') {
      final isAiGemini = meta['cost_type'] == 'ai_gemini';
      cardBorder = isAiGemini ? const Color(0xFF6366F1) : MetaColors.emerald;
      iconColor = isAiGemini ? const Color(0xFF6366F1) : MetaColors.emerald;
      icon = isAiGemini ? Icons.psychology_rounded : Icons.smart_toy_rounded;
      badgeLabel = isAiGemini ? '🧠 Consultoria IA' : '🤖 Robô WhatsApp';
    } else {
      cardBorder = MetaColors.cardBorder(context);
      iconColor = MetaColors.subtext(context);
      icon = Icons.notifications_active_rounded;
      badgeLabel = 'ℹ️ Notificação';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUrgent
            ? Colors.redAccent.withValues(alpha: 0.05)
            : MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? Colors.redAccent.withValues(alpha: 0.35)
              : cardBorder.withValues(alpha: 0.25),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      studentName,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timeStr,
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            event['title'] ?? '',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((event['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              event['description'] ?? '',
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () => _contactStudentFromPulse(event),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_rounded, size: 12, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'WhatsApp',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isViewed)
                InkWell(
                  onTap: () => _markPulseEventViewed(event['id']?.toString() ?? '', actionTaken: 'trainer_acknowledged'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MetaColors.cardBorder(context),
                      ),
                    ),
                    child: Text(
                      'Marcar Ciente',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded, size: 13, color: MetaColors.emerald),
                    const SizedBox(width: 3),
                    Text(
                      'Ciente',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveOneTouchActions(BuildContext context) {
    final topStreaks = (_weeklyDigest?['top_streaks'] as List?) ?? [];
    final inactiveCount = _inactiveStudents.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Color(0xFF818CF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ações Rápidas Executivas',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Automações táticas para retenção e engajamento da carteira',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1 Toque',
                  style: TextStyle(
                    color: Color(0xFF818CF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Cobrar Check-in
          _buildOneTouchActionTile(
            context,
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Cobrar Check-in em Lote',
            subtitle: inactiveCount > 0
                ? '$inactiveCount alunos ausentes há +4 dias'
                : 'Todos os alunos estão em dia com a frequência',
            badgeText: inactiveCount > 0 ? '$inactiveCount Ausentes' : 'Em Dia',
            badgeColor: inactiveCount > 0 ? const Color(0xFFF59E0B) : MetaColors.emerald,
            buttonLabel: _isDispatchingBatch ? 'Disparando...' : 'Cobrar Todos',
            onTap: inactiveCount > 0 && !_isDispatchingBatch
                ? () => _triggerProactiveCheckin(force: true)
                : null,
          ),
          const SizedBox(height: 10),

          // 2. Elogiar Ofensiva
          _buildOneTouchActionTile(
            context,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Elogiar Campeões de Ofensiva',
            subtitle: topStreaks.isNotEmpty
                ? '${topStreaks.length} alunos com consistência máxima esta semana'
                : 'Nenhum aluno em streak ativa no momento',
            badgeText: topStreaks.isNotEmpty ? 'Top Streaks' : 'Sem Dados',
            badgeColor: topStreaks.isNotEmpty ? const Color(0xFFEF4444) : MetaColors.subtext(context),
            buttonLabel: 'Elogiar no WhatsApp',
            onTap: topStreaks.isNotEmpty
                ? () => _openCongratulateStreaksSheet(context, topStreaks)
                : null,
          ),
          const SizedBox(height: 10),

          // 3. Gerar Ficha com IA
          _buildOneTouchActionTile(
            context,
            icon: Icons.auto_awesome_rounded,
            iconColor: MetaColors.emerald,
            title: 'Gerar Nova Ficha com IA',
            subtitle: 'Periodização biomecânica hipertrófica via Gemini em 30 segundos',
            badgeText: 'IA Gemini',
            badgeColor: MetaColors.emerald,
            buttonLabel: 'Abrir Gerador',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrainerAnamnesisScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOneTouchActionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required String buttonLabel,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetaColors.cardBorder(context).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: enabled ? iconColor : MetaColors.subtext(context).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                buttonLabel,
                style: TextStyle(
                  color: enabled ? Colors.black : MetaColors.subtext(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCongratulateStreaksSheet(BuildContext context, List<dynamic> topStreaks) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: MetaColors.bg(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: MetaColors.cardBorder(ctx)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.subtext(ctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elogiar Campeões de Consistência',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Envie um incentivo personalizado no WhatsApp em 1 toque',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...topStreaks.map((s) {
                final student = Map<String, dynamic>.from(s as Map);
                final sname = student['full_name'] ?? 'Aluno';
                final firstName = sname.toString().split(' ').first;
                final streak = student['streak_days'] ?? 0;
                final phone = (student['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(ctx),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetaColors.cardBorder(ctx).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 14, color: Color(0xFFEF4444)),
                            const SizedBox(width: 2),
                            Text(
                              '$streak d',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sname,
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final msg = 'Fala $firstName! Passando para parabenizar sua dedicação impecável: você está com $streak dias seguidos de treino firme no Mr. Coach! 🔥 Orgulho demais da sua consistência, bora manter o foco!';
                          await WhatsAppDirectService.sendOneClick(
                            context: context,
                            message: msg,
                            phone: phone,
                            studentId: student['id']?.toString(),
                            studentName: sname.toString(),
                            category: 'congratulate_streak',
                          );
                          await Future.wait([
                            _fetchTelemetry(),
                            _fetchStudentPulse(),
                          ]);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 13, color: Colors.black),
                              SizedBox(width: 3),
                              Text(
                                'Elogiar 1-Clique',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (topStreaks.length > 1) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.electric_bolt_rounded, size: 18),
                    label: Text(
                      'Elogiar Todos os ${topStreaks.length} Campeões em 1 Clique',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      for (final s in topStreaks) {
                        final st = Map<String, dynamic>.from(s as Map);
                        final sname = (st['full_name'] ?? 'Aluno').toString();
                        final firstName = sname.split(' ').first;
                        final streak = st['streak_days'] ?? 0;
                        final phone = (st['phone'] ?? '').toString();
                        final msg = 'Fala $firstName! Passando para parabenizar sua dedicação impecável: você está com $streak dias seguidos de treino firme no Mr. Coach! 🔥 Orgulho demais da sua consistência, bora manter o foco!';
                        await WhatsAppDirectService.sendOneClick(
                          context: context,
                          message: msg,
                          phone: phone,
                          studentId: st['id']?.toString(),
                          studentName: sname,
                          category: 'congratulate_streak_batch',
                          showFeedback: false,
                          allowExternalFallback: false,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: MetaColors.emerald,
                            content: Text(
                              '🎉 Parabéns enviados com 1 clique para ${topStreaks.length} alunos no WhatsApp!',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                            ),
                          ),
                        );
                      }
                      await Future.wait([
                        _fetchTelemetry(),
                        _fetchStudentPulse(),
                      ]);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyDigestCard(BuildContext context) {
    final digest = _weeklyDigest ?? {};
    final totalStudents = digest['total_students'] ?? 0;
    final weeklyWorkouts = digest['weekly_workouts_completed'] ?? 0;
    final retentionRate = digest['retention_rate'] ?? 100;
    final pendingAlerts = digest['pending_alerts_count'] ?? 0;
    final topStreaks = (digest['top_streaks'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assessment_rounded, color: MetaColors.emerald, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo Executivo Semanal',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Performance da consultoria, streaks e alertas da semana',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Coach 2.0',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Alunos',
                    value: '$totalStudents',
                    color: MetaColors.emerald,
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Treinos',
                    value: '$weeklyWorkouts',
                    color: MetaColors.emerald,
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Presença',
                    value: '$retentionRate%',
                    color: retentionRate >= 75 ? MetaColors.emerald : (retentionRate > 0 ? Colors.amber : MetaColors.subtext(context)),
                    icon: Icons.verified_user_outlined,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Alertas',
                    value: '$pendingAlerts',
                    color: pendingAlerts > 0 ? Colors.redAccent : MetaColors.emerald,
                    icon: Icons.healing_outlined,
                  ),
                ),
              ],
            ),
          ),
          if (topStreaks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '🏆 Destaques de Consistência na Semana:',
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topStreaks.map((raw) {
                final item = Map<String, dynamic>.from(raw as Map);
                final name = (item['full_name'] ?? 'Aluno').toString().split(' ').first;
                final st = item['streak_days'] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '🔥 $name ($st dias)',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSendingDigest ? null : _sendWeeklyDigestToMyWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isSendingDigest
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSendingDigest
                    ? 'Enviando Resumo...'
                    : 'Enviar Resumo Executivo para o Meu WhatsApp',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProactiveRetentionRadarCard(BuildContext context) {
    final count = _inactiveStudents.length;
    final eligibleCount = _inactiveStudents.where((s) => s['recently_contacted_48h'] != true).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: count > 0
              ? Colors.amber.withValues(alpha: 0.45)
              : MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (count > 0 ? Colors.amber : MetaColors.emerald).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  count > 0 ? Icons.radar_rounded : Icons.verified_rounded,
                  color: count > 0 ? Colors.amber : MetaColors.emerald,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Radar de Retenção Proativa (>4 dias)',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Resgate automático de alunos ausentes com trava anti-spam 48h',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (count > 0 ? Colors.amber : MetaColors.emerald).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count > 0 ? '$count Ausente(s)' : '100% Em Dia',
                  style: TextStyle(
                    color: count > 0 ? Colors.amber : MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (count == 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, color: MetaColors.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Excelente! Nenhum aluno ativo está há mais de 4 dias sem registrar treino.',
                      style: TextStyle(color: MetaColors.text(context), fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ..._inactiveStudents.take(5).map((student) {
              final sid = (student['id'] ?? '').toString();
              final name = (student['full_name'] ?? 'Aluno').toString();
              final daysOff = student['days_inactive'] ?? 4;
              final locked48h = student['recently_contacted_48h'] == true;
              final isBusy = _dispatchingStudentId == sid;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: locked48h
                          ? MetaColors.emerald.withValues(alpha: 0.35)
                          : Colors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: (locked48h ? MetaColors.emerald : Colors.amber).withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: TextStyle(
                            color: locked48h ? MetaColors.emerald : Colors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '$daysOff dias sem treinar',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (locked48h ? MetaColors.emerald : Colors.redAccent).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    locked48h ? '✓ Contatado <48h' : 'Pendente',
                                    style: TextStyle(
                                      color: locked48h ? MetaColors.emerald : Colors.redAccent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () => _triggerProactiveCheckin(
                                  studentIds: [sid],
                                  singleStudentFallback: student,
                                  force: true,
                                ),
                        style: TextButton.styleFrom(
                          backgroundColor: MetaColors.emerald.withValues(alpha: 0.15),
                          foregroundColor: MetaColors.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: isBusy
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(color: MetaColors.emerald, strokeWidth: 2),
                              )
                            : const Icon(Icons.chat_rounded, size: 14),
                        label: Text(
                          locked48h ? 'Reenviar' : 'Check-in',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDispatchingBatch
                    ? null
                    : () => _triggerProactiveCheckin(force: eligibleCount == 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isDispatchingBatch
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded, size: 19),
                label: Text(
                  _isDispatchingBatch
                      ? 'Disparando Check-ins...'
                      : (eligibleCount > 0
                          ? 'Disparar Check-in em Lote via Robô ($eligibleCount pendente${eligibleCount > 1 ? 's' : ''})'
                          : 'Reenviar Check-in em Lote para Todos ($count)'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZeroCostSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: MetaColors.emerald, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Triagem de Custo Zero',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Respostas instantâneas sem gastar tokens de IA',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '0 Tokens',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Comandos rápidos disponíveis para todos os seus alunos em qualquer plano:',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _buildCommandCard(
            context,
            badge: '1',
            commandLabel: '1 ou treino',
            title: 'Ficha de Treino Ativa',
            description: 'Envia o resumo da ficha completa com exercícios, séries e descanso.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '2',
            commandLabel: '2 ou streak',
            title: 'Ofensiva & Consistência',
            description: 'Informa os dias seguidos de treino do aluno (Streak 🔥).',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '3',
            commandLabel: '3 ou app',
            title: 'Acesso Direto ao App',
            description: 'Envia o link direto seguro para o aluno acessar a plataforma.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '4',
            commandLabel: '4 ou recado:',
            title: 'Recado / Alerta ao Personal',
            description: 'Registra um recado ou observação do aluno direto nos alertas do seu painel.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '5',
            commandLabel: '5 ou biohub',
            title: 'Meu Bio-Hub (Peso, IMC e Meta)',
            description: 'Retorna o último peso, altura, cálculo de IMC, BF% e objetivo do aluno.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '0',
            commandLabel: 'oi, ola ou menu',
            title: 'Menu de Opções Imediato',
            description: 'Recepciona o aluno e exibe as 5 opções de atendimento automático.',
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(
    BuildContext context, {
    required String badge,
    required String commandLabel,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Numérico de Largura Fixa para Alinhamento Perfeito
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                badge,
                style: const TextStyle(
                  color: MetaColors.emerald,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: MetaColors.card(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        commandLabel,
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiEngineSection(BuildContext context) {
    final hasAi = _hasAiActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasAi ? const Color(0xFF6366F1).withValues(alpha: 0.4) : MetaColors.cardBorder(context),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motor Biomecânico Gemini',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Text(
                      'IA 24h para dúvidas técnicas de exercícios',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Quando o aluno envia perguntas abertas (ex: "como posicionar os pés no leg press?", "posso trocar o crucifixo pelo voador?"), o Gemini 2.5 Flash responde no tom do seu método:',
            style: TextStyle(color: MetaColors.subtext(context), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          _buildBulletItem(context, 'Baseado estritamente na ficha prescrita por você.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Guardrails médicos: nunca medica e orienta procurar você em caso de dor.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Cota de segurança: até 15 dúvidas diárias por aluno para evitar abusos.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Liberado para: Personal Pro, Elite Coach e Studio.'),
        ],
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: MetaColors.text(context), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulador do Robô no WhatsApp',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Teste as respostas em tempo real como se fosse seu aluno',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Testes rápidos de 1 toque:',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickTestChip(context, '📋 1 - Treino', '1'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '🔥 2 - Streak', '2'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '🧬 5 - Bio-Hub', '5'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '📝 4 - Recado', 'recado: Hoje finalizei o treino A em 45min!'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '💡 Substituir Peito', 'Posso trocar supino por peck deck?'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '⚠️ Alerta de Dor', 'Estou sentindo muita dor no joelho'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _simulatorController,
                  style: TextStyle(color: MetaColors.text(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Digite uma mensagem de teste...',
                    hintStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 12.5),
                    filled: true,
                    fillColor: MetaColors.highlight(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.border.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.border.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
                    ),
                  ),
                  onSubmitted: _runSimulation,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: MetaColors.emerald,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSimulating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isSimulating
                      ? null
                      : () => _runSimulation(_simulatorController.text),
                ),
              ),
            ],
          ),
          if (_simulationResult != null) ...[
            const SizedBox(height: 14),
            _buildSimulationBubble(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickTestChip(BuildContext context, String label, String query) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      backgroundColor: MetaColors.highlight(context),
      side: BorderSide(color: MetaColors.border.withValues(alpha: 0.6)),
      onPressed: _isSimulating ? null : () => _runSimulation(query),
    );
  }

  Widget _buildSimulationBubble(BuildContext context) {
    final reply = _simulationResult?['reply'] ?? '';
    final cost = _simulationResult?['cost_type'] ?? 'free';
    final tokens = _simulationResult?['tokens_used'] ?? 0;
    final isAlert = _simulationResult?['is_alert'] == true;
    final isFree = cost == 'free';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? Colors.amber.withValues(alpha: 0.6)
              : (isFree ? MetaColors.emerald.withValues(alpha: 0.4) : const Color(0xFF6366F1).withValues(alpha: 0.4)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, size: 14, color: Color(0xFF25D366)),
                  const SizedBox(width: 6),
                  const Text(
                    'Resposta do Robô no WhatsApp:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isAlert
                      ? Colors.amber.withValues(alpha: 0.2)
                      : (isFree ? MetaColors.emerald.withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAlert
                      ? '⚠️ Alerta de Dor'
                      : (isFree ? '⚡ Custo Zero (0 tokens)' : '🧠 IA Gemini ($tokens tokens)'),
                  style: TextStyle(
                    color: isAlert
                        ? Colors.amber
                        : (isFree ? MetaColors.emerald : const Color(0xFF818CF8)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            reply,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(BuildContext context) {
    final total = _telemetry?['total_interactions'] ?? 0;
    final students = _telemetry?['unique_students'] ?? 0;
    final hours = _telemetry?['hours_saved'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, color: MetaColors.emerald, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Impacto do Robô no Mês',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Tempo Poupado',
                  value: '${hours}h',
                  color: MetaColors.emerald,
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Alunos Atendidos',
                  value: '$students',
                  color: const Color(0xFF6366F1),
                  icon: Icons.people_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Mensagens',
                  value: '$total',
                  color: Colors.amber,
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetaColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
