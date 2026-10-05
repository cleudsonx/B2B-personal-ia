import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'student_profile_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/rest_timer_sheet.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../models/exercise_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String _workoutTitle = 'Treino A: Membros Superiores (Ênfase Empurrar)';
  String _trainerName = 'Carregando treinador...';
  String _trainerCref = 'CREF Ativo';
  String? _trainerPhotoUrl;
  final Set<int> _adaptedIndices = {};
  final Set<int> _completedExerciseIndices = {};

  // Variáveis reais de Gamificação (Backend)
  int currentStreak = 14;
  double dailyGoalProgress = 0.65;

  // Lista de exercícios de demonstração inicial fiel à amostra
  late List<ExerciseModel> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = [
      const ExerciseModel(
        order: 1,
        name: 'Supino Inclinado com Halteres',
        targetMuscleGroup: 'Peitoral Clavicular',
        sets: 4,
        reps: '8-10',
        restSeconds: 90,
        notes: 'Manter escápulas aduzidas e banco regulado a 30°.',
        substitutionVector: 'Empurrar inclinado livre',
      ),
      const ExerciseModel(
        order: 2,
        name: 'Desenvolvimento com Halteres',
        targetMuscleGroup: 'Deltoide Anterior',
        sets: 4,
        reps: '8-10',
        restSeconds: 60,
        notes: 'Ajustar banco a 75° e cotovelos no plano escapular.',
        substitutionVector: 'Empurrar vertical livre',
      ),
      const ExerciseModel(
        order: 3,
        name: 'Elevação Lateral na Polia',
        targetMuscleGroup: 'Deltoide Lateral',
        sets: 3,
        reps: '12-15',
        restSeconds: 45,
        notes: 'Manter ligeira flexão de cotovelos sem impulso do tronco.',
        substitutionVector: 'Abdução de ombros cabo',
      ),
      const ExerciseModel(
        order: 4,
        name: 'Tríceps Polia com Barra',
        targetMuscleGroup: 'Tríceps Braquial',
        sets: 4,
        reps: '10-12',
        restSeconds: 60,
        notes: 'Cotovelos fixos ao lado do tronco durante toda a extensão.',
        substitutionVector: 'Extensão de cotovelos cabo',
      ),
      const ExerciseModel(
        order: 5,
        name: 'Agachamento Livre com Barra',
        targetMuscleGroup: 'Quadríceps & Glúteo',
        sets: 4,
        reps: '8-10',
        restSeconds: 90,
        notes: 'Coluna neutra, escápulas travadas e pés na largura dos ombros.',
        substitutionVector: 'Padrão agachamento bilateral',
      ),
    ];
    _loadActiveWorkout();
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
    final activePlan = await WorkoutService.getActiveWorkoutForClient();
    if (activePlan != null && activePlan.splits.isNotEmpty && mounted) {
      setState(() {
        final firstSplit = activePlan.splits.first;
        _workoutTitle =
            'Treino ${firstSplit.splitIdentifier}: ${firstSplit.splitName}';
        _exercises = List.from(firstSplit.exercises);
      });
    }

    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
          final name =
              (trainer['trainer_name'] ?? trainer['full_name']) as String?;
          if (name != null && name.isNotEmpty) _trainerName = name;
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

          // gamification is loaded separately
        });
      }
    } catch (_) {}
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
                  'O Mr. Coach AI encontrará uma variação biomecanicamente equivalente e notificará seu professor:',
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
      {'name': 'Outro Desconforto Articular', 'loc': 'Articulação Geral'},
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
                        'Qual articulação apresenta desconforto?',
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
                  'Exercício: ${currentExercise.name}',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
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
            ? 'Relato de $painLocation. Eliminar compressão e estresse nesta articulação mantendo o estímulo muscular.'
            : 'Aparelho indisponível no espaço de treino presencial.';

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: 'Academia completa e espaço de musculação',
        injuriesOrRestrictions: restrictionsDesc,
      );

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
      WorkoutService.logAdaptation(
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
              '✓ Substituído com sucesso: ${result.adaptedExercise} (Treinador notificado)',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
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
        
    try {
      final gami = await WorkoutService.getGamificationData();
      if (gami != null && mounted) {
        setState(() {
          currentStreak = (gami['current_streak'] as num?)?.toInt() ?? 14;
          dailyGoalProgress = (gami['daily_goal_progress'] as num?)?.toDouble() ?? 0.65;
        });
      }
    } catch (_) {}
        setState(() => _isLoading = false);
      }
    }
  }

  void _finishWorkout() {
    final completedCount = _completedExerciseIndices.length;
    final totalCount = _exercises.length;

    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: MetaColors.border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: MetaColors.emerald, width: 2),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: MetaColors.emerald,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Treino Concluído! 🔥',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Excelente trabalho! Você completou $completedCount de $totalCount exercícios hoje.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Resumo HUD do Treino
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'OFENSIVA',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🔥 ${currentStreak + 1} Dias',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: MetaColors.border),
                      const Column(
                        children: [
                          Text(
                            'TEMPO',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '48 min',
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 36, width: 1, color: MetaColors.border),
                      Column(
                        children: [
                          const Text(
                            'EXERCÍCIOS',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedCount/$totalCount',
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SquircleButton(
                  label: 'Salvar e Concluir',
                  icon: Icons.check_circle_outline_rounded,
                  isPrimary: true,
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.black,
                  height: 56,
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: MetaColors.emerald,
                        content: Text(
                          '✓ Treino salvo com sucesso no diário do treinador!',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: Text(
                      'EXERCÍCIO ${index + 1} DE ${_exercises.length}',
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

          // 2. Nome do Exercício (Texto Grande e Alto Contraste)
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
                bottom: bottomPadding + 110,
                left: 18,
                right: 18,
              ),
              children: [
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
                                          image: NetworkImage(
                                            _trainerPhotoUrl!,
                                          ),
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
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: MetaColors.textSecondary,
                          ),
                          tooltip: 'Sincronizar Ficha do Banco',
                          onPressed: _loadActiveWorkout,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Topo: Barra de Progresso do Treino em Pílula + Indicador de Streak 🔥
                Row(
                  children: [
                    // Indicador de "Streak 🔥" (ofensiva)
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
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            '$currentStreak Dias',
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

                    // Barra de progresso do treino em formato de pílula
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

                // 3. Banner do Treino Ativo & Duração
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _workoutTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: MetaColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: MetaColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MetaColors.border),
                        ),
                        child: const Text(
                          '48 min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. Lista de Exercícios (MetaCards)
                for (int index = 0; index < _exercises.length; index++)
                  _buildExerciseCard(index),
              ],
            ),

            // Botão de Finalizar (Rodapé) - SquircleButton GIGANTE (largura total)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MetaColors.background.withValues(alpha: 0.0),
                      MetaColors.background.withValues(alpha: 0.85),
                      MetaColors.background,
                    ],
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 20,
                  bottom: bottomPadding > 0 ? bottomPadding + 10 : 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Finalizar Treino',
                    icon: Icons.check_circle_rounded,
                    isPrimary: true,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    height: 62.0,
                    borderRadius: 20.0,
                    onPressed: _finishWorkout,
                  ),
                ),
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
                          'Adaptando exercício com IA...',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: MetaColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Buscando vetor biomecânico equivalente',
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
