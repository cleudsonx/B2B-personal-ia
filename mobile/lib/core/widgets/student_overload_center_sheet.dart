import '../../services/workout_service.dart';
import '../../services/auth_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meta_components.dart';

/// Modelo de dados analítico de 1RM e Volume de um exercício
class ExerciseOverloadData {
  final String exerciseName;
  final String muscleGroup;
  final double currentWeightKg;
  final int currentReps;
  final double initialWeightKg;
  final int lastRpe;
  final List<double> weeklyVolumesKg;

  const ExerciseOverloadData({
    required this.exerciseName,
    required this.muscleGroup,
    required this.currentWeightKg,
    required this.currentReps,
    required this.initialWeightKg,
    required this.lastRpe,
    required this.weeklyVolumesKg,
  });

  /// 1RM Estimado pela Fórmula de Epley: Carga * (1 + Reps / 30)
  double get estimatedOneRmEpley {
    if (currentWeightKg <= 0 || currentReps <= 0) return 0.0;
    if (currentReps == 1) return currentWeightKg;
    final val = currentWeightKg * (1.0 + (currentReps / 30.0));
    return (val * 10).round() / 10.0;
  }

  /// 1RM Estimado pela Fórmula de Brzycki: Carga * 36 / (37 - Reps)
  double get estimatedOneRmBrzycki {
    if (currentWeightKg <= 0 || currentReps <= 0) return 0.0;
    if (currentReps >= 37) return currentWeightKg * 2.0;
    if (currentReps == 1) return currentWeightKg;
    final val = currentWeightKg * (36.0 / (37.0 - currentReps));
    return (val * 10).round() / 10.0;
  }

  /// Percentual de ganho de força comparado à carga inicial
  double get strengthGainPercent {
    if (initialWeightKg <= 0) return 0.0;
    final gain = ((currentWeightKg - initialWeightKg) / initialWeightKg) * 100.0;
    return (gain * 10).round() / 10.0;
  }
}

/// Central de Metas de Sobrecarga, Visualizador de 1RM e Curva de Volume Semanal
class StudentOverloadCenterSheet extends StatefulWidget {
  final String? studentId;
  final String? initialExerciseName;
  final double? initialWeight;
  final int? initialReps;
  final List<ExerciseOverloadData>? customExercises;

  const StudentOverloadCenterSheet({
    super.key,
    this.studentId,
    this.initialExerciseName,
    this.initialWeight,
    this.initialReps,
    this.customExercises,
  });

  static Future<void> show(
    BuildContext context, {
    String? studentId,
    String? exerciseName,
    double? currentWeight,
    int? currentReps,
    List<ExerciseOverloadData>? customExercises,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => StudentOverloadCenterSheet(
        studentId: studentId,
        initialExerciseName: exerciseName,
        initialWeight: currentWeight,
        initialReps: currentReps,
        customExercises: customExercises,
      ),
    );
  }

  @override
  State<StudentOverloadCenterSheet> createState() =>
      _StudentOverloadCenterSheetState();
}

class _StudentOverloadCenterSheetState extends State<StudentOverloadCenterSheet> {
  int _selectedExerciseIndex = 0;

  // Calculadora Interativa de 1RM State
  late double _calcWeight;
  late int _calcReps;

