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
  String _trainerName = 'Prof. Roberto Mendes';
  String _trainerCref = 'CREF 019284';
  final Set<int> _adaptedIndices = {};
  int _currentCarouselIndex = 0;
  late final PageController _pageController;

  // Lista de exercícios de demonstração inicial fiel à amostra
  late List<ExerciseModel> _exercises;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _getAnatomicalImage(String exerciseName, String targetMuscle) {
    final name = exerciseName.toLowerCase();
    final muscle = targetMuscle.toLowerCase();

    if (name.contains('supino') || name.contains('peito') || name.contains('crucifixo') || muscle.contains('peitor')) {
      return 'assets/images/anatomical_chest.png';
    } else if (name.contains('desenvolvimento') || name.contains('elevacao') || name.contains('elevação') || name.contains('ombro') || muscle.contains('deltoid')) {
      return 'assets/images/anatomical_shoulders.png';
    } else if (name.contains('triceps') || name.contains('tríceps') || name.contains('biceps') || name.contains('bíceps') || name.contains('rosca') || muscle.contains('braco') || muscle.contains('braquial')) {
      return 'assets/images/anatomical_triceps.png';
    } else if (name.contains('agachamento') || name.contains('leg') || name.contains('extensora') || name.contains('quadr') || muscle.contains('perna') || muscle.contains('glúteo') || muscle.contains('gluteo')) {
      return 'assets/images/anatomical_legs.png';
    } else if (name.contains('puxada') || name.contains('remada') || name.contains('dorsal') || muscle.contains('costas') || muscle.contains('lat')) {
      return 'assets/images/anatomical_back.png';
    }
    return 'assets/images/anatomical_chest.png';
  }

  String _getEmgForExercise(String exerciseName) {
    final lower = exerciseName.toLowerCase();
    if (lower.contains('triceps') || lower.contains('tríceps')) return '96% EMG';
    if (lower.contains('elevacao') || lower.contains('elevação') || lower.contains('agachamento')) return '95% EMG';
    if (lower.contains('supino')) return '94% EMG';
    if (lower.contains('puxada')) return '93% EMG';
    return '92% EMG';
  }

  Future<void> _loadActiveWorkout() async {
    final activePlan = await WorkoutService.getActiveWorkoutForClient();
    if (activePlan != null && activePlan.splits.isNotEmpty && mounted) {
      setState(() {
        final firstSplit = activePlan.splits.first;
        _workoutTitle = 'Treino ${firstSplit.splitIdentifier}: ${firstSplit.splitName}';
        _exercises = List.from(firstSplit.exercises);
      });
    }

    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
          final name = trainer['full_name'] as String?;
          if (name != null && name.isNotEmpty) _trainerName = name;
          final reg = (trainer['cref_or_registry'] ?? trainer['cref'] ?? trainer['professional_document']) as String?;
          if (reg != null && reg.isNotEmpty) _trainerCref = reg;
        });
      }
    } catch (_) {}
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
                  'O Mr. Coach AI encontrará uma variação biomecanicamente equivalente e notificará seu professor:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Aparelho Ocupado / Fila no Espaço de Treino'),
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
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.orange),
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Qual articulação apresenta desconforto?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exercício: ${currentExercise.name}',
                  style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...locations.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.centerLeft,
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
                          const Icon(Icons.radio_button_checked, size: 16, color: Colors.orange),
                          const SizedBox(width: 10),
                          Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _executeAdaptation(int index, String reason, {String? painLocation}) async {
    setState(() => _isLoading = true);
    final target = _exercises[index];
    final restrictionsDesc = painLocation != null
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
          notes: '${result.notes}\n[Mr. Coach AI: ${result.biomechanicalRationale}]',
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
            backgroundColor: Colors.green.shade800,
            content: Text('✓ Substituído com sucesso: ${result.adaptedExercise} (Treinador notificado em tempo real)'),
            duration: const Duration(seconds: 4),
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
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              children: [
                // 1. Supervisor Header & Theme Switch Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/images/trainer_roberto_avatar.png',
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.emerald(context).withValues(alpha: 0.15),
                                  child: Icon(Icons.person_rounded, color: AppColors.emerald(context), size: 30),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 1,
                              right: 1,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B37E),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.bg(context), width: 2.2),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B37E),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00B37E).withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text(
                                      'Online',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supervisionado por',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subtext(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _trainerName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.text(context),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '($_trainerCref)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.subtext(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Theme Switcher & Actions
                    Row(
                      children: [
                        if (kDebugMode)
                          IconButton(
                            icon: const Icon(Icons.settings_ethernet_rounded, size: 20),
                            tooltip: 'Configurar IP do Servidor (Dev)',
                            onPressed: () => ServerConfigDialog.show(context),
                          ),
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, size: 20, color: AppColors.subtext(context)),
                          tooltip: 'Sincronizar Ficha do Banco',
                          onPressed: _loadActiveWorkout,
                        ),
                        const SizedBox(width: 4),
                        const ThemeToggleButton(),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Workout Split Duration Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _workoutTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '48 min',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Carousel Hero Card (PageView)
                SizedBox(
                  height: 380,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _exercises.length,
                    onPageChanged: (idx) {
                      setState(() => _currentCarouselIndex = idx);
                    },
                    itemBuilder: (ctx, index) {
                      final item = _exercises[index];
                      final isAdapted = _adaptedIndices.contains(index);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isAdapted
                                ? AppColors.tangerine(context)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            width: isAdapted ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black45 : const Color(0x0C0F172A),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left details column
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
                                          const SizedBox(width: 4),
                                          Text(
                                            'ADAPTADO POR MR. COACH',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.tangerine(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      height: 1.15,
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Micro-Pills
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _MicroPill(icon: Icons.repeat_rounded, label: '${item.sets} Séries'),
                                      _MicroPill(icon: Icons.fitness_center_rounded, label: '${item.reps} reps'),
                                      _MicroPill(icon: Icons.speed_rounded, label: 'Cadência 3-0-1-0'),
                                      _MicroPill(
                                        icon: Icons.timer_outlined,
                                        label: '${item.restSeconds}s Descanso',
                                        isTimer: true,
                                        onTap: () => RestTimerSheet.show(
                                          context,
                                          seconds: item.restSeconds,
                                          exerciseName: item.name,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Green Activation Capsule
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B37E),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00B37E).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.targetMuscleGroup,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          _getEmgForExercise(item.name),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.95),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Right 3D Model Column
                            SizedBox(
                              width: 125,
                              height: 235,
                              child: Image.asset(
                                _getAnatomicalImage(item.name, item.targetMuscleGroup),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => _AnatomicalMuscleCard(
                                  exerciseName: item.name,
                                  targetMuscle: item.targetMuscleGroup,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Dot Carousel Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_exercises.length, (idx) {
                    final isCurrent = idx == _currentCarouselIndex;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          idx,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrent ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF00B37E)
                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // 5. Bottom Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.card(context),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => BiomechanicalAnalysisSheet.show(
                          context,
                          exerciseName: _exercises[_currentCarouselIndex].name,
                        ),
                        child: Text(
                          'Raio-X & Fases',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.card(context),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => _showAdaptationModal(_currentCarouselIndex),
                        child: Text(
                          'Trocar Exercício',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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

// ---------------------------------------------------------------------------
// Card Anatômico 3D com Músculo Alvo em Ação & Eletromiografia
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
    Color glowColor = const Color(0xFF10B981); // Emerald default

    if (lower.contains('supino') || lower.contains('peito') || lower.contains('crucifixo')) {
      emg = 94;
      secondary = 'Deltoide Anterior, Tríceps Braquial';
      stabilizers = 'Manguito Rotador, Serrátil Anterior';
      glowColor = const Color(0xFF10B981); // Emerald
    } else if (lower.contains('desenvolvimento') || lower.contains('elevacao') || lower.contains('ombro')) {
      emg = 92;
      secondary = 'Tríceps Braquial, Trapézio Superior';
      stabilizers = 'Manguito Rotador, Core Abdominal';
      glowColor = const Color(0xFFF59E0B); // Amber
    } else if (lower.contains('triceps') || lower.contains('polia') || lower.contains('testa')) {
      emg = 96;
      secondary = 'Ancôneo, Extensores do Punho';
      stabilizers = 'Deltóide Posterior, Core';
      glowColor = const Color(0xFF06B6D4); // Cyan
    } else if (lower.contains('agachamento') || lower.contains('leg press') || lower.contains('extensora')) {
      emg = 95;
      secondary = 'Glúteo Máximo, Isquiotibiais';
      stabilizers = 'Core Abdominal, Eretores da Espinha';
      glowColor = const Color(0xFF10B981); // Emerald
    } else if (lower.contains('puxada') || lower.contains('remada') || lower.contains('costas')) {
      emg = 93;
      secondary = 'Bíceps Braquial, Braquiorradial';
      stabilizers = 'Trapézio Médio/Inferior, Romboides';
      glowColor = const Color(0xFF3B82F6); // Blue
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
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
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
                    child: Icon(Icons.biotech_rounded, size: 15, color: glowColor),
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
          // Anatomical Body Hologram Canvas
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
          // Muscle Role Breakdown
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
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: glowColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Agonista: $targetMuscle',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sinergistas: $secondary',
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFA78BFA), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Estabilizadores: $stabilizers',
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
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

// Custom Painter para Silhueta Anatômica com Músculo Alvo Iluminado
class _AnatomicalBodyPainter extends CustomPainter {
  final String exerciseType;
  final Color glowColor;

  _AnatomicalBodyPainter({
    required this.exerciseType,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Grid lines tecnológicas
    final gridPaint = Paint()
      ..color = const Color(0xFF161F33)
      ..strokeWidth = 0.8;
    for (double x = cx - 120; x <= cx + 120; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 25) {
      canvas.drawLine(Offset(cx - 120, y), Offset(cx + 120, y), gridPaint);
    }

    // Contorno da Silhueta Corporal (Cabeça, Ombros, Peito, Braços, Cintura)
    final bodyOutlinePaint = Paint()
      ..color = const Color(0xFF2D3748)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Cabeça
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 36), width: 22, height: 26),
      bodyOutlinePaint,
    );

    // Pescoço e Trapézio
    final trapPath = Path()
      ..moveTo(cx - 6, cy - 24)
      ..lineTo(cx - 24, cy - 14)
      ..lineTo(cx + 24, cy - 14)
      ..lineTo(cx + 6, cy - 24)
      ..close();
    canvas.drawPath(trapPath, bodyOutlinePaint);

    // Tronco e Cintura
    final torsoPath = Path()
      ..moveTo(cx - 28, cy - 14)
      ..lineTo(cx - 36, cy + 2) // Ombro esq
      ..lineTo(cx - 24, cy + 30) // Costela esq
      ..lineTo(cx - 18, cy + 50) // Quadril esq
      ..lineTo(cx + 18, cy + 50) // Quadril dir
      ..lineTo(cx + 24, cy + 30) // Costela dir
      ..lineTo(cx + 36, cy + 2) // Ombro dir
      ..lineTo(cx + 28, cy - 14)
      ..close();
    canvas.drawPath(torsoPath, bodyOutlinePaint);

    // Braços
    final leftArmPath = Path()
      ..moveTo(cx - 36, cy + 2)
      ..lineTo(cx - 44, cy + 24)
      ..lineTo(cx - 38, cy + 48);
    final rightArmPath = Path()
      ..moveTo(cx + 36, cy + 2)
      ..lineTo(cx + 44, cy + 24)
      ..lineTo(cx + 38, cy + 48);
    canvas.drawPath(leftArmPath, bodyOutlinePaint);
    canvas.drawPath(rightArmPath, bodyOutlinePaint);

    // Pintura e Iluminação do Músculo Ativo
    final muscleGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final muscleSolidPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill;

    final muscleBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (exerciseType.contains('supino') ||
        exerciseType.contains('peito') ||
        exerciseType.contains('crucifixo')) {
      // Peitoral Esquerdo
      final pecLeft = Path()
        ..moveTo(cx - 4, cy - 10)
        ..lineTo(cx - 26, cy - 6)
        ..quadraticBezierTo(cx - 28, cy + 12, cx - 18, cy + 16)
        ..quadraticBezierTo(cx - 6, cy + 15, cx - 4, cy + 6)
        ..close();
      // Peitoral Direito
      final pecRight = Path()
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

      // Fibras musculares internas do peitoral
      final fiberPaint = Paint()
        ..color = Colors.white38
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(cx - 6, cy - 5), Offset(cx - 20, cy - 2), fiberPaint);
      canvas.drawLine(Offset(cx - 6, cy + 2), Offset(cx - 22, cy + 6), fiberPaint);
      canvas.drawLine(Offset(cx + 6, cy - 5), Offset(cx + 20, cy - 2), fiberPaint);
      canvas.drawLine(Offset(cx + 6, cy + 2), Offset(cx + 22, cy + 6), fiberPaint);
    } else if (exerciseType.contains('desenvolvimento') ||
        exerciseType.contains('elevacao') ||
        exerciseType.contains('ombro')) {
      // Deltoide Esquerdo
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

      // Deltoide Direito
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
      // Braço e Tríceps Esquerdo
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 39, cy + 16), width: 10, height: 22),
          const Radius.circular(5),
        ),
        muscleGlowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx - 39, cy + 16), width: 10, height: 22),
          const Radius.circular(5),
        ),
        muscleSolidPaint,
      );

      // Braço e Tríceps Direito
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 39, cy + 16), width: 10, height: 22),
          const Radius.circular(5),
        ),
        muscleGlowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx + 39, cy + 16), width: 10, height: 22),
          const Radius.circular(5),
        ),
        muscleSolidPaint,
      );
    } else {
      // Grande Dorsal ou Core Central
      final centerCore = Path()
        ..moveTo(cx - 14, cy - 4)
        ..lineTo(cx + 14, cy - 4)
        ..lineTo(cx + 10, cy + 34)
        ..lineTo(cx - 10, cy + 34)
        ..close();
      canvas.drawPath(centerCore, muscleGlowPaint);
      canvas.drawPath(centerCore, muscleSolidPaint);
      canvas.drawPath(centerCore, muscleBorderPaint);
    }

    // Ponto indicador biomecânico com sensor
    final sensorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 16, cy + 4), 3, sensorPaint);
    canvas.drawCircle(Offset(cx + 16, cy + 4), 3, sensorPaint);
  }

  @override
  bool shouldRepaint(covariant _AnatomicalBodyPainter oldDelegate) {
    return oldDelegate.exerciseType != exerciseType || oldDelegate.glowColor != glowColor;
  }
}


