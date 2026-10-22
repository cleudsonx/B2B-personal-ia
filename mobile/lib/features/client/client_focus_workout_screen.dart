import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/widgets/meta_components.dart';
import '../../core/widgets/exercise_media_sheet.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'widgets/warmup_sheet.dart';
import '../../models/exercise_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_session_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/exercise_media_service.dart';
import '../../core/widgets/offline_sync_banner.dart';

/// Modo de Treino Focado no Salão (Focus Mode HUD)
///
/// Desenvolvido para ergonomia One-Hand (Thumb Zone), navegação horizontal
/// por gestos de deslizar (Swipe com PageView), controle de carga sem teclado (+/- 2.5kg),
/// Auto-Rest Timer Dynamic Island com feedback háptico e cálculo de volume total.
class ClientFocusWorkoutScreen extends StatefulWidget {
  final String workoutTitle;
  final String splitIdentifier;
  final String splitName;
  final List<ExerciseModel> exercises;
  final String trainerName;
  final String? trainerPhone;
  final String workoutLocation;
  final int? currentStreak;
  final int initialExerciseIndex;

  const ClientFocusWorkoutScreen({
    super.key,
    required this.workoutTitle,
    required this.splitIdentifier,
    required this.splitName,
    required this.exercises,
    required this.trainerName,
    this.trainerPhone,
    required this.workoutLocation,
    this.currentStreak,
    this.initialExerciseIndex = 0,
  });

  @override
  State<ClientFocusWorkoutScreen> createState() =>
      _ClientFocusWorkoutScreenState();
}

class _SetProgress {
  double weightKg;
  int reps;
  bool isCompleted;

  _SetProgress({required this.weightKg, required this.reps})
      : isCompleted = false;
}

class _ClientFocusWorkoutScreenState extends State<ClientFocusWorkoutScreen> {
  final ApiService _apiService = ApiService();
  final WorkoutSessionService _sessionService = WorkoutSessionService();
  late PageController _pageController;
  late List<ExerciseModel> _currentExercises;
  late Map<int, List<_SetProgress>> _exerciseSets;

  int _currentPage = 0;
  DateTime _startedAt = DateTime.now();
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Auto-Rest Timer State
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  int _restInitialDuration = 60;
  bool _isRestTimerActive = false;
  bool _isAdapting = false;

  // Mapeamento de nomes originais para evitar duplicação recursiva na substituição IA
  final Map<int, String> _originalExerciseNames = {};

  // Persistência e detecção de Recordes Pessoais (PR)
  Map<int, double> _referencePreviousWeights = {};
  int _lastReportedRpe = 8;
  final Set<int> _dismissedOverloadIndices = {};
  int _newPrCount = 0;

  static String _weightKey(String clientId, String exerciseName) =>
      'pwa_last_weight_${clientId}_${exerciseName.toLowerCase().trim()}';

  @override
  void initState() {
    super.initState();
    final initialPage =
        (widget.initialExerciseIndex >= 0 &&
                widget.initialExerciseIndex < widget.exercises.length)
            ? widget.initialExerciseIndex
            : 0;
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);
    _currentExercises = List.from(widget.exercises);
    _initSets();
    _loadPreviousWeights();
    ExerciseMediaService.preloadExerciseNames(
      _currentExercises.map((e) => e.name).toList(),
    );