  static const List<ExerciseOverloadData> defaultCatalog = [
    ExerciseOverloadData(
      exerciseName: 'Supino Reto com Barra',
      muscleGroup: 'Peitoral Maior',
      currentWeightKg: 70.0,
      currentReps: 8,
      initialWeightKg: 55.0,
      lastRpe: 8,
      weeklyVolumesKg: [2640, 2800, 3080, 3360],
    ),
    ExerciseOverloadData(
      exerciseName: 'Agachamento Livre',
      muscleGroup: 'Quadríceps & Glúteos',
      currentWeightKg: 90.0,
      currentReps: 6,
      initialWeightKg: 70.0,
      lastRpe: 8,
      weeklyVolumesKg: [3360, 3600, 3960, 4320],
    ),
    ExerciseOverloadData(
      exerciseName: 'Puxada Alta Aberta',
      muscleGroup: 'Latíssimo do Dorso',
      currentWeightKg: 65.0,
      currentReps: 10,
      initialWeightKg: 50.0,
      lastRpe: 9,
      weeklyVolumesKg: [2500, 2600, 2850, 3120],
    ),
    ExerciseOverloadData(
      exerciseName: 'Leg Press 45°',
      muscleGroup: 'Quadríceps',
      currentWeightKg: 180.0,
      currentReps: 10,
      initialWeightKg: 140.0,
      lastRpe: 7,
      weeklyVolumesKg: [6720, 7200, 7920, 8640],
    ),
    ExerciseOverloadData(
      exerciseName: 'Desenvolvimento com Halteres',
      muscleGroup: 'Deltoides',
      currentWeightKg: 24.0,
      currentReps: 8,
      initialWeightKg: 18.0,
      lastRpe: 8,
      weeklyVolumesKg: [864, 960, 1056, 1152],
    ),
  ];

  late List<ExerciseOverloadData> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = widget.customExercises != null && widget.customExercises!.isNotEmpty
        ? List.from(widget.customExercises!)
        : List.from(defaultCatalog);

    if (widget.initialExerciseName != null) {
      final idx = _catalog.indexWhere((e) => e.exerciseName
          .toLowerCase()
          .contains(widget.initialExerciseName!.toLowerCase().trim()));
      if (idx >= 0) {
        _selectedExerciseIndex = idx;
      }
    }

    _calcWeight = widget.initialWeight ??
        _catalog[_selectedExerciseIndex].currentWeightKg;
    _calcReps =
        widget.initialReps ?? _catalog[_selectedExerciseIndex].currentReps;

