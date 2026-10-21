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
import '../../core/widgets/workout_triumph_modal.dart';
import '../../core/widgets/rest_timer_sheet.dart';
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
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _workoutTitle = '';
  String _workoutLocation = 'Academia completa e espaÃ§o de musculaÃ§Ã£o';
  String _trainerName = 'Carregando treinador...';
  String? _trainerPhone;
  String _trainerCref = 'CREF Ativo';
  String? _trainerPhotoUrl;
  final Set<int> _adaptedIndices = {};
  final Set<int> _completedExerciseIndices = {};
  final WorkoutSessionService _sessionService = WorkoutSessionService();
  bool _isLoadingWorkout = true;
  DateTime? _startedAt;
  String? _splitIdentifier;
  String? _splitName;
  List<SplitModel> _splits = [];
  int _selectedSplitIndex = 0;
  Timer? _ticker;
  RealtimeChannel? _workoutRealtimeChannel;

  // VariÃ¡veis reais de GamificaÃ§Ã£o (Backend)
  int? currentStreak;

  // ExercÃ­cios da ficha ativa real do aluno (vazio = sem ficha)
  late List<ExerciseModel> _exercises;
  final bool _showExpandedExerciseCards = false;

  // Cache de miniaturas de alta resoluÃ§Ã£o (PadrÃ£o Hevy / Strong)
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
              debugPrint('[Realtime] AtualizaÃ§Ã£o de treino recebida para $uid: ${payload.eventType}');
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
                              ? 'Nova versÃ£o da ficha disponÃ­vel! Conclua seu treino ou recarregue.'
                              : 'Sua ficha de treino foi atualizada pelo seu treinador!',
                          style: const TextStyle(
                            color: MetaColors.textPrimary,
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
                  backgroundColor: MetaColors.surfaceHighlight,
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
            .replaceAll('Prof.', '')
            .replaceAll('Carregando...', '')
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
        name.contains('elevaÃ§Ã£o') ||
        name.contains('ombro') ||
        muscle.contains('deltoid')) {
      return 'assets/images/biomech_3d_shoulders.jpg';
    } else if (name.contains('triceps') ||
        name.contains('trÃ­ceps') ||
        name.contains('biceps') ||
        name.contains('bÃ­ceps') ||
        name.contains('rosca') ||
        muscle.contains('braco') ||
        muscle.contains('braquial')) {
      return 'assets/images/biomech_3d_arms.jpg';
    } else if (name.contains('agachamento') ||
        name.contains('leg') ||
        name.contains('extensora') ||
        name.contains('quadr') ||
        muscle.contains('perna') ||
        muscle.contains('glÃºteo') ||
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
    if (lower.contains('triceps') || lower.contains('trÃ­ceps')) {
      return '96% EMG';
    }
    if (lower.contains('elevacao') ||
        lower.contains('elevaÃ§Ã£o') ||
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
        _adaptedIndices.clear();
        _startedAt ??= DateTime.now();
      } else {
        _splits = [];
        _selectedSplitIndex = 0;
        _exercises = [];
        _workoutTitle = '';
        _completedExerciseIndices.clear();
        _adaptedIndices.clear();
        _startedAt = null;
      }
      _isLoadingWorkout = false;
    });

    final workoutLocation = await WorkoutService.getClientWorkoutLocation();
    if (mounted && workoutLocation != null) {
      setState(() => _workoutLocation = workoutLocation);
    }

    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
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
      } else if (mounted && _trainerName == 'Carregando treinador...') {
        setState(() {
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
      _adaptedIndices.clear();
      _startedAt = DateTime.now();
    });
    _loadExerciseThumbnails();
  }

  void _startFocusMode({int initialIndex = 0}) {
    if (_exercises.isEmpty) return;
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
          initialExerciseIndex: initialIndex,
        ),
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
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
      } else if (result is Set<int> && result.isNotEmpty) {
        setState(() {
          _completedExerciseIndices.addAll(result);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.surfaceHighlight,
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
                    'Progresso salvo (${result.length} exercício(s) concluído(s))!',
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
            'Seu treinador ($_trainerName) ainda nÃ£o cadastrou o WhatsApp profissional.',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('55')
        ? digits
        : (digits.length >= 10 && digits.length <= 11 ? '55$digits' : digits);
    final msg = Uri.encodeComponent(
      'OlÃ¡ professor(a) $_trainerName! Sou aluno no Mr. Coach e gostaria de tirar uma dÃºvida sobre meu treino.',
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
            'NÃ£o foi possÃ­vel abrir o WhatsApp automaticamente.',
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
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: MetaColors.border),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: MetaColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'O Mr. Coach AI encontrarÃ¡ uma variaÃ§Ã£o biomecanicamente equivalente e notificarÃ¡ seu professor:',
                  style: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
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
      {'name': 'Outro Desconforto Articular', 'loc': 'ArticulaÃ§Ã£o Geral'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: MetaColors.border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Qual articulaÃ§Ã£o apresenta desconforto?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: MetaColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ExercÃ­cio: ${currentExercise.name}',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
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
                        side: const BorderSide(color: MetaColors.border),
                        backgroundColor: MetaColors.surfaceHighlight,
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
                            style: const TextStyle(
                              color: MetaColors.textPrimary,
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
            ? 'Relato de $painLocation. Eliminar compressÃ£o e estresse nesta articulaÃ§Ã£o mantendo o estÃ­mulo muscular.'
            : 'Aparelho indisponÃ­vel no espaÃ§o de treino presencial.';

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

      // Dispara persistÃªncia e alerta em tempo real para o professor
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
              'SubstituÃ­do: ${result.adaptedExercise}',
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
        debugPrint('Erro ao adaptar exercÃ­cio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: const Text(
              'NÃ£o foi possÃ­vel adaptar este exercÃ­cio. Tente novamente.',
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

  Widget _buildNoWorkoutScaffold(double topPadding) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: Padding(
          padding: EdgeInsets.fromLTRB(24, topPadding + 14, 24, 24),
          child: _isLoadingWorkout
              ? const Center(
                  child: CircularProgressIndicator(color: MetaColors.emerald),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.person_outline_rounded,
                          color: MetaColors.textSecondary,
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
                    const Icon(
                      Icons.fitness_center_rounded,
                      size: 56,
                      color: MetaColors.textSecondary,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nenhuma ficha ativa',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Quando seu professor liberar sua ficha, ela aparece aqui. '
                      'Enquanto isso, aguarde o contato dele para conversar sobre a consultoria. '
                      'Se vocÃª estÃ¡ sem conexÃ£o, conecte-se e atualize.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SquircleButton(
                      label: 'Atualizar',
                      icon: Icons.refresh_rounded,
                      isPrimary: true,
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
        debugPrint('[ActiveWorkout] Erro ao salvar sessÃ£o: $e');
      }
    }

    if (!mounted) return;

    await WorkoutTriumphModal.show(
      context,
      workoutTitle:
          _workoutTitle.isNotEmpty ? _workoutTitle : 'Treino ConcluÃ­do',
      trainerName: _trainerName,
      trainerPhone: _trainerPhone,
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
            _startedAt = DateTime.now();
          });
          StudentNotificationService.instance.refreshNotifications();
        }
      },
    );
  }

  Widget _buildFallbackExerciseIcon(int index, String targetMuscle) {
    return Container(
      color: MetaColors.surfaceHighlight,
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: MetaColors.textPrimary,
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
    final setsCount = item.sets > 0 ? item.sets : 3;
    final thumbUrl = _exerciseThumbnails[item.name];

    return MetaCard(
      backgroundColor: MetaColors.surface,
      borderColor: isCompleted
          ? MetaColors.emerald.withValues(alpha: 0.6)
          : (isAdapted ? const Color(0xFFF59E0B) : MetaColors.border),
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () {
        HapticFeedback.lightImpact();
        _startFocusMode(initialIndex: index);
      },
      child: Row(
        children: [
          // 1. Miniatura Visual Interativa (Toque abre o vÃ­deo em tela cheia)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ExerciseMediaSheet.show(context, exerciseName: item.name);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: MetaColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCompleted
                      ? MetaColors.emerald.withValues(alpha: 0.4)
                      : MetaColors.border,
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

          // 2. InformaÃ§Ãµes CinesiolÃ³gicas (Nome, SÃ©ries x Reps, Descanso)
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
                              ? MetaColors.textSecondary
                              : MetaColors.textPrimary,
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MetaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('â€¢', style: TextStyle(color: MetaColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 5),
                    Text(
                      '$setsCount sÃ©ries Ã— ${item.reps}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MetaColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('â€¢', style: TextStyle(color: MetaColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 5),
                    Text(
                      '${item.restSeconds}s',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: MetaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // 3. AÃ§Ã£o RÃ¡pida de ConclusÃ£o / Ir Treinar
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted
                    ? MetaColors.emerald
                    : MetaColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted
                      ? MetaColors.emerald
                      : MetaColors.border,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.play_arrow_rounded,
                    size: 16,
                    color: isCompleted ? Colors.black : MetaColors.emerald,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted ? 'Feito' : 'Treinar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isCompleted ? Colors.black : MetaColors.emerald,
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
      backgroundColor: MetaColors.surface,
      borderColor:
          isCompleted
              ? MetaColors.emerald
              : (isAdapted ? const Color(0xFFF59E0B) : MetaColors.border),
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Row: Ordem, EMG pill & Checkbox gigante de conclusÃ£o
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: Text(
                      'EXERCÃCIO ${index + 1} DE ${_exercises.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: MetaColors.textSecondary,
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
              // BotÃ£o circular de marcar exercÃ­cio concluÃ­do
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
                            : MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isCompleted ? MetaColors.emerald : MetaColors.border,
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
                            isCompleted ? Colors.black : MetaColors.textSecondary,
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
                                  : MetaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Nome do ExercÃ­cio (Texto Grande e Alto Contraste)
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: MetaColors.textPrimary,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.targetMuscleGroup,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MetaColors.textSecondary,
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

          // 3. Miniatura / Preview BiomecÃ¢nico 3D interativo
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
                border: Border.all(color: MetaColors.border, width: 1.0),
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
                              '3D BiomecÃ¢nica & EMG',
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

          // BotÃµes de AÃ§Ã£o Visual (VÃ­deo Demonstrativo + Raio-X 3D)
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
                          'VÃ­deo ExecuÃ§Ã£o',
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
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetaColors.border),
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

          // 4. Grade HUD de Telemetria (SÃ©ries, Reps, CadÃªncia, Descanso)
          Row(
            children: [
              Expanded(
                child: _HudStatTile(label: 'SÃ©ries', value: '${item.sets}'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _HudStatTile(label: 'Reps', value: item.reps)),
              const SizedBox(width: 8),
              const Expanded(
                child: _HudStatTile(label: 'CadÃªncia', value: '3-0-1-0'),
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

          // 5. Dica de ExecuÃ§Ã£o (se houver)
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MetaColors.surfaceHighlight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MetaColors.border),
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
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: MetaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 6. BotÃ£o de PÃ¢nico (Aparelho Ocupado / Dor)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(
                Icons.bolt_rounded,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
              label: const Text(
                'Substituir â€¢ Aparelho Ocupado ou Dor',
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: topPadding + 14,
                bottom: bottomPadding + 140, // EspaÃ§o seguro para o OneUiFloatingNavBar nunca cobrir os cards
                left: 18,
                right: 18,
              ),
              children: [
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
                // 1. Topo: Treinador & Ações
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    MetaColors.emerald,
                                    MetaColors.accentBlue,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                image:
                                    _trainerPhotoUrl != null &&
                                            _trainerPhotoUrl!.isNotEmpty
                                        ? DecorationImage(
                                          image: _trainerPhotoUrl!.startsWith('assets/')
                                              ? AssetImage(_trainerPhotoUrl!) as ImageProvider
                                              : NetworkImage(_trainerPhotoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  _trainerPhotoUrl == null ||
                                          _trainerPhotoUrl!.isEmpty
                                      ? Center(
                                        child: Text(
                                          _getTrainerInitials(),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      )
                                      : null,
                            ),
                            Positioned(
                              bottom: -1,
                              right: -1,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: MetaColors.background,
                                    width: 2.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Seu treino com',
                              style: TextStyle(
                                fontSize: 11,
                                color: MetaColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _trainerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: MetaColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '($_trainerCref)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: MetaColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (kDebugMode)
                          IconButton(
                            icon: const Icon(
                              Icons.settings_ethernet_rounded,
                              size: 20,
                              color: MetaColors.textSecondary,
                            ),
                            tooltip: 'Configurar IP do Servidor (Dev)',
                            onPressed: () => ServerConfigDialog.show(context),
                          ),
                        InkWell(
                          onTap: () => StudentNotificationSheet.show(
                            context,
                            onOpenWorkout: () {
                              if (_exercises.isNotEmpty) {
                                _startFocusMode();
                              }
                            },
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: MetaColors.highlight(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MetaColors.cardBorder(context),
                                width: 0.8,
                              ),
                            ),
                            child: ValueListenableBuilder<int>(
                              valueListenable: StudentNotificationService.unreadCountNotifier,
                              builder: (context, unreadCount, child) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      unreadCount > 0
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_outlined,
                                      size: 16,
                                      color: unreadCount > 0
                                          ? const Color(0xFFF59E0B)
                                          : MetaColors.subtext(context),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: -3,
                                        right: -3,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _contactTrainerWhatsApp,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_rounded,
                                  size: 14,
                                  color: MetaColors.emerald,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Zap 24h',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Topo: Barra de Progresso do Treino em PÃ­lula + Indicador de Streak ðŸ”¥
                Row(
                  children: [
                    // Indicador de "Streak ðŸ”¥" (ofensiva)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: MetaColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('ðŸ”¥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            currentStreak == null ? 'â€”' : '$currentStreak dias',
                            semanticsLabel: currentStreak == null
                                ? 'SequÃªncia indisponÃ­vel'
                                : '$currentStreak dias',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Barra de progresso do treino em formato de pÃ­lula
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: MetaColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: MetaColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Progresso do Treino',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: MetaColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${_completedExerciseIndices.length}/${_exercises.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: MetaColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value:
                                    _exercises.isEmpty
                                        ? 0.0
                                        : (_completedExerciseIndices.length /
                                            _exercises.length),
                                minHeight: 6,
                                backgroundColor: MetaColors.surfaceHighlight,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  MetaColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. SELETOR DE DIVISÃ•ES (Carrossel Compacto de PÃ­lulas - Hevy / Strong)
                if (_splits.length > 1) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _splits.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final split = _splits[index];
                        final isSelected = index == _selectedSplitIndex;
                        final isToday = index == 0;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _selectSplit(index);
                          },
                          borderRadius: BorderRadius.circular(22),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? MetaColors.emerald
                                  : MetaColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? MetaColors.emerald
                                    : MetaColors.border,
                                width: isSelected ? 1.4 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: MetaColors.emerald.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Split ${split.splitIdentifier}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : MetaColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.black.withValues(alpha: 0.15)
                                          : MetaColors.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Hoje',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.black : MetaColors.emerald,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. CARD HERO: SEU TREINO DE HOJE (PadrÃ£o Ouro das Melhores Academias)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        MetaColors.surface,
                        Color(0xFF0F1E19),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'DIVISÃƒO ${(_splitIdentifier ?? 'A').toUpperCase()} â€¢ PROGRAMADO',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: MetaColors.emerald,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: MetaColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MetaColors.border),
                            ),
                            child: Text(
                              _elapsedLabel(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: MetaColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _splitName ?? 'Treino de Hoje',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: MetaColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 14, color: MetaColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            '${_exercises.length} exercÃ­cios',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('â€¢', style: TextStyle(color: MetaColors.textSecondary)),
                          const SizedBox(width: 8),
                          const Icon(Icons.timer_outlined, size: 14, color: MetaColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            '~${_exercises.length * 8} min',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('â€¢', style: TextStyle(color: MetaColors.textSecondary)),
                          const SizedBox(width: 8),
                          Text(
                            '${_completedExerciseIndices.length}/${_exercises.length} Feitos',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _completedExerciseIndices.isNotEmpty
                                  ? MetaColors.emerald
                                  : MetaColors.textSecondary,
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
                        label: _completedExerciseIndices.isEmpty
                            ? 'Iniciar Treino de Hoje'
                            : 'Continuar Treino (${_completedExerciseIndices.length}/${_exercises.length})',
                        icon: _completedExerciseIndices.isEmpty
                            ? Icons.play_arrow_rounded
                            : Icons.bolt_rounded,
                        isPrimary: true,
                        height: 52,
                        borderRadius: 16,
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.black,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          int nextIndex = 0;
                          for (int i = 0; i < _exercises.length; i++) {
                            if (!_completedExerciseIndices.contains(i)) {
                              nextIndex = i;
                              break;
                            }
                          }
                          _startFocusMode(initialIndex: nextIndex);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 5. CABEÃ‡ALHO DA SEÃ‡ÃƒO DE EXERCÃCIOS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'EXERCÃCIOS DA SESSÃƒO',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: MetaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MetaColors.border),
                          ),
                          child: Text(
                            '${_exercises.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MetaColors.textPrimary,
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

                // Lista de ExercÃ­cios (Compacta por padrÃ£o, ou Expandida se selecionado)
                for (int index = 0; index < _exercises.length; index++)
                  _showExpandedExerciseCards
                      ? _buildExerciseCard(index)
                      : _buildCompactExerciseCard(index),

                const SizedBox(height: 12),

                // BotÃ£o de Concluir no Fim da Lista (Scroll Natural)
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
                        : MetaColors.surfaceHighlight,
                    foregroundColor: _completedExerciseIndices.isNotEmpty
                        ? Colors.black
                        : MetaColors.textSecondary,
                    height: 54.0,
                    borderRadius: 18.0,
                    onPressed: _finishWorkout,
                  ),
                ),
              ],
            ),

            // BotÃ£o de Finalizar Flutuante (RodapÃ©) - Flutua acima da dock bar flutuante sem colisÃ£o
            if (_completedExerciseIndices.isNotEmpty)
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

            // Loading State Overlay
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(28.0),
                    decoration: BoxDecoration(
                      color: MetaColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MetaColors.emerald.withValues(alpha: 0.2),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            MetaColors.emerald,
                          ),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Adaptando exercÃ­cio com IA...',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Buscando vetor biomecÃ¢nico equivalente',
                          style: TextStyle(
                            fontSize: 12,
                            color: MetaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetaColors.border, width: 1),
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
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: MetaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: MetaColors.textPrimary,
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
// Card AnatÃ´mico 3D com MÃºsculo Alvo em AÃ§Ã£o & Eletromiografia (Fallback)
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
    String secondary = 'Deltoide Anterior & TrÃ­ceps';
    String stabilizers = 'Manguito Rotador & Core';
    Color glowColor = MetaColors.emerald;

    if (lower.contains('supino') ||
        lower.contains('peito') ||
        lower.contains('crucifixo')) {
      emg = 94;
      secondary = 'Deltoide Anterior, TrÃ­ceps Braquial';
      stabilizers = 'Manguito Rotador, SerrÃ¡til Anterior';
      glowColor = MetaColors.emerald;
    } else if (lower.contains('desenvolvimento') ||
        lower.contains('elevacao') ||
        lower.contains('ombro')) {
      emg = 92;
      secondary = 'TrÃ­ceps Braquial, TrapÃ©zio Superior';
      stabilizers = 'Manguito Rotador, Core Abdominal';
      glowColor = const Color(0xFFF59E0B);
    } else if (lower.contains('triceps') ||
        lower.contains('polia') ||
        lower.contains('testa')) {
      emg = 96;
      secondary = 'AncÃ´neo, Extensores do Punho';
      stabilizers = 'DeltÃ³ide Posterior, Core';
      glowColor = MetaColors.accentBlue;
    } else if (lower.contains('agachamento') ||
        lower.contains('leg press') ||
        lower.contains('extensora')) {
      emg = 95;
      secondary = 'GlÃºteo MÃ¡ximo, Isquiotibiais';
      stabilizers = 'Core Abdominal, Eretores da Espinha';
      glowColor = MetaColors.emerald;
    } else if (lower.contains('puxada') ||
        lower.contains('remada') ||
        lower.contains('costas')) {
      emg = 93;
      secondary = 'BÃ­ceps Braquial, Braquiorradial';
      stabilizers = 'TrapÃ©zio MÃ©dio/Inferior, Romboides';
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
                        'BIOMECÃ‚NICA & ATIVAÃ‡ÃƒO 3D',
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
