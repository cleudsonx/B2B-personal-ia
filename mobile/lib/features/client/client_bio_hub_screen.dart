import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/split_photo_slider.dart';
import '../../core/widgets/student_weekly_checkin_sheet.dart';
import '../../services/auth_service.dart';
import '../../services/body_metrics_service.dart';
import '../../services/evolution_photo_service.dart';
import '../../services/workout_service.dart';
import 'welcome_onboarding_screen.dart';
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

  // Histórico & Linha do Tempo de Anamnese State
  List<Map<String, dynamic>> _anamnesisHistory = [];
  bool _isLoadingAnamnesisHistory = true;

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
  bool _useSplitSlider = true;

  // Medidas Corporais & Antropometria State
  List<BodyMetricsRecord> _metricsHistory = [];
  bool _isLoadingMetrics = true;

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
    _loadAnamnesisHistory();
    _loadBodyMetrics();
  }

  Future<void> _loadBodyMetrics() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingMetrics = false);
      return;
    }
    try {
      final list = await BodyMetricsService.getMetricsHistory(user.id);
      if (mounted) {
        setState(() {
          _metricsHistory = list;
          _isLoadingMetrics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMetrics = false);
    }
  }

  Future<void> _loadAnamnesisHistory() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAnamnesisHistory = false);
      return;
    }
    try {
      final list = await WorkoutService.getStudentAnamnesisHistory(user.id);
      if (mounted) {
        setState(() {
          _anamnesisHistory = list;
          _isLoadingAnamnesisHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnamnesisHistory = false);
    }
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

  void _showAddMetricsSheet() {
    final latest = _metricsHistory.isNotEmpty ? _metricsHistory.first : null;
    double weight = latest?.weightKg ?? 75.0;
    double height = latest?.heightCm ?? 175.0;
    double? bodyFat = latest?.bodyFatPct;
    double waist = latest?.waistCm ?? 82.0;
    double hip = latest?.hipCm ?? 96.0;
    double chest = latest?.chestCm ?? 100.0;
    double armRight = latest?.armRightCm ?? 36.0;
    double thighRight = latest?.thighRightCm ?? 56.0;
    final notesCtrl = TextEditingController();

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
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: SingleChildScrollView(
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
                          child: const Icon(Icons.straighten_rounded, color: MetaColors.emerald, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registrar Medidas Corporais',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                'Bio-Hub 2.0 • Sincronizado com seu treinador',
                                style: TextStyle(color: subtextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Peso e Altura
                    _buildStepperField(
                      title: 'Peso Corporal (kg)',
                      value: weight,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => weight = val),
                    ),
                    const SizedBox(height: 10),
                    _buildStepperField(
                      title: 'Altura (cm)',
                      value: height,
                      step: 1.0,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => height = val),
                    ),
                    const SizedBox(height: 10),
                    // Circunferências
                    _buildStepperField(
                      title: 'Cintura / Abdômen (cm)',
                      value: waist,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => waist = val),
                    ),
                    const SizedBox(height: 10),
                    _buildStepperField(
                      title: 'Quadril (cm)',
                      value: hip,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => hip = val),
                    ),
                    const SizedBox(height: 10),
                    _buildStepperField(
                      title: 'Braço Direito (cm)',
                      value: armRight,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => armRight = val),
                    ),
                    const SizedBox(height: 10),
                    _buildStepperField(
                      title: 'Coxa Direita (cm)',
                      value: thighRight,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => thighRight = val),
                    ),
                    const SizedBox(height: 10),
                    _buildStepperField(
                      title: 'Tórax / Peito (cm)',
                      value: chest,
                      step: 0.5,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      border: border,
                      onChanged: (val) => setSheetState(() => chest = val),
                    ),
                    const SizedBox(height: 20),
                    SquircleButton(
                      label: 'Salvar Medições de Hoje',
                      icon: Icons.check_circle_rounded,
                      isPrimary: true,
                      height: 48,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final saved = await BodyMetricsService.saveMetrics(
                          weightKg: weight,
                          heightCm: height,
                          waistCm: waist,
                          hipCm: hip,
                          chestCm: chest,
                          armRightCm: armRight,
                          thighRightCm: thighRight,
                          bodyFatPct: bodyFat,
                          notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                        );
                        if (saved != null && mounted) {
                          setState(() {
                            _metricsHistory.removeWhere((r) => r.id == saved.id);
                            _metricsHistory.insert(0, saved);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: MetaColors.emerald,
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Medições registradas! Peso: ${weight.toStringAsFixed(1)} kg • IMC ${saved.bmi?.toStringAsFixed(1) ?? "--"}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildStepperField({
    required String title,
    required double value,
    required double step,
    required Color textColor,
    required Color subtextColor,
    required Color border,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: MetaColors.emerald),
                onPressed: () => onChanged((value - step).clamp(10.0, 300.0)),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 54),
                child: Text(
                  value.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: MetaColors.emerald),
                onPressed: () => onChanged((value + step).clamp(10.0, 300.0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRecordLoadSheet({String? defaultExercise}) {
    final exerciseCtrl = TextEditingController(text: defaultExercise ?? '');
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
                        hintText: 'Ex: Supino Reto, Agachamento Livre...',
                        hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.6)),
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
        // Bloco 1: Linha do Tempo & Evolução das Metas / Anamnese
        _buildAnamnesisEvolutionSection(),
        const SizedBox(height: 24),

        // Bloco 1.2: Check-in Semanal com Foto & Peso
        _buildWeeklyCheckinCard(),
        const SizedBox(height: 24),

        // Bloco 1.4: Telemetria de Saúde & Conectores Vitais (Apple Health / Health Connect)
        const HealthMetricsCard(),
        const SizedBox(height: 24),

        // Bloco 1.5: Medidas Corporais & Antropometria (Bio-Hub 2.0)
        _buildBodyMetricsSection(),
        const SizedBox(height: 24),

        // Bloco 2: Sobrecarga Progressiva
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
        else if (_progressiveOverloads.isNotEmpty) ...[
          if (_progressiveOverloads.every((e) => e['is_baseline'] == true))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: MetaColors.emerald, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exercícios da sua ficha ativa carregados como Marco Inicial. Conclua seus treinos no Modo Foco para calcular a progressão de carga (%) automaticamente.',
                        style: TextStyle(color: MetaColors.text(context), fontSize: 11.5, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          }),
        ] else
          MetaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.trending_up_rounded, color: MetaColors.emerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Curva de Sobrecarga em Calibração',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Assim que você concluir treinos no Modo Foco ou registrar uma carga inicial, sua progressão real de força aparecerá aqui.',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Registrar Primeira Carga',
                    icon: Icons.add_circle_outline_rounded,
                    isPrimary: true,
                    onPressed: _showRecordLoadSheet,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Bloco 2.5: Conquistas & Selos de Força (Gamificação)
        MetaCard(
          onTap: () => StudentAchievementsModalSheet.show(context),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Galeria de Conquistas & Selos de Força',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Desbloqueie marcos de 1RM, tonelagem e hábitos',
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFF59E0B),
                size: 22,
              ),
            ],
          ),
        ),
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
              // Comparativo Antes x Atual Real com Split Slider
              if (_isLoadingPhotos)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                  ),
                )
              else if (_beforePhoto != null && _afterPhoto != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _useSplitSlider = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _useSplitSlider ? MetaColors.emerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 14, color: _useSplitSlider ? Colors.white : MetaColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Split-Slider',
                                    style: TextStyle(
                                      color: _useSplitSlider ? Colors.white : MetaColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => setState(() => _useSplitSlider = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_useSplitSlider ? MetaColors.emerald : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.view_column_rounded, size: 14, color: !_useSplitSlider ? Colors.white : MetaColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lado a Lado',
                                    style: TextStyle(
                                      color: !_useSplitSlider ? Colors.white : MetaColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_useSplitSlider)
                  SplitPhotoSlider(
                    beforeImageUrl: _beforePhoto!.photoUrl,
                    afterImageUrl: _afterPhoto!.photoUrl,
                    beforeLabel: 'Início',
                    afterLabel: 'Atual',
                    beforeWeightKg: _beforePhoto!.weightKg,
                    afterWeightKg: _afterPhoto!.weightKg,
                    beforeDate: _beforePhoto!.takenAt,
                    afterDate: _afterPhoto!.takenAt,
                    height: 380,
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
              ] else
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

  Widget _buildBodyMetricsSection() {
    final latest = _metricsHistory.isNotEmpty ? _metricsHistory.first : null;
    final initial = _metricsHistory.length > 1 ? _metricsHistory.last : latest;

    double? weightDelta;
    if (latest?.weightKg != null && initial?.weightKg != null && _metricsHistory.length > 1) {
      weightDelta = latest!.weightKg! - initial!.weightKg!;
    }

    double? waistDelta;
    if (latest?.waistCm != null && initial?.waistCm != null && _metricsHistory.length > 1) {
      waistDelta = latest!.waistCm! - initial!.waistCm!;
    }

    double? armDelta;
    if (latest?.armRightCm != null && initial?.armRightCm != null && _metricsHistory.length > 1) {
      armDelta = latest!.armRightCm! - initial!.armRightCm!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                icon: Icons.straighten_rounded,
                title: 'Medidas Corporais & Antropometria',
                tag: 'BIO-HUB 2.0',
                tagColor: MetaColors.emerald,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddMetricsSheet,
              icon: const Icon(Icons.add, size: 16, color: MetaColors.emerald),
              label: const Text(
                'Novas Medidas',
                style: TextStyle(color: MetaColors.emerald, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isLoadingMetrics)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
            ),
          )
        else if (latest == null)
          MetaCard(
            child: Column(
              children: [
                const Icon(Icons.straighten_rounded, color: MetaColors.emerald, size: 36),
                const SizedBox(height: 10),
                const Text(
                  'Acompanhe sua Evolução Corporal',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Registre peso, altura e circunferências para visualizar a redução de gordura e ganho de massa magra.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MetaColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                SquircleButton(
                  label: 'Registrar Primeira Medição',
                  icon: Icons.add_chart_rounded,
                  isPrimary: true,
                  height: 44,
                  onPressed: _showAddMetricsSheet,
                ),
              ],
            ),
          )
        else
          MetaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ÚLTIMO CHECK-IN',
                          style: TextStyle(color: MetaColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${latest.measuredAt.day.toString().padLeft(2, '0')}/${latest.measuredAt.month.toString().padLeft(2, '0')}/${latest.measuredAt.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (latest.bmi != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4), width: 0.8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.speed_rounded, size: 14, color: MetaColors.emerald),
                            const SizedBox(width: 5),
                            Text(
                              'IMC ${latest.bmi!.toStringAsFixed(1)} • ${latest.bmiCategory}',
                              style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Grid de métricas principais
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Peso Atual',
                        value: latest.weightKg != null ? '${latest.weightKg!.toStringAsFixed(1)} kg' : '--',
                        delta: weightDelta != null ? '${weightDelta > 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg' : null,
                        deltaColor: (weightDelta != null && weightDelta < 0) ? MetaColors.emerald : Colors.amber,
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Cintura',
                        value: latest.waistCm != null ? '${latest.waistCm!.toStringAsFixed(1)} cm' : '--',
                        delta: waistDelta != null ? '${waistDelta > 0 ? '+' : ''}${waistDelta.toStringAsFixed(1)} cm' : null,
                        deltaColor: (waistDelta != null && waistDelta < 0) ? MetaColors.emerald : Colors.amber,
                        icon: Icons.accessibility_new_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Braço D.',
                        value: latest.armRightCm != null ? '${latest.armRightCm!.toStringAsFixed(1)} cm' : '--',
                        delta: armDelta != null ? '${armDelta > 0 ? '+' : ''}${armDelta.toStringAsFixed(1)} cm' : null,
                        deltaColor: (armDelta != null && armDelta > 0) ? MetaColors.emerald : Colors.amber,
                        icon: Icons.fitness_center_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Quadril',
                        value: latest.hipCm != null ? '${latest.hipCm!.toStringAsFixed(1)} cm' : '--',
                        icon: Icons.straighten_rounded,
                      ),
                    ),
                  ],
                ),
                if (latest.chestCm != null || latest.thighRightCm != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (latest.chestCm != null)
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Tórax/Peito',
                            value: '${latest.chestCm!.toStringAsFixed(1)} cm',
                            icon: Icons.health_and_safety_outlined,
                          ),
                        ),
                      if (latest.chestCm != null && latest.thighRightCm != null)
                        const SizedBox(width: 10),
                      if (latest.thighRightCm != null)
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Coxa D.',
                            value: '${latest.thighRightCm!.toStringAsFixed(1)} cm',
                            icon: Icons.directions_walk_rounded,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_metricsHistory.length} medição(ões) no histórico',
                      style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    String? delta,
    Color deltaColor = MetaColors.emerald,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: MetaColors.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: deltaColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          delta,
                          style: TextStyle(color: deltaColor, fontSize: 10, fontWeight: FontWeight.w800),
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
    );
  }

  Widget _buildAnamnesisEvolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.timeline_rounded,
          title: 'Evolução & Histórico de Metas',
          tag: 'CHECK-IN BIOMÉDICO',
          tagColor: MetaColors.emerald,
        ),
        const SizedBox(height: 12),
        if (_isLoadingAnamnesisHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
            ),
          )
        else if (_anamnesisHistory.isEmpty)
          MetaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: MetaColors.emerald, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faça seu Primeiro Check-in',
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Registre seu peso, metas e restrições para orientar sua periodização.',
                            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SquircleButton(
                  label: 'Iniciar Avaliação Biomecânica',
                  icon: Icons.arrow_forward_rounded,
                  isPrimary: true,
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WelcomeOnboardingScreen(isReviewMode: true),
                      ),
                    );
                    if (updated == true) _loadAnamnesisHistory();
                  },
                ),
              ],
            ),
          )
        else ...[
          _buildBeforeAfterMetricsCard(),
          const SizedBox(height: 12),
          SquircleButton(
            label: 'Novo Check-in / Atualizar Metas',
            icon: Icons.published_with_changes_rounded,
            isPrimary: true,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const WelcomeOnboardingScreen(isReviewMode: true),
                ),
              );
              if (updated == true) {
                await _loadAnamnesisHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: MetaColors.emerald,
                      content: Text('✓ Check-in salvo e sincronizado com seu treinador!'),
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 16),
          _buildAnamnesisTimelineList(),
        ],
      ],
    );
  }

  Widget _buildWeeklyCheckinCard() {
    final latest = _metricsHistory.isNotEmpty ? _metricsHistory.first : null;
    final daysSince = latest != null ? DateTime.now().difference(latest.measuredAt).inDays : null;
    final isPending = daysSince == null || daysSince >= 7;

    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isPending ? Colors.amber : MetaColors.emerald).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPending ? Icons.scale_rounded : Icons.verified_rounded,
                        color: isPending ? Colors.amber : MetaColors.emerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check-in Semanal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isPending ? 'Pesagem & Foto Pendente' : 'Check-in Realizado',
                            style: TextStyle(
                              color: isPending ? Colors.amber : MetaColors.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPending ? Colors.amber : MetaColors.emerald).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isPending ? Colors.amber : MetaColors.emerald).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isPending ? 'PENDENTE' : 'EM DIA',
                  style: TextStyle(
                    color: isPending ? Colors.amber : MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPending
                ? (daysSince != null
                    ? 'Faz $daysSince dias desde sua última pesagem. Faça seu check-in semanal para atualizar seu peso e fotos para o treinador.'
                    : 'Registre sua primeira pesagem e foto confidencial de evolução para calibrar as metas com seu personal.')
                : 'Seu check-in foi realizado há $daysSince ${daysSince == 1 ? "dia" : "dias"}. Próximo check-in recomendado em ${7 - daysSince} dias.',
            style: const TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (latest != null && latest.weightKg != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MetaColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monitor_weight_outlined, size: 16, color: MetaColors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    'Último peso: ${latest.weightKg!.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${latest.measuredAt.day.toString().padLeft(2, '0')}/${latest.measuredAt.month.toString().padLeft(2, '0')})',
                    style: const TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SquircleButton(
            label: isPending ? 'Fazer Check-in Semanal (Peso & Foto)' : 'Atualizar Check-in Semanal',
            icon: Icons.assignment_turned_in_rounded,
            isPrimary: isPending,
            onPressed: () {
              StudentWeeklyCheckinSheet.show(
                context,
                previousWeightKg: latest?.weightKg,
                onCheckinCompleted: () {
                  _loadBodyMetrics();
                  _loadEvolutionPhotos();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfterMetricsCard() {
    final latest = _anamnesisHistory.first;
    final earliest = _anamnesisHistory.last;

    final latestW = (latest['weight'] as num?)?.toDouble();
    final earliestW = (earliest['weight'] as num?)?.toDouble();

    final latestH = (latest['height'] as num?)?.toDouble();
    final earliestH = (earliest['height'] as num?)?.toDouble();

    String? deltaStr;
    Color deltaColor = MetaColors.textSecondary;
    if (latestW != null && earliestW != null) {
      final delta = latestW - earliestW;
      if (delta > 0) {
        deltaStr = '+${delta.toStringAsFixed(1)} kg';
        deltaColor = const Color(0xFF38BDF8);
      } else if (delta < 0) {
        deltaStr = '${delta.toStringAsFixed(1)} kg';
        deltaColor = MetaColors.emerald;
      } else {
        deltaStr = 'Estável';
      }
    }

    String? calcBmi(double? w, double? h) {
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      final hm = h > 3 ? h / 100 : h;
      final bmi = w / (hm * hm);
      return bmi.toStringAsFixed(1);
    }

    final latestBmi = calcBmi(latestW, latestH);
    final earliestBmi = calcBmi(earliestW, earliestH);

    final earliestInj = (earliest['injuries_summary'] ?? (earliest['injuries'] as List?)?.join(', ') ?? '').toString();
    final latestInj = (latest['injuries_summary'] ?? (latest['injuries'] as List?)?.join(', ') ?? '').toString();
    final overcamePain = earliestInj.isNotEmpty && !earliestInj.contains('Nenhuma') && (latestInj.isEmpty || latestInj.contains('Nenhuma'));

    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded, color: MetaColors.emerald, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Antes vs. Agora',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (deltaStr != null && _anamnesisHistory.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: deltaColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Variação: $deltaStr',
                    style: TextStyle(color: deltaColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 14, color: MetaColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(earliest['created_at']?.toString()),
                            style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        earliestW != null ? '${earliestW.toStringAsFixed(1)} kg' : '--',
                        style: const TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (earliestBmi != null)
                        Text(
                          'IMC: $earliestBmi',
                          style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        earliest['objective']?.toString() ?? 'Objetivo inicial',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                      ),
                      Text(
                        '${earliest['weekly_days'] ?? 3}x por semana',
                        style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: MetaColors.emerald),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(latest['created_at']?.toString()),
                            style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latestW != null ? '${latestW.toStringAsFixed(1)} kg' : '--',
                        style: const TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (latestBmi != null)
                        Text(
                          'IMC: $latestBmi',
                          style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        latest['objective']?.toString() ?? 'Objetivo atual',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${latest['weekly_days'] ?? 4}x por semana',
                        style: const TextStyle(color: MetaColors.textPrimary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (overcamePain) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: MetaColors.emerald),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dores superadas! Seu condicionamento físico e articular evoluiu.',
                      style: TextStyle(color: MetaColors.emerald, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnamnesisTimelineList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Histórico de Atualizações',
          style: TextStyle(
            color: MetaColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ..._anamnesisHistory.take(4).map((item) {
          final dateStr = _formatDate(item['created_at']?.toString());
          final w = (item['weight'] as num?)?.toDouble();
          final obj = item['objective']?.toString() ?? 'Check-in';
          final days = item['weekly_days'] ?? 4;
          final inj = item['injuries_summary'] ?? (item['injuries'] as List?)?.join(', ') ?? 'Sem restrições';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: MetaColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded, color: MetaColors.emerald, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            obj,
                            style: const TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${w != null ? "${w.toStringAsFixed(1)} kg • " : ""}${days}x/sem • $inj',
                        style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recente';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return 'Recente';
    }
  }

  Widget _buildExerciseLoadCard({
    required String exercise,
    required String startLoad,
    required String currentLoad,
    required String gainPercent,
    required List<String> history,
  }) {
    final isSingleEntry = history.length <= 1 || startLoad == currentLoad;

    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise,
                  style: const TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
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
          if (isSingleEntry) ...[
            Row(
              children: [
                const Icon(Icons.flag_circle_rounded, color: MetaColors.emerald, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Carga Base: $currentLoad (Marco Inicial)',
                  style: const TextStyle(
                    color: MetaColors.emerald,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ] else ...[
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
          ],
          const SizedBox(height: 12),
          // Mini Timeline de Cargas
          if (history.length <= 1)
            Text(
              'Próximos treinos registrarão sua evolução percentual na linha do tempo.',
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 11.5,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: history.map((val) {
                  final isLatest = val == currentLoad;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
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
                    ),
                  );
                }).toList(),
              ),
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