    _loadUserSavedLoads();
    if (widget.customExercises == null || widget.customExercises!.isEmpty) {
      _fetchRealExercises();
    }
  }

  Future<void> _fetchRealExercises() async {
    final effectiveStudentId = widget.studentId ?? AuthService.currentUser?.id;
    if (effectiveStudentId == null) return;

    try {
      final overloads = await WorkoutService.getStudentProgressiveOverload(effectiveStudentId);
      final activePlan = await WorkoutService.getActiveWorkoutForClient(clientId: effectiveStudentId);

      final Map<String, ExerciseOverloadData> exerciseMap = {};

      for (final item in overloads) {
        final name = (item['exercise'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final historyList = (item['history'] as List<dynamic>?)
            ?.map((h) => double.tryParse(h.toString().replaceAll('kg', '').trim()) ?? 0.0)
            .where((w) => w > 0)
            .toList() ?? [];

        final currentWeight = historyList.isNotEmpty ? historyList.last : 50.0;
        final initialWeight = historyList.isNotEmpty ? historyList.first : currentWeight;
        final volumes = <double>[];
        if (historyList.isNotEmpty) {
          for (final w in historyList.take(4)) {
            volumes.add((w * 10 * 3).roundToDouble());
          }
        }
        while (volumes.length < 4) {
          volumes.insert(0, (initialWeight * 8 * 3).roundToDouble());
        }

        exerciseMap[name.toLowerCase()] = ExerciseOverloadData(
          exerciseName: name,
          muscleGroup: 'Geral',
          currentWeightKg: currentWeight,
          currentReps: 10,
          initialWeightKg: initialWeight,
          lastRpe: 8,
          weeklyVolumesKg: volumes,
        );
      }

      if (activePlan != null) {
        for (final split in activePlan.splits) {
          for (final ex in split.exercises) {
            final key = ex.name.toLowerCase().trim();
            if (!exerciseMap.containsKey(key)) {
              final prefs = await SharedPreferences.getInstance();
              final savedWeight = prefs.getDouble('pwa_last_weight_${effectiveStudentId}_$key') ??
                  prefs.getDouble('pwa_last_weight_default_$key') ?? 40.0;
              final reps = int.tryParse(ex.reps.split('-').first.replaceAll(RegExp(r'\D'), '')) ?? 10;
              exerciseMap[key] = ExerciseOverloadData(
                exerciseName: ex.name,
                muscleGroup: ex.targetMuscleGroup.isNotEmpty ? ex.targetMuscleGroup : split.splitName,
                currentWeightKg: savedWeight,
                currentReps: reps,
                initialWeightKg: (savedWeight * 0.85).roundToDouble(),
                lastRpe: 8,
                weeklyVolumesKg: [
                  (savedWeight * 0.85 * reps * ex.sets).roundToDouble(),
                  (savedWeight * 0.90 * reps * ex.sets).roundToDouble(),
                  (savedWeight * 0.95 * reps * ex.sets).roundToDouble(),
                  (savedWeight * reps * ex.sets).roundToDouble(),
                ],
              );
            } else {
              final existing = exerciseMap[key]!;
              if (ex.targetMuscleGroup.isNotEmpty) {
                exerciseMap[key] = ExerciseOverloadData(
                  exerciseName: existing.exerciseName,
                  muscleGroup: ex.targetMuscleGroup,
                  currentWeightKg: existing.currentWeightKg,
                  currentReps: existing.currentReps,
                  initialWeightKg: existing.initialWeightKg,
                  lastRpe: existing.lastRpe,
                  weeklyVolumesKg: existing.weeklyVolumesKg,
                );
              }
            }
          }
        }
      }

      if (exerciseMap.isNotEmpty && mounted) {
        setState(() {
          _catalog = exerciseMap.values.toList();
          if (widget.initialExerciseName != null) {
            final idx = _catalog.indexWhere((e) => e.exerciseName
                .toLowerCase()
                .contains(widget.initialExerciseName!.toLowerCase().trim()));
            _selectedExerciseIndex = idx >= 0 ? idx : 0;
          } else {
            _selectedExerciseIndex = 0;
          }
          _calcWeight = widget.initialWeight ?? _catalog[_selectedExerciseIndex].currentWeightKg;
          _calcReps = widget.initialReps ?? _catalog[_selectedExerciseIndex].currentReps;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUserSavedLoads() async {
    try {
      final effectiveStudentId = widget.studentId ?? AuthService.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      final key = effectiveStudentId != null
          ? 'pwa_last_weight_${effectiveStudentId}_${_catalog[_selectedExerciseIndex].exerciseName.toLowerCase().trim()}'
          : 'pwa_last_weight_default_${_catalog[_selectedExerciseIndex].exerciseName.toLowerCase().trim()}';
      final savedWeight = prefs.getDouble(key) ??
          prefs.getDouble('pwa_last_weight_default_${_catalog[_selectedExerciseIndex].exerciseName.toLowerCase().trim()}');
      if (savedWeight != null && savedWeight > 0 && mounted) {
        setState(() {
          _calcWeight = savedWeight;
        });
      }
    } catch (_) {}
  }

  double _computeEpley(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0.0;
    if (reps == 1) return weight;
    final val = weight * (1.0 + (reps / 30.0));
    return (val * 10).round() / 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF090D16) : Colors.white;
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final selected = _catalog[_selectedExerciseIndex];
    final oneRm = selected.estimatedOneRmEpley;
    final brzycki = selected.estimatedOneRmBrzycki;

    final overloadSuggestion = ProgressiveOverloadEngine.computeSuggestion(
      exerciseName: selected.exerciseName,
      targetMuscleGroup: selected.muscleGroup,
      currentWeight: selected.currentWeightKg,
      currentReps: selected.currentReps,
      previousWeight: selected.initialWeightKg,
      lastRpe: selected.lastRpe,
    );

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrasto
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabeçalho da Central
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: MetaColors.emerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Central de Sobrecarga & 1RM',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Métricas de Força Máxima & Curva de Volume',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Seletor horizontal de exercícios
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_catalog.length, (index) {
                    final item = _catalog[index];
                    final isSelected = index == _selectedExerciseIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.exerciseName),
                        selected: isSelected,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedExerciseIndex = index;
                            _calcWeight = item.currentWeightKg;
                            _calcReps = item.currentReps;
                          });
                        },
                        selectedColor: MetaColors.emerald,
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : subtextColor,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? MetaColors.emerald : border,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // 1. Card Hero de 1RM Estimado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MetaColors.emerald.withValues(alpha: 0.18),
                      cardBg,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '1RM TEÓRICO (EPLEY)',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  selected.muscleGroup,
                                  style: const TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${selected.strengthGainPercent}% Ganho Total',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${oneRm.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• Brzycki: ${brzycki.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Baseado na série de ${selected.currentWeightKg} kg para ${selected.currentReps} repetições com RPE ${selected.lastRpe}/10.',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tabela de Zonas de Intensidade (% 1RM)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildZoneItem(
                            label: 'FORÇA',
                            percent: '90%',
                            weight: '${(oneRm * 0.9).toStringAsFixed(1)} kg',
                            color: Colors.redAccent,
                          ),
                          _buildZoneItem(
                            label: 'HIPERTROFIA',
                            percent: '75%',
                            weight: '${(oneRm * 0.75).toStringAsFixed(1)} kg',
                            color: MetaColors.emerald,
                          ),
                          _buildZoneItem(
                            label: 'RESISTÊNCIA',
                            percent: '60%',
                            weight: '${(oneRm * 0.6).toStringAsFixed(1)} kg',
                            color: const Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Card da Meta Recomendada pela IA (Progressive Overload Engine)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Color(0xFF818CF8),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'META DE SOBRECARGA IA (PRÓXIMA SESSÃO)',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            overloadSuggestion.badge,
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Carga Atual',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '${selected.currentWeightKg} kg × ${selected.currentReps} reps',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: MetaColors.emerald,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Alvo da IA',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${overloadSuggestion.suggestedWeightKg} kg × ${overloadSuggestion.suggestedReps} reps',
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overloadSuggestion.rationale,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Gráfico de Volume Acumulado Semanal (kg)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bar_chart_rounded,
                          size: 18,
                          color: MetaColors.emerald,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'VOLUME TOTAL ACUMULADO (4 SEMANAS)',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(selected.weeklyVolumesKg.last / 1000).toStringAsFixed(1)}t nesta sem.',
                          style: const TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Barras de volume semanal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(
                        selected.weeklyVolumesKg.length,
                        (i) {
                          final vol = selected.weeklyVolumesKg[i];
                          final maxVol = selected.weeklyVolumesKg.reduce(max);
                          final double heightFactor = (vol / maxVol).clamp(0.2, 1.0);
                          final isCurrent =
                              i == selected.weeklyVolumesKg.length - 1;

                          return Column(
                            children: [
                              Text(
                                '${(vol / 1000).toStringAsFixed(1)}t',
                                style: TextStyle(
                                  color: isCurrent
                                      ? MetaColors.emerald
                                      : subtextColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 36,
                                height: 75 * heightFactor,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? MetaColors.emerald
                                      : MetaColors.emerald.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sem ${i + 1}',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Calculadora Interativa Rápida de 1RM
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIMULADOR DE 1RM',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Carga
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Carga: ${_calcWeight.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _calcWeight.clamp(5.0, 300.0),
                                min: 5.0,
                                max: 300.0,
                                divisions: 59,
                                activeColor: MetaColors.emerald,
                                onChanged: (v) {
                                  setState(() => _calcWeight = (v * 2).round() / 2);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Repetições
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reps: $_calcReps',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Slider(
                                value: _calcReps.toDouble().clamp(1.0, 20.0),
                                min: 1.0,
                                max: 20.0,
                                divisions: 19,
                                activeColor: const Color(0xFF38BDF8),
                                onChanged: (v) {
                                  setState(() => _calcReps = v.round());
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: Text(
                        '1RM Estimado: ${_computeEpley(_calcWeight, _calcReps)} kg',
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botão Concluir / Fechar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                  },
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
                    'Entendido • Focar na Sobrecarga',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  Widget _buildZoneItem({
    required String label,
    required String percent,
    required String weight,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          percent,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          weight,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: MetaColors.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
