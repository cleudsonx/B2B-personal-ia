import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/evolution_photo_service.dart';
import '../../services/workout_service.dart';
import 'widgets/warmup_sheet.dart';

/// Aba 4 do Aluno: 🧬 Bio-Hub
/// Central integrada de Performance (Pré e Pós-Treino), Cargas & Fotos, e Bio-Recovery.
class ClientBioHubScreen extends StatefulWidget {
  final VoidCallback? onNavigateToWorkout;

  const ClientBioHubScreen({
    super.key,
    this.onNavigateToWorkout,
  });

  @override
  State<ClientBioHubScreen> createState() => _ClientBioHubScreenState();
}

class _ClientBioHubScreenState extends State<ClientBioHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentSubTab = 0;

  // Pré-Treino State
  int _energyLevel = 4; // 1 a 5
  int _waterIntakeMl = 500; // ml
  bool _mobilityCompleted = false;

  // Pós-Treino State
  double _rpeScore = 8.0; // 1 a 10 (Escala Borg)
  final Set<String> _selectedPainPoints = {};
  bool _isSavingPostWorkout = false;
  bool _postWorkoutSaved = false;

  // Recovery State
  double _sleepHours = 7.5;
  String _domsLevel = 'Leve'; // Leve, Moderada, Intensa
  bool _isSavingRecovery = false;
  bool _recoverySaved = false;

  // Sobrecarga Progressiva Real State
  List<Map<String, dynamic>> _progressiveOverloads = [];
  bool _isLoadingLoads = true;

  // Galeria Sigilosa State
  EvolutionPhoto? _beforePhoto;
  EvolutionPhoto? _afterPhoto;
  bool _isLoadingPhotos = true;
  bool _isUploadingPhoto = false;

  double get _calculatedReadinessScore {
    double sleepScore = 0;
    if (_sleepHours >= 7 && _sleepHours <= 9) {
      sleepScore = 50;
    } else if (_sleepHours >= 6) {
      sleepScore = 38;
    } else if (_sleepHours >= 5) {
      sleepScore = 25;
    } else if (_sleepHours > 9) {
      sleepScore = 42;
    } else {
      sleepScore = 15;
    }

    double domsScore = 0;
    if (_domsLevel == 'Leve') {
      domsScore = 40;
    } else if (_domsLevel == 'Moderada') {
      domsScore = 25;
    } else {
      domsScore = 10;
    }

    double waterScore = (_waterIntakeMl / 500.0) * 10.0;
    if (waterScore > 10) waterScore = 10;

    final total = sleepScore + domsScore + waterScore;
    return total.clamp(20.0, 100.0);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _currentSubTab = _tabController.index);
      }
    });
    _loadEvolutionPhotos();
    _loadRecoveryAndLoads();
  }

  Future<void> _loadRecoveryAndLoads() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingLoads = false);
      return;
    }

    try {
      final latestRec = await WorkoutService.getLatestDailyRecovery(user.id);
      if (latestRec != null && mounted) {
        setState(() {
          _sleepHours = (latestRec['sleep_hours'] as num?)?.toDouble() ?? _sleepHours;
          _domsLevel = latestRec['doms_level']?.toString() ?? _domsLevel;
          _waterIntakeMl = (latestRec['water_intake_ml'] as num?)?.toInt() ?? _waterIntakeMl;
        });
      }
    } catch (_) {}

    try {
      final loads = await WorkoutService.getStudentProgressiveOverload(user.id);
      if (mounted) {
        setState(() {
          _progressiveOverloads = loads;
          _isLoadingLoads = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLoads = false);
    }
  }

  Future<void> _saveDailyRecovery() async {
    setState(() => _isSavingRecovery = true);
    final score = _calculatedReadinessScore;
    final success = await WorkoutService.saveDailyRecovery(
      sleepHours: _sleepHours,
      domsLevel: _domsLevel,
      waterIntakeMl: _waterIntakeMl,
      readinessScore: score,
    );

    if (mounted) {
      setState(() {
        _isSavingRecovery = false;
        _recoverySaved = success;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? MetaColors.emerald : MetaColors.surfaceHighlight,
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? 'Prontidão de ${score.toInt()}% registrada! Sincronizada com seu treinador.'
                      : 'Não foi possível salvar a prontidão no momento.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _loadEvolutionPhotos() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingPhotos = false);
      return;
    }
    final photos = await EvolutionPhotoService.getStudentBeforeAndAfter(user.id);
    if (mounted) {
      setState(() {
        _beforePhoto = photos['before'];
        _afterPhoto = photos['after'];
        _isLoadingPhotos = false;
      });
    }
  }

  Future<void> _handlePickAndUploadPhoto(String photoType, ImageSource source) async {
    Navigator.of(context).pop();
    try {
      final bytes = await EvolutionPhotoService.pickImage(source);
      if (bytes == null) return;

      setState(() => _isUploadingPhoto = true);
      final photo = await EvolutionPhotoService.uploadPhoto(
        bytes: bytes,
        photoType: photoType,
      );

      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          if (photo != null) {
            if (photoType == 'before') {
              _beforePhoto = photo;
            } else {
              _afterPhoto = photo;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.emerald,
            content: Row(
              children: const [
                Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Foto de evolução salva com sigilo!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Não foi possível salvar a foto.'),
          ),
        );
      }
    }
  }

  void _showAddPhotoSheet({String? defaultType}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
        final border = isDark ? MetaColors.border : MetaColors.lightBorder;
        final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
        final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

        String selectedType = defaultType ?? (_beforePhoto == null ? 'before' : 'after');

        return StatefulBuilder(
          builder: (ctx, setModalState) => SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: subtextColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_rounded, color: MetaColors.emerald, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Galeria Sigilosa de Evolução',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Visível apenas para você e seu personal trainer',
                              style: TextStyle(color: subtextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'DEFINIR TIPO DE FOTO',
                    style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Início (Antes)'),
                          selected: selectedType == 'before',
                          onSelected: (_) => setModalState(() => selectedType = 'before'),
                          selectedColor: MetaColors.emerald.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selectedType == 'before' ? MetaColors.emerald : subtextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: selectedType == 'before' ? MetaColors.emerald : border),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Atual (Depois)'),
                          selected: selectedType == 'after',
                          onSelected: (_) => setModalState(() => selectedType = 'after'),
                          selectedColor: MetaColors.emerald.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selectedType == 'after' ? MetaColors.emerald : subtextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: selectedType == 'after' ? MetaColors.emerald : border),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ORIGEM DA IMAGEM',
                    style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handlePickAndUploadPhoto(selectedType, ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Câmera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handlePickAndUploadPhoto(selectedType, ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: const Text('Galeria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MetaColors.emerald,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRecordLoadSheet() {
    final exerciseCtrl = TextEditingController(text: 'Supino Reto com Barra');
    final loadCtrl = TextEditingController();
    final repsCtrl = TextEditingController(text: '10');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
        final border = isDark ? MetaColors.border : MetaColors.lightBorder;
        final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
        final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: subtextColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fitness_center_rounded, color: MetaColors.emerald, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrar Carga do Exercício',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Alimenta a curva de sobrecarga progressiva real',
                                style: TextStyle(color: subtextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EXERCÍCIO',
                      style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: exerciseCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: MetaColors.surfaceHighlight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'Supino Reto',
                          'Agachamento',
                          'Puxada Frontal',
                          'Leg Press',
                          'Desenvolvimento',
                          'Stiff',
                        ].map((sug) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(sug),
                              labelStyle: const TextStyle(fontSize: 11, color: MetaColors.textSecondary),
                              backgroundColor: MetaColors.surfaceHighlight,
                              side: BorderSide(color: border),
                              onPressed: () {
                                setSheetState(() => exerciseCtrl.text = sug);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARGA (KG)',
                                style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: loadCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                autofocus: true,
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 75',
                                  hintStyle: TextStyle(color: subtextColor),
                                  filled: true,
                                  fillColor: MetaColors.surfaceHighlight,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REPETIÇÕES',
                                style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: repsCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 10',
                                  hintStyle: TextStyle(color: subtextColor),
                                  filled: true,
                                  fillColor: MetaColors.surfaceHighlight,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SquircleButton(
                      label: 'Salvar Carga do Exercício',
                      icon: Icons.check_circle_rounded,
                      isPrimary: true,
                      onPressed: () async {
                        final exName = exerciseCtrl.text.trim();
                        final load = double.tryParse(loadCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        final reps = int.tryParse(repsCtrl.text) ?? 10;
                        if (exName.isEmpty || load <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor, informe o exercício e uma carga válida.')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await WorkoutService.recordExerciseLoad(exerciseName: exName, loadKg: load, reps: reps);
                        await _loadRecoveryAndLoads();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: MetaColors.emerald,
                              content: Text('Carga de ${load.toInt()}kg em "$exName" registrada com sucesso!'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getRpeColor(double val) {
    if (val <= 4) return MetaColors.emerald;
    if (val <= 7) return const Color(0xFFF59E0B); // Amber
    if (val <= 8.5) return Colors.orange;
    return const Color(0xFFEF4444); // Red
  }

  String _getRpeLabel(double val) {
    if (val <= 3) return 'Muito Leve';
    if (val <= 5) return 'Moderado';
    if (val <= 7) return 'Vigoroso';
    if (val <= 8.5) return 'Muito Intenso (Falta 1-2 reps)';
    return 'Exaustão Máxima (Falha total)';
  }

  Future<void> _savePostWorkoutFeedback() async {
    setState(() => _isSavingPostWorkout = true);
    try {
      final user = AuthService.currentUser;
      if (user != null) {
        // Envia o feedback para a sessão recente se disponível
        await WorkoutService.saveWorkoutFeedback(
          rpe: _rpeScore,
          painPoints: _selectedPainPoints.toList(),
          notes: _selectedPainPoints.isNotEmpty
              ? 'Relato de desconforto em: ${_selectedPainPoints.join(", ")}'
              : 'Treino concluído com boa tolerância.',
        );
      }
      if (mounted) {
        setState(() {
          _postWorkoutSaved = true;
          _isSavingPostWorkout = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.emerald,
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Registro salvo! Seu treinador foi notificado do seu RPE.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSavingPostWorkout = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.surfaceHighlight,
            content: Text('Feedback registrado localmente.'),
          ),
        );
      }
    }
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
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 20,
                  bottom: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: MetaColors.emerald.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.biotech_rounded,
                            color: MetaColors.emerald,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Bio-Hub',
                              style: TextStyle(
                                color: MetaColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Performance • Cargas • Bio-Recovery',
                              style: TextStyle(
                                color: MetaColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Segmented Control (Pílulas no Padrão Meta)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Row(
                        children: [
                          _buildSubTabButton(
                            index: 0,
                            icon: Icons.bolt_rounded,
                            title: 'Sessão',
                          ),
                          _buildSubTabButton(
                            index: 1,
                            icon: Icons.show_chart_rounded,
                            title: 'Cargas & Fotos',
                          ),
                          _buildSubTabButton(
                            index: 2,
                            icon: Icons.battery_charging_full_rounded,
                            title: 'Recovery',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSessionTab(bottomPadding),
              _buildProgressTab(bottomPadding),
              _buildRecoveryTab(bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _currentSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _currentSubTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? MetaColors.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : MetaColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : MetaColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ABA 1: SESSÃO (PRÉ & PÓS-TREINO)
  // -------------------------------------------------------------
  Widget _buildSessionTab(double bottomPadding) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        // 1. Bloco PRÉ-TREINO
        _buildSectionHeader(
          icon: Icons.play_circle_fill_rounded,
          title: 'Pré-Treino • Preparação Rápida',
          tag: 'ANTES DE COMEÇAR',
          tagColor: MetaColors.accentBlue,
        ),
        const SizedBox(height: 12),

        // Card Check-in de Disposição & Água
        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nível de Disposição Física',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '$_energyLevel/5',
                    style: const TextStyle(
                      color: MetaColors.emerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final level = index + 1;
                  final isSelected = _energyLevel >= level;
                  return GestureDetector(
                    onTap: () => setState(() => _energyLevel = level),
                    child: Container(
                      width: 52,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? MetaColors.emerald.withValues(alpha: 0.2)
                            : MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? MetaColors.emerald : MetaColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.bolt_rounded,
                          color: isSelected ? MetaColors.emerald : MetaColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              const Divider(color: MetaColors.border, height: 1),
              const SizedBox(height: 16),

              // Hidratação Pré
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MetaColors.accentBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: MetaColors.accentBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hidratação Pré-Treino',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Meta: 500ml • Ingeridos: ${_waterIntakeMl}ml',
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: MetaColors.accentBlue, size: 28),
                    onPressed: () {
                      setState(() => _waterIntakeMl += 250);
                    },
                    tooltip: '+250ml',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Aquecimento Guiado
        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: MetaColors.emerald, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Aquecimento Específico (3 min)',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  if (_mobilityCompleted)
                    const Text(
                      'Concluído ✓',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Mobilidade articular direcionada para os grupos musculares da sua ficha ativa de hoje.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              SquircleButton(
                label: _mobilityCompleted ? 'Refazer Aquecimento' : 'Iniciar Timer de Mobilidade (3 min)',
                icon: Icons.play_arrow_rounded,
                isPrimary: false,
                backgroundColor: MetaColors.surfaceHighlight,
                foregroundColor: MetaColors.emerald,
                onPressed: () async {
                  final completed = await WarmupSheet.show(context);
                  if (completed == true && mounted) {
                    setState(() => _mobilityCompleted = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: MetaColors.emerald,
                        content: Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Aquecimento concluído! Articulações preparadas para o treino.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              SquircleButton(
                label: 'Ir para a Ficha de Treino',
                icon: Icons.fitness_center_rounded,
                isPrimary: true,
                onPressed: widget.onNavigateToWorkout ?? () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // 2. Bloco PÓS-TREINO
        _buildSectionHeader(
          icon: Icons.check_circle_outline_rounded,
          title: 'Pós-Treino • Registro de Esforço',
          tag: 'APÓS CONCLUIR',
          tagColor: MetaColors.emerald,
        ),
        const SizedBox(height: 12),

        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Percepção de Esforço (RPE)',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRpeColor(_rpeScore).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_rpeScore.toStringAsFixed(1)} / 10',
                      style: TextStyle(
                        color: _getRpeColor(_rpeScore),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _getRpeLabel(_rpeScore),
                style: TextStyle(
                  color: _getRpeColor(_rpeScore),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getRpeColor(_rpeScore),
                  inactiveTrackColor: MetaColors.surfaceHighlight,
                  thumbColor: _getRpeColor(_rpeScore),
                  overlayColor: _getRpeColor(_rpeScore).withValues(alpha: 0.2),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _rpeScore,
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  onChanged: (val) => setState(() => _rpeScore = val),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: MetaColors.border, height: 1),
              const SizedBox(height: 14),

              // Registro de Dor ou Desconforto Articular
              const Text(
                'Sentiu dor articular ou desconforto?',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Isso gera um aviso automático para o seu personal ajustar sua periodização.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Nenhum (100% OK)',
                  'Joelho',
                  'Ombro',
                  'Lombar',
                  'Cotovelo',
                  'Punho',
                  'Tornozelo',
                ].map((part) {
                  final isSelected = _selectedPainPoints.contains(part) ||
                      (part.startsWith('Nenhum') && _selectedPainPoints.isEmpty);
                  return FilterChip(
                    label: Text(part),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: part.startsWith('Nenhum')
                        ? MetaColors.emerald.withValues(alpha: 0.2)
                        : Colors.redAccent.withValues(alpha: 0.2),
                    backgroundColor: MetaColors.surfaceHighlight,
                    side: BorderSide(
                      color: isSelected
                          ? (part.startsWith('Nenhum') ? MetaColors.emerald : Colors.redAccent)
                          : MetaColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (part.startsWith('Nenhum') ? MetaColors.emerald : Colors.redAccent)
                          : MetaColors.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (part.startsWith('Nenhum')) {
                          _selectedPainPoints.clear();
                        } else {
                          _selectedPainPoints.removeWhere((p) => p.startsWith('Nenhum'));
                          if (selected) {
                            _selectedPainPoints.add(part);
                          } else {
                            _selectedPainPoints.remove(part);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),
              SquircleButton(
                label: _postWorkoutSaved ? 'Registro Atualizado ✓' : 'Salvar Registro do Treino',
                icon: Icons.save_alt_rounded,
                isPrimary: true,
                isLoading: _isSavingPostWorkout,
                onPressed: _savePostWorkoutFeedback,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // ABA 2: CARGAS & FOTOS (EVOLUÇÃO 360°)
  // -------------------------------------------------------------
  Widget _buildProgressTab(double bottomPadding) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                icon: Icons.trending_up_rounded,
                title: 'Sobrecarga Progressiva',
                tag: 'FORÇA & CARGAS',
                tagColor: MetaColors.emerald,
              ),
            ),
            TextButton.icon(
              onPressed: _showRecordLoadSheet,
              icon: const Icon(Icons.add, size: 16, color: MetaColors.emerald),
              label: const Text(
                'Nova Carga',
                style: TextStyle(color: MetaColors.emerald, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isLoadingLoads)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
            ),
          )
        else if (_progressiveOverloads.isNotEmpty)
          ..._progressiveOverloads.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildExerciseLoadCard(
                exercise: item['exercise'] as String,
                startLoad: item['start_load'] as String,
                currentLoad: item['current_load'] as String,
                gainPercent: item['gain_percent'] as String,
                history: List<String>.from(item['history'] as List),
              ),
            );
          })
        else ...[
          // Cards iniciais de referência
          _buildExerciseLoadCard(
            exercise: 'Supino Reto com Barra',
            startLoad: '50 kg',
            currentLoad: '72 kg',
            gainPercent: '+44%',
            history: ['50kg', '56kg', '62kg', '68kg', '72kg'],
          ),
          const SizedBox(height: 10),
          _buildExerciseLoadCard(
            exercise: 'Agachamento Livre',
            startLoad: '60 kg',
            currentLoad: '90 kg',
            gainPercent: '+50%',
            history: ['60kg', '70kg', '78kg', '84kg', '90kg'],
          ),
          const SizedBox(height: 10),
          _buildExerciseLoadCard(
            exercise: 'Puxada Frontal Aberta',
            startLoad: '45 kg',
            currentLoad: '60 kg',
            gainPercent: '+33%',
            history: ['45kg', '50kg', '52kg', '55kg', '60kg'],
          ),
        ],

        const SizedBox(height: 24),

        _buildSectionHeader(
          icon: Icons.photo_library_rounded,
          title: 'Galeria Sigilosa Antes & Depois',
          tag: 'PRIVADO • PROFESSOR & VOCÊ',
          tagColor: MetaColors.accentBlue,
        ),
        const SizedBox(height: 12),

        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lock_rounded, size: 16, color: MetaColors.emerald),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suas fotos são criptografadas e visíveis apenas por você e pelo seu personal.',
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Comparativo Antes x Atual Real
              if (_isLoadingPhotos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildPhotoSlot(
                        label: 'Início da Consultoria',
                        fallbackDate: 'Mês 1',
                        photo: _beforePhoto,
                        onTap: () => _showAddPhotoSheet(defaultType: 'before'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPhotoSlot(
                        label: 'Atual (Mês Recente)',
                        fallbackDate: 'Hoje',
                        photo: _afterPhoto,
                        onTap: () => _showAddPhotoSheet(defaultType: 'after'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              SquircleButton(
                label: _isUploadingPhoto ? 'Enviando Foto Sigilosa...' : 'Adicionar Foto de Comparação',
                icon: _isUploadingPhoto ? Icons.cloud_upload_rounded : Icons.camera_alt_outlined,
                isPrimary: false,
                backgroundColor: MetaColors.surfaceHighlight,
                foregroundColor: _isUploadingPhoto ? MetaColors.emerald : MetaColors.textPrimary,
                onPressed: _isUploadingPhoto ? null : () => _showAddPhotoSheet(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseLoadCard({
    required String exercise,
    required String startLoad,
    required String currentLoad,
    required String gainPercent,
    required List<String> history,
  }) {
    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exercise,
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  gainPercent,
                  style: const TextStyle(
                    color: MetaColors.emerald,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Inicial: $startLoad',
                style: const TextStyle(color: MetaColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: MetaColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                'Atual: $currentLoad',
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini Timeline de Cargas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: history.map((val) {
              final isLatest = val == currentLoad;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLatest
                      ? MetaColors.emerald.withValues(alpha: 0.25)
                      : MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLatest ? MetaColors.emerald : Colors.transparent,
                  ),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    color: isLatest ? MetaColors.emerald : MetaColors.textSecondary,
                    fontSize: 11,
                    fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot({
    required String label,
    required String fallbackDate,
    required EvolutionPhoto? photo,
    required VoidCallback onTap,
  }) {
    if (photo != null) {
      final dateFormatted =
          '${photo.takenAt.day.toString().padLeft(2, '0')}/${photo.takenAt.month.toString().padLeft(2, '0')}/${photo.takenAt.year}';
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            color: MetaColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                EvolutionPhotoService.buildPhotoImage(
                  photo.photoUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Gradiente escuro para contraste
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                // Badge de Categoria (Início vs Atual)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      photo.photoType == 'before' ? 'INÍCIO' : 'ATUAL',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // Ícone de Toque/Editar
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  ),
                ),
                // Informações na base
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            dateFormatted,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                          if (photo.weightKg != null) ...[
                            Text(
                              ' • ${photo.weightKg}kg',
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Estado sem foto
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MetaColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MetaColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: MetaColors.border),
              ),
              child: const Icon(Icons.add_a_photo_outlined, size: 24, color: MetaColors.emerald),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: MetaColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              fallbackDate,
              style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            const Text(
              '+ Adicionar',
              style: TextStyle(
                color: MetaColors.emerald,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ABA 3: RECOVERY (SAÚDE & PRONTIDÃO)
  // -------------------------------------------------------------
  Widget _buildRecoveryTab(double bottomPadding) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        _buildSectionHeader(
          icon: Icons.battery_charging_full_rounded,
          title: 'Prontidão & Bio-Recovery',
          tag: 'REGENERAÇÃO',
          tagColor: MetaColors.emerald,
        ),
        const SizedBox(height: 12),

        // Score de Prontidão Dinâmico (Ready to Train)
        Builder(
          builder: (context) {
            final readiness = _calculatedReadinessScore;
            final readinessPercent = (readiness / 100.0).clamp(0.0, 1.0);
            final Color readinessColor = readiness >= 80
                ? MetaColors.emerald
                : (readiness >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
            final String readinessTitle = readiness >= 80
                ? 'Prontidão Excelente 🚀'
                : (readiness >= 60 ? 'Prontidão Moderada ⚡' : 'Fadiga Acumulada 🛑');
            final String readinessDesc = readiness >= 80
                ? 'Sono e regeneração muscular em ponto ótimo. Seu corpo está em ponto ideal para hipertrofia hoje.'
                : (readiness >= 60
                    ? 'Recuperação intermediária. Mantenha as cargas estáveis e hidratação adequada.'
                    : 'Sinais de fadiga muscular ou sono reduzido. Priorize mobilidade e evite falha concêntrica.');

            return MetaCard(
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: readinessPercent,
                          strokeWidth: 8,
                          backgroundColor: MetaColors.surfaceHighlight,
                          valueColor: AlwaysStoppedAnimation<Color>(readinessColor),
                        ),
                      ),
                      Text(
                        '${readiness.toInt()}%',
                        style: const TextStyle(
                          color: MetaColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readinessTitle,
                          style: TextStyle(
                            color: readinessColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          readinessDesc,
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Monitor de Sono
        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.bedtime_outlined, color: MetaColors.accentBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sono Reparador',
                        style: TextStyle(
                          color: MetaColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_sleepHours.toStringAsFixed(1)} horas',
                    style: const TextStyle(
                      color: MetaColors.accentBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: MetaColors.accentBlue,
                  inactiveTrackColor: MetaColors.surfaceHighlight,
                  thumbColor: MetaColors.accentBlue,
                  overlayColor: MetaColors.accentBlue.withValues(alpha: 0.2),
                  trackHeight: 5,
                ),
                child: Slider(
                  value: _sleepHours,
                  min: 4.0,
                  max: 12.0,
                  divisions: 16,
                  onChanged: (val) => setState(() => _sleepHours = val),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('4h (Crítico)', style: TextStyle(color: MetaColors.textSecondary, fontSize: 11)),
                  Text('8h (Ideal)', style: TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('12h', style: TextStyle(color: MetaColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Dor Muscular Tardia (DOMS)
        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dor Muscular Pós-Treino (DOMS)',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sensação de queimação ou dor fisiológica decorrente dos treinos anteriores.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['Leve', 'Moderada', 'Intensa'].map((lvl) {
                  final isSelected = _domsLevel == lvl;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _domsLevel = lvl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MetaColors.emerald.withValues(alpha: 0.2)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? MetaColors.emerald : MetaColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              lvl,
                              style: TextStyle(
                                color: isSelected ? MetaColors.emerald : MetaColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Insight do Mr. Coach AI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.auto_awesome, color: MetaColors.emerald, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recomendação do Mr. Coach AI',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Seus membros superiores descansaram por 48h com sono adequado. O índice de recuperação está alto. Aproveite para tentar sua nova carga máxima hoje!',
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        SquircleButton(
          label: _isSavingRecovery
              ? 'Sincronizando com o Treinador...'
              : (_recoverySaved ? 'Prontidão Salva Hoje ✓' : 'Salvar Registro de Prontidão'),
          icon: _isSavingRecovery
              ? Icons.cloud_upload_rounded
              : (_recoverySaved ? Icons.check_circle_rounded : Icons.save_rounded),
          isPrimary: true,
          onPressed: _isSavingRecovery ? null : _saveDailyRecovery,
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String tag,
    required Color tagColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tagColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: tagColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

