import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/rest_timer_sheet.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../models/exercise_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/workout_service.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _workoutTitle = 'Treino A - Peito e Tríceps';
  final Set<int> _adaptedIndices = {};

  // Lista de exercícios de demonstração inicial
  late List<ExerciseModel> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = [
      const ExerciseModel(
        order: 1,
        name: 'Supino Reto com Barra',
        targetMuscleGroup: 'Peitoral Maior',
        sets: 4,
        reps: '8-10',
        restSeconds: 90,
        notes: 'Manter escápulas aduzidas e descer até a linha do esterno.',
        substitutionVector: 'Empurrar horizontal livre',
      ),
      const ExerciseModel(
        order: 2,
        name: 'Desenvolvimento Máquina Articulada',
        targetMuscleGroup: 'Deltoide Anterior/Lateral',
        sets: 3,
        reps: '10-12',
        restSeconds: 60,
        notes: 'Ajustar altura do banco para que as pegadas fiquem na linha do queixo.',
        substitutionVector: 'Empurrar vertical guiado',
      ),
      const ExerciseModel(
        order: 3,
        name: 'Tríceps Polia com Barra Reta',
        targetMuscleGroup: 'Tríceps Braquial',
        sets: 4,
        reps: '12-15',
        restSeconds: 45,
        notes: 'Cotovelos fixos ao lado do tronco durante toda a extensão.',
        substitutionVector: 'Extensão de cotovelos cabo',
      ),
    ];
    _loadActiveWorkout();
  }

  Future<void> _loadActiveWorkout() async {
    final activePlan = await WorkoutService.getActiveWorkoutForClient();
    if (activePlan != null && activePlan.splits.isNotEmpty && mounted) {
      setState(() {
        final firstSplit = activePlan.splits.first;
        _workoutTitle = 'Treino ${firstSplit.splitIdentifier} - ${firstSplit.splitName}';
        _exercises = List.from(firstSplit.exercises);
      });
    }
  }

  void _showAdaptationModal(int exerciseIndex) {
    final currentExercise = _exercises[exerciseIndex];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Substituir: ${currentExercise.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'A IA encontrará uma variação biomecanicamente idêntica ou mais confortável:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Aparelho Ocupado / Fila'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeAdaptation(exerciseIndex, 'Aparelho Ocupado / Fila');
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.health_and_safety_outlined, color: Colors.orange),
                  label: const Text(
                    'Desconforto ou Dor Articular',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeAdaptation(exerciseIndex, 'Desconforto ou Dor Articular');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeAdaptation(int index, String reason) async {
    setState(() => _isLoading = true);
    final target = _exercises[index];

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: 'Academia completa',
        injuriesOrRestrictions: 'Histórico de leve desconforto no ombro',
      );

      setState(() {
        _adaptedIndices.add(index);
        _exercises[index] = target.copyWith(
          name: result.adaptedExercise,
          sets: result.sets,
          reps: result.reps,
          restSeconds: result.restSeconds,
          notes: '${result.notes}\n[IA: ${result.biomechanicalRationale}]',
        );
      });

      WorkoutService.logAdaptation(
        originalExercise: target.name,
        adaptedExercise: result.adaptedExercise,
        reason: reason,
        details: result.toJson(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('Substituído com sucesso: ${result.adaptedExercise}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Erro ao adaptar exercício: $e'),
            action: SnackBarAction(
              label: 'Mudar IP',
              textColor: Colors.yellow,
              onPressed: () => ServerConfigDialog.show(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _workoutTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.text(context),
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Configurar IP do Servidor (Dev)',
              onPressed: () => ServerConfigDialog.show(context),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.subtext(context)),
            tooltip: 'Sincronizar Ficha do Banco',
            onPressed: _loadActiveWorkout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // 1. Humanized Personal Trainer Header Card
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder(context)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : const Color(0x0A0F172A),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.emerald(context).withValues(alpha: 0.15),
                          child: Icon(
                            Icons.person_rounded,
                            color: AppColors.emerald(context),
                            size: 28,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: AppColors.emerald(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.card(context), width: 2.2),
                            ),
                          ),
                        ),
                      ],
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
                                  'Prof. Roberto Mendes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 14, color: AppColors.accentBlue(context)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'CREF 019284-G/SP • Prescrição Biomecânica Ativa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.subtext(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBg(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.emerald(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.emerald(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Split Duration Hero Banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.accentBlue(context)),
                        const SizedBox(width: 8),
                        Text(
                          _workoutTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pillBg(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.pillBorder(context)),
                      ),
                      child: Text(
                        '48 min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Exercise Cards List
              ...List.generate(_exercises.length, (index) {
                final item = _exercises[index];
                final isAdapted = _adaptedIndices.contains(index);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAdapted ? AppColors.tangerine(context) : AppColors.cardBorder(context),
                      width: isAdapted ? 1.8 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : const Color(0x080F172A),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Exercise Name & AI Adapted Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isAdapted)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.tangerineBg(context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.tangerine(context).withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 12, color: AppColors.tangerine(context)),
                                        const SizedBox(width: 5),
                                        Text(
                                          'ADAPTADO NO SALÃO POR IA',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                            color: AppColors.tangerine(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  '${item.order}. ${item.name}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.emeraldBg(context),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.biotech_rounded, size: 12, color: AppColors.emerald(context)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item.targetMuscleGroup} • 94% EMG',
                                            style: TextStyle(
                                              color: AppColors.emerald(context),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Micro-Pills Row: Séries, Reps, Cadência, Descanso
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MicroPill(
                            icon: Icons.repeat_rounded,
                            label: '${item.sets} Séries',
                          ),
                          _MicroPill(
                            icon: Icons.fitness_center_rounded,
                            label: '${item.reps} reps',
                          ),
                          _MicroPill(
                            icon: Icons.speed_rounded,
                            label: 'Cadência 3-0-1-0',
                          ),
                          _MicroPill(
                            icon: Icons.timer_outlined,
                            label: '${item.restSeconds}s descanso',
                            isTimer: true,
                            onTap: () => RestTimerSheet.show(
                              context,
                              seconds: item.restSeconds,
                              exerciseName: item.name,
                            ),
                          ),
                        ],
                      ),

                      // Posture Cues / Notes
                      if (item.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg(context).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.pillBorder(context).withValues(alpha: 0.7)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.subtext(context)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.notes,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.subtext(context),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Bottom Tactile Actions Row
                      Row(
                        children: [
                          // Left: Biomechanical Analysis Button (Split-View & Raio-X)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                side: BorderSide(color: AppColors.accentBlue(context).withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppColors.accentBlue(context).withValues(alpha: 0.08),
                              ),
                              onPressed: () => BiomechanicalAnalysisSheet.show(
                                context,
                                exerciseName: item.name,
                              ),
                              icon: Icon(Icons.biotech_rounded, size: 16, color: AppColors.accentBlue(context)),
                              label: Text(
                                'Raio-X & Fases',
                                style: TextStyle(
                                  color: AppColors.accentBlue(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right: Fast Adaptation Button (Salão)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tangerine(context),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _showAdaptationModal(index),
                              icon: const Icon(Icons.bolt_rounded, size: 16),
                              label: const Text(
                                'Trocar Exercício',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald(context).withValues(alpha: 0.15),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald(context)),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Adaptando exercício com IA...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buscando vetor biomecânico equivalente',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MicroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTimer;
  final VoidCallback? onTap;

  const _MicroPill({
    required this.icon,
    required this.label,
    this.isTimer = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isTimer
            ? AppColors.tangerineBg(context)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTimer
              ? AppColors.tangerine(context).withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isTimer ? AppColors.tangerine(context) : AppColors.subtext(context),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isTimer ? AppColors.tangerine(context) : AppColors.text(context),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: pillWidget,
      );
    }
    return pillWidget;
  }
}

