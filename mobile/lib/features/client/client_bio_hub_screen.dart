import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/student_ux_components.dart';
import '../../core/widgets/split_photo_slider.dart';
import '../../core/widgets/student_weekly_checkin_sheet.dart';
import '../../services/auth_service.dart';
import '../../services/body_metrics_service.dart';
import '../../services/evolution_photo_service.dart';
import '../../services/workout_service.dart';
import 'welcome_onboarding_screen.dart';
import 'widgets/warmup_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/one_ui_glass_components.dart';
import '../../core/widgets/workout_guide_modal.dart';
import '../../core/widgets/thematic_editorial_card.dart';
import '../../core/widgets/thematic_watermarks.dart';
import 'student_profile_screen.dart';

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
  String _trainerName = 'Seu Treinador';
  String _trainerPhone = '';
  String? _trainerPhotoUrl;
  String _trainerCref = 'CREF Ativo';

  // Histórico & Linha do Tempo de Anamnese State
  List<Map<String, dynamic>> _anamnesisHistory = [];
  bool _isLoadingAnamnesisHistory = true;

  // Pré-Treino & Prontidão State
  final int _energyLevel = 4; // 1 a 5
  int _waterIntakeMl = 1750; // ml
  bool _mobilityCompleted = false;

  // Pós-Treino State
  double _rpeScore = 8.0; // 1 a 10 (Escala Borg)
  final Set<String> _selectedPainPoints = {};
  bool _isSavingPostWorkout = false;
  bool _postWorkoutSaved = false;

  // Recovery State
  double _sleepHours = 7.5;
  String _domsLevel = 'Leve'; // Leve, Moderada, Intensa

  // Sobrecarga Progressiva Real State
  List<Map<String, dynamic>> _progressiveOverloads = [];
  bool _isLoadingLoads = true;
  bool _isOverloadsExpanded = false;
  String _selectedOverloadFilter = 'all'; // 'all', 'prs', 'compounds'

  // Galeria Sigilosa State
  EvolutionPhoto? _beforePhoto;
  EvolutionPhoto? _afterPhoto;
  bool _isLoadingPhotos = true;
  bool _isUploadingPhoto = false;
  bool _useSplitSlider = true;

  // Medidas Corporais & Antropometria State
  List<BodyMetricsRecord> _metricsHistory = [];
  bool _isLoadingMetrics = true;
  String _selectedBodyPart = 'waist'; // chest, arm, waist, hip, thigh

  double get _calculatedReadinessScore {
    double sleepScore = 0;
    if (_sleepHours >= 7 && _sleepHours <= 9) {
      sleepScore = 45;
    } else if (_sleepHours >= 6) {
      sleepScore = 35;
    } else if (_sleepHours > 9) {
      sleepScore = 40;
    } else {
      sleepScore = 20;
    }

    double domsScore = 0;
    if (_domsLevel == 'Leve') {
      domsScore = 40;
    } else if (_domsLevel == 'Moderada') {
      domsScore = 25;
    } else {
      domsScore = 10;
    }

    double waterScore = (_waterIntakeMl / 2500.0) * 15.0;
    if (waterScore > 15) waterScore = 15;

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
    _loadTrainer();
    _loadEvolutionPhotos();
    _loadRecoveryAndLoads();
    _loadAnamnesisHistory();
    _loadBodyMetrics();
  }

  Future<void> _loadTrainer() async {
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
          final name = (trainer['trainer_name'] ?? trainer['full_name']) as String?;
          if (name != null && name.isNotEmpty) _trainerName = name;
          final phone = (trainer['phone'] ?? trainer['whatsapp']) as String?;
          if (phone != null && phone.isNotEmpty) _trainerPhone = phone;
          final photoUrl = trainer['trainer_photo_url'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            _trainerPhotoUrl = photoUrl;
          }
          final reg = (trainer['cref_or_registry'] ??
                  trainer['cref'] ??
                  trainer['professional_document']) as String?;
          if (reg != null && reg.isNotEmpty) _trainerCref = reg;
        });
      }
    } catch (_) {}
  }

  void _openCoachSheet() {
    final subtitle = _trainerCref.isNotEmpty ? _trainerCref : 'CREF Ativo';
    OneUiGlassSheet.show(
      context,
      header: Row(
        children: [
          _buildCoachAvatar(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trainerName,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: MetaColors.emerald),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 12,
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
      actions: [
        GlassAction(
          icon: Icons.chat_bubble_rounded,
          label: 'Falar no WhatsApp (24h)',
          subtitle: 'Tire dúvidas sobre prontidão e cargas',
          onTap: _contactTrainerWhatsApp,
        ),
      ],
    );
  }

  Future<void> _contactTrainerWhatsApp() async {
    Navigator.of(context, rootNavigator: true).pop();
    final cleanPhone = _trainerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: MetaColors.surfaceHighlight,
          content: Text('Seu treinador ($_trainerName) ainda não cadastrou o WhatsApp profissional.'),
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent('Olá professor(a) $_trainerName! Gostaria de falar sobre meu Bio-Hub e prontidão no Mr. Coach.')}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Não foi possível abrir o WhatsApp.'),
          ),
        );
      }
    }
  }

  void _openMoreMenu() {
    final dark = ThemeController.instance.isEffectiveDark(context);
    OneUiGlassSheet.show(
      context,
      actions: [
        GlassAction(
          icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: dark ? 'Modo Claro' : 'Modo Escuro',
          subtitle: 'Alterna o tema de todo o aplicativo',
          color: const Color(0xFF8B5CF6),
          onTap: () => ThemeController.instance.toggleTheme(context),
        ),
        GlassAction(
          icon: Icons.fitness_center_rounded,
          label: 'Como treinar',
          subtitle: 'Guia de execução, cargas e trocas',
          color: const Color(0xFFF59E0B),
          onTap: () => WorkoutGuideModal.show(context),
        ),
        GlassAction(
          icon: Icons.explore_rounded,
          label: 'Tour do Aluno',
          subtitle: 'Apresentação rápida das funções',
          onTap: () => InteractiveTourGuideModal.show(context, role: 'student'),
        ),
        GlassAction(
          icon: Icons.person_outline_rounded,
          label: 'Meu Perfil & Anamnese',
          color: const Color(0xFF38BDF8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachAvatar({double size = 40}) {
    final hasPhoto = _trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty;
    final initials = _trainerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [MetaColors.emerald, MetaColors.accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: hasPhoto
                ? DecorationImage(
                    image: _trainerPhotoUrl!.startsWith('assets/')
                        ? AssetImage(_trainerPhotoUrl!) as ImageProvider
                        : NetworkImage(_trainerPhotoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasPhoto
              ? null
              : Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'P',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.34,
                    ),
                  ),
                ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              color: MetaColors.emerald,
              shape: BoxShape.circle,
              border: Border.all(color: MetaColors.bg(context), width: 2),
            ),
            child: Icon(Icons.check_rounded, color: Colors.black, size: size * 0.24),
          ),
        ),
      ],
    );
  }

  Widget _buildBioHubHeader() {
    return Row(
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
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bio-Hub',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Performance • Cargas • Recovery',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _openCoachSheet,
          behavior: HitTestBehavior.opaque,
          child: _buildCoachAvatar(size: 38),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: 'Menu',
          onTap: _openMoreMenu,
        ),
      ],
    );
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

  Future<void> _autoSaveRecoverySilent() async {
    final score = _calculatedReadinessScore;
    try {
      await WorkoutService.saveDailyRecovery(
        sleepHours: _sleepHours,
        domsLevel: _domsLevel,
        waterIntakeMl: _waterIntakeMl,
        readinessScore: score,
      );
    } catch (_) {}
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

    final isDark = ThemeController.instance.isEffectiveDark(context);
    final readinessScore = _calculatedReadinessScore.clamp(0.0, 100.0);
    final readinessInsight = _getReadinessInsight(readinessScore);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
            backgroundColor: MetaColors.bg(context),
            body: Stack(
              children: [
                const AmbientGlowCanvas(),
                NestedScrollView(
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
                            _buildBioHubHeader(),
                            const SizedBox(height: 14),
                            // Card Editorial One UI 7 Health: Telemetria & Prontidão
                            ThematicEditorialCard(
                              category: 'Telemetria & Prontidão Bio-Hub',
                              title: readinessInsight,
                              description: 'Análise integrada de sono, hidratação e estresse de carga para guiar seu treino.',
                              palette: readinessScore >= 75
                                  ? ThematicCardPalette.cardioCobalt
                                  : (readinessScore >= 50 ? ThematicCardPalette.biomechanicsCyan : ThematicCardPalette.muscleMagenta),
                              customWatermark: readinessScore >= 75
                                  ? ThematicWatermarkType.cardioLoad
                                  : (readinessScore >= 50 ? ThematicWatermarkType.biomechanics : ThematicWatermarkType.muscleFatigue),
                              minHeight: 115,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                        const SizedBox(height: 14),
                        // Top 3 Activity Rings Summary Card (Apple Fitness+ / Whoop style)
                        _buildActivityRingsSummaryCard(),
                        const SizedBox(height: 14),
                        // Segmented Control (Pílulas no Padrão One UI 7 Frosted Glass)
                        OneUiGlassSegmentedBar(
                          selectedIndex: _currentSubTab,
                          onChanged: (index) {
                            _tabController.animateTo(index);
                            setState(() => _currentSubTab = index);
                          },
                          segments: const [
                            GlassSegment(
                              icon: Icons.bolt_rounded,
                              label: 'Hoje',
                            ),
                            GlassSegment(
                              icon: Icons.accessibility_new_rounded,
                              label: 'Meu Corpo',
                            ),
                            GlassSegment(
                              icon: Icons.emoji_events_rounded,
                              label: 'Força',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildHojeTab(bottomPadding),
                  _buildMeuCorpoTab(bottomPadding),
                  _buildForcaTab(bottomPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReadinessInsight(double readiness) {
    if (readiness >= 80) {
      return 'Prontidão alta (${readiness.toInt()}%) — excelente janela para progredir carga hoje.';
    } else if (readiness >= 60) {
      return 'Prontidão moderada (${readiness.toInt()}%) — mantenha a cadência e hidratação.';
    } else {
      return 'Recuperação em atenção (${readiness.toInt()}%) — priorize técnica e mobilidade.';
    }
  }

  Widget _buildActivityRingsSummaryCard() {
    final readiness = _calculatedReadinessScore.clamp(0.0, 100.0);
    final prepProgress = (((_energyLevel / 5.0) * 0.6) +
            ((_waterIntakeMl.clamp(0, 500) / 500.0) * 0.4))
        .clamp(0.0, 1.0);
    final overloadProgress =
        _progressiveOverloads.isNotEmpty ? 1.0 : (_mobilityCompleted ? 0.7 : 0.35);

    final insightText = _getReadinessInsight(readiness);

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniRingMetric(
                  progress: readiness / 100.0,
                  color: MetaColors.emerald,
                  value: '${readiness.toInt()}%',
                  label: 'Prontidão',
                  onTap: () {
                    _tabController.animateTo(2);
                    setState(() => _currentSubTab = 2);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniRingMetric(
                  progress: prepProgress,
                  color: MetaColors.accentBlue,
                  value: '$_energyLevel/5',
                  label: 'Energia & Água',
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _currentSubTab = 0);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniRingMetric(
                  progress: overloadProgress,
                  color: const Color(0xFFF59E0B),
                  value: '${_progressiveOverloads.length}',
                  label: 'Cargas Ativas',
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _currentSubTab = 1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: MetaColors.emerald,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insightText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRingMetric({
    required double progress,
    required Color color,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          children: [
            ProgressRing(
              progress: progress,
              size: 38,
              strokeWidth: 4,
              color: color,
              center: Text(
                value,
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // -------------------------------------------------------------
  // ABA 1: ⚡ HOJE (PRONTIDÃO & PULSO EM 5 SEGUNDOS)
  // -------------------------------------------------------------
  Widget _buildHojeTab(double bottomPadding) {
    final readiness = _calculatedReadinessScore;
    final readinessInt = readiness.toInt();

    // Determinação do status e badge da prontidão
    final String readinessBadge;
    final String readinessTitle;
    final String readinessDesc;
    final Color orbColor;

    if (readiness >= 75) {
      readinessBadge = 'JANELA IDEAL DE FORÇA 🚀';
      readinessTitle = 'Seu corpo está 100% recuperado!';
      readinessDesc = 'Excelente dia para buscar carga máxima ou manter cadência alta. Articulações descansadas e SNC pronto.';
      orbColor = MetaColors.emerald;
    } else if (readiness >= 50) {
      readinessBadge = 'RECUPERAÇÃO MODERADA 🟡';
      readinessTitle = 'Energia suficiente para treinar';
      readinessDesc = 'Priorize cadência controlada e bom aquecimento articular. Ajuste as cargas conforme a percepção da primeira série.';
      orbColor = const Color(0xFFF59E0B);
    } else {
      readinessBadge = 'FOCO EM RECUPERAÇÃO 🛌';
      readinessTitle = 'Atenção aos sinais de fadiga';
      readinessDesc = 'Seu corpo pede hidratação e sono reparador. Vale focar em mobilidade, treino técnico ou descanso ativo.';
      orbColor = const Color(0xFFEF4444);
    }

    final sleepLabel = _sleepHours >= 8.0
        ? '8h+ (Reparador)'
        : (_sleepHours >= 7.0 ? '7h - 8h (Ideal)' : 'Menos de 6h');

    final muscleLabel = _domsLevel == 'none'
        ? '100% Recuperado'
        : (_domsLevel == 'mild' ? 'Dor Leve' : 'Fadiga / Dor Articular');

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        // 1. HERO BIO-BATTERY ORB
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                orbColor.withValues(alpha: 0.16),
                MetaColors.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: orbColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: orbColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular Orb Indicator
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(
                    color: orbColor,
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$readinessInt%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      readiness >= 75
                          ? 'PRONTO'
                          : (readiness >= 50 ? 'MODERADO' : 'BAIXO'),
                      style: TextStyle(
                        color: orbColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Contextual Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: orbColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        readinessBadge,
                        style: TextStyle(
                          color: orbColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      readinessTitle,
                      style: const TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      readinessDesc,
                      style: const TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. MICRO CHECK-IN 1-TOQUE (AUTO-SALVO)
        MetaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Calibrar Prontidão de Hoje',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Auto-Salvo ✓',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // SONO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🌙 Como dormiu esta noite?',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sleepLabel,
                    style: const TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCheckinChip(
                      label: '😴 < 6h',
                      isSelected: _sleepHours < 6.0,
                      onTap: () {
                        setState(() => _sleepHours = 5.5);
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCheckinChip(
                      label: '⚡ 7h - 8h',
                      isSelected: _sleepHours >= 6.0 && _sleepHours <= 8.0,
                      onTap: () {
                        setState(() => _sleepHours = 7.5);
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCheckinChip(
                      label: '🛌 8h+',
                      isSelected: _sleepHours > 8.0,
                      onTap: () {
                        setState(() => _sleepHours = 8.5);
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // SENSAÇÃO MUSCULAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💪 Sensação Muscular / Articular',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    muscleLabel,
                    style: TextStyle(
                      color: _domsLevel == 'none'
                          ? MetaColors.emerald
                          : (_domsLevel == 'mild' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildCheckinChip(
                      label: '🟢 100% Novo',
                      isSelected: _domsLevel == 'none',
                      onTap: () {
                        setState(() => _domsLevel = 'none');
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCheckinChip(
                      label: '🟡 Dor Leve',
                      isSelected: _domsLevel == 'mild',
                      onTap: () {
                        setState(() => _domsLevel = 'mild');
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCheckinChip(
                      label: '🔴 Fadigado',
                      isSelected: _domsLevel == 'severe',
                      onTap: () {
                        setState(() => _domsLevel = 'severe');
                        _autoSaveRecoverySilent();
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: MetaColors.border, height: 1),
              const SizedBox(height: 14),

              // HIDRATAÇÃO RÁPIDA
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: MetaColors.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
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
                          'Hidratação do Dia',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_waterIntakeMl}ml de 2.500ml consumidos',
                          style: const TextStyle(
                            color: MetaColors.accentBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() => _waterIntakeMl += 250);
                      _autoSaveRecoverySilent();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: MetaColors.accentBlue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: MetaColors.accentBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        '+ 250ml',
                        style: TextStyle(
                          color: MetaColors.accentBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. SELO DO TREINADOR & RECIPROCIDADE
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MetaColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MetaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: MetaColors.emerald.withValues(alpha: 0.2),
                    backgroundImage: (_trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty)
                        ? NetworkImage(_trainerPhotoUrl!)
                        : null,
                    child: (_trainerPhotoUrl == null || _trainerPhotoUrl!.isEmpty)
                        ? Text(
                            _trainerName.isNotEmpty
                                ? _trainerName.substring(0, 1).toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Prof. $_trainerName',
                              style: const TextStyle(
                                color: MetaColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓ Sincronizado Zap',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _trainerCref.isNotEmpty ? 'CREF: $_trainerCref' : 'Treinador Responsável',
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_trainerPhone.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: MetaColors.emerald, size: 20),
                      onPressed: _contactTrainerWhatsApp,
                      tooltip: 'Falar no WhatsApp',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  readiness >= 75
                      ? '"Olá! Vi que sua prontidão está em $readinessInt%. Hoje é dia de foco total e você pode progredir carga nos compostos. Bom treino!"'
                      : '"Olá! Prontidão em $readinessInt%. Mantenha boa hidratação e faça o aquecimento com calma antes de iniciar as séries."',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. CTA DIRETO PARA O TREINO DO DIA
        SquircleButton(
          label: '⚡ INICIAR TREINO COM PRONTIDÃO ($readinessInt%)',
          icon: Icons.bolt_rounded,
          isPrimary: true,
          backgroundColor: MetaColors.emerald,
          foregroundColor: Colors.black,
          onPressed: widget.onNavigateToWorkout ?? () => Navigator.pop(context),
        ),

        const SizedBox(height: 24),

        // 5. AQUECIMENTO ESPECÍFICO GUIADO (MANTIDO)
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
                      fontSize: 14,
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
              const SizedBox(height: 6),
              const Text(
                'Mobilidade articular direcionada para os grupos musculares da sua ficha ativa de hoje.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 12),
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
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 6. BLOCO PÓS-TREINO • REGISTRO DE ESFORÇO & RPE BORG (MANTIDO)
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
                      fontSize: 14,
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
                        fontSize: 13,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              const Divider(color: MetaColors.border, height: 1),
              const SizedBox(height: 12),

              const Text(
                'Sentiu dor articular ou desconforto?',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Isso gera um aviso automático para o seu personal ajustar sua periodização.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 11),
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

              const SizedBox(height: 16),
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

  Widget _buildCheckinChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.18)
              : MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? MetaColors.emerald : MetaColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ABA 2: 📐 MEU CORPO (MAPA CORPORAL, RECOMPOSIÇÃO & FOTOS)
  // -------------------------------------------------------------
  Widget _buildMeuCorpoTab(double bottomPadding) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        if (_isLoadingMetrics)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
            ),
          )
        else ...[
          // 1. JORNADA DE PESO & META UNIFICADA + DETECTOR DE RECOMPOSIÇÃO
          _buildUnifiedWeightJourneySection(),
          const SizedBox(height: 20),

          // 2. MAPA CORPORAL ANATÔMICO INTERATIVO COM SILHUETA E HOTSPOTS
          _buildInteractiveBodyMapSection(),
          const SizedBox(height: 20),
        ],

        // 3. ESTÚDIO SIGILOSO ANTES & DEPOIS COM SPLIT SLIDER
        _buildPrivatePhotoStudioSection(),
        const SizedBox(height: 20),

        // 4. CHECK-IN SEMANAL PENDENTE / CONCLUÍDO
        _buildWeeklyCheckinCard(),
        const SizedBox(height: 20),

        // 5. TELEMETRIA DE SAÚDE & CONECTORES VITAIS
        const HealthMetricsCard(),
        const SizedBox(height: 20),

        // 6. LINHA DO TEMPO & EVOLUÇÃO DAS METAS / ANAMNESE
        _buildAnamnesisEvolutionSection(),
      ],
    );
  }

  Widget _buildUnifiedWeightJourneySection() {
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

    final currentWeight = latest?.weightKg ?? 78.4;
    final initialWeight = initial?.weightKg ?? (latest?.weightKg ?? 84.0);
    final targetWeight = (initialWeight > 70 ? initialWeight - 6.0 : initialWeight + 4.0);

    double progressPct = 0.65;
    if ((initialWeight - targetWeight).abs() > 0.1) {
      progressPct = ((initialWeight - currentWeight) / (initialWeight - targetWeight)).clamp(0.05, 1.0);
    }

    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'JORNADA DE PESO & META',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        latest?.weightKg != null ? '${latest!.weightKg!.toStringAsFixed(1)} kg' : '-- kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (weightDelta != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (weightDelta < 0 ? MetaColors.emerald : Colors.amber).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (weightDelta < 0 ? MetaColors.emerald : Colors.amber).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${weightDelta < 0 ? "" : "+"}${weightDelta.toStringAsFixed(1)} kg desde o início',
                            style: TextStyle(
                              color: weightDelta < 0 ? MetaColors.emerald : Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (latest?.bmi != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'IMC ATUAL',
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${latest!.bmi!.toStringAsFixed(1)} • ${latest.bmiCategory}',
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de Progresso com Gradiente
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              width: double.infinity,
              color: MetaColors.surfaceHighlight,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPct,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [MetaColors.emerald, MetaColors.accentBlue],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Início: ${initialWeight.toStringAsFixed(1)} kg',
                style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
              ),
              Text(
                '${(progressPct * 100).toInt()}% da Meta',
                style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                'Meta: ${targetWeight.toStringAsFixed(1)} kg',
                style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Detector de Recomposição Corporal
          _buildRecompositionCard(waistDelta, armDelta),
        ],
      ),
    );
  }

  Widget _buildRecompositionCard(double? waistDelta, double? armDelta) {
    final bool isRecomposition = (waistDelta != null && waistDelta < 0) &&
        (armDelta != null && armDelta >= 0);

    if (isRecomposition) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MetaColors.emerald.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🧬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recomposição Corporal Detectada! ✨',
                    style: TextStyle(
                      color: MetaColors.emerald,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Você reduziu ${waistDelta.abs().toStringAsFixed(1)} cm de cintura e ganhou/manteve +${armDelta.toStringAsFixed(1)} cm de braço. Você está perdendo gordura visceral e construindo massa magra simultaneamente!',
                    style: const TextStyle(
                      color: Colors.white70,
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
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.border),
      ),
      child: Row(
        children: const [
          Icon(Icons.auto_awesome_rounded, color: MetaColors.emerald, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'O detector de recomposição analisa redução de cintura vs. preservação de membros a cada check-in registrado.',
              style: TextStyle(color: MetaColors.textSecondary, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveBodyMapSection() {
    final latest = _metricsHistory.isNotEmpty ? _metricsHistory.first : null;
    final initial = _metricsHistory.length > 1 ? _metricsHistory.last : latest;

    double? delta;
    String regionTitle;
    String currentValue;
    String historyInfo;
    IconData icon;

    switch (_selectedBodyPart) {
      case 'arm':
        regionTitle = 'Braço Direito';
        currentValue = latest?.armRightCm != null ? '${latest!.armRightCm!.toStringAsFixed(1)} cm' : '-- cm';
        if (latest?.armRightCm != null && initial?.armRightCm != null && _metricsHistory.length > 1) {
          delta = latest!.armRightCm! - initial!.armRightCm!;
        }
        historyInfo = 'Início: ${initial?.armRightCm != null ? "${initial!.armRightCm!.toStringAsFixed(1)} cm" : "--"} • Hipertrofia';
        icon = Icons.fitness_center_rounded;
        break;
      case 'chest':
        regionTitle = 'Tórax / Peito';
        currentValue = latest?.chestCm != null ? '${latest!.chestCm!.toStringAsFixed(1)} cm' : '-- cm';
        if (latest?.chestCm != null && initial?.chestCm != null && _metricsHistory.length > 1) {
          delta = latest!.chestCm! - initial!.chestCm!;
        }
        historyInfo = 'Início: ${initial?.chestCm != null ? "${initial!.chestCm!.toStringAsFixed(1)} cm" : "--"} • Caixa Torácica';
        icon = Icons.health_and_safety_outlined;
        break;
      case 'hip':
        regionTitle = 'Quadril / Glúteo';
        currentValue = latest?.hipCm != null ? '${latest!.hipCm!.toStringAsFixed(1)} cm' : '-- cm';
        if (latest?.hipCm != null && initial?.hipCm != null && _metricsHistory.length > 1) {
          delta = latest!.hipCm! - initial!.hipCm!;
        }
        historyInfo = 'Início: ${initial?.hipCm != null ? "${initial!.hipCm!.toStringAsFixed(1)} cm" : "--"} • Proporção';
        icon = Icons.straighten_rounded;
        break;
      case 'thigh':
        regionTitle = 'Coxa Direita';
        currentValue = latest?.thighRightCm != null ? '${latest!.thighRightCm!.toStringAsFixed(1)} cm' : '-- cm';
        if (latest?.thighRightCm != null && initial?.thighRightCm != null && _metricsHistory.length > 1) {
          delta = latest!.thighRightCm! - initial!.thighRightCm!;
        }
        historyInfo = 'Início: ${initial?.thighRightCm != null ? "${initial!.thighRightCm!.toStringAsFixed(1)} cm" : "--"} • Quadríceps';
        icon = Icons.directions_walk_rounded;
        break;
      case 'waist':
      default:
        regionTitle = 'Cintura / Abdômen';
        currentValue = latest?.waistCm != null ? '${latest!.waistCm!.toStringAsFixed(1)} cm' : '-- cm';
        if (latest?.waistCm != null && initial?.waistCm != null && _metricsHistory.length > 1) {
          delta = latest!.waistCm! - initial!.waistCm!;
        }
        historyInfo = 'Início: ${initial?.waistCm != null ? "${initial!.waistCm!.toStringAsFixed(1)} cm" : "--"} • Redução de Gordura';
        icon = Icons.accessibility_new_rounded;
        break;
    }

    return MetaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'MAPA CORPORAL ANATÔMICO',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Toque nos pontos da silhueta para inspecionar',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _showAddMetricsSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: MetaColors.emerald),
                      SizedBox(width: 4),
                      Text(
                        'Nova Medição',
                        style: TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Silhueta Anatômica com Hotspots
              Container(
                width: 110,
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MetaColors.border),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    return Stack(
                      children: [
                        CustomPaint(
                          size: Size(w, h),
                          painter: BodySilhouettePainter(selectedPart: _selectedBodyPart),
                        ),
                        // Hotspots táteis precisos
                        _buildHotspot(part: 'chest', left: w * 0.50 - 12, top: h * 0.27 - 12),
                        _buildHotspot(part: 'arm', left: w * 0.77 - 12, top: h * 0.34 - 12),
                        _buildHotspot(part: 'waist', left: w * 0.50 - 12, top: h * 0.44 - 12),
                        _buildHotspot(part: 'hip', left: w * 0.50 - 12, top: h * 0.54 - 12),
                        _buildHotspot(part: 'thigh', left: w * 0.61 - 12, top: h * 0.70 - 12),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),

              // Painel de Detalhes da Região Selecionada
              Expanded(
                child: Column(
                  children: [
                    // Card da Região Ativa
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, size: 16, color: MetaColors.emerald),
                                  const SizedBox(width: 6),
                                  Text(
                                    regionTitle,
                                    style: const TextStyle(
                                      color: MetaColors.emerald,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              if (delta != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (delta < 0 ? MetaColors.emerald : Colors.amber).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${delta > 0 ? "+" : ""}${delta.toStringAsFixed(1)} cm',
                                    style: TextStyle(
                                      color: delta < 0 ? MetaColors.emerald : Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentValue,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            historyInfo,
                            style: const TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grid de Pílulas Rápidas
                    Row(
                      children: [
                        Expanded(
                          child: _buildRegionPill(
                            part: 'waist',
                            label: 'Cintura',
                            val: latest?.waistCm != null ? '${latest!.waistCm!.toStringAsFixed(1)} cm' : '--',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRegionPill(
                            part: 'arm',
                            label: 'Braço D.',
                            val: latest?.armRightCm != null ? '${latest!.armRightCm!.toStringAsFixed(1)} cm' : '--',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRegionPill(
                            part: 'chest',
                            label: 'Tórax',
                            val: latest?.chestCm != null ? '${latest!.chestCm!.toStringAsFixed(1)} cm' : '--',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRegionPill(
                            part: 'thigh',
                            label: 'Coxa D.',
                            val: latest?.thighRightCm != null ? '${latest!.thighRightCm!.toStringAsFixed(1)} cm' : '--',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHotspot({
    required String part,
    required double left,
    required double top,
  }) {
    final isSelected = _selectedBodyPart == part;
    final color = isSelected ? MetaColors.emerald : const Color(0xFF38BDF8);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedBodyPart = part),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? color.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.5),
            border: Border.all(
              color: color,
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionPill({
    required String part,
    required String label,
    required String val,
  }) {
    final isSelected = _selectedBodyPart == part;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedBodyPart = part),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.18)
              : MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? MetaColors.emerald : MetaColors.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivatePhotoStudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.photo_library_rounded,
          title: 'Estúdio Sigiloso Antes & Depois',
          tag: 'SÓ VOCÊ & TREINADOR',
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
                    color: MetaColors.card(context),
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

  List<Map<String, dynamic>> _getFilteredOverloads() {
    // 1. Deduplicação inteligente de nomes similares (ex: 'Supino Reto com Barra' vs 'Supino Reto')
    final seen = <String, Map<String, dynamic>>{};
    for (final item in _progressiveOverloads) {
      final rawName = (item['exercise'] as String? ?? '').trim();
      final normalizedKey = rawName
          .toLowerCase()
          .replaceAll('com barra', '')
          .replaceAll('livre', '')
          .replaceAll('articulado', '')
          .replaceAll('máquina', '')
          .replaceAll('  ', ' ')
          .trim();

      if (!seen.containsKey(normalizedKey)) {
        seen[normalizedKey] = item;
      } else {
        final currentGain = double.tryParse((item['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
        final existingGain = double.tryParse((seen[normalizedKey]!['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
        if (currentGain > existingGain || (item['history'] as List? ?? []).length > (seen[normalizedKey]!['history'] as List? ?? []).length) {
          seen[normalizedKey] = item;
        }
      }
    }

    final uniqueList = seen.values.toList();

    // 2. Filtro por pílula selecionada
    if (_selectedOverloadFilter == 'prs') {
      return uniqueList.where((e) {
        final gain = double.tryParse((e['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
        return gain > 0;
      }).toList();
    } else if (_selectedOverloadFilter == 'compounds') {
      const compounds = ['supino', 'agachamento', 'terra', 'leg press', 'puxada', 'desenvolvimento', 'remada'];
      return uniqueList.where((e) {
        final name = (e['exercise'] as String? ?? '').toLowerCase();
        return compounds.any((c) => name.contains(c));
      }).toList();
    }
    return uniqueList;
  }

  Widget _buildTopPRCards(List<Map<String, dynamic>> topPRs) {
    if (topPRs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.auto_awesome, color: MetaColors.emerald, size: 14),
            SizedBox(width: 6),
            Text(
              'TOP PROGRESSÕES RECENTES',
              style: TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: topPRs.take(2).map((item) {
            final exercise = item['exercise'] as String? ?? '';
            final startLoad = item['start_load'] as String? ?? '';
            final currentLoad = item['current_load'] as String? ?? '';
            final gainPercent = item['gain_percent'] as String? ?? '+0%';

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: MetaColors.emerald.withValues(alpha: 0.05),
                        blurRadius: 10,
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
                          Expanded(
                            child: Text(
                              exercise,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MetaColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              gainPercent,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '$startLoad ➔ ',
                            style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                          ),
                          Text(
                            currentLoad,
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Mini Barra de Evolução
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 4,
                          width: double.infinity,
                          color: MetaColors.surfaceHighlight,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.85,
                            child: Container(color: MetaColors.emerald),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompactExerciseRow(Map<String, dynamic> item) {
    final exercise = item['exercise'] as String? ?? '';
    final startLoad = item['start_load'] as String? ?? '';
    final currentLoad = item['current_load'] as String? ?? '';
    final gainPercent = item['gain_percent'] as String? ?? '+0%';
    final isBaseline = item['is_baseline'] == true || startLoad == currentLoad;

    IconData muscleIcon = Icons.fitness_center_rounded;
    final lowerName = exercise.toLowerCase();
    if (lowerName.contains('supino') || lowerName.contains('peito') || lowerName.contains('crucifixo')) {
      muscleIcon = Icons.shield_rounded;
    } else if (lowerName.contains('agachamento') || lowerName.contains('leg') || lowerName.contains('coxa') || lowerName.contains('panturrilha')) {
      muscleIcon = Icons.directions_walk_rounded;
    } else if (lowerName.contains('costas') || lowerName.contains('puxada') || lowerName.contains('remada') || lowerName.contains('terra')) {
      muscleIcon = Icons.sports_gymnastics_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(muscleIcon, size: 16, color: MetaColors.emerald),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isBaseline ? 'Marco Inicial: $currentLoad' : 'Inicial: $startLoad',
                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    currentLoad,
                    style: const TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!isBaseline) ...[
                    Text(
                      '($gainPercent)',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Base',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverloadFilterChip({
    required String label,
    required String filterKey,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedOverloadFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.emerald : MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : MetaColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
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
                color: MetaColors.card(context),
                shape: BoxShape.circle,
                border: Border.all(color: MetaColors.cardBorder(context)),
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
  Widget _buildForcaTab(double bottomPadding) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding + 32,
      ),
      children: [
        // 1. CARD DE TONELAGEM SEMANAL GAMIFICADA
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF59E0B).withValues(alpha: 0.18),
                MetaColors.surface.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VOLUME MOVIMENTADO NA SEMANA',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Text(
                    '🔥 Top 10% do Studio',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    '14.420 kg',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '+12% vs. semana passada',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Equivale a levantar 9 SUVs médios! Calculado automaticamente a cada treino concluído.',
                style: TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. CONQUISTAS & SELOS DE FORÇA
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
                      'Desbloqueie marcos de 1RM, tonelagem e novos recordes',
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

        const SizedBox(height: 20),

        // 3. SOBRECARGA PROGRESSIVA REAL (COCKPIT INTELIGENTE E COMPACTO)
        Builder(
          builder: (context) {
            final filteredList = _getFilteredOverloads();
            final topPRs = filteredList.where((e) {
              final gain = double.tryParse((e['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
              return gain > 0;
            }).toList();
            topPRs.sort((a, b) {
              final ga = double.tryParse((a['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
              final gb = double.tryParse((b['gain_percent'] as String? ?? '').replaceAll('%', '').replaceAll('+', '')) ?? 0.0;
              return gb.compareTo(ga);
            });

            final displayedList = _isOverloadsExpanded ? filteredList : filteredList.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildSectionHeader(
                        icon: Icons.trending_up_rounded,
                        title: 'Sobrecarga Progressiva Real',
                        tag: '${filteredList.length} EXERCÍCIOS',
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
                const SizedBox(height: 8),

                // Pílulas de Filtro Rápido
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildOverloadFilterChip(
                        label: '🔥 Top PRs (${topPRs.length})',
                        filterKey: 'prs',
                        isSelected: _selectedOverloadFilter == 'prs',
                      ),
                      const SizedBox(width: 8),
                      _buildOverloadFilterChip(
                        label: 'Todos (${_progressiveOverloads.length})',
                        filterKey: 'all',
                        isSelected: _selectedOverloadFilter == 'all',
                      ),
                      const SizedBox(width: 8),
                      _buildOverloadFilterChip(
                        label: '🏋️ Compostos',
                        filterKey: 'compounds',
                        isSelected: _selectedOverloadFilter == 'compounds',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (_isLoadingLoads)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                    ),
                  )
                else if (filteredList.isNotEmpty) ...[
                  // Cards de Destaque (Top 2 PRs)
                  if (_selectedOverloadFilter != 'prs' && topPRs.isNotEmpty) ...[
                    _buildTopPRCards(topPRs),
                    const SizedBox(height: 14),
                  ],

                  // Cockpit Compacto em Linhas (44px)
                  MetaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Histórico Consolidado de Cargas',
                              style: TextStyle(
                                color: MetaColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Exibindo ${displayedList.length} de ${filteredList.length}',
                              style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(color: MetaColors.border, height: 12),
                        ...displayedList.map((item) => _buildCompactExerciseRow(item)),
                        if (filteredList.length > 3) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(() => _isOverloadsExpanded = !_isOverloadsExpanded),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.25)),
                              ),
                              child: Center(
                                child: Text(
                                  _isOverloadsExpanded
                                      ? 'Mostrar menos ▴'
                                      : 'Ver todos os ${filteredList.length} exercícios ▾',
                                  style: const TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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
                                    'Nenhum registro para este filtro',
                                    style: TextStyle(
                                      color: MetaColors.text(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Toque em "Todos" ou registre uma nova carga de treino.',
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
                      ],
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // 4. INSIGHT INTELIGENTE DO MR. COACH AI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: MetaColors.emerald, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insight Cinesiológico • Sobrecarga Progressiva',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sua taxa de sobrecarga média nos compostos está positiva. O aumento de carga no Supino (+33%) sem dor articular registrada sinaliza adaptação neuromuscular consolidada.',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: tagColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: tagColor,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pintor customizado para renderizar a silhueta anatômica vetorial interativa do Bio-Hub.
class BodySilhouettePainter extends CustomPainter {
  final String selectedPart;

  const BodySilhouettePainter({required this.selectedPart});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Cabeça
    final headCenter = Offset(w * 0.5, h * 0.12);
    final headRadius = w * 0.12;
    canvas.drawCircle(headCenter, headRadius, fillPaint);
    canvas.drawCircle(headCenter, headRadius, basePaint);

    // Tronco (Peito, Abdômen e Quadril)
    final torsoPath = Path()
      ..moveTo(w * 0.30, h * 0.22) // Ombro esquerdo
      ..lineTo(w * 0.70, h * 0.22) // Ombro direito
      ..lineTo(w * 0.65, h * 0.42) // Cintura direita
      ..lineTo(w * 0.72, h * 0.56) // Quadril direito
      ..lineTo(w * 0.50, h * 0.58) // Virilha
      ..lineTo(w * 0.28, h * 0.56) // Quadril esquerdo
      ..lineTo(w * 0.35, h * 0.42) // Cintura esquerda
      ..close();
    canvas.drawPath(torsoPath, fillPaint);
    canvas.drawPath(torsoPath, basePaint);

    // Braço esquerdo
    final leftArm = Path()
      ..moveTo(w * 0.30, h * 0.22)
      ..lineTo(w * 0.16, h * 0.36)
      ..lineTo(w * 0.14, h * 0.50);
    canvas.drawPath(leftArm, basePaint);

    // Braço direito
    final rightArm = Path()
      ..moveTo(w * 0.70, h * 0.22)
      ..lineTo(w * 0.84, h * 0.36)
      ..lineTo(w * 0.86, h * 0.50);
    canvas.drawPath(rightArm, basePaint);

    // Perna esquerda
    final leftLeg = Path()
      ..moveTo(w * 0.36, h * 0.56)
      ..lineTo(w * 0.34, h * 0.75)
      ..lineTo(w * 0.36, h * 0.94);
    canvas.drawPath(leftLeg, basePaint);

    // Perna direita
    final rightLeg = Path()
      ..moveTo(w * 0.64, h * 0.56)
      ..lineTo(w * 0.66, h * 0.75)
      ..lineTo(w * 0.64, h * 0.94);
    canvas.drawPath(rightLeg, basePaint);

    // Realce da região selecionada
    final highlightPaint = Paint()
      ..color = MetaColors.emerald.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final highlightStroke = Paint()
      ..color = MetaColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (selectedPart == 'chest') {
      final chestRect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.29),
        width: w * 0.38,
        height: h * 0.11,
      );
      final rrect = RRect.fromRectAndRadius(chestRect, const Radius.circular(8));
      canvas.drawRRect(rrect, highlightPaint);
      canvas.drawRRect(rrect, highlightStroke);
    } else if (selectedPart == 'waist') {
      final waistRect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.44),
        width: w * 0.32,
        height: h * 0.09,
      );
      final rrect = RRect.fromRectAndRadius(waistRect, const Radius.circular(8));
      canvas.drawRRect(rrect, highlightPaint);
      canvas.drawRRect(rrect, highlightStroke);
    } else if (selectedPart == 'hip') {
      final hipRect = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.54),
        width: w * 0.42,
        height: h * 0.09,
      );
      final rrect = RRect.fromRectAndRadius(hipRect, const Radius.circular(8));
      canvas.drawRRect(rrect, highlightPaint);
      canvas.drawRRect(rrect, highlightStroke);
    } else if (selectedPart == 'arm') {
      final rArmRect = Rect.fromCenter(
        center: Offset(w * 0.78, h * 0.36),
        width: w * 0.16,
        height: h * 0.16,
      );
      final lArmRect = Rect.fromCenter(
        center: Offset(w * 0.22, h * 0.36),
        width: w * 0.16,
        height: h * 0.16,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rArmRect, const Radius.circular(8)), highlightPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rArmRect, const Radius.circular(8)), highlightStroke);
      canvas.drawRRect(RRect.fromRectAndRadius(lArmRect, const Radius.circular(8)), highlightPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(lArmRect, const Radius.circular(8)), highlightStroke);
    } else if (selectedPart == 'thigh') {
      final rThigh = Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.70),
        width: w * 0.18,
        height: h * 0.20,
      );
      final lThigh = Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.70),
        width: w * 0.18,
        height: h * 0.20,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rThigh, const Radius.circular(8)), highlightPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(rThigh, const Radius.circular(8)), highlightStroke);
      canvas.drawRRect(RRect.fromRectAndRadius(lThigh, const Radius.circular(8)), highlightPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(lThigh, const Radius.circular(8)), highlightStroke);
    }
  }

  @override
  bool shouldRepaint(covariant BodySilhouettePainter oldDelegate) {
    return oldDelegate.selectedPart != selectedPart;
  }
}