    _startedAt = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
        });
      }
    });
  }

  void _initSets() {
    _exerciseSets = {};
    for (int i = 0; i < _currentExercises.length; i++) {
      final ex = _currentExercises[i];
      final setsCount = ex.sets > 0 ? ex.sets : 3;
      final defaultReps = _parseDefaultReps(ex.reps);
      final defaultWeight = _parseDefaultWeight(ex.notes);

      _exerciseSets[i] = List.generate(
        setsCount,
        (_) => _SetProgress(weightKg: defaultWeight, reps: defaultReps),
      );
    }
  }

  Future<void> _loadPreviousWeights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = AuthService.currentUser?.id ?? 'guest';
      final Map<int, double> refs = {};

      for (int i = 0; i < _currentExercises.length; i++) {
        final ex = _currentExercises[i];
        final key = _weightKey(uid, ex.name);
        final savedWeight = prefs.getDouble(key);
        if (savedWeight != null && savedWeight > 0) {
          refs[i] = savedWeight;
          if (_exerciseSets.containsKey(i)) {
            for (final s in _exerciseSets[i]!) {
              s.weightKg = savedWeight;
            }
          }
        } else {
          refs[i] = _parseDefaultWeight(ex.notes);
        }
      }

      if (mounted) {
        setState(() {
          _referencePreviousWeights = refs;
          final savedRpe = prefs.getInt('last_session_rpe');
          if (savedRpe != null && savedRpe > 0) {
            _lastReportedRpe = savedRpe;
          }
        });
      }
    } catch (_) {}
  }

  void _applyOverloadSuggestion(
    int exerciseIndex,
    OverloadSuggestion suggestion,
  ) {
    HapticFeedback.heavyImpact();
    setState(() {
      final sets = _exerciseSets[exerciseIndex] ?? [];
      for (final s in sets) {
        if (!s.isCompleted) {
          s.weightKg = suggestion.suggestedWeightKg;
          s.reps = suggestion.suggestedReps;
        }
      }
    });
  }

  Future<void> _saveWeights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = AuthService.currentUser?.id ?? 'guest';

      for (int i = 0; i < _currentExercises.length; i++) {
        final ex = _currentExercises[i];
        final sets = _exerciseSets[i] ?? [];
        double maxWeight = 0.0;
        int maxReps = 0;
        for (final s in sets) {
          if (s.isCompleted && s.weightKg >= maxWeight) {
            maxWeight = s.weightKg;
            maxReps = s.reps;
          }
        }
        if (maxWeight > 0) {
          await prefs.setDouble(_weightKey(uid, ex.name), maxWeight);
          await WorkoutService.recordExerciseLoad(
            exerciseName: ex.name,
            loadKg: maxWeight,
            reps: maxReps > 0 ? maxReps : null,
          );
        }
      }
    } catch (_) {}
  }

  bool _isExerciseFullyCompleted(int exIndex) {
    final sets = _exerciseSets[exIndex];
    if (sets == null || sets.isEmpty) return false;
    return sets.every((s) => s.isCompleted);
  }

  void _addSet(int exerciseIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      final sets = _exerciseSets[exerciseIndex] ?? [];
      final lastWeight = sets.isNotEmpty ? sets.last.weightKg : 20.0;
      final lastReps = sets.isNotEmpty ? sets.last.reps : 10;
      sets.add(_SetProgress(weightKg: lastWeight, reps: lastReps));
      _exerciseSets[exerciseIndex] = sets;
    });
  }

  void _removeLastSet(int exerciseIndex) {
    final sets = _exerciseSets[exerciseIndex];
    if (sets != null && sets.length > 1) {
      HapticFeedback.selectionClick();
      setState(() {
        sets.removeLast();
      });
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

  @override
  void dispose() {
    _pageController.dispose();
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onSetChecked(int exerciseIndex, int setIndex) {
    final set = _exerciseSets[exerciseIndex]![setIndex];

    setState(() {
      set.isCompleted = !set.isCompleted;
    });

    if (set.isCompleted) {
      final prevRef = _referencePreviousWeights[exerciseIndex] ?? 0.0;
      if (prevRef > 0 && set.weightKg > prevRef) {
        _newPrCount++;
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      final currentEx = _currentExercises[exerciseIndex];
      final restDuration =
          currentEx.restSeconds > 0 ? currentEx.restSeconds : 60;
      _startRestTimer(restDuration);
    } else {
      HapticFeedback.lightImpact();
    }

    final uid = AuthService.currentUser?.id;
    if (uid != null) {
      _saveDraftDebounced(uid);
    }
  }

  void _saveDraftDebounced(String uid) {
    try {
      final draftSets = <String, dynamic>{};
      _exerciseSets.forEach((k, v) {
        draftSets[k.toString()] =
            v
                .map(
                  (s) => {
                    'weightKg': s.weightKg,
                    'reps': s.reps,
                    'isCompleted': s.isCompleted,
                  },
                )
                .toList();
      });
      OfflineSyncService.instance.saveWorkoutDraft(uid, {
        'splitIdentifier': widget.splitIdentifier,
        'splitName': widget.splitName,
        'startedAt': _startedAt.toIso8601String(),
        'currentPage': _currentPage,
        'exerciseSets': draftSets,
      });
    } catch (_) {}
  }

  void _startRestTimer(int durationSeconds) {
    _restTimer?.cancel();
    setState(() {
      _restInitialDuration = durationSeconds;
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
        RestTimerSheet.triggerCadencedFeedback(0);
        setState(() {
          _restSecondsRemaining = 0;
          _isRestTimerActive = false;
        });
      } else {
        setState(() {
          _restSecondsRemaining--;
        });
        if (_restSecondsRemaining <= 3) {
          RestTimerSheet.triggerCadencedFeedback(_restSecondsRemaining);
        }
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
    setState(() {
      final set = _exerciseSets[exerciseIndex]![setIndex];
      final newW = (set.weightKg + delta).clamp(0.0, 500.0);
      set.weightKg = (newW * 2).round() / 2; // Arredonda para 0.5kg
    });
  }

  void _adjustReps(int exerciseIndex, int setIndex, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final set = _exerciseSets[exerciseIndex]![setIndex];
      final newReps = (set.reps + delta).clamp(1, 100);
      set.reps = newReps;
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

  int _countTotalSets() {
    int count = 0;
    for (final sets in _exerciseSets.values) {
      count += sets.length;
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
    final currentEx = _currentExercises[exerciseIndex];
    final cardBg = MetaColors.card(context);
    final border = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: border),
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
                        'Variação com IA: ${currentEx.name}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'O Mr. Coach AI encontra alternativas biomecanicamente equivalentes e notifica seu treinador em tempo real:',
                  style: TextStyle(
                    color: textSecondary,
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
                    _showJointPainSelectorModal(exerciseIndex);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJointPainSelectorModal(int exerciseIndex) {
    final currentEx = _currentExercises[exerciseIndex];
    final joints = [
      {'name': 'Ombro', 'icon': Icons.accessibility_new_rounded},
      {'name': 'Joelho', 'icon': Icons.airline_seat_legroom_extra_rounded},
      {'name': 'Lombar', 'icon': Icons.airline_seat_recline_normal_rounded},
      {'name': 'Punho', 'icon': Icons.pan_tool_rounded},
      {'name': 'Cotovelo', 'icon': Icons.fitness_center_rounded},
    ];

    final cardBg = MetaColors.card(context);
    final border = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: border),
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
                      Icons.health_and_safety_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Onde você está sentindo dor?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'A IA do Mr. Coach substituirá "${currentEx.name}" por uma alternativa que alivia a articulação afetada e alertará ${widget.trainerName}.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children:
                      joints.map((j) {
                        final jName = j['name'] as String;
                        final jIcon = j['icon'] as IconData;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _executeSubstitution(
                              exerciseIndex,
                              'Dor Articular ($jName)',
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: MetaColors.highlight(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  jIcon,
                                  size: 16,
                                  color: const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  jName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeSubstitution(int exerciseIndex, String reason) async {
    setState(() => _isAdapting = true);
    final target = _currentExercises[exerciseIndex];

    // Guarda nome original para metadados e evita duplicação infinita
    _originalExerciseNames[exerciseIndex] ??= target.name;

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: widget.workoutLocation,
        injuriesOrRestrictions: 'Adaptação imediata durante o treino.',
      );

      if (!mounted) return;

      setState(() {
        _currentExercises[exerciseIndex] = target.copyWith(
          name: result.adaptedExercise,
          sets: result.sets,
          reps: result.reps,
          restSeconds: result.restSeconds,
          notes: result.notes.isNotEmpty
              ? '${result.notes}\n[IA: ${result.biomechanicalRationale}]'
              : '[IA: ${result.biomechanicalRationale}]',
        );
      });

      // Notifica o professor e persiste em adaptation_logs
      await WorkoutService.logAdaptation(
        originalExercise: _originalExerciseNames[exerciseIndex]!,
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
                color: Colors.white,
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
            content: Text(
              'Não foi possível adaptar o exercício no momento.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdapting = false);
    }
  }

  Future<void> _finishWorkout() async {
    await _saveWeights();
    final totalVolume = _calculateTotalVolumeLoadKg();
    final totalCompleted = _countCompletedSets();
    final durationMin = (_elapsedSeconds / 60).round();
    final uid = AuthService.currentUser?.id;

    if (uid != null) {
      try {
        final record = WorkoutSessionRecord(
          id: WorkoutSessionRecord.newId(),
          clientId: uid,
          splitIdentifier: widget.splitIdentifier,
          splitName: widget.splitName,
          totalExercises: _currentExercises.length,
          completedExercises: _currentExercises.length,
          startedAt: _startedAt,
          completedAt: DateTime.now(),
        );
        final status = await _sessionService.complete(record);
        await OfflineSyncService.instance.clearWorkoutDraft(uid);
        if (status == SessionSaveStatus.pendingSync) {
          await OfflineSyncService.instance.refreshPendingCount(uid);
        }
      } catch (e) {
        debugPrint('Aviso ao salvar sessão: $e');
      }
    }

    if (!mounted) return;

    await WorkoutTriumphModal.show(
      context,
      workoutTitle: widget.workoutTitle,
      trainerName: widget.trainerName,
      trainerPhone: widget.trainerPhone,
      durationMin: durationMin,
      totalVolumeKg: totalVolume,
      completedSets: totalCompleted,
      totalSets: _countTotalSets(),
      currentStreak: widget.currentStreak,
      newPrCount: _newPrCount,
      onDismiss: () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      },
    );
  }

  Set<int> _getCompletedExerciseIndices() {
    final Set<int> indices = {};
    for (int i = 0; i < _currentExercises.length; i++) {
      if (_isExerciseFullyCompleted(i)) {
        indices.add(i);
      }
    }
    return indices;
  }

  Future<void> _handleExitRequest() async {
    final completedSets = _countCompletedSets();
    if (completedSets == 0) {
      Navigator.pop(context);
      return;
    }

    final cardBg = MetaColors.card(context);
    final border = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pause_circle_filled_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pausar ou Sair do Treino?',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Seu progresso atual está ativo.',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    'Você já completou $completedSets série(s). Deseja salvar o progresso dos exercícios concluídos ou descartar este treino?',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continuar Treinando',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'save_exit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textPrimary,
                    side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        size: 18,
                        color: MetaColors.emeraldText(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Salvar Progresso e Sair',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'discard'),
                  child: const Text(
                    'Descartar e Sair Sem Salvar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'save_exit' && mounted) {
      await _saveWeights();
      final uid = AuthService.currentUser?.id;
      if (uid != null) {
        await OfflineSyncService.instance.clearWorkoutDraft(uid);
      }
      final completedIndices = _getCompletedExerciseIndices();
      if (mounted) {
        Navigator.pop(context, completedIndices);
      }
    } else if (action == 'discard' && mounted) {
      final uid = AuthService.currentUser?.id;
      if (uid != null) {
        await OfflineSyncService.instance.clearWorkoutDraft(uid);
      }
      if (mounted) {
        Navigator.pop(context, null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = MetaColors.isDark(context);
    final bg = MetaColors.bg(context);
    final cardBg = MetaColors.card(context);
    final border = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);

    if (_currentExercises.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Text(
            'Nenhum exercício encontrado neste split.',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final totalEx = _currentExercises.length;
    final completedSetsTotal = _countCompletedSets();
    final allSetsTotal = _countTotalSets();
    final double completionRatio =
        allSetsTotal > 0 ? (completedSetsTotal / allSetsTotal).clamp(0.0, 1.0) : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExitRequest();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              Column(
                children: [
                  // 1. Top HUD Telemetry Bar (Apple Fitness+ Minimalist Edge-to-Edge)
                  Container(
                    padding: EdgeInsets.only(
                      top: topPadding + 8,
                      bottom: 10,
                      left: 16,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border(
                        bottom: BorderSide(color: border, width: 0.8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: textSecondary,
                                size: 24,
                              ),
                              tooltip: 'Fechar Focus Mode',
                              onPressed: _handleExitRequest,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${widget.splitIdentifier} · ${_currentPage + 1}/$totalEx',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: MetaColors.emerald.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$completedSetsTotal/$allSetsTotal Séries (${(completionRatio * 100).toInt()}%)',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: MetaColors.emeraldText(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.splitName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Aquecimento 3 min
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                WarmupSheet.show(
                                  context,
                                  initialFocus: widget.splitName,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Text('🔥', style: TextStyle(fontSize: 11)),
                                    SizedBox(width: 3),
                                    Text(
                                      '3 min',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Cronômetro da Sessão
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 13,
                                    color: MetaColors.emeraldText(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimer(_elapsedSeconds),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Toggle Claro / Escuro Rápido
                            const ThemeToggleButton(compact: true),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Segmented Stories Pills
                        Row(
                          children: List.generate(totalEx, (barIdx) {
                            final isDone = _isExerciseFullyCompleted(barIdx);
                            final isCurrent = barIdx == _currentPage;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _pageController.animateToPage(
                                    barIdx,
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  );
                                },
                                child: Container(
                                  height: 4.5,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: totalEx > 6 ? 1.5 : 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? MetaColors.emerald
                                        : (isCurrent
                                            ? MetaColors.emerald.withValues(alpha: 0.75)
                                            : border),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const OfflineSyncBanner(padding: EdgeInsets.only(top: 8)),
                      ],
                    ),
                  ),

                  // 2. PageView com Swipe Horizontal
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

                  // 3. Bottom Controls (Thumb Zone)
                  Container(
                    padding: EdgeInsets.only(
                      left: 18,
                      right: 18,
                      top: 10,
                      bottom: bottomPadding + 12,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      border: Border(
                        top: BorderSide(color: border, width: 0.8),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_currentPage > 0) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                side: BorderSide(color: border),
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
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: textPrimary,
                                size: 20,
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
                                  backgroundColor: MetaColors.emerald,
                                  onPressed: _finishWorkout,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 4. Auto-Rest Timer Floating Sheet (Dynamic Island Style)
              if (_isRestTimerActive)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: bottomPadding + 76,
                  child: Builder(
                    builder: (context) {
                      final isUrgent =
                          _restSecondsRemaining <= 3 && _restSecondsRemaining > 0;
                      final timerColor = isUrgent
                          ? Colors.redAccent
                          : (_restSecondsRemaining < 15
                              ? Colors.amber
                              : MetaColors.emeraldText(context));

                      return InkWell(
                        onTap: () {
                          if (_currentPage < _currentExercises.length) {
                            RestTimerSheet.show(
                              context,
                              seconds: _restSecondsRemaining,
                              exerciseName: _currentExercises[_currentPage].name,
                              onFinished: _skipRestTimer,
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: MetaColors.elevated(context),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: timerColor.withValues(alpha: isUrgent ? 0.9 : 0.45),
                              width: isUrgent ? 1.8 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isUrgent
                                    ? Colors.redAccent.withValues(alpha: 0.25)
                                    : (isDark
                                        ? Colors.black.withValues(alpha: 0.45)
                                        : Colors.grey.withValues(alpha: 0.2)),
                                blurRadius: isUrgent ? 20 : 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: timerColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$_restSecondsRemaining',
                                    style: TextStyle(
                                      color: timerColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
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
                                    Row(
                                      children: [
                                        Text(
                                          'DESCANSO EM ANDAMENTO',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            color: isUrgent ? Colors.redAccent : textSecondary,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        if (isUrgent) ...[
                                          const SizedBox(width: 4),
                                          const Text('🔥', style: TextStyle(fontSize: 11)),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      isUrgent
                                          ? '$_restSecondsRemaining s • Prepare-se para a série!'
                                          : '${_formatTimer(_restSecondsRemaining)} restantes',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: isUrgent ? Colors.redAccent : textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: _restInitialDuration > 0
                                            ? (_restSecondsRemaining / _restInitialDuration).clamp(0.0, 1.0)
                                            : 0.0,
                                        backgroundColor: border,
                                        color: timerColor,
                                        minHeight: 2.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _addRestSeconds(30),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  backgroundColor: MetaColors.highlight(context),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  '+30s',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  color: textSecondary,
                                  size: 20,
                                ),
                                tooltip: 'Pular Descanso',
                                onPressed: _skipRestTimer,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 5. Overlay de Adaptação de Exercício (IA)
              if (_isAdapting)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: MetaColors.emerald),
                          const SizedBox(height: 16),
                          Text(
                            'Adaptando exercício com IA...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildExerciseCard(int index) {
    final ex = _currentExercises[index];
    final sets = _exerciseSets[index] ?? [];
    final emg = _getEmgForExercise(ex.name);
    final cardBg = MetaColors.card(context);
    final border = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);

    final prevWeight = _referencePreviousWeights[index] ?? 0.0;
    double currentMaxWeight = 0.0;
    for (final s in sets) {
      if (s.isCompleted && s.weightKg > currentMaxWeight) {
        currentMaxWeight = s.weightKg;
      }
    }
    final bool hasNewPr = prevWeight > 0 && currentMaxWeight > prevWeight;

    // A primeira série não concluída é a "série ativa"
    int activeSetIndex = -1;
    for (int i = 0; i < sets.length; i++) {
      if (!sets[i].isCompleted) {
        activeSetIndex = i;
        break;
      }
    }

    final origName = _originalExerciseNames[index];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        // Hero Stage (Card Unificado Raio 24px)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasNewPr
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                  : border,
              width: hasNewPr ? 1.5 : 1.0,
            ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                emg,
                                style: TextStyle(
                                  color: MetaColors.emeraldText(context),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ex.targetMuscleGroup.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: textSecondary,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (origName != null && origName != ex.name) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Substituído de: $origName',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                        if (hasNewPr) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 13,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Novo Recorde: +${(currentMaxWeight - prevWeight).toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (prevWeight > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Carga anterior: ${prevWeight.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Imagem anatômica com badge de reprodução
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ExerciseMediaSheet.show(context, exerciseName: ex.name);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            _getAnatomicalImage(ex.name, ex.targetMuscleGroup),
                            width: 66,
                            height: 66,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 66,
                              height: 66,
                              color: MetaColors.highlight(context),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: textSecondary,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.8),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 12,
                              color: MetaColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Dock Unificado (3 Pílulas Ghost Horizontais)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 15,
                        color: MetaColors.emerald,
                      ),
                      label: Text(
                        'Execução',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: MetaColors.emeraldText(context),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        side: BorderSide(
                          color: MetaColors.emerald.withValues(alpha: 0.35),
                        ),
                        backgroundColor: MetaColors.emerald.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ExerciseMediaSheet.show(context, exerciseName: ex.name);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.accessibility_new_rounded,
                        size: 15,
                        color: Color(0xFF6366F1),
                      ),
                      label: Text(
                        'Raio-X 3D',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: MetaColors.blueText(context),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        side: BorderSide(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        ),
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        BiomechanicalAnalysisSheet.show(
                          context,
                          exerciseName: ex.name,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.bolt,
                        size: 15,
                        color: Color(0xFFF59E0B),
                      ),
                      label: const Text(
                        'Trocar IA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        side: BorderSide(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                        backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showEquipmentBusyModal(index),
                    ),
                  ),
                ],
              ),

              if (ex.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 15,
                        color: MetaColors.emeraldText(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ex.notes,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
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
        const SizedBox(height: 14),

        // Cabeçalho da Tabela de Séries
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  'SÉRIE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textSecondary,
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
                      color: textSecondary,
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
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: Center(
                  child: Text(
                    'FEITO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Matriz Tátil de Séries (Tactile Set Rows)
        ...List.generate(sets.length, (sIdx) {
          final set = sets[sIdx];
          final isDone = set.isCompleted;
          final isActive = sIdx == activeSetIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? MetaColors.emerald.withValues(alpha: 0.08)
                  : (isActive
                      ? cardBg
                      : cardBg.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(
                  color: isActive
                      ? MetaColors.emerald
                      : (isDone ? MetaColors.emerald : border),
                  width: isActive ? 3.5 : 1.0,
                ),
                top: BorderSide(
                  color: isDone
                      ? MetaColors.emerald.withValues(alpha: 0.3)
                      : border,
                ),
                right: BorderSide(
                  color: isDone
                      ? MetaColors.emerald.withValues(alpha: 0.3)
                      : border,
                ),
                bottom: BorderSide(
                  color: isDone
                      ? MetaColors.emerald.withValues(alpha: 0.3)
                      : border,
                ),
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: MetaColors.emerald.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Número da série
                SizedBox(
                  width: 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${sIdx + 1}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: isDone
                              ? MetaColors.emeraldText(context)
                              : (isActive ? textPrimary : textSecondary),
                        ),
                      ),
                      if (isDone && prevWeight > 0 && set.weightKg > prevWeight)
                        const Text('🏆', style: TextStyle(fontSize: 10)),
                    ],
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
                        onLongPress: () => _adjustWeight(index, sIdx, -5.0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 15,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${set.weightKg} kg',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _adjustWeight(index, sIdx, 2.5),
                        onLongPress: () => _adjustWeight(index, sIdx, 5.0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 15,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Reps (Ajuste Tátil)
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () => _adjustReps(index, sIdx, -1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 12,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${set.reps}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _adjustReps(index, sIdx, 1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: border),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 12,
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
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
                          color: isDone ? MetaColors.emerald : MetaColors.highlight(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? MetaColors.emerald : border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: isDone ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Ações de Séries (Adicionar / Remover)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: MetaColors.emerald,
                ),
                label: Text(
                  'Adicionar Série',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetaColors.emeraldText(context),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: MetaColors.emerald.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: MetaColors.emerald.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                onPressed: () => _addSet(index),
              ),
              if (sets.length > 1) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: textSecondary,
                  ),
                  label: Text(
                    'Remover Última',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: MetaColors.highlight(context),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _removeLastSet(index),
                ),
              ],
            ],
          ),
        ),

        // Sugestão de Sobrecarga Progressiva Inteligente (IA Overload)
        if (!_dismissedOverloadIndices.contains(index)) ...[
          Builder(
            builder: (context) {
              final currentWeight =
                  sets.isNotEmpty ? sets.first.weightKg : prevWeight;
              final currentReps =
                  sets.isNotEmpty ? sets.first.reps : _parseDefaultReps(ex.reps);

              final suggestion = ProgressiveOverloadEngine.computeSuggestion(
                exerciseName: ex.name,
                targetMuscleGroup: ex.targetMuscleGroup,
                currentWeight: currentWeight,
                currentReps: currentReps,
                previousWeight: prevWeight > 0 ? prevWeight : null,
                lastRpe: _lastReportedRpe,
              );

              return AiOverloadCard(
                suggestion: suggestion,
                onApply: () => _applyOverloadSuggestion(index, suggestion),
                onDismiss: () => setState(() => _dismissedOverloadIndices.add(index)),
              );
            },
          ),
        ],
      ],
    );
  }
}
