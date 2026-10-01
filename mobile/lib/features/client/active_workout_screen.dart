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
  String _trainerName = 'Carregando treinador...';
  String _trainerCref = 'CREF Ativo';
  final Set<int> _adaptedIndices = {};
  int _currentCarouselIndex = 0;
  late final PageController _pageController;

  // Lista de exercícios de demonstração inicial fiel à amostra
  late List<ExerciseModel> _exercises;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
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

  String _getTrainerInitials() {
    final clean = _trainerName.replaceAll('Prof.', '').replaceAll('Carregando...', '').trim();
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

    if (name.contains('supino') || name.contains('peito') || name.contains('crucifixo') || muscle.contains('peitor')) {
      return 'assets/images/biomech_3d_chest.jpg';
    } else if (name.contains('desenvolvimento') || name.contains('elevacao') || name.contains('elevação') || name.contains('ombro') || muscle.contains('deltoid')) {
      return 'assets/images/biomech_3d_shoulders.jpg';
    } else if (name.contains('triceps') || name.contains('tríceps') || name.contains('biceps') || name.contains('bíceps') || name.contains('rosca') || muscle.contains('braco') || muscle.contains('braquial')) {
      return 'assets/images/biomech_3d_arms.jpg';
    } else if (name.contains('agachamento') || name.contains('leg') || name.contains('extensora') || name.contains('quadr') || muscle.contains('perna') || muscle.contains('glúteo') || muscle.contains('gluteo')) {
      return 'assets/images/biomech_3d_legs.jpg';
    } else if (name.contains('puxada') || name.contains('remada') || name.contains('dorsal') || muscle.contains('costas') || muscle.contains('lat')) {
      return 'assets/images/biomech_3d_back.jpg';
    }
    return 'assets/images/biomech_3d_chest.jpg';
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
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.emerald(context),
                                    AppColors.accentBlue(context),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emerald(context).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _getTrainerInitials(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -1,
                              right: -1,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5A3),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.bg(context), width: 2.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00E5A3).withValues(alpha: 0.45),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 13,
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
                  height: 505,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _exercises.length,
                    onPageChanged: (idx) {
                      setState(() => _currentCarouselIndex = idx);
                    },
                    itemBuilder: (ctx, index) {
                      final item = _exercises[index];
                      final isAdapted = _adaptedIndices.contains(index);
                      final isCurrent = index == _currentCarouselIndex;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : AppColors.card(context),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isAdapted
                                ? AppColors.tangerine(context)
                                : (isCurrent
                                    ? const Color(0xFF00E5A3)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                            width: (isCurrent || isAdapted) ? 2.0 : 1.2,
                          ),
                          boxShadow: [
                            if (isCurrent)
                              BoxShadow(
                                color: const Color(0xFF00E5A3).withValues(alpha: 0.16),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            BoxShadow(
                              color: isDark ? Colors.black54 : const Color(0x0C0F172A),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Top Tags: Exercise Order & Target Muscle EMG Pill
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'EXERCÍCIO ${index + 1} DE ${_exercises.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5A3).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF00E5A3), width: 1.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF00E5A3)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${item.targetMuscleGroup.toUpperCase()} • ${_getEmgForExercise(item.name)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF00E5A3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 2. Full-Width Exercise Name (No broken words!)
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                height: 1.2,
                                color: AppColors.text(context),
                              ),
                            ),
                            if (isAdapted) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.tangerineBg(context),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 11, color: AppColors.tangerine(context)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'ADAPTADO POR MR. COACH AI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.tangerine(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),

                            // 3. 3D Biomechanical Visual Stage (High-Fidelity Render)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => BiomechanicalAnalysisSheet.show(
                                  context,
                                  exerciseName: item.name,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFCBD5E1),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          _getAnatomicalImage(item.name, item.targetMuscleGroup),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _AnatomicalMuscleCard(
                                            exerciseName: item.name,
                                            targetMuscle: item.targetMuscleGroup,
                                          ),
                                        ),
                                        // Gradient shading overlay
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.70),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Floating Badge on Bottom Left
                                        Positioned(
                                          left: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white24, width: 0.8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.view_in_ar_rounded, size: 13, color: Color(0xFF00E5A3)),
                                                SizedBox(width: 5),
                                                Text(
                                                  '3D Biomecânica & EMG',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Hint on Bottom Right
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00E5A3).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Toque p/ Raio-X',
                                                  style: TextStyle(
                                                    color: Color(0xFF00E5A3),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 3),
                                                Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF00E5A3)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 4. HUD Telemetry Stat Grid (4 Expanded columns - Zero Clipping!)
                            Row(
                              children: [
                                Expanded(
                                  child: _HudStatTile(
                                    label: 'Séries',
                                    value: '${item.sets}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _HudStatTile(
                                    label: 'Reps',
                                    value: item.reps,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _HudStatTile(
                                    label: 'Cadência',
                                    value: '3-0-1-0',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _HudStatTile(
                                    label: 'Descanso',
                                    value: '${item.restSeconds}s',
                                    icon: Icons.timer_outlined,
                                    onTap: () => RestTimerSheet.show(
                                      context,
                                      seconds: item.restSeconds,
                                      exerciseName: item.name,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // 5. Execution Tip / Notes
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.tips_and_updates_outlined, size: 14, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.25,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                              ? const Color(0xFF00E5A3)
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
                          backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
                          side: const BorderSide(
                            color: Color(0xFF00BCD4), // cyan / neon teal border
                            width: 1.6,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        onPressed: () => BiomechanicalAnalysisSheet.show(
                          context,
                          exerciseName: _exercises[_currentCarouselIndex].name,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.biotech_rounded, size: 18, color: Color(0xFF38BDF8)),
                            SizedBox(width: 6),
                            Text(
                              'Raio-X & Fases',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        onPressed: () => _showAdaptationModal(_currentCarouselIndex),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 18, color: isDark ? Colors.white70 : AppColors.text(context)),
                            const SizedBox(width: 6),
                            Text(
                              'Trocar Exercício',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.text(context),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.8) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: const Color(0xFF00E5A3)),
                const SizedBox(width: 3),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
              color: isDark ? Colors.white : const Color(0xFF0F172A),
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


