import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import '../../models/exercise_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/workout_session_service.dart';

/// Modo de Treino Focado no Salão (Focus Mode)
///
/// Desenvolvido para ergonomia One-Hand (Thumb Zone), navegação horizontal
/// por gestos de deslizar (Swipe com PageView), controle de carga sem teclado (+/- 2.5kg),
/// Auto-Rest Timer com feedback háptico e cálculo de tonelagem total (volume load).
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

  _SetProgress({
    required this.weightKg,
    required this.reps,
  }) : isCompleted = false;
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

  // Persistência e detecção de Recordes Pessoais (PR)
  Map<int, double> _referencePreviousWeights = {};
  int _newPrCount = 0;

  static String _weightKey(String clientId, String exerciseName) =>
      'pwa_last_weight_${clientId}_${exerciseName.toLowerCase().trim()}';

  @override
  void initState() {
    super.initState();
    final initialPage = (widget.initialExerciseIndex >= 0 &&
            widget.initialExerciseIndex < widget.exercises.length)
        ? widget.initialExerciseIndex
        : 0;
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);
    _currentExercises = List.from(widget.exercises);
    _initSets();
    _loadPreviousWeights();

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
          // Hidrata a carga atual com a última carga real utilizada
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
        });
      }
    } catch (_) {}
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
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg|quilos)', caseSensitive: false)
        .firstMatch(notes);
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
                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                    backgroundColor:
                        const Color(0xFFF59E0B).withValues(alpha: 0.1),
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
      {'name': 'Ombro / Manguito', 'icon': Icons.accessibility_new_rounded},
      {'name': 'Lombar / Coluna', 'icon': Icons.airline_seat_recline_normal_rounded},
      {'name': 'Joelho', 'icon': Icons.directions_walk_rounded},
      {'name': 'Cotovelo', 'icon': Icons.front_hand_rounded},
      {'name': 'Punho / Mão', 'icon': Icons.pan_tool_rounded},
      {'name': 'Quadril', 'icon': Icons.accessibility_rounded},
    ];

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
                  children: const [
                    Icon(Icons.health_and_safety_rounded, color: Color(0xFFF59E0B), size: 26),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Onde você está sentindo dor?',
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
                  'A IA do Mr. Coach substituirá "${currentEx.name}" por uma alternativa que alivia a articulação afetada e alertará ${widget.trainerName}.',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: joints.map((j) {
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: MetaColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(jIcon, size: 16, color: const Color(0xFFF59E0B)),
                            const SizedBox(width: 8),
                            Text(
                              jName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MetaColors.textPrimary,
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
          notes:
              '${result.notes}\n[IA: ${result.biomechanicalRationale}]',
        );
      });

      // Notifica o professor e persiste em adaptation_logs
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
        await _sessionService.complete(record);
      } catch (e) {
        debugPrint('Aviso ao salvar sessão: $e');
      }
    }

    if (!mounted) return;

    // Feedback tátil de triunfo (conquista neurológica padrão Apple Fitness / Nike)
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      HapticFeedback.mediumImpact();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.paddingOf(ctx).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle bar refinado
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Hero Emblem de Celebração com Aura & Animação Elástica
              Center(
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Aura neon pulsante esmeralda em loop
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                              color: MetaColors.emerald.withValues(alpha: 0.35),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.08, 1.08),
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          ),

                      // Círculo central com borda luminescente
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              MetaColors.surfaceHighlight,
                              MetaColors.surface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.5),
                            width: 2.2,
                          ),
                        ),
                        child: const Center(
                          child: Text('🎉', style: TextStyle(fontSize: 42)),
                        ),
                      ),

                      // Partícula 1 (Sparkle Âmbar superior-direita)
                      Positioned(
                        top: 2,
                        right: 4,
                        child: const Text('✨', style: TextStyle(fontSize: 18))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.25, 1.25),
                              duration: 1200.ms,
                            )
                            .fadeIn(delay: 200.ms),
                      ),

                      // Partícula 2 (Sparkle Dourada inferior-esquerda)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: const Text('⚡', style: TextStyle(fontSize: 16))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1.15, 1.15),
                              end: const Offset(0.75, 0.75),
                              duration: 1400.ms,
                            )
                            .fadeIn(delay: 300.ms),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.35, 0.35),
                    end: const Offset(1, 1),
                    duration: 650.ms,
                    curve: Curves.elasticOut,
                  )
                  .rotate(
                    begin: -0.06,
                    end: 0,
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 14),

              // Título principal com entrada escalonada
              const Center(
                child: Text(
                  'Treino Concluído com Sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: MetaColors.textPrimary,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms)
                  .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),

              // Subtítulo em Pill com nome do treino e treinador
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Text(
                    '${widget.workoutTitle} · ${widget.trainerName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 220.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 22),

              // Métricas em Cards One UI 7 com Animação em Cascata
              Row(
                children: [
                  // Card TEMPO
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: MetaColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: MetaColors.textSecondary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'TEMPO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: MetaColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$durationMin min',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 280.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                  ),
                  const SizedBox(width: 8),

                  // Card VOLUME (Destaque Esmeralda com Shimmer)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: MetaColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.38),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MetaColors.emerald.withValues(alpha: 0.08),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 12,
                                color: MetaColors.emerald,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'VOLUME',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: MetaColors.emerald,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${totalVolume.toStringAsFixed(0)} kg',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 350.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad)
                        .shimmer(delay: 750.ms, duration: 1100.ms, color: Colors.white12),
                  ),
                  const SizedBox(width: 8),

                  // Card SÉRIES
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: MetaColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 12,
                                color: MetaColors.textSecondary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SÉRIES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: MetaColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$totalCompleted/${_countTotalSets()}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 420.ms)
                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Streak / Ofensiva com Fogo Vivo Animado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.14),
                      const Color(0xFFD97706).withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.38),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24))
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.18, 1.18),
                          duration: 900.ms,
                          curve: Curves.easeInOut,
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentStreak != null
                                ? 'Ofensiva ativa: ${widget.currentStreak! + 1} dias'
                                : 'Ofensiva mantida com consistência!',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Meta diária de estímulo muscular concluída com foco.',
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
              )
                  .animate()
                  .fadeIn(duration: 380.ms, delay: 490.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

              // Destaque de Recordes Pessoais (PR) com Shimmer de Celebração
              if (_newPrCount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MetaColors.emerald.withValues(alpha: 0.16),
                        MetaColors.emerald.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 24))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.16, 1.16),
                            duration: 1100.ms,
                          ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_newPrCount Novo(s) Recorde(s) de Carga Batido(s)!',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: MetaColors.emerald,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Sua progressão de sobrecarga está evoluindo.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: MetaColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 380.ms, delay: 550.ms)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic)
                    .shimmer(delay: 900.ms, duration: 1200.ms, color: Colors.white24),
              ],
              const SizedBox(height: 24),

              // Botão Compartilhar WhatsApp com Gradiente e Squircle Oficial
              if (widget.trainerPhone != null &&
                  widget.trainerPhone!.trim().isNotEmpty) ...[
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      final cleanPhone = widget.trainerPhone!
                          .replaceAll(RegExp(r'\D'), '');
                      final phoneWithCountry = cleanPhone.startsWith('55')
                          ? cleanPhone
                          : '55$cleanPhone';
                      final prMsg = _newPrCount > 0
                          ? '🏆 Recordes batidos: $_newPrCount novo(s) PR(s)!\n'
                          : '';
                      final msg = Uri.encodeComponent(
                        'Fala Prof. ${widget.trainerName}! 💪 Acabei de concluir o ${widget.workoutTitle}!\n'
                        '⏱ Tempo: $durationMin min\n'
                        '📊 Volume total: ${totalVolume.toStringAsFixed(0)} kg\n'
                        '$prMsg'
                        '🔥 Treino registrado com Focus Mode no Mr. Coach AI.',
                      );
                      launchUrl(
                        Uri.parse(
                          'https://api.whatsapp.com/send?phone=$phoneWithCountry&text=$msg',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_rounded,
                            size: 19,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Compartilhar no WhatsApp de ${widget.trainerName}',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 350.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),
              ],

              // Botão Secundário Concluir e Sair com SquircleButton
              SquircleButton(
                label: 'Concluir e Sair',
                icon: Icons.check_circle_outline_rounded,
                isPrimary: false,
                backgroundColor: MetaColors.surfaceHighlight,
                foregroundColor: MetaColors.textPrimary,
                onPressed: () {
                  Navigator.pop(ctx); // fecha modal
                  Navigator.pop(context, true); // fecha Focus Mode
                },
              )
                  .animate()
                  .fadeIn(delay: 660.ms, duration: 350.ms)
                  .slideY(begin: 0.1, end: 0),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    if (_currentExercises.isEmpty) {
      return Scaffold(
        backgroundColor: MetaColors.background,
        body: const Center(
          child: Text(
            'Nenhum exercício encontrado neste split.',
            style: TextStyle(color: MetaColors.textSecondary),
          ),
        ),
      );
    }

    final totalEx = _currentExercises.length;

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
                // 1. Top Bar Edge-to-Edge
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
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: MetaColors.textSecondary,
                              size: 26,
                            ),
                            tooltip: 'Fechar Focus Mode',
                            onPressed: () => Navigator.pop(context),
                          ),
                          Column(
                            children: [
                              Text(
                                '${widget.splitIdentifier} · EXERCÍCIO ${_currentPage + 1}/$totalEx',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: MetaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.splitName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: MetaColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Segmented Story Pills (Instagram / WhatsApp Status Pattern)
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
                                height: 5,
                                margin: EdgeInsets.symmetric(
                                  horizontal: totalEx > 6 ? 1.5 : 3.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? MetaColors.emerald
                                      : (isCurrent
                                          ? MetaColors.emerald.withValues(alpha: 0.7)
                                          : MetaColors.surfaceHighlight),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: MetaColors.emerald.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
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

            // 4. Auto-Rest Timer Floating Sheet
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
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _restInitialDuration > 0
                                    ? (_restSecondsRemaining / _restInitialDuration).clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: MetaColors.background,
                                color: MetaColors.emerald,
                                minHeight: 3,
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

            // 5. Overlay de Adaptação de Exercício (IA)
            if (_isAdapting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: MetaColors.emerald),
                        SizedBox(height: 16),
                        Text(
                          'Adaptando exercício com IA...',
                          style: TextStyle(
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
    );
  }

  Widget _buildExerciseCard(int index) {
    final ex = _currentExercises[index];
    final sets = _exerciseSets[index] ?? [];
    final emg = _getEmgForExercise(ex.name);

    final prevWeight = _referencePreviousWeights[index] ?? 0.0;
    double currentMaxWeight = 0.0;
    for (final s in sets) {
      if (s.isCompleted && s.weightKg > currentMaxWeight) {
        currentMaxWeight = s.weightKg;
      }
    }
    final bool hasNewPr = prevWeight > 0 && currentMaxWeight > prevWeight;

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
            border: Border.all(
              color: hasNewPr
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                  : MetaColors.border,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
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
                        if (hasNewPr) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: MetaColors.textSecondary,
                            ),
                          ),
                        ],
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
                      errorBuilder: (_, _, _) => Container(
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '#${sIdx + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDone
                              ? MetaColors.emerald
                              : MetaColors.textSecondary,
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

                // Reps (Ajuste Tátil sem Teclado)
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
                            color: MetaColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MetaColors.border),
                          ),
                          child: const Icon(
                            Icons.remove,
                            size: 12,
                            color: MetaColors.textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '${set.reps}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _adjustReps(index, sIdx, 1),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: MetaColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MetaColors.border),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 12,
                            color: MetaColors.textSecondary,
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

        // Ações de Séries (One-Hand Gym UX)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: MetaColors.emerald,
                ),
                label: const Text(
                  'Adicionar Série',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: MetaColors.emerald,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: MetaColors.emerald.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: MetaColors.textSecondary,
                  ),
                  label: const Text(
                    'Remover Última',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: MetaColors.surfaceHighlight,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      ],
    );
  }
}

