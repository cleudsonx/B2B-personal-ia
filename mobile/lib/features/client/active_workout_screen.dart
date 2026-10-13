import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'student_profile_screen.dart';
import '../../core/widgets/meta_components.dart';
import '../../models/exercise_model.dart';
import '../../models/split_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_session_service.dart';

class _SetProgress {
  double weightKg;
  int reps;
  bool isCompleted;

  _SetProgress({
    required this.weightKg,
    required this.reps,
    this.isCompleted = false,
  });
}

/// Tela de Treino Ativo do Aluno Mr. Coach
///
/// Experiência One-Hand (Thumb Zone), navegação horizontal nativa por gestos de deslizar
/// (Swipe com PageView), controle ergonômico de carga rápida sem teclado (+/- 2.5kg),
/// Auto-Rest Timer flutuante com feedback tátil e cálculo de tonelagem total (volume load).
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final ApiService _apiService = ApiService();
  final WorkoutSessionService _sessionService = WorkoutSessionService();

  bool _isLoadingWorkout = true;
  String _workoutTitle = '';
  String _workoutLocation = 'Academia completa e espaço de musculação';
  String _trainerName = 'Carregando treinador...';
  String? _trainerPhone;
  String _trainerCref = 'CREF Ativo';
  String? _trainerPhotoUrl;

  List<SplitModel> _splits = [];
  int _selectedSplitIndex = 0;
  String? _splitIdentifier;
  String? _splitName;
  late List<ExerciseModel> _exercises;

  // Controle de Séries e Progresso em tempo real
  late PageController _pageController;
  int _currentPage = 0;
  late Map<int, List<_SetProgress>> _exerciseSets;

  DateTime? _startedAt;
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Auto-Rest Timer Flutuante
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isRestTimerActive = false;

  bool _isAdapting = false;
  int? currentStreak;

  @override
  void initState() {
    super.initState();
    _exercises = [];
    _exerciseSets = {};
    _pageController = PageController();

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _startedAt != null) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
        });
      }
    });

    _loadActiveWorkout();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
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
        _currentPage = 0;
        _startedAt = DateTime.now();
        _elapsedSeconds = 0;
        _initSets();
      } else {
        _splits = [];
        _selectedSplitIndex = 0;
        _exercises = [];
        _exerciseSets = {};
        _workoutTitle = '';
        _startedAt = null;
        _elapsedSeconds = 0;
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
      }
    } catch (_) {}

    try {
      final gami = await WorkoutService.getGamificationData();
      if (gami != null && mounted) {
        setState(() {
          currentStreak = (gami['current_streak'] as num?)?.toInt();
        });
      }
    } catch (_) {}
  }

  void _initSets() {
    _exerciseSets = {};
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      final setsCount = ex.sets > 0 ? ex.sets : 3;
      final defaultReps = _parseDefaultReps(ex.reps);
      final defaultWeight = _parseDefaultWeight(ex.notes);

      _exerciseSets[i] = List.generate(
        setsCount,
        (_) => _SetProgress(weightKg: defaultWeight, reps: defaultReps),
      );
    }
  }

  int _parseDefaultReps(String repsStr) {
    final match = RegExp(r'\d+').firstMatch(repsStr);
    if (match != null) {
      return int.tryParse(match.group(0) ?? '') ?? 10;
    }
    return 10;
  }

  double _parseDefaultWeight(String notes) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:kg|quilos)',
      caseSensitive: false,
    ).firstMatch(notes);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? 20.0;
    }
    return 20.0;
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
      _currentPage = 0;
      _startedAt = DateTime.now();
      _elapsedSeconds = 0;
      _initSets();
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onSetChecked(int exerciseIndex, int setIndex) {
    HapticFeedback.lightImpact();
    final sets = _exerciseSets[exerciseIndex];
    if (sets == null || setIndex >= sets.length) return;
    final set = sets[setIndex];

    setState(() {
      set.isCompleted = !set.isCompleted;
    });

    if (set.isCompleted) {
      final currentEx = _exercises[exerciseIndex];
      final restDuration =
          currentEx.restSeconds > 0 ? currentEx.restSeconds : 60;
      _startRestTimer(restDuration);
    }
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = durationSeconds;
      _isRestTimerActive = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restSecondsRemaining <= 1) {
        t.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _restSecondsRemaining = 0;
          _isRestTimerActive = false;
        });
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
      }
    });
  }

  void _addRestSeconds(int seconds) {
    setState(() {
      _restSecondsRemaining += seconds;
    });
  }

  void _skipRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestTimerActive = false;
      _restSecondsRemaining = 0;
    });
  }

  void _adjustWeight(int exerciseIndex, int setIndex, double delta) {
    HapticFeedback.selectionClick();
    final sets = _exerciseSets[exerciseIndex];
    if (sets == null || setIndex >= sets.length) return;
    setState(() {
      final set = sets[setIndex];
      final newW = (set.weightKg + delta).clamp(0.0, 500.0);
      set.weightKg = (newW * 2).round() / 2;
    });
  }

  double _calculateTotalVolumeLoadKg() {
    double total = 0.0;
    for (final sets in _exerciseSets.values) {
      for (final s in sets) {
        if (s.isCompleted) {
          total += (s.weightKg * s.reps);
        }
      }
    }
    return total;
  }

  int _countCompletedSets() {
    int count = 0;
    for (final sets in _exerciseSets.values) {
      for (final s in sets) {
        if (s.isCompleted) count++;
      }
    }
    return count;
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

  void _showEquipmentBusyModal(int exerciseIndex) {
    final currentEx = _exercises[exerciseIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        'Substituir: ${currentEx.name}',
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
                  'O Mr. Coach AI encontra alternativas biomecanicamente equivalentes e notifica seu treinador em tempo real:',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 13,
                  ),
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
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeSubstitution(
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
                    side: const BorderSide(
                      color: Color(0xFFF59E0B),
                      width: 1.5,
                    ),
                    backgroundColor: const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeSubstitution(
                      exerciseIndex,
                      'Desconforto Articular',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeSubstitution(int exerciseIndex, String reason) async {
    setState(() => _isAdapting = true);
    final target = _exercises[exerciseIndex];

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: _workoutLocation,
        injuriesOrRestrictions: 'Adaptação imediata durante o treino.',
      );

      if (!mounted) return;

      setState(() {
        _exercises[exerciseIndex] = target.copyWith(
          name: result.adaptedExercise,
          sets: result.sets,
          reps: result.reps,
          restSeconds: result.restSeconds,
          notes: '${result.notes}\n[IA: ${result.biomechanicalRationale}]',
        );
      });

      await WorkoutService.logAdaptation(
        originalExercise: target.name,
        adaptedExercise: result.adaptedExercise,
        reason: reason,
        details: result.toJson(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Text(
              '✓ Substituído por: ${result.adaptedExercise}',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Não foi possível adaptar o exercício no momento.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdapting = false);
    }
  }

  Future<void> _finishWorkout() async {
    final totalVolume = _calculateTotalVolumeLoadKg();
    final durationMin = (_elapsedSeconds / 60).round();
    final uid = AuthService.currentUser?.id;

    if (uid != null) {
      try {
        final record = WorkoutSessionRecord(
          id: WorkoutSessionRecord.newId(),
          clientId: uid,
          splitIdentifier: _splitIdentifier,
          splitName: _splitName,
          totalExercises: _exercises.length,
          completedExercises: _exercises.length,
          startedAt: _startedAt ?? DateTime.now(),
          completedAt: DateTime.now(),
        );
        await _sessionService.complete(record);
      } catch (e) {
        debugPrint('Aviso ao salvar sessão: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.paddingOf(ctx).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: MetaColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('🎉', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Treino Concluído com Sucesso!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MetaColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '$_workoutTitle · $_trainerName',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MetaColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Métricas em Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MetaColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TEMPO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$durationMin min',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MetaColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'VOLUME TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${totalVolume.toStringAsFixed(0)} kg',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
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

              // Streak / Ofensiva
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStreak != null
                                ? 'Ofensiva ativa: ${currentStreak! + 1} dias'
                                : 'Ofensiva mantida com consistência!',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Meta diária de estímulo muscular concluída.',
                            style: TextStyle(
                              fontSize: 12,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botão WhatsApp
              if (_trainerPhone != null &&
                  _trainerPhone!.trim().isNotEmpty) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('Compartilhar no WhatsApp de $_trainerName'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final cleanPhone = _trainerPhone!.replaceAll(
                      RegExp(r'\D'),
                      '',
                    );
                    final phoneWithCountry = cleanPhone.startsWith('55')
                        ? cleanPhone
                        : '55$cleanPhone';
                    final msg = Uri.encodeComponent(
                      'Fala Prof. $_trainerName! 💪 Acabei de concluir o $_workoutTitle!\n'
                      '⏱ Tempo: $durationMin min\n'
                      '📊 Volume total: ${totalVolume.toStringAsFixed(0)} kg\n'
                      '🔥 Treino registrado pelo Mr. Coach AI.',
                    );
                    launchUrl(
                      Uri.parse(
                        'https://api.whatsapp.com/send?phone=$phoneWithCountry&text=$msg',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              SquircleButton(
                label: 'Concluir Treino',
                icon: Icons.check_circle_outline_rounded,
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadActiveWorkout();
                },
              ),
            ],
          ),
        );
      },
    );
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
                      'Se você está sem conexão, conecte-se e atualize.',
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    if (_isLoadingWorkout || _exercises.isEmpty) {
      return _buildNoWorkoutScaffold(topPadding);
    }

    final totalEx = _exercises.length;
    final progress = (totalEx > 0) ? (_currentPage + 1) / totalEx : 0.0;

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
            Column(
              children: [
                // 1. Top Bar Edge-to-Edge Integrada
                Container(
                  padding: EdgeInsets.only(
                    top: topPadding + 10,
                    bottom: 12,
                    left: 18,
                    right: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: MetaColors.background,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: MetaColors.surfaceHighlight,
                                backgroundImage: _trainerPhotoUrl != null &&
                                        _trainerPhotoUrl!.isNotEmpty
                                    ? NetworkImage(_trainerPhotoUrl!)
                                    : null,
                                child: _trainerPhotoUrl == null ||
                                        _trainerPhotoUrl!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: MetaColors.emerald,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _trainerName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: MetaColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    _trainerCref,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: MetaColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: MetaColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: MetaColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 14,
                                      color: MetaColors.emerald,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimer(_elapsedSeconds),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: MetaColors.textSecondary,
                                  size: 22,
                                ),
                                tooltip: 'Meu Perfil',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StudentProfileScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Splits Seletor (A, B, C...)
                      if (_splits.length > 1) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < _splits.length;
                                index++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      '${_splits[index].splitIdentifier} · ${_splits[index].splitName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: index == _selectedSplitIndex
                                            ? Colors.black
                                            : MetaColors.textSecondary,
                                      ),
                                    ),
                                    selected: index == _selectedSplitIndex,
                                    selectedColor: MetaColors.emerald,
                                    backgroundColor:
                                        MetaColors.surfaceHighlight,
                                    onSelected: (_) => _selectSplit(index),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Indicador de Posição do Exercício e Barra de Progresso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'EXERCÍCIO ${_currentPage + 1} DE $totalEx',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                          Text(
                            currentStreak != null
                                ? '🔥 $currentStreak dias'
                                : 'Mr. Coach Focus',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: MetaColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            MetaColors.emerald,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. PageView com Swipe Horizontal Nativo
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (idx) {
                      setState(() => _currentPage = idx);
                    },
                    itemCount: totalEx,
                    itemBuilder: (ctx, idx) {
                      return _buildExerciseCard(idx);
                    },
                  ),
                ),

                // 3. Thumb Zone Rodapé (Navegação & Finalização Rápida)
                Container(
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 12,
                    bottom: bottomPadding + 14,
                  ),
                  decoration: const BoxDecoration(
                    color: MetaColors.background,
                    border: Border(
                      top: BorderSide(color: MetaColors.border, width: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_currentPage > 0) ...[
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: MetaColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 3,
                        child: _currentPage < totalEx - 1
                            ? SquircleButton(
                                label: 'Próximo Exercício',
                                icon: Icons.arrow_forward_rounded,
                                isPrimary: true,
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                              )
                            : SquircleButton(
                                label: 'Finalizar Treino',
                                icon: Icons.check_circle_rounded,
                                isPrimary: true,
                                onPressed: _finishWorkout,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 4. Auto-Rest Timer Flutuante com Feedback Tátil
            if (_isRestTimerActive)
              Positioned(
                left: 18,
                right: 18,
                bottom: bottomPadding + 80,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$_restSecondsRemaining',
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'DESCANSO EM ANDAMENTO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: MetaColors.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              '${_formatTimer(_restSecondsRemaining)} restantes',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: MetaColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _addRestSeconds(30),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          backgroundColor: MetaColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '+30s',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: MetaColors.textSecondary,
                        ),
                        tooltip: 'Pular Descanso',
                        onPressed: _skipRestTimer,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(int index) {
    final ex = _exercises[index];
    final sets = _exerciseSets[index] ?? [];
    final emg = _getEmgForExercise(ex.name);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
      children: [
        // Card Principal do Exercício
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetaColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MetaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                emg,
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ex.targetMuscleGroup.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: MetaColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ex.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: MetaColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Imagem anatômica
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      _getAnatomicalImage(ex.name, ex.targetMuscleGroup),
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 68,
                        height: 68,
                        color: MetaColors.surfaceHighlight,
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: MetaColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Botão de Pânico "Aparelho Ocupado"
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.bolt,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
                label: const Text(
                  'Aparelho Ocupado? Sugerir Variação com IA',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: BorderSide(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                  backgroundColor:
                      const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showEquipmentBusyModal(index),
              ),

              if (ex.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: MetaColors.emerald,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ex.notes,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MetaColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cabeçalho da Tabela de Séries
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: const [
              SizedBox(
                width: 36,
                child: Text(
                  'SÉRIE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: MetaColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Center(
                  child: Text(
                    'CARGA (KG)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'REPS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    'CHECK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Linhas de Séries
        ...List.generate(sets.length, (sIdx) {
          final set = sets[sIdx];
          final isDone = set.isCompleted;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? MetaColors.emerald.withValues(alpha: 0.08)
                  : MetaColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone
                    ? MetaColors.emerald.withValues(alpha: 0.4)
                    : MetaColors.border,
              ),
            ),
            child: Row(
              children: [
                // Número da série
                SizedBox(
                  width: 32,
                  child: Text(
                    '#${sIdx + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isDone
                          ? MetaColors.emerald
                          : MetaColors.textSecondary,
                    ),
                  ),
                ),

                // Seletor tátil de carga (+/- 2.5kg)
                Expanded(
                  flex: 5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _adjustWeight(index, sIdx, -2.5),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MetaColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MetaColors.border),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 16,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${set.weightKg} kg',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _adjustWeight(index, sIdx, 2.5),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MetaColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: MetaColors.border),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 16,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reps
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      '${set.reps}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: MetaColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Botão de Check
                SizedBox(
                  width: 44,
                  child: Center(
                    child: InkWell(
                      onTap: () => _onSetChecked(index, sIdx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDone
                              ? MetaColors.emerald
                              : MetaColors.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone
                                ? MetaColors.emerald
                                : MetaColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: isDone ? Colors.black : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
