import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BiomechanicalAnalysisSheet extends StatefulWidget {
  final String exerciseName;
  final String? primaryMuscle;
  final VoidCallback? onAskAI;

  const BiomechanicalAnalysisSheet({
    super.key,
    required this.exerciseName,
    this.primaryMuscle,
    this.onAskAI,
  });

  static Future<void> show(
    BuildContext context, {
    required String exerciseName,
    String? primaryMuscle,
    VoidCallback? onAskAI,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BiomechanicalAnalysisSheet(
            exerciseName: exerciseName,
            primaryMuscle: primaryMuscle,
            onAskAI: onAskAI,
          ),
    );
  }

  @override
  State<BiomechanicalAnalysisSheet> createState() =>
      _BiomechanicalAnalysisSheetState();
}

class _BiomechanicalAnalysisSheetState extends State<BiomechanicalAnalysisSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPhase =
      0; // 0: Completo, 1: Excêntrica, 2: Isométrica, 3: Concêntrica
  double _animationProgress = 0.0;
  Timer? _ticker;

  // Biomechanical database lookup
  late final _ExerciseBiomechanicsData _data;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _data = _getBiomechanicsData(widget.exerciseName);

    // Continuous cadence animation (3s excentric + 1s isometric + 1s concentric = 5s cycle)
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _animationProgress = (_animationProgress + 0.01) % 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  _ExerciseBiomechanicsData _getBiomechanicsData(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('supino') &&
        (lower.contains('inclinado') || lower.contains('halteres'))) {
      return const _ExerciseBiomechanicsData(
        title: 'Supino Inclinado com Halteres',
        targetMuscle: 'Peitoral Maior (Fibras Claviculares)',
        secondaryMuscles: 'Deltoide Anterior, Tríceps Braquial',
        stabilizers: 'Manguito Rotador, Serrátil Anterior, Core',
        jointAngleCue: 'Cotovelos a 45° - 60° em relação ao tronco',
        criticalError:
            'Projetar os ombros à frente (perder a retração escapular)',
        tempoCadence: '3s descida • 1s transição • 1s subida',
        emgTarget: 92,
        emgSecondary: 68,
        emgStabilizers: 45,
        eccentricCue:
            'Desça abrindo o peito lentamente sem tocar os halteres nos ombros.',
        isometricCue:
            'Pausa controlada na máxima extensão sem relaxar as escápulas.',
        concentricCue:
            'Suba convergindo levemente os halteres sem bater no topo.',
      );
    } else if (lower.contains('agachamento') || lower.contains('búlgaro')) {
      return const _ExerciseBiomechanicsData(
        title: 'Agachamento Búlgaro',
        targetMuscle: 'Quadríceps & Glúteo Máximo',
        secondaryMuscles: 'Isquiotibiais, Adutores',
        stabilizers: 'Core, Glúteo Médio (Estabilizador Pélvico)',
        jointAngleCue: 'Tronco ligeiramente inclinado (~15°) para focar glúteo',
        criticalError:
            'Valgo dinâmico (joelho colapsando para dentro) ou calcanhar saindo do chão',
        tempoCadence: '3s descida • 1s pausa inferior • 1.5s subida',
        emgTarget: 95,
        emgSecondary: 72,
        emgStabilizers: 82,
        eccentricCue:
            'Flexione o joelho da frente descendo a pelve na vertical sem tombar.',
        isometricCue:
            'Mantenha a tíbia estável e o quadril nivelado no ponto mais baixo.',
        concentricCue:
            'Empurre o solo com o calcanhar ativando a cadeia posterior.',
      );
    } else if (lower.contains('leg press')) {
      return const _ExerciseBiomechanicsData(
        title: 'Leg Press 45°',
        targetMuscle: 'Quadríceps (Vasto Lateral e Reto Femoral)',
        secondaryMuscles: 'Glúteo Máximo, Adutor Magno',
        stabilizers: 'Eretores da Espinha, Core Abdominal',
        jointAngleCue:
            'Joelho a 90° no ponto de reversão sem retroversão pélvica',
        criticalError:
            'Tirar o quadril/sacro do encosto (flexão lombar severa sob carga)',
        tempoCadence: '3s descida • 0s pausa • 1.5s subida sem hiperestensão',
        emgTarget: 90,
        emgSecondary: 65,
        emgStabilizers: 50,
        eccentricCue:
            'Controle a plataforma resistindo à gravidade até os joelhos atingirem 90°.',
        isometricCue:
            'Inversão suave sem permitir que a lombar descole do assento.',
        concentricCue:
            'Estenda os joelhos sem travá-los no topo para proteger a patela.',
      );
    } else if (lower.contains('puxada') || lower.contains('lat')) {
      return const _ExerciseBiomechanicsData(
        title: 'Puxada Alta (Lat Pulldown)',
        targetMuscle: 'Latíssimo do Dorso (Grande Dorsal)',
        secondaryMuscles: 'Bíceps Braquial, Braquiorradial, Redondo Maior',
        stabilizers: 'Trapézio Médio/Inferior, Romboides, Core',
        jointAngleCue: 'Puxada em direção à fúrcula esternal com tronco a ~10°',
        criticalError:
            'Puxar atrás da nuca ou usar balanço excessivo de coluna lombar',
        tempoCadence:
            '1.5s puxada • 1s contração isométrica • 3s subida controlada',
        emgTarget: 94,
        emgSecondary: 60,
        emgStabilizers: 55,
        eccentricCue:
            'Permita o alongamento das dorsais sem deixar os ombros subirem nas orelhas.',
        isometricCue:
            'Aperte os cotovelos contra os bolsos das calças por 1 segundo.',
        concentricCue:
            'Inicie o movimento deprimindo as escápulas antes de flexionar os cotovelos.',
      );
    } else {
      return _ExerciseBiomechanicsData(
        title: name,
        targetMuscle: widget.primaryMuscle ?? 'Grupo Muscular Primário',
        secondaryMuscles: 'Sinergistas e Auxiliares',
        stabilizers: 'Core e Estabilizadores Articulares',
        jointAngleCue:
            'Alinhamento articular neutro com respeito à anatomia individual',
        criticalError:
            'Compensação postural por excesso de carga ou velocidade balística',
        tempoCadence: '3s excêntrica • 1s transição • 1s concêntrica',
        emgTarget: 88,
        emgSecondary: 62,
        emgStabilizers: 48,
        eccentricCue:
            'Fase de controle excêntrico: acumule energia elástica e preserve a tensão.',
        isometricCue: 'Transição suave sem tranco articular.',
        concentricCue:
            'Aplique força contra a carga com máxima intenção motora.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
          left: BorderSide(color: Color(0xFF1E293B), width: 1),
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.studentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.studentCyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.biotech_rounded,
                    color: AppColors.studentCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _data.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.trainerEmerald.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _data.targetMuscle.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.trainerEmerald,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '• Split-View IA',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Bar (Split-View Toggle)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.studentCyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.studentCyan.withValues(alpha: 0.6),
                ),
              ),
              labelColor: AppColors.studentCyan,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.play_circle_outline_rounded, size: 18),
                  text: '1. Execução & Fases',
                ),
                Tab(
                  iconMargin: EdgeInsets.only(bottom: 2),
                  icon: Icon(Icons.visibility_rounded, size: 18),
                  text: '2. Raio-X Anatômico',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExecutionAndPhasesTab(),
                _buildAnatomicalXRayTab(),
              ],
            ),
          ),

          // Bottom Action Bar (Perguntar à IA)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF070B12),
              border: Border(top: BorderSide(color: Color(0xFF161E2E))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.trainerIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.smart_toy_outlined, size: 18),
                    label: const Text(
                      'Tirar Dúvida de Execução com IA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      if (widget.onAskAI != null) {
                        widget.onAskAI!();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: Execução em Vídeo/GIF & Fases do Movimento
  // --------------------------------------------------------------------------
  Widget _buildExecutionAndPhasesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Simulated Video / Looping Biomechanical Player
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: const Color(0xFF030712),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.studentCyan.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.studentCyan.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated Motion Simulation Grid
              CustomPaint(
                size: const Size(double.infinity, 190),
                painter: _BiomechanicalMotionPainter(
                  progress: _animationProgress,
                  accentColor: AppColors.studentCyan,
                ),
              ),
              // Live Looping Badge
              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.redAccent,
                        size: 10,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'LOOP DE EXECUÇÃO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Cadence Floating Badge
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.studentAmber.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    _data.tempoCadence,
                    style: const TextStyle(
                      color: AppColors.studentAmber,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Center Exercise Label & Vector Avatar
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.studentCyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.studentCyan,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.studentCyan,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cadência Controlada • Ângulo Seguro',
                      style: TextStyle(
                        color: AppColors.textMuted.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Rhythm Progress Bar at bottom of player
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                  child: LinearProgressIndicator(
                    value: _animationProgress,
                    minHeight: 4,
                    color: AppColors.studentCyan,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Phase Selector Tabs
        Row(
          children: [
            _buildPhaseChip('Tudo', 0),
            const SizedBox(width: 6),
            _buildPhaseChip('Excêntrica (Descida)', 1),
            const SizedBox(width: 6),
            _buildPhaseChip('Isometria', 2),
            const SizedBox(width: 6),
            _buildPhaseChip('Concêntrica (Subida)', 3),
          ],
        ),
        const SizedBox(height: 14),

        // Dynamic Phase Instruction Card
        _buildPhaseDetailCard(),
        const SizedBox(height: 12),

        // Biomechanical Checklist Cards
        _buildChecklistCard(
          icon: Icons.track_changes_rounded,
          iconColor: AppColors.studentCyan,
          title: 'Alinhamento & Ângulo Articular',
          description: _data.jointAngleCue,
        ),
        const SizedBox(height: 8),
        _buildChecklistCard(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.studentAmber,
          title: 'Erro Crítico a Evitar',
          description: _data.criticalError,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildPhaseChip(String label, int index) {
    final isSelected = _selectedPhase == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPhase = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.studentCyan.withValues(alpha: 0.18)
                    : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected ? AppColors.studentCyan : const Color(0xFF1F2937),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color:
                  isSelected ? AppColors.studentCyan : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseDetailCard() {
    String title;
    String cue;
    Color accent;
    IconData icon;

    switch (_selectedPhase) {
      case 1:
        title = 'Fase Excêntrica (Alongamento sob Tensão)';
        cue = _data.eccentricCue;
        accent = AppColors.studentCyan;
        icon = Icons.south_rounded;
        break;
      case 2:
        title = 'Ponto de Transição / Isometria Zero';
        cue = _data.isometricCue;
        accent = AppColors.studentAmber;
        icon = Icons.pause_circle_outline_rounded;
        break;
      case 3:
        title = 'Fase Concêntrica (Pico de Contração)';
        cue = _data.concentricCue;
        accent = AppColors.trainerEmerald;
        icon = Icons.north_rounded;
        break;
      default:
        title = 'Ciclo Motor Completo';
        cue = '${_data.eccentricCue} ${_data.concentricCue}';
        accent = AppColors.trainerIndigo;
        icon = Icons.sync_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cue,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: Raio-X Anatômico & Alavancas Biomecânicas
  // --------------------------------------------------------------------------
  Widget _buildAnatomicalXRayTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        // Anatomical Body Hologram Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B132B), Color(0xFF070B12)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.trainerEmerald.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.trainerEmerald.withValues(alpha: 0.08),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MAPA DE ATIVAÇÃO MUSCULAR',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.trainerEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Eletromiografia (EMG)',
                      style: TextStyle(
                        color: AppColors.trainerEmerald,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Muscle Legend Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem('Agonista Primário', Colors.redAccent),
                  _buildLegendItem('Sinergistas', AppColors.studentCyan),
                  _buildLegendItem('Estabilizadores', AppColors.trainerEmerald),
                ],
              ),
              const SizedBox(height: 18),

              // EMG Distribution Bars
              _buildEmgBar(
                muscleName: _data.targetMuscle,
                percentage: _data.emgTarget,
                barColor: Colors.redAccent,
                label: 'Agonista (Foco Principal)',
              ),
              const SizedBox(height: 10),
              _buildEmgBar(
                muscleName: _data.secondaryMuscles,
                percentage: _data.emgSecondary,
                barColor: AppColors.studentCyan,
                label: 'Sinergistas Auxiliares',
              ),
              const SizedBox(height: 10),
              _buildEmgBar(
                muscleName: _data.stabilizers,
                percentage: _data.emgStabilizers,
                barColor: AppColors.trainerEmerald,
                label: 'Estabilização Postural',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Biomechanical Moment Arm Insights
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.architecture_rounded,
                    color: AppColors.studentCyan,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Braço de Momento & Força Articular',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'O pico de torque muscular ocorre no terço médio da amplitude de movimento. Mantenha os estabilizadores rígidos para transferir 100% da carga sobre o músculo-alvo sem sobrecarregar as cápsulas articulares.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    color: AppColors.trainerEmerald,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sobrecarga articular: Baixa a Moderada com execução padrão',
                    style: TextStyle(
                      color: AppColors.trainerEmerald.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmgBar({
    required String muscleName,
    required int percentage,
    required Color barColor,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                muscleName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$percentage% EMG',
              style: TextStyle(
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100.0,
            minHeight: 6,
            color: barColor,
            backgroundColor: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

// Data holder for exercise biomechanics
class _ExerciseBiomechanicsData {
  final String title;
  final String targetMuscle;
  final String secondaryMuscles;
  final String stabilizers;
  final String jointAngleCue;
  final String criticalError;
  final String tempoCadence;
  final int emgTarget;
  final int emgSecondary;
  final int emgStabilizers;
  final String eccentricCue;
  final String isometricCue;
  final String concentricCue;

  const _ExerciseBiomechanicsData({
    required this.title,
    required this.targetMuscle,
    required this.secondaryMuscles,
    required this.stabilizers,
    required this.jointAngleCue,
    required this.criticalError,
    required this.tempoCadence,
    required this.emgTarget,
    required this.emgSecondary,
    required this.emgStabilizers,
    required this.eccentricCue,
    required this.isometricCue,
    required this.concentricCue,
  });
}

// Custom Painter for animated motion simulation in loop
class _BiomechanicalMotionPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  _BiomechanicalMotionPainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF161E2E)
          ..strokeWidth = 1.0;

    // Grid lines
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Dynamic wave/arc simulating range of motion
    final wavePaint =
        Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(40, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3 + (progress * 20),
      size.width - 40,
      size.height * 0.7,
    );
    canvas.drawPath(path, wavePaint);

    // Glowing point tracking the rep position
    final pointPaint =
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;

    final x = 40 + (size.width - 80) * progress;
    final y =
        size.height * 0.7 -
        (size.height * 0.35 * (1 - (progress - 0.5).abs() * 2));
    canvas.drawCircle(Offset(x, y), 5, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _BiomechanicalMotionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
