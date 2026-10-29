import '../../core/widgets/connect_trainer_sheet.dart';
import '../../core/widgets/explorer_trial_banner.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/thematic_editorial_card.dart';
import '../../core/widgets/thematic_watermarks.dart';
import '../../core/widgets/card_style_selection_sheet.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'student_profile_screen.dart';
import 'client_focus_workout_screen.dart';
import 'widgets/warmup_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/one_ui_glass_components.dart';
import '../../core/widgets/student_ux_components.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/exercise_media_sheet.dart';
import '../../core/widgets/broadcast_banner.dart';
import '../../core/widgets/offline_sync_banner.dart';
import '../../services/offline_sync_service.dart';
import '../../core/widgets/student_notification_sheet.dart';
import '../../core/widgets/student_trigger_banner.dart';
import '../../services/student_notification_service.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/workout_guide_modal.dart';
import '../../services/exercise_media_service.dart';
import '../../models/exercise_model.dart';
import '../../models/split_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  bool get _isDark => ThemeController.instance.isEffectiveDark(context);
  Color get _bg => MetaColors.bg(context);
  Color get _cardBg => MetaColors.card(context);
  Color get _border => MetaColors.cardBorder(context);
  Color get _textPrimary => MetaColors.text(context);
  Color get _textSecondary => MetaColors.subtext(context);
  Color get _highlight => MetaColors.highlight(context);

  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _workoutTitle = '•';
  String _workoutLocation = 'Academia completa e espaço de musculação';
  bool _hasTrainerLinked = true;
  String _trainerName = 'Carregando treinador...';
  String? _trainerPhone;
  String _trainerCref = 'CREF Ativo';
  String? _trainerPhotoUrl;
  final Set<int> _adaptedIndices = {};
  final Set<int> _completedExerciseIndices = {};
  final Map<int, int> _partialSetsByExercise = {};
  final WorkoutSessionService _sessionService = WorkoutSessionService();
  bool _isLoadingWorkout = true;
  DateTime? _startedAt;
  String? _splitIdentifier;
  String? _splitName;
  List<SplitModel> _splits = [];
  int _selectedSplitIndex = 0;
  Timer? _ticker;
  RealtimeChannel? _workoutRealtimeChannel;

  // Variáveis reais de Gamificação (Backend)
  int? currentStreak;

  // Exercícios da ficha ativa real do aluno (vazio = sem ficha)
  late List<ExerciseModel> _exercises;
  final bool _showExpandedExerciseCards = false;

  // Cache de miniaturas de alta resolução (Padrão Hevy / Strong)
  final Map<String, String?> _exerciseThumbnails = {};

  @override
  void initState() {
    super.initState();
    _exercises = [];
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _startedAt != null) setState(() {});
    });
    _loadActiveWorkout();
    _initRealtimeWorkoutListener();
    StudentNotificationService.instance.refreshNotifications();
    OfflineSyncService.instance.initAutoSync();
  }

  @override
  void dispose() {
    _workoutRealtimeChannel?.unsubscribe();
    _ticker?.cancel();
    OfflineSyncService.instance.dispose();
    super.dispose();
  }


  void _initRealtimeWorkoutListener() {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    try {
      _workoutRealtimeChannel = Supabase.instance.client
          .channel('public:workouts:client:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'workouts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'client_id',
              value: uid,
            ),
            callback: (payload) {
              if (!mounted) return;
              debugPrint('[Realtime] Atualização de treino recebida para $uid: ${payload.eventType}');
              final isWorkoutInProgress = _completedExerciseIndices.isNotEmpty;
              if (!isWorkoutInProgress) {
                _loadActiveWorkout();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: MetaColors.emerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isWorkoutInProgress
                              ? 'Nova versão da ficha disponível! Conclua seu treino ou recarregue.'
                              : 'Sua ficha de treino foi atualizada pelo seu treinador!',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          _loadActiveWorkout();
                        },
                        child: const Text(
                          'Recarregar',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: _highlight,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: MetaColors.emerald.withValues(alpha: 0.3),
                    ),
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[Realtime] Erro ao subscrever canal de treinos: $e');
    }
  }

  String _getTrainerInitials() {
    final clean =
        _trainerName
            .replaceAll('Prof.', '•')
            .replaceAll('Carregando...', '•')
            .trim();
    if (clean.isEmpty) return 'PT';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _getAnatomicalImage(String exerciseName, String targetMuscle) {
    final name = exerciseName.toLowerCase();
    final muscle = targetMuscle.toLowerCase();

    if (name.contains('supino') ||
        name.contains('peito') ||
        name.contains('crucifixo') ||
        muscle.contains('peitor')) {
      return 'assets/images/biomech_3d_chest.jpg';
    } else if (name.contains('desenvolvimento') ||
        name.contains('elevacao') ||
        name.contains('elevação') ||
        name.contains('ombro') ||
        muscle.contains('deltoid')) {
      return 'assets/images/biomech_3d_shoulders.jpg';
    } else if (name.contains('triceps') ||
        name.contains('tríceps') ||
        name.contains('biceps') ||
        name.contains('bíceps') ||
        name.contains('rosca') ||
        muscle.contains('braco') ||
        muscle.contains('braquial')) {
      return 'assets/images/biomech_3d_arms.jpg';
    } else if (name.contains('agachamento') ||
        name.contains('leg') ||
        name.contains('extensora') ||
        name.contains('quadr') ||
        muscle.contains('perna') ||
        muscle.contains('glúteo') ||
        muscle.contains('gluteo')) {
      return 'assets/images/biomech_3d_legs.jpg';
    } else if (name.contains('puxada') ||
        name.contains('remada') ||
        name.contains('dorsal') ||
        muscle.contains('costas') ||
        muscle.contains('lat')) {
      return 'assets/images/biomech_3d_back.jpg';
    }
    return 'assets/images/biomech_3d_chest.jpg';
  }

  String _getEmgForExercise(String exerciseName) {
    final lower = exerciseName.toLowerCase();
    if (lower.contains('triceps') || lower.contains('tríceps')) {
      return '96% EMG';
    }
    if (lower.contains('elevacao') ||
        lower.contains('elevação') ||
        lower.contains('agachamento')) {
      return '95% EMG';
    }
    if (lower.contains('supino')) return '94% EMG';
    if (lower.contains('puxada')) return '93% EMG';
    return '92% EMG';
  }

  Future<void> _loadActiveWorkout() async {
    if (mounted) setState(() => _isLoadingWorkout = true);
    final uid = AuthService.currentUser?.id;
    if (uid != null) {
      try {
        await _sessionService.flushPending(uid);
      } catch (_) {}
    }
    final activePlan = await WorkoutService.getActiveWorkoutForClient();
    if (!mounted) return;
    setState(() {
      if (activePlan != null && activePlan.splits.isNotEmpty) {
        _splits = List.of(activePlan.splits);
        _selectedSplitIndex = 0;
        final firstSplit = _splits[_selectedSplitIndex];
        _splitIdentifier = firstSplit.splitIdentifier;
        _splitName = firstSplit.splitName;
        _workoutTitle =
            'Treino ${firstSplit.splitIdentifier}: ${firstSplit.splitName}';
        _exercises = List.from(firstSplit.exercises);
        _completedExerciseIndices.clear();
        _partialSetsByExercise.clear();
        _adaptedIndices.clear();
        _startedAt ??= DateTime.now();
      } else {
        _splits = [];
        _selectedSplitIndex = 0;
        _exercises = [];
        _workoutTitle = '•';
        _completedExerciseIndices.clear();
        _partialSetsByExercise.clear();
        _adaptedIndices.clear();
        _startedAt = null;
      }
      _isLoadingWorkout = false;
    });

    await _restoreSavedDraftForCurrentSplit();

    final workoutLocation = await WorkoutService.getClientWorkoutLocation();
    if (mounted && workoutLocation != null) {
      setState(() => _workoutLocation = workoutLocation);
    }

    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
          _hasTrainerLinked = true;
          final name =
              (trainer['trainer_name'] ?? trainer['full_name']) as String?;
          if (name != null && name.isNotEmpty) _trainerName = name;
          final phone = (trainer['phone'] ?? trainer['whatsapp']) as String?;
          if (phone != null && phone.isNotEmpty) _trainerPhone = phone;
          final photoUrl = trainer['trainer_photo_url'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            _trainerPhotoUrl = photoUrl;
          }
          final reg =
              (trainer['cref_or_registry'] ??
                      trainer['cref'] ??
                      trainer['professional_document'])
                  as String?;
          if (reg != null && reg.isNotEmpty) _trainerCref = reg;
        });
      } else if (mounted) {
        setState(() {
          _hasTrainerLinked = false;
          _trainerName = 'Seu Personal Trainer';
          _trainerCref = 'CREF Ativo';
        });
      }
    } catch (_) {
      if (mounted && _trainerName == 'Carregando treinador...') {
        setState(() {
          _trainerName = 'Seu Personal Trainer';
          _trainerCref = 'CREF Ativo';
        });
      }
    }

    try {
      final gami = await WorkoutService.getGamificationData();
      if (gami != null && mounted) {
        setState(() {
          currentStreak = (gami['current_streak'] as num?)?.toInt();
        });
      }
    } catch (_) {}

    _loadExerciseThumbnails();
  }

  Future<void> _restoreSavedDraftForCurrentSplit() async {
    try {
      final uid = AuthService.currentUser?.id ?? 'guest';
      final draft = await OfflineSyncService.instance.getWorkoutDraft(uid);
      final currentSplitId = _splitIdentifier ?? 'A';
      if (draft == null) return;

      Map<String, dynamic>? splitDraft;
      if (draft['splits'] is Map &&
          (draft['splits'] as Map)[currentSplitId] is Map) {
        splitDraft = Map<String, dynamic>.from(
          (draft['splits'] as Map)[currentSplitId] as Map,
        );
      } else if (draft['splitIdentifier'] == currentSplitId) {
        splitDraft = draft;
      }

      if (splitDraft == null || splitDraft['exerciseSets'] is! Map) {
        return;
      }

      final draftSets = splitDraft['exerciseSets'] as Map;
      final Set<int> restoredCompleted = {};
      final Map<int, int> restoredPartial = {};

      for (int i = 0; i < _exercises.length; i++) {
        final rawList = draftSets[i.toString()];
        if (rawList is List && rawList.isNotEmpty) {
          final totalSets = rawList.length;
          int doneCount = 0;
          for (final s in rawList) {
            if (s is Map && s['isCompleted'] == true) {
              doneCount++;
            }
          }
          if (doneCount >= totalSets && totalSets > 0) {
            restoredCompleted.add(i);
          } else if (doneCount > 0) {
            restoredPartial[i] = doneCount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _completedExerciseIndices
            ..clear()
            ..addAll(restoredCompleted);
          _partialSetsByExercise
            ..clear()
            ..addAll(restoredPartial);
        });
      }
    } catch (_) {}
  }

  Future<void> _syncManualExerciseToggleToDraft(
    int exerciseIndex,
    bool completed,
  ) async {
    try {
      final uid = AuthService.currentUser?.id ?? 'guest';
      final currentSplitId = _splitIdentifier ?? 'A';
      final existingDraft =
          await OfflineSyncService.instance.getWorkoutDraft(uid) ??
              <String, dynamic>{};
      final splitsMap = existingDraft['splits'] is Map
          ? Map<String, dynamic>.from(existingDraft['splits'] as Map)
          : <String, dynamic>{};

      Map<String, dynamic> splitData = {};
      if (splitsMap[currentSplitId] is Map) {
        splitData = Map<String, dynamic>.from(splitsMap[currentSplitId] as Map);
      } else if (existingDraft['splitIdentifier'] == currentSplitId) {
        splitData = Map<String, dynamic>.from(existingDraft);
      }

      final draftSets = splitData['exerciseSets'] is Map
          ? Map<String, dynamic>.from(splitData['exerciseSets'] as Map)
          : <String, dynamic>{};

      for (int i = 0; i < _exercises.length; i++) {
        final ex = _exercises[i];
        final setsCount = ex.sets > 0 ? ex.sets : 3;
        final isExDone = i == exerciseIndex
            ? completed
            : _completedExerciseIndices.contains(i);

        if (i == exerciseIndex || !draftSets.containsKey(i.toString())) {
          final existingList = draftSets[i.toString()];
          if (existingList is List && existingList.isNotEmpty) {
            draftSets[i.toString()] = existingList.map((item) {
              if (item is Map) {
                return {
                  'weightKg': item['weightKg'] ?? 20.0,
                  'reps': item['reps'] ?? 10,
                  'isCompleted': i == exerciseIndex
                      ? completed
                      : (item['isCompleted'] == true),
                };
              }
              return {
                'weightKg': 20.0,
                'reps': 10,
                'isCompleted': isExDone,
              };
            }).toList();
          } else {
            draftSets[i.toString()] = List.generate(
              setsCount,
              (_) => {
                'weightKg': 20.0,
                'reps': 10,
                'isCompleted': isExDone,
              },
            );
          }
        }
      }

      final updatedSplitData = {
        'splitIdentifier': currentSplitId,
        'splitName': _splitName ?? 'Treino do Dia',
        'startedAt': (_startedAt ?? DateTime.now()).toIso8601String(),
        'currentPage': exerciseIndex,
        'exerciseSets': draftSets,
      };

      splitsMap[currentSplitId] = updatedSplitData;

      await OfflineSyncService.instance.saveWorkoutDraft(uid, {
        ...updatedSplitData,
        'splits': splitsMap,
      });
    } catch (_) {}
  }

  void _loadExerciseThumbnails() {
    for (final ex in _exercises) {
      if (!_exerciseThumbnails.containsKey(ex.name)) {
        ExerciseMediaService.getMediaFor(ex.name).then((media) {
          if (mounted && media != null && media.inAppMediaUrl != null) {
            setState(() {
              _exerciseThumbnails[ex.name] = media.inAppMediaUrl;
            });
          }
        });
      }
    }
  }

  void _selectSplit(int index) {
    if (index < 0 || index >= _splits.length || index == _selectedSplitIndex) {
      return;
    }
    final split = _splits[index];
    setState(() {
      _selectedSplitIndex = index;
      _splitIdentifier = split.splitIdentifier;
      _splitName = split.splitName;
      _workoutTitle = 'Treino ${split.splitIdentifier}: ${split.splitName}';
      _exercises = List.from(split.exercises);
      _completedExerciseIndices.clear();
      _partialSetsByExercise.clear();
      _adaptedIndices.clear();
      _startedAt = DateTime.now();
    });
    _restoreSavedDraftForCurrentSplit();
    _loadExerciseThumbnails();
  }

  void _startFocusMode({int? initialIndex}) {
    if (_exercises.isEmpty) return;
    int targetIndex = initialIndex ?? 0;
    if (initialIndex == null) {
      // Prioriza exercício com séries parciais em andamento ou o primeiro não concluído
      int? firstPartial;
      for (int i = 0; i < _exercises.length; i++) {
        if (_partialSetsByExercise.containsKey(i)) {
          firstPartial = i;
          break;
        }
      }
      if (firstPartial != null) {
        targetIndex = firstPartial;
      } else {
        for (int i = 0; i < _exercises.length; i++) {
          if (!_completedExerciseIndices.contains(i)) {
            targetIndex = i;
            break;
          }
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientFocusWorkoutScreen(
          workoutTitle: _workoutTitle,
          splitIdentifier: _splitIdentifier ?? 'A',
          splitName: _splitName ?? 'Treino do Dia',
          exercises: _exercises,
          trainerName: _trainerName,
          trainerPhone: _trainerPhone,
          workoutLocation: _workoutLocation,
          currentStreak: currentStreak,
          initialExerciseIndex: targetIndex,
          initialCompletedIndices: Set<int>.from(_completedExerciseIndices),
        ),
      ),
    ).then((result) async {
      if (!mounted) return;
      if (result == true) {
        setState(() {
          _completedExerciseIndices.clear();
          _partialSetsByExercise.clear();
        });
        _loadActiveWorkout();
        _initRealtimeWorkoutListener();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Treino finalizado e registrado com sucesso!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (result == 'discarded') {
        setState(() {
          _completedExerciseIndices.clear();
          _partialSetsByExercise.clear();
        });
      } else if (result is Set<int>) {
        await _restoreSavedDraftForCurrentSplit();
        if (!mounted) return;
        setState(() {
          _completedExerciseIndices.addAll(result);
          for (final idx in result) {
            _partialSetsByExercise.remove(idx);
          }
        });
        final int doneExCount = _completedExerciseIndices.length;
        final int partialSetsCount = _partialSetsByExercise.values.fold(
          0,
          (sum, val) => sum + val,
        );
        String msg = 'Progresso salvo!';
        if (doneExCount > 0 && partialSetsCount > 0) {
          msg =
              'Progresso salvo ($doneExCount exercício(s) completo(s) + $partialSetsCount série(s) parcial(is))!';
        } else if (doneExCount > 0) {
          msg = 'Progresso salvo ($doneExCount exercício(s) concluído(s))!';
        } else if (partialSetsCount > 0) {
          msg = 'Progresso salvo ($partialSetsCount série(s) realizada(s))!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _highlight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: MetaColors.emerald.withValues(alpha: 0.3),
              ),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.bookmark_added_rounded,
                  color: MetaColors.emerald,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        await _restoreSavedDraftForCurrentSplit();
      }
    });
  }

  Future<void> _contactTrainerWhatsApp() async {
    final rawPhone = _trainerPhone;
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seu treinador ($_trainerName) ainda não cadastrou o WhatsApp profissional.',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final digits = rawPhone.replaceAll(RegExp(r'\D'), '•');
    final phone = digits.startsWith('55')
        ? digits
        : (digits.length >= 10 && digits.length <= 11 ? '55$digits' : digits);
    final msg = Uri.encodeComponent(
      'Olá professor(a) $_trainerName! Sou aluno no Mr. Coach e gostaria de tirar uma dúvida sobre meu treino.',
    );
    final uri = Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$msg');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Erro ao abrir WhatsApp do treinador: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Não foi possível abrir o WhatsApp automaticamente.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAdaptationModal(int exerciseIndex) {
    final currentExercise = _exercises[exerciseIndex];

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: _border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Substituir: ${currentExercise.name}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'O Mr. Coach AI encontrará uma variação biomecanicamente equivalente e notificará seu professor:',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_outline, size: 20),
                  label: const Text(
                    'Aparelho Ocupado / Fila na Academia',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: MetaColors.accentBlue,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeAdaptation(
                      exerciseIndex,
                      'Aparelho Ocupado / Fila',
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  label: const Text(
                    'Desconforto ou Dor Articular',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    backgroundColor:
                        const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showPainLocationSelector(exerciseIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPainLocationSelector(int exerciseIndex) {
    final currentExercise = _exercises[exerciseIndex];
    final locations = [
      {'name': 'Dor no Ombro / Manguito', 'loc': 'Ombro Anterior'},
      {'name': 'Dor no Joelho / Patela', 'loc': 'Joelho / Patela'},
      {'name': 'Desconforto na Coluna / Lombar', 'loc': 'Coluna Lombar'},
      {'name': 'Dor no Cotovelo / Punho', 'loc': 'Cotovelo'},
      {'name': 'Outro Desconforto Articular', 'loc': 'Articulação Geral'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: _border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Qual articulação apresenta desconforto?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exercício: ${currentExercise.name}',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
                ...locations.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        alignment: Alignment.centerLeft,
                        side: BorderSide(color: _border),
                        backgroundColor: _highlight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeAdaptation(
                          exerciseIndex,
                          'Desconforto ou Dor Articular',
                          painLocation: item['loc'],
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radio_button_checked,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item['name']!,
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeAdaptation(
    int index,
    String reason, {
    String? painLocation,
  }) async {
    setState(() => _isLoading = true);
    final target = _exercises[index];
    final restrictionsDesc =
        painLocation != null
            ? 'Relato de $painLocation. Eliminar compressão e estresse nesta articulação mantendo o estímulo muscular.'
            : 'Aparelho indisponível no espaço de treino presencial.';

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: _workoutLocation,
        injuriesOrRestrictions: restrictionsDesc,
      );
      if (!mounted) return;

      setState(() {
        _adaptedIndices.add(index);
        _exercises[index] = target.copyWith(
          name: result.adaptedExercise,
          sets: result.sets,
          reps: result.reps,
          restSeconds: result.restSeconds,
          notes:
              '${result.notes}\n[Mr. Coach AI: ${result.biomechanicalRationale}]',
        );
      });

      // Dispara persistência e alerta em tempo real para o professor
      await WorkoutService.logAdaptation(
        originalExercise: target.name,
        adaptedExercise: result.adaptedExercise,
        reason: reason,
        painLocation: painLocation,
        details: result.toJson(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Text(
              'Substituído: ${result.adaptedExercise}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Erro ao adaptar exercício: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: const Text(
              'Não foi possível adaptar este exercício. Tente novamente.',
            ),
            action: kDebugMode
                ? SnackBarAction(
                    label: 'Mudar IP',
                    textColor: Colors.yellow,
                    onPressed: () => ServerConfigDialog.show(context),
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _elapsedLabel() {
    final s = _startedAt;
    if (s == null) return '--';
    return '${DateTime.now().difference(s).inMinutes} min';
  }


  // ---------------------------------------------------------------------------
  // Cabeçalho Edge-to-Edge unificado (Título + Notificações + Coach + Menu ⋮)
  // ---------------------------------------------------------------------------
  void _openCoachSheet() {
    final subtitle = _trainerCref.isNotEmpty ? _trainerCref : 'CREF Ativo';
    OneUiGlassSheet.show(
      context,
      header: Row(
        children: [
          _buildCoachAvatar(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trainerName,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: MetaColors.emerald),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 12,
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
      actions: [
        GlassAction(
          icon: Icons.chat_bubble_rounded,
          label: 'Falar no WhatsApp (24h)',
          subtitle: 'Tire dúvidas direto com o seu treinador',
          onTap: _contactTrainerWhatsApp,
        ),
      ],
    );
  }

  void _openMoreMenu() {
    final dark = ThemeController.instance.isEffectiveDark(context);
    OneUiGlassSheet.show(
      context,
      actions: [
        GlassAction(
          icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: dark ? 'Modo Claro' : 'Modo Escuro',
          subtitle: 'Alterna o tema de todo o aplicativo',
          color: const Color(0xFF8B5CF6),
          onTap: () => ThemeController.instance.toggleTheme(context),
        ),
        GlassAction(
          icon: Icons.view_carousel_rounded,
          label: 'Estilo dos Cards',
          subtitle: ThemeController.instance.cardThemeMode.label,
          color: const Color(0xFF0EA5E9),
          onTap: () => CardStyleSelectionSheet.show(context),
        ),
        GlassAction(
          icon: Icons.fitness_center_rounded,
          label: 'Como treinar',
          subtitle: 'Guia de execução, cargas e trocas',
          color: const Color(0xFFF59E0B),
          onTap: () => WorkoutGuideModal.show(context),
        ),
        GlassAction(
          icon: Icons.explore_rounded,
          label: 'Tour do Aluno',
          subtitle: 'Apresentação rápida das funções',
          onTap: () => InteractiveTourGuideModal.show(context, role: 'student'),
        ),
        GlassAction(
          icon: Icons.person_outline_rounded,
          label: 'Meu Perfil & Anamnese',
          color: const Color(0xFF38BDF8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
          ),
        ),
        if (kDebugMode)
          GlassAction(
            icon: Icons.settings_ethernet_rounded,
            label: 'Configurar IP do Servidor (Dev)',
            color: Colors.grey,
            onTap: () => ServerConfigDialog.show(context),
          ),
      ],
    );
  }

  Widget _buildCoachAvatar({double size = 40}) {
    final hasPhoto = _trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [MetaColors.emerald, MetaColors.accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: hasPhoto
                ? DecorationImage(
                    image: _trainerPhotoUrl!.startsWith('assets/')
                        ? AssetImage(_trainerPhotoUrl!) as ImageProvider
                        : NetworkImage(_trainerPhotoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasPhoto
              ? null
              : Center(
                  child: Text(
                    _getTrainerInitials(),
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.34,
                    ),
                  ),
                ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              color: MetaColors.emerald,
              shape: BoxShape.circle,
              border: Border.all(color: MetaColors.bg(context), width: 2),
            ),
            child: Icon(Icons.check_rounded,
                color: Colors.black, size: size * 0.24),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentHeader() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _openCoachSheet,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meu Treino',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'com $_trainerName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        size: 13, color: MetaColors.emerald),
                  ],
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: StudentNotificationService.unreadCountNotifier,
          builder: (context, unread, _) => GlassIconButton(
            icon: unread > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            tooltip: 'Notificações',
            showDot: unread > 0,
            onTap: () => StudentNotificationSheet.show(
              context,
              onOpenWorkout: () {
                if (_exercises.isNotEmpty) _startFocusMode();
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _openCoachSheet,
          child: _buildCoachAvatar(size: 40),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: 'Mais opções',
          onTap: _openMoreMenu,
        ),
      ],
    );
  }

  // Bento de telemetria: Ofensiva + Progresso da Sessão
  Widget _buildTelemetryBento() {
    final done = _completedExerciseIndices.length;
    final total = _exercises.length;
    final ratio = total == 0 ? 0.0 : done / total;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 118,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'OFENSIVA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('\u{1F525}', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        currentStreak == null ? '\u2014' : '$currentStreak',
                        semanticsLabel: currentStreak == null
                            ? 'Sequência indisponível'
                            : '$currentStreak dias',
                        style: TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('dias',
                            style: TextStyle(fontSize: 11, color: _textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PROGRESSO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _textSecondary,
                        ),
                      ),
                      Text(
                        '${(ratio * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: MetaColors.emeraldText(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$done',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: _textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' / $total exerc\u00EDcios',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: _highlight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          MetaColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWorkoutScaffold(double topPadding) {
    final isDark = _isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Padding(
          padding: EdgeInsets.fromLTRB(24, topPadding + 14, 24, 24),
          child: _isLoadingWorkout
              ? const Center(
                  child: ShaipadosLoaderContainer(
                    type: ShaipadosLoaderType.activityRings,
                    isOverlay: false,
                    customTitle: 'Calibrando Treino Ativo',
                    loadingMessages: [
                      'Sincronizando séries, cargas e descanso...',
                      'Carregando histórico de progressão e RPE...',
                      'Ajustando metas do Bio-Hub em tempo real...',
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          Icons.person_outline_rounded,
                          color: _textSecondary,
                        ),
                        tooltip: 'Meu Perfil & Anamnese',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentProfileScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const Spacer(),
                    if (!_hasTrainerLinked) ...[
                      ExplorerTrialBanner(
                        onLinked: _loadActiveWorkout,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 56,
                      color: _textSecondary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nenhuma ficha ativa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      !_hasTrainerLinked
                          ? 'Você está no modo degustação. Conecte-se a um Personal Trainer na Vitrine para prescrever seus treinos.'
                          : 'Quando seu professor liberar sua ficha, ela aparece aqui. '
                            'Enquanto isso, aguarde o contato dele para conversar sobre a consultoria. '
                            'Se você está sem conexão, conecte-se e atualize.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_hasTrainerLinked) ...[
                      SquircleButton(
                        label: 'Conectar Personal Trainer',
                        icon: Icons.handshake_rounded,
                        isPrimary: true,
                        onPressed: () => ConnectTrainerSheet.show(
                          context,
                          onLinked: _loadActiveWorkout,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SquircleButton(
                      label: 'Atualizar',
                      icon: Icons.refresh_rounded,
                      isPrimary: _hasTrainerLinked,
                      onPressed: _loadActiveWorkout,
                    ),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _finishWorkout() async {
    final completedCount = _completedExerciseIndices.length;
    final totalCount = _exercises.length;
    final uid = AuthService.currentUser?.id;
    final completedAt = DateTime.now();
    final record = uid == null
        ? null
        : WorkoutSessionRecord(
            id: WorkoutSessionRecord.newId(),
            clientId: uid,
            splitIdentifier: _splitIdentifier,
            splitName: _splitName,
            totalExercises: totalCount,
            completedExercises: completedCount,
            startedAt: _startedAt ?? completedAt,
            completedAt: completedAt,
          );
    final minutes = (record?.durationSeconds ?? 0) ~/ 60;

    // Calcula volume estimado com base nas cargas salvas
    double totalVolume = 0;
    int totalSets = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final idx in _completedExerciseIndices) {
        if (idx < _exercises.length) {
          final ex = _exercises[idx];
          final setsCount = ex.sets;
          final repsCount =
              int.tryParse(ex.reps.replaceAll(RegExp(r'\D'), '')) ?? 10;
          totalSets += setsCount;
          final weightKey =
              'pwa_last_weight_${uid}_${ex.name.toLowerCase().trim()}';
          final lastWeight = prefs.getDouble(weightKey) ?? 20.0;
          totalVolume += setsCount * repsCount * lastWeight;
          if (uid != null && lastWeight > 0) {
            WorkoutService.recordExerciseLoad(
              exerciseName: ex.name,
              loadKg: lastWeight,
            ).catchError((_) => false);
          }
        }
      }
    } catch (_) {}

    if (record != null) {
      try {
        await _sessionService.complete(record);
      } catch (e) {
        debugPrint('[ActiveWorkout] Erro ao salvar sessão: $e');
      }
    }

    try {
      await OfflineSyncService.instance.clearWorkoutDraft(uid ?? 'guest');
    } catch (_) {}

    if (!mounted) return;

    await WorkoutTriumphModal.show(
      context,
      workoutTitle:
          _workoutTitle.isNotEmpty ? _workoutTitle : 'Treino Concluído',
      trainerName: _trainerName,
      trainerPhone: _trainerPhone,
      trainerCref: _trainerCref,
      trainerUsername: _trainerName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_'),
      durationMin: minutes,
      totalVolumeKg: totalVolume,
      completedSets: totalSets > 0 ? totalSets : completedCount,
      totalSets: totalSets > 0 ? totalSets : totalCount,
      currentStreak: currentStreak,
      newPrCount: 0,
      onDismiss: () {
        if (mounted) {
          setState(() {
            _completedExerciseIndices.clear();
            _partialSetsByExercise.clear();
            _startedAt = DateTime.now();
          });
          StudentNotificationService.instance.refreshNotifications();
        }
      },
    );
  }

  Widget _buildFallbackExerciseIcon(int index, String targetMuscle) {
    return Container(
      color: _highlight,
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactExerciseCard(int index) {
    final item = _exercises[index];
    final isAdapted = _adaptedIndices.contains(index);
    final isCompleted = _completedExerciseIndices.contains(index);
    final int partialSets = _partialSetsByExercise[index] ?? 0;
    final bool isPartial = !isCompleted && partialSets > 0;
    final setsCount = item.sets > 0 ? item.sets : 3;
    final thumbUrl = _exerciseThumbnails[item.name];

    return MetaCard(
      backgroundColor: _cardBg,
      borderColor: isCompleted
          ? MetaColors.emerald.withValues(alpha: 0.6)
          : (isPartial
              ? const Color(0xFFF59E0B).withValues(alpha: 0.65)
              : (isAdapted ? const Color(0xFFF59E0B) : _border)),
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () {
        HapticFeedback.lightImpact();
        _startFocusMode(initialIndex: index);
      },
      child: Row(
        children: [
          // 1. Miniatura Visual Interativa (Toque abre o vídeo em tela cheia)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ExerciseMediaSheet.show(context, exerciseName: item.name);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _highlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted
                      ? MetaColors.emerald.withValues(alpha: 0.4)
                      : (isPartial
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : _border),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbUrl != null && thumbUrl.isNotEmpty)
                      Image.network(
                        thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackExerciseIcon(index, item.targetMuscleGroup),
                      )
                    else
                      _buildFallbackExerciseIcon(index, item.targetMuscleGroup),
                    Container(
                      color: Colors.black.withValues(alpha: 0.22),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. Informações Cinesiológicas (Nome, Séries x Reps, Descanso)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isCompleted
                              ? _textSecondary
                              : _textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdapted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Adaptado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.targetMuscleGroup.isNotEmpty ? item.targetMuscleGroup : 'Geral',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('•', style: TextStyle(color: _textSecondary, fontSize: 11)),
                    const SizedBox(width: 5),
                    Text(
                      isCompleted
                          ? '✓ $setsCount/$setsCount séries \u2022 ${item.reps}'
                          : (isPartial
                              ? '$partialSets/$setsCount séries feitas \u2022 ${item.reps}'
                              : '$setsCount séries \u2022 ${item.reps}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPartial ? const Color(0xFFF59E0B) : MetaColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('•', style: TextStyle(color: _textSecondary, fontSize: 11)),
                    const SizedBox(width: 5),
                    Text(
                      '${item.restSeconds}s',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. Ação Rápida de Conclusão / Ir Treinar
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              if (isPartial) {
                _startFocusMode(initialIndex: index);
                return;
              }
              final nextCompleted = !isCompleted;
              setState(() {
                if (isCompleted) {
                  _completedExerciseIndices.remove(index);
                } else {
                  _completedExerciseIndices.add(index);
                  _partialSetsByExercise.remove(index);
                }
              });
              _syncManualExerciseToggleToDraft(index, nextCompleted);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? MetaColors.emerald
                    : (isPartial
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                        : _highlight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted
                      ? MetaColors.emerald
                      : (isPartial
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                          : _border),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : (isPartial
                            ? Icons.timelapse_rounded
                            : Icons.play_arrow_rounded),
                    size: 16,
                    color: isCompleted
                        ? Colors.black
                        : (isPartial ? const Color(0xFFF59E0B) : MetaColors.emerald),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted
                        ? 'Feito'
                        : (isPartial ? 'Continuar ($partialSets/$setsCount)' : 'Treinar'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isCompleted
                          ? Colors.black
                          : (isPartial ? const Color(0xFFF59E0B) : MetaColors.emerald),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int index) {
    final item = _exercises[index];
    final isAdapted = _adaptedIndices.contains(index);
    final isCompleted = _completedExerciseIndices.contains(index);

    return MetaCard(
      backgroundColor: _cardBg,
      borderColor:
          isCompleted
              ? MetaColors.emerald
              : (isAdapted ? const Color(0xFFF59E0B) : _border),
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Ordem, EMG pill & Checkbox gigante de conclusão
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _highlight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      'EXERCÍCIO ${index + 1} DE ${_exercises.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: MetaColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: MetaColors.accentBlue.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _getEmgForExercise(item.name),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: MetaColors.accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
              // Botão circular de marcar exercício concluído
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isCompleted) {
                      _completedExerciseIndices.remove(index);
                    } else {
                      _completedExerciseIndices.add(index);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isCompleted
                            ? MetaColors.emerald
                            : _highlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isCompleted ? MetaColors.emerald : _border,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color:
                            isCompleted ? Colors.black : _textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCompleted ? 'Feito' : 'Concluir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color:
                              isCompleted
                                  ? Colors.black
                                  : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Nome do Exercício (Texto Grande e Alto Contraste)
          Text(
            item.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.targetMuscleGroup,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textSecondary,
            ),
          ),

          if (isAdapted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF59E0B)),
                  SizedBox(width: 6),
                  Text(
                    'ADAPTADO POR MR. COACH AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 3. Miniatura / Preview Biomecânico 3D interativo
          GestureDetector(
            onTap:
                () => BiomechanicalAnalysisSheet.show(
                  context,
                  exerciseName: item.name,
                ),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 1.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _getAnatomicalImage(item.name, item.targetMuscleGroup),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (ctx, _, _) => _AnatomicalMuscleCard(
                            exerciseName: item.name,
                            targetMuscle: item.targetMuscleGroup,
                          ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.view_in_ar_rounded,
                              size: 13,
                              color: MetaColors.accentBlue,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '3D Biomecânica & EMG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: MetaColors.accentBlue.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MetaColors.accentBlue.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Toque p/ Raio-X',
                              style: TextStyle(
                                color: MetaColors.accentBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: MetaColors.accentBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Botões de Ação Visual (Vídeo Demonstrativo + Raio-X 3D)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => ExerciseMediaSheet.show(context, exerciseName: item.name),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 16,
                          color: MetaColors.emerald,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Vídeo Execução',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => BiomechanicalAnalysisSheet.show(
                  context,
                  exerciseName: item.name,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _highlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.view_in_ar_rounded, size: 16, color: MetaColors.accentBlue),
                      SizedBox(width: 6),
                      Text(
                        'Raio-X 3D',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Grade HUD de Telemetria (Séries, Reps, Cadência, Descanso)
          Row(
            children: [
              Expanded(
                child: _HudStatTile(label: 'Séries', value: '${item.sets}'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _HudStatTile(label: 'Reps', value: item.reps)),
              const SizedBox(width: 8),
              const Expanded(
                child: _HudStatTile(label: 'Cadência', value: '3-0-1-0'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudStatTile(
                  label: 'Descanso',
                  value: '${item.restSeconds}s',
                  icon: Icons.timer_outlined,
                  onTap:
                      () => RestTimerSheet.show(
                        context,
                        seconds: item.restSeconds,
                        exerciseName: item.name,
                      ),
                ),
              ),
            ],
          ),

          // 5. Dica de Execução (se houver)
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _highlight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 15,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.notes,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 6. Botão de Pânico (Aparelho Ocupado / Dor)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
              label: const Text(
                'Substituir • Aparelho Ocupado ou Dor',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF59E0B),
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                alignment: Alignment.center,
              ),
              onPressed: () => _showAdaptationModal(index),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    if (_isLoadingWorkout || _exercises.isEmpty) {
      return _buildNoWorkoutScaffold(topPadding);
    }

    final isDark = _isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            const AmbientGlowCanvas(),
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: topPadding + 14,
                bottom: bottomPadding + 140, // Espaço seguro para o OneUiFloatingNavBar nunca cobrir os cards
                left: 18,
                right: 18,
              ),
              children: [
                if (!_hasTrainerLinked)
                  ExplorerTrialBanner(
onLinked: _loadActiveWorkout,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                const BroadcastBanner(
                  audience: 'students',
                  padding: EdgeInsets.only(bottom: 12),
                ),
                const OfflineSyncBanner(
                  padding: EdgeInsets.only(bottom: 12),
                ),
                StudentTriggerBanner(
                  onOpenWorkout: () {
                    if (_exercises.isNotEmpty) {
                      _startFocusMode();
                    }
                  },
                  padding: const EdgeInsets.only(bottom: 12),
                ),
                // 1. Cabeçalho Edge-to-Edge unificado
                _buildStudentHeader(),
                const SizedBox(height: 16),

                // 2. Bento de telemetria translúcido
                _buildTelemetryBento(),
                const SizedBox(height: 16),

                // 3. Seletor de divisões em cápsula translúcida (One UI)
                if (_splits.length > 1) ...[
                  OneUiGlassSegmentedBar(
                    selectedIndex: _selectedSplitIndex,
                    onChanged: _selectSplit,
                    segments: [
                      for (int i = 0; i < _splits.length; i++)
                        GlassSegment(label: 'Split ${_splits[i].splitIdentifier}', badge: i == 0 ? 'Hoje' : null),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. CARD HERO: SEU TREINO DE HOJE (Padrão Ouro das Melhores Academias - One UI 7 Health)
                ThematicEditorialCard(
                  category: 'DIVISÃO ${(_splitIdentifier ?? 'A').toUpperCase()} • PROGRAMADO',
                  palette: ThematicCardPalette.biomechanicsCyan,
                  customWatermark: ThematicWatermarkType.biomechanics,
                  padding: const EdgeInsets.all(18),
                  trailingBadge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isDark ? Colors.white.withValues(alpha: 0.12) : _highlight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      _elapsedLabel(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _isDark ? Colors.white : _textSecondary,
                      ),
                    ),
                  ),
                  customContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _splitName ?? 'Treino de Hoje',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: _textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.fitness_center_rounded,
                                          size: 14,
                                          color: _textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_exercises.length} exercícios',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: _textSecondary,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: _textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '~${_exercises.length * 8} min',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '•',
                                      style: TextStyle(
                                        color: _textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${_completedExerciseIndices.length}/${_exercises.length} Feitos',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _completedExerciseIndices.isNotEmpty
                                            ? MetaColors.emerald
                                            : _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ProgressRing(
                            progress: _exercises.isEmpty
                                ? 0.0
                                : (_completedExerciseIndices.length /
                                    _exercises.length),
                            size: 52,
                            strokeWidth: 5,
                            color: MetaColors.emerald,
                            center: Text(
                              _exercises.isEmpty
                                  ? '0%'
                                  : '${((_completedExerciseIndices.length / _exercises.length) * 100).round()}%',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          WarmupSheet.show(
                            context,
                            initialFocus: _splitName ?? 'Geral',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Text(
                                'Aquecimento Articular Guiado (3 min)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SquircleButton(
                        label: (_completedExerciseIndices.isEmpty &&
                                _partialSetsByExercise.isEmpty)
                            ? 'Iniciar Treino de Hoje'
                            : (_completedExerciseIndices.length == _exercises.length
                                ? 'Finalizar Treino (${_completedExerciseIndices.length}/${_exercises.length})'
                                : 'Continuar Treino (${_completedExerciseIndices.length}/${_exercises.length})'),
                        icon: (_completedExerciseIndices.isEmpty &&
                                _partialSetsByExercise.isEmpty)
                            ? Icons.play_arrow_rounded
                            : (_completedExerciseIndices.length == _exercises.length
                                ? Icons.check_circle_rounded
                                : Icons.bolt_rounded),
                        isPrimary: true,
                        height: 52,
                        borderRadius: 16,
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.black,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          if (_completedExerciseIndices.isNotEmpty &&
                              _completedExerciseIndices.length == _exercises.length) {
                            _finishWorkout();
                            return;
                          }
                          int? nextIndex;
                          for (int i = 0; i < _exercises.length; i++) {
                            if (_partialSetsByExercise.containsKey(i) &&
                                !_completedExerciseIndices.contains(i)) {
                              nextIndex = i;
                              break;
                            }
                          }
                          if (nextIndex == null) {
                            for (int i = 0; i < _exercises.length; i++) {
                              if (!_completedExerciseIndices.contains(i)) {
                                nextIndex = i;
                                break;
                              }
                            }
                          }
                          _startFocusMode(initialIndex: nextIndex ?? 0);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. CABEÇALHO DA SEÇÃO DE EXERCÍCIOS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'EXERCÍCIOS DA SESSÃO',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _highlight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _border),
                          ),
                          child: Text(
                            '${_exercises.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => WorkoutGuideModal.show(context),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.help_outline_rounded, size: 14, color: MetaColors.emerald),
                            SizedBox(width: 4),
                            Text(
                              'Como treinar',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: MetaColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista de Exercícios (Compacta por padrão, ou Expandida se selecionado)
                for (int index = 0; index < _exercises.length; index++)
                  _showExpandedExerciseCards
                      ? _buildExerciseCard(index)
                      : _buildCompactExerciseCard(index),

                const SizedBox(height: 12),

                // Botão de Concluir no Fim da Lista (Scroll Natural)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SquircleButton(
                    label: _completedExerciseIndices.isEmpty
                        ? 'Concluir Treino'
                        : 'Concluir Treino (${_completedExerciseIndices.length}/${_exercises.length} Feitos)',
                    icon: Icons.check_circle_rounded,
                    isPrimary: _completedExerciseIndices.isNotEmpty,
                    backgroundColor: _completedExerciseIndices.isNotEmpty
                        ? MetaColors.emerald
                        : _highlight,
                    foregroundColor: _completedExerciseIndices.isNotEmpty
                        ? Colors.black
                        : _textSecondary,
                    height: 54.0,
                    borderRadius: 18.0,
                    onPressed: _finishWorkout,
                  ),
                ),
              ],
            ),

            // Botão de Finalizar Flutuante (Rodapé) - Exibido apenas quando todos os exercícios forem concluídos (100%)
            if (_exercises.isNotEmpty && _completedExerciseIndices.length == _exercises.length)
              Positioned(
                left: 18,
                right: 18,
                bottom: bottomPadding > 0 ? bottomPadding + 76 : 84,
                child: SquircleButton(
                  label: 'Concluir Treino (${_completedExerciseIndices.length}/${_exercises.length})',
                  icon: Icons.check_circle_rounded,
                  isPrimary: true,
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.black,
                  height: 56.0,
                  borderRadius: 18.0,
                  onPressed: _finishWorkout,
                ),
              ),

            // Loading State Overlay com Suíte Shaipados Kinetic Hex-Core (Biomecânica)
            if (_isLoading)
              const Positioned.fill(
                child: ShaipadosLoaderContainer(
                  type: ShaipadosLoaderType.kineticHexCore,
                  customTitle: 'Adaptando Exercício...',
                  loadingMessages: [
                    'Analisando vetor de força e curva de carga...',
                    'Filtrando aparelhos livres com mesmo estímulo...',
                    'Validando integridade articular e biomecânica...',
                    'Variação aprovada! Pronto para o treino.',
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HudStatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;

  const _HudStatTile({
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = MetaColors.highlight(context);
    final border = MetaColors.cardBorder(context);
    final textSecondary = MetaColors.subtext(context);
    final textPrimary = MetaColors.text(context);

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: MetaColors.emerald),
                const SizedBox(width: 3),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }
    return content;
  }
}

// ---------------------------------------------------------------------------
// Card Anatômico 3D com Músculo Alvo em Ação & Eletromiografia (Fallback)
// ---------------------------------------------------------------------------
class _AnatomicalMuscleCard extends StatelessWidget {
  final String exerciseName;
  final String targetMuscle;

  const _AnatomicalMuscleCard({
    required this.exerciseName,
    required this.targetMuscle,
  });

  @override
  Widget build(BuildContext context) {
    final lower = exerciseName.toLowerCase();
    int emg = 94;
    String secondary = 'Deltoide Anterior & Tríceps';
    String stabilizers = 'Manguito Rotador & Core';
    Color glowColor = MetaColors.emerald;

    if (lower.contains('supino') ||
        lower.contains('peito') ||
        lower.contains('crucifixo')) {
      emg = 94;
      secondary = 'Deltoide Anterior, Tríceps Braquial';
      stabilizers = 'Manguito Rotador, Serrátil Anterior';
      glowColor = MetaColors.emerald;
    } else if (lower.contains('desenvolvimento') ||
        lower.contains('elevacao') ||
        lower.contains('ombro')) {
      emg = 92;
      secondary = 'Tríceps Braquial, Trapézio Superior';
      stabilizers = 'Manguito Rotador, Core Abdominal';
      glowColor = const Color(0xFFF59E0B);
    } else if (lower.contains('triceps') ||
        lower.contains('polia') ||
        lower.contains('testa')) {
      emg = 96;
      secondary = 'Ancôneo, Extensores do Punho';
      stabilizers = 'Deltóide Posterior, Core';
      glowColor = MetaColors.accentBlue;
    } else if (lower.contains('agachamento') ||
        lower.contains('leg press') ||
        lower.contains('extensora')) {
      emg = 95;
      secondary = 'Glúteo Máximo, Isquiotibiais';
      stabilizers = 'Core Abdominal, Eretores da Espinha';
      glowColor = MetaColors.emerald;
    } else if (lower.contains('puxada') ||
        lower.contains('remada') ||
        lower.contains('costas')) {
      emg = 93;
      secondary = 'Bíceps Braquial, Braquiorradial';
      stabilizers = 'Trapézio Médio/Inferior, Romboides';
      glowColor = MetaColors.accentBlue;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF070C18), Color(0xFF0B1426)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: glowColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.biotech_rounded,
                      size: 15,
                      color: glowColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIOMECÂNICA & ATIVAÇÃO 3D',
                        style: TextStyle(
                          color: glowColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        targetMuscle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: glowColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$emg% EMG',
                  style: TextStyle(
                    color: glowColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _AnatomicalBodyPainter(
                  exerciseType: lower,
                  glowColor: glowColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: glowColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Agonista: $targetMuscle',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: MetaColors.accentBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sinergistas: $secondary',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA78BFA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Estabilizadores: $stabilizers',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
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
    );
  }
}

class _AnatomicalBodyPainter extends CustomPainter {
  final String exerciseType;
  final Color glowColor;

  _AnatomicalBodyPainter({required this.exerciseType, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final gridPaint =
        Paint()
          ..color = const Color(0xFF161F33)
          ..strokeWidth = 0.8;
    for (double x = cx - 120; x <= cx + 120; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 25) {
      canvas.drawLine(Offset(cx - 120, y), Offset(cx + 120, y), gridPaint);
    }

    final bodyOutlinePaint =
        Paint()
          ..color = const Color(0xFF2D3748)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 36), width: 22, height: 26),
      bodyOutlinePaint,
    );

    final trapPath =
        Path()
          ..moveTo(cx - 6, cy - 24)
          ..lineTo(cx - 24, cy - 14)
          ..lineTo(cx + 24, cy - 14)
          ..lineTo(cx + 6, cy - 24)
          ..close();
    canvas.drawPath(trapPath, bodyOutlinePaint);

    final torsoPath =
        Path()
          ..moveTo(cx - 28, cy - 14)
          ..lineTo(cx - 36, cy + 2)
          ..lineTo(cx - 24, cy + 30)
          ..lineTo(cx - 18, cy + 50)
          ..lineTo(cx + 18, cy + 50)
          ..lineTo(cx + 24, cy + 30)
          ..lineTo(cx + 36, cy + 2)
          ..lineTo(cx + 28, cy - 14)
          ..close();
    canvas.drawPath(torsoPath, bodyOutlinePaint);

    final leftArmPath =
        Path()
          ..moveTo(cx - 36, cy + 2)
          ..lineTo(cx - 44, cy + 24)
          ..lineTo(cx - 38, cy + 48);
    final rightArmPath =
        Path()
          ..moveTo(cx + 36, cy + 2)
          ..lineTo(cx + 44, cy + 24)
          ..lineTo(cx + 38, cy + 48);
    canvas.drawPath(leftArmPath, bodyOutlinePaint);
    canvas.drawPath(rightArmPath, bodyOutlinePaint);

    final muscleGlowPaint =
        Paint()
          ..color = glowColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final muscleSolidPaint =
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.fill;

    final muscleBorderPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    if (exerciseType.contains('supino') ||
        exerciseType.contains('peito') ||
        exerciseType.contains('crucifixo')) {
      final pecLeft =
          Path()
            ..moveTo(cx - 4, cy - 10)
            ..lineTo(cx - 26, cy - 6)
            ..quadraticBezierTo(cx - 28, cy + 12, cx - 18, cy + 16)
            ..quadraticBezierTo(cx - 6, cy + 15, cx - 4, cy + 6)
            ..close();
      final pecRight =
          Path()
            ..moveTo(cx + 4, cy - 10)
            ..lineTo(cx + 26, cy - 6)
            ..quadraticBezierTo(cx + 28, cy + 12, cx + 18, cy + 16)
            ..quadraticBezierTo(cx + 6, cy + 15, cx + 4, cy + 6)
            ..close();

      canvas.drawPath(pecLeft, muscleGlowPaint);
      canvas.drawPath(pecLeft, muscleSolidPaint);
      canvas.drawPath(pecLeft, muscleBorderPaint);

      canvas.drawPath(pecRight, muscleGlowPaint);
      canvas.drawPath(pecRight, muscleSolidPaint);
      canvas.drawPath(pecRight, muscleBorderPaint);

      final fiberPaint =
          Paint()
            ..color = Colors.white38
            ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(cx - 6, cy - 5),
        Offset(cx - 20, cy - 2),
        fiberPaint,
      );
      canvas.drawLine(
        Offset(cx - 6, cy + 2),
        Offset(cx - 22, cy + 6),
        fiberPaint,
      );
      canvas.drawLine(
        Offset(cx + 6, cy - 5),
        Offset(cx + 20, cy - 2),
        fiberPaint,
      );
      canvas.drawLine(
        Offset(cx + 6, cy + 2),
        Offset(cx + 22, cy + 6),
        fiberPaint,
      );
    } else if (exerciseType.contains('desenvolvimento') ||
        exerciseType.contains('elevacao') ||
        exerciseType.contains('ombro')) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 32, cy - 4), width: 14, height: 18),
        muscleGlowPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 32, cy - 4), width: 14, height: 18),
        muscleSolidPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 32, cy - 4), width: 14, height: 18),
        muscleBorderPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 32, cy - 4), width: 14, height: 18),
        muscleGlowPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 32, cy - 4), width: 14, height: 18),
        muscleSolidPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 32, cy - 4), width: 14, height: 18),
        muscleBorderPaint,
      );
    } else if (exerciseType.contains('triceps') ||
        exerciseType.contains('polia') ||
        exerciseType.contains('testa')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx - 39, cy + 16),
            width: 10,
            height: 22,
          ),
          const Radius.circular(5),
        ),
        muscleGlowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx - 39, cy + 16),
            width: 10,
            height: 22,
          ),
          const Radius.circular(5),
        ),
        muscleSolidPaint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + 39, cy + 16),
            width: 10,
            height: 22,
          ),
          const Radius.circular(5),
        ),
        muscleGlowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + 39, cy + 16),
            width: 10,
            height: 22,
          ),
          const Radius.circular(5),
        ),
        muscleSolidPaint,
      );
    } else {
      final centerCore =
          Path()
            ..moveTo(cx - 14, cy - 4)
            ..lineTo(cx + 14, cy - 4)
            ..lineTo(cx + 10, cy + 34)
            ..lineTo(cx - 10, cy + 34)
            ..close();
      canvas.drawPath(centerCore, muscleGlowPaint);
      canvas.drawPath(centerCore, muscleSolidPaint);
      canvas.drawPath(centerCore, muscleBorderPaint);
    }

    final sensorPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 16, cy + 4), 3, sensorPaint);
    canvas.drawCircle(Offset(cx + 16, cy + 4), 3, sensorPaint);
  }

  @override
  bool shouldRepaint(covariant _AnatomicalBodyPainter oldDelegate) {
    return oldDelegate.exerciseType != exerciseType ||
        oldDelegate.glowColor != glowColor;
  }
}
