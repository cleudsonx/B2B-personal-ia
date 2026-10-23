import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/avatar_selector_sheet.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/profile_edit_sheet.dart';
import '../../core/widgets/student_ux_components.dart';
import '../../core/widgets/app_version_footer.dart';
import '../../core/widgets/pwa_install_prompt_card.dart';
import '../../services/auth_service.dart';
import '../../services/body_metrics_service.dart';
import '../../services/referral_service.dart';
import '../../services/student_profile_service.dart';
import '../../services/workout_service.dart';
import '../auth/teacher_mfa_screen.dart';
import 'welcome_onboarding_screen.dart';
import '../../core/widgets/one_ui_glass_components.dart';

class StudentProfileScreen extends StatefulWidget {
  /// Injetáveis para testes; em produção usam o usuário autenticado e o Supabase.
  final StudentProfileService? service;
  final String? userId;
  final bool isTab;

  const StudentProfileScreen({
    super.key,
    this.service,
    this.userId,
    this.isTab = false,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final StudentProfileService _service;
  bool _isLoadingData = true;
  String? _loadError;
  StudentProfileData? _original;
  String? _email;
  List<String> _roles = const [];
  String? _totpFactorId;
  bool _isSwitchingRole = false;
  Map<String, dynamic>? _latestAnamnesis;
  int _currentStreak = 1;

  // Informações do Treinador Associado
  String? _trainerName;
  String? _trainerCref;
  String? _trainerPhotoUrl;
  String? _trainerPhone;
  bool _isLoadingTrainer = true;

  String? get _userId => widget.userId ?? AuthService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StudentProfileService();
    _load();
  }

  Future<void> _load() async {
    final uid = _userId;
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });
    if (uid == null) {
      setState(() {
        _isLoadingData = false;
        _loadError = 'Sessão expirada. Faça login novamente.';
      });
      return;
    }
    try {
      final data = await _service.load(uid);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _isLoadingData = false;
          _loadError = 'Perfil não encontrado.';
        });
        return;
      }
      _original = data;

      // Carrega a Anamnese Expandida para sincronizar biometria e metas
      try {
        final anamnesis = await WorkoutService.getLatestStudentAnamnesis(uid);
        if (anamnesis != null && mounted) {
          _latestAnamnesis = anamnesis;
          final s = anamnesis['streak_days'] ?? anamnesis['streak'];
          if (s is num) _currentStreak = s.toInt();
        }
      } catch (_) {}

      // Carregar dados de conta e sessão
      _email = AuthService.currentUser?.email;
      try {
        final profile = await AuthService.getCurrentProfile();
        if (profile != null) {
          _roles = AuthService.availableRoles(profile);
          if (_roles.contains('trainer')) {
            _totpFactorId = await AuthService.getVerifiedTotpFactorId();
          }
        }
      } catch (_) {}

      // Carregar dados do treinador associado
      _loadTrainerInfo();

      setState(() => _isLoadingData = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _loadError =
            'Não foi possível carregar seu perfil. Verifique a conexão.';
      });
    }
  }

  Future<void> _loadTrainerInfo() async {
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (!mounted) return;
      if (trainer != null) {
        setState(() {
          _trainerName =
              (trainer['trainer_name'] ?? trainer['full_name']) as String?;
          _trainerCref =
              (trainer['cref'] ?? trainer['professional_document']) as String?;
          _trainerPhotoUrl = (trainer['trainer_photo_url'] ??
              trainer['photo_url'] ??
              trainer['avatar_url']) as String?;
          _trainerPhone = (trainer['phone'] ?? trainer['whatsapp']) as String?;
          _isLoadingTrainer = false;
        });
      } else {
        setState(() => _isLoadingTrainer = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTrainer = false);
    }
  }

  Future<void> _contactTrainerWhatsApp() async {
    final rawPhone = _trainerPhone;
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      _snack(
        'Seu treinador ainda não cadastrou o WhatsApp profissional.',
        color: Colors.orange.shade800,
      );
      return;
    }
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final phone = digits.startsWith('55') ? digits : '55$digits';
    final msg = Uri.encodeComponent(
      'Olá professor(a) ${_trainerName ?? ""}! Sou aluno no Mr. Coach e gostaria de tirar uma dúvida.',
    );
    final uri =
        Uri.parse('https://api.whatsapp.com/send?phone=$phone&text=$msg');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      _snack('Não foi possível abrir o WhatsApp.', color: Colors.redAccent);
    }
  }

  void _snack(
    String msg, {
    Color? color,
    SnackBarAction? action,
    IconData? icon,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? MetaColors.emerald,
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveFromSheet(StudentProfileData updated) async {
    final uid = _userId;
    final original = _original;
    if (uid == null || original == null) return;

    final weightChanged = updated.weightKg != original.weightKg;
    final heightChanged = updated.heightCm != original.heightCm;

    final result = await _service.save(
      userId: uid,
      original: original,
      updated: updated,
    );
    _original = updated;

    if ((weightChanged || heightChanged) &&
        (updated.weightKg != null || updated.heightCm != null)) {
      try {
        await BodyMetricsService.saveMetrics(
          targetStudentId: uid,
          weightKg: updated.weightKg,
          heightCm: updated.heightCm?.toDouble(),
          notes: 'Atualização rápida no Perfil',
        );
      } catch (_) {}
    }

    try {
      AuthService.saveLastAuthenticatedUser(
        email: _email ?? '',
        name: updated.name,
        role: 'client',
        photoUrl: updated.photoUrl,
      ).catchError((_) {});
    } catch (_) {}

    if (!mounted) return;
    setState(() {});

    switch (result.review) {
      case ReviewStatus.notNeeded:
        _snack(
          'Perfil atualizado com sucesso.',
          color: MetaColors.emerald,
          icon: Icons.check_circle_rounded,
        );
        break;
      case ReviewStatus.requested:
        _snack(
          'Perfil atualizado. Seu professor foi notificado para revisar a ficha com suas novas restrições.',
          color: MetaColors.emerald,
          icon: Icons.mark_email_read_rounded,
        );
        break;
      case ReviewStatus.noTrainer:
        _snack(
          'Perfil atualizado. Você ainda não tem professor vinculado para revisar a ficha.',
          color: MetaColors.emerald,
          icon: Icons.info_outline_rounded,
        );
        break;
      case ReviewStatus.failed:
        _snack(
          'Perfil salvo, mas não conseguimos avisar seu professor para revisar a ficha.',
          color: Colors.orange.shade800,
          icon: Icons.warning_amber_rounded,
          action: SnackBarAction(
            label: 'Tentar novamente',
            textColor: Colors.white,
            onPressed: () => _service.requestReview(userId: uid, data: updated),
          ),
        );
        break;
    }
  }

  Future<void> _openEditProfileSheet() async {
    final original = _original;
    if (original == null) return;
    await ProfileEditSheet.show(
      context: context,
      initialData: original,
      onSave: _saveFromSheet,
    );
  }

  Future<void> _openShareModal() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: MetaColors.card(ctx),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: MetaColors.cardBorder(ctx)),
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
                    color: MetaColors.subtext(ctx).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Compartilhar',
                style: TextStyle(
                  color: MetaColors.text(ctx),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                title: Text(
                  'Conquistas & Selos de Força',
                  style: TextStyle(
                    color: MetaColors.text(ctx),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Text(
                  'Compartilhe seus marcos de treino e ofensiva',
                  style: TextStyle(
                    color: MetaColors.subtext(ctx),
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  StudentAchievementsModalSheet.show(
                    context,
                    userId: _userId,
                    trainerName: _trainerName,
                  );
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: MetaColors.emerald,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Convidar Amigo para Treinar',
                  style: TextStyle(
                    color: MetaColors.text(ctx),
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                subtitle: Text(
                  'Envie o link exclusivo de indicação do app',
                  style: TextStyle(
                    color: MetaColors.subtext(ctx),
                    fontSize: 12,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  final slug = ReferralService.getActiveReferralSlug() ?? 'ALUNO';
                  final link = 'https://mrcoach.app/r/$slug';
                  await Clipboard.setData(ClipboardData(text: link));
                  _snack(
                    'Link de indicação copiado: $link',
                    icon: Icons.link_rounded,
                    color: MetaColors.emerald,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(bool allDevices) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.card(ctx),
        title: Text(
          allDevices ? 'Sair de todos os dispositivos?' : 'Sair deste aparelho?',
          style: TextStyle(color: MetaColors.text(ctx)),
        ),
        content: Text(
          allDevices
              ? 'Isso revogará todas as sessões ativas da sua conta em qualquer dispositivo. Você precisará fazer login novamente.'
              : 'Deseja realmente encerrar a sessão neste dispositivo?',
          style: TextStyle(color: MetaColors.subtext(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(allDevices ? 'Revogar e Sair' : 'Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthService.signOut(allDevices: allDevices);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''), color: Colors.red);
      }
    }
  }

  Widget _buildIdentityHeroCard() {
    final d = _original;
    final emerald = AppColors.emerald(context);
    final details = (_latestAnamnesis?['details'] as Map<String, dynamic>?) ?? {};
    final weeklyDays =
        _latestAnamnesis?['weekly_days'] ?? details['weekly_days'] ?? 4;
    final ageText = d?.age != null ? '${d!.age} anos' : null;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final uid = _userId;
                  final selected = await AvatarSelectorSheet.show(
                    context: context,
                    isTrainer: false,
                    currentUrl: d?.photoUrl,
                    userId: uid,
                  );
                  if (selected != null && mounted) {
                    final updated = d!.copyWith(photoUrl: selected.isEmpty ? null : selected);
                    _saveFromSheet(updated);
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ProgressRing(
                      progress: 0.85, // Meta semanal ativa
                      size: 86,
                      strokeWidth: 4.5,
                      color: emerald,
                      center: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MetaColors.highlight(context),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (d?.photoUrl != null && d!.photoUrl!.isNotEmpty)
                            ? (d.photoUrl!.startsWith('assets/')
                                ? Image.asset(d.photoUrl!, fit: BoxFit.cover)
                                : Image.network(
                                    d.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_rounded,
                                      size: 36,
                                      color: Colors.grey,
                                    ),
                                  ))
                            : Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: emerald,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: emerald,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.card(context),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d?.name.isNotEmpty == true ? d!.name : 'Atleta Mr. Coach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (_email != null && _email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.subtext(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Decisão 2: Streak e Meta semanal no cabeçalho
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildIdentityPill(
                          icon: Icons.local_fire_department_rounded,
                          label: '$_currentStreak dias 🔥',
                          color: const Color(0xFFF59E0B),
                        ),
                        _buildIdentityPill(
                          icon: Icons.flag_rounded,
                          label: 'Meta: ${weeklyDays}x/sem',
                          color: emerald,
                        ),
                        if (ageText != null)
                          _buildIdentityPill(
                            icon: Icons.cake_outlined,
                            label: ageText,
                            color: MetaColors.accentBlue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Decisão 1 e 3: Ações "Editar perfil" (sheet) e "Compartilhar" (conquistas + convite)
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const Key('btn_open_edit_profile'),
                  onPressed: _openEditProfileSheet,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text(
                    'Editar perfil',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: emerald.withValues(alpha: 0.16),
                    foregroundColor: emerald,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const Key('btn_share_profile'),
                onPressed: _openShareModal,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text(
                  'Compartilhar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: MetaColors.highlight(context),
                  foregroundColor: MetaColors.text(context),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBiometricStats() {
    final d = _original;
    final w = d?.weightKg;
    final h = d?.heightCm;
    double? bmi;
    String bmiStatus = 'Pendente';
    Color bmiColor = MetaColors.subtext(context);

    if (w != null && h != null && h >= 100) {
      final hm = h / 100.0;
      bmi = w / (hm * hm);
      if (bmi < 18.5) {
        bmiStatus = 'Abaixo';
        bmiColor = MetaColors.accentBlue;
      } else if (bmi < 25.0) {
        bmiStatus = 'Ideal';
        bmiColor = MetaColors.emerald;
      } else if (bmi < 30.0) {
        bmiStatus = 'Atenção';
        bmiColor = const Color(0xFFF59E0B);
      } else {
        bmiStatus = 'Elevado';
        bmiColor = Colors.redAccent;
      }
    }

    final weightDisplay =
        w != null ? w.toStringAsFixed(1).replaceAll('.', ',') : '--';
    final heightDisplay =
        h != null ? (h / 100.0).toStringAsFixed(2).replaceAll('.', ',') : '--';
    final bmiDisplay =
        bmi != null ? bmi.toStringAsFixed(1).replaceAll('.', ',') : '--';

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Peso atual',
            value: weightDisplay,
            unit: 'kg',
            badgeText: w != null ? 'Ativo' : null,
            icon: Icons.monitor_weight_rounded,
            accentColor: MetaColors.emerald,
            onTap: _openEditProfileSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Estatura',
            value: heightDisplay,
            unit: 'm',
            icon: Icons.straighten_rounded,
            accentColor: MetaColors.accentBlue,
            onTap: _openEditProfileSheet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'IMC estimado',
            value: bmiDisplay,
            badgeText: bmi != null ? bmiStatus : null,
            badgeColor: bmiColor,
            icon: Icons.speed_rounded,
            accentColor: bmi != null ? bmiColor : const Color(0xFFF59E0B),
            onTap: _openEditProfileSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBentoCards() {
    return Row(
      children: [
        Expanded(
          child: MetaCard(
            onTap: () => StudentOverloadCenterSheet.show(context),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: MetaColors.emerald,
                        size: 20,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: MetaColors.emerald,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Central de Metas & 1RM',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Curvas de volume e 1RM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MetaCard(
            onTap: () => StudentAchievementsModalSheet.show(
              context,
              userId: _userId,
              trainerName: _trainerName,
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Galeria de Conquistas & Selos',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Marcos de força e volume',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnamnesisHeroCard() {
    final details = (_latestAnamnesis?['details'] as Map<String, dynamic>?) ?? {};
    final objective =
        (_latestAnamnesis?['objective'] ?? details['objective'])?.toString();
    final weeklyDays =
        (_latestAnamnesis?['weekly_days'] ?? details['weekly_days'])?.toString();
    final location = (_latestAnamnesis?['workout_location'] ??
            details['workout_location'])
        ?.toString();
    final rawPriorities =
        _latestAnamnesis?['muscle_priorities'] ?? details['muscle_priorities'];
    final List<String> priorities = rawPriorities is List
        ? rawPriorities.map((e) => e.toString()).toList()
        : [];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.emerald(context).withValues(alpha: 0.16),
            AppColors.card(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.emerald(context).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald(context).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.emerald(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anamnese Completa',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Renovação de periodização e rotina clínica',
                      style: TextStyle(
                        color: AppColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (objective != null ||
              weeklyDays != null ||
              location != null ||
              priorities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (objective != null && objective.isNotEmpty)
                  _buildAnamnesisSummaryChip(Icons.flag_rounded, objective),
                if (weeklyDays != null && weeklyDays.isNotEmpty)
                  _buildAnamnesisSummaryChip(
                    Icons.calendar_today_rounded,
                    '${weeklyDays}x / semana',
                  ),
                if (location != null && location.isNotEmpty)
                  _buildAnamnesisSummaryChip(
                    Icons.fitness_center_rounded,
                    location,
                  ),
                if (priorities.isNotEmpty)
                  _buildAnamnesisSummaryChip(
                    Icons.bolt_rounded,
                    'Foco: ${priorities.take(3).join(", ")}',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WelcomeOnboardingScreen(
                      studentName: _original?.name,
                      trainerId: _original?.trainerId,
                      isReviewMode: true,
                      initialData: _latestAnamnesis,
                    ),
                  ),
                );
                if (mounted) _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text(
                'Revisar / Atualizar Anamnese Completa',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnamnesisSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.emerald(context).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.emerald(context).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: AppColors.emerald(context)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.text(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text(context)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final d = _original;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        bottomInset + (widget.isTab ? 110 : 48),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Identity Hero Card com Avatar, ProgressRing, Streak 🔥 e Ações
          _buildIdentityHeroCard(),
          const SizedBox(height: 14),

          // 2. Pílula Compacta do Treinador Responsável (1 linha 72px)
          TrainerCompactPill(
            isLoading: _isLoadingTrainer,
            trainerName: _trainerName,
            trainerCref: _trainerCref,
            trainerPhotoUrl: _trainerPhotoUrl,
            hasWhatsApp: _trainerPhone != null && _trainerPhone!.trim().isNotEmpty,
            onWhatsAppTap: _contactTrainerWhatsApp,
          ),
          const SizedBox(height: 14),

          // 3. Card Indutor PWA
          const PwaInstallPromptCard(),
          const SizedBox(height: 18),

          // 4. Estatísticas Vivas (Peso com delta, Estatura, IMC)
          StudentSectionHeader(
            title: 'Biometria e composição',
            subtitle: 'Toque para editar ou atualizar seus dados',
            icon: Icons.monitor_weight_rounded,
            actionLabel: 'Editar',
            onActionTap: _openEditProfileSheet,
          ),
          _buildLiveBiometricStats(),
          const SizedBox(height: 22),

          // 5. Progresso & Gamificação (Bento Grid 2 colunas)
          const StudentSectionHeader(
            title: 'Performance e evolução',
            subtitle: 'Metas de sobrecarga, 1RM e marcos conquistados',
            icon: Icons.emoji_events_rounded,
            iconColor: Color(0xFFF59E0B),
          ),
          _buildProgressBentoCards(),
          const SizedBox(height: 22),

          // 6. Saúde & Anamnese Completa
          const StudentSectionHeader(
            title: 'Saúde e periodização',
            subtitle: 'Ficha clínica e preferências de rotina',
            icon: Icons.favorite_rounded,
          ),
          _buildAnamnesisHeroCard(),
          const SizedBox(height: 22),

          // 7. Preferências e Conta (Lista Agrupada estilo One UI / iOS 18)
          const StudentSectionHeader(
            title: 'Preferências e conta',
            icon: Icons.settings_rounded,
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aparência do aplicativo',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) {
                    final currentMode = ThemeController.instance.themeMode;
                    return SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Escuro'),
                            icon: Icon(Icons.dark_mode_rounded),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Claro'),
                            icon: Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('Sistema'),
                            icon: Icon(Icons.brightness_auto_rounded),
                          ),
                        ],
                        selected: {currentMode},
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            ThemeController.instance.setThemeMode(selection.first);
                          }
                        },
                        emptySelectionAllowed: false,
                      ),
                    );
                  },
                ),
                // Decisão 4: "Usar aplicativo como" só para quem tem mais de um papel
                if (_roles.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Usar aplicativo como',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        for (final role in _roles)
                          ButtonSegment<String>(
                            value: role,
                            label: Text(
                              role == 'admin'
                                  ? 'Admin ⚡'
                                  : (role == 'trainer' ? 'Treinador' : 'Aluno'),
                            ),
                            icon: Icon(
                              role == 'admin'
                                  ? Icons.admin_panel_settings_rounded
                                  : (role == 'trainer'
                                      ? Icons.fitness_center
                                      : Icons.person_outline),
                            ),
                          ),
                      ],
                      selected: const {'client'},
                      onSelectionChanged: (selection) async {
                        if (_isSwitchingRole) return;
                        final nextRole = selection.first;
                        if (nextRole == 'client') return;
                        setState(() => _isSwitchingRole = true);
                        try {
                          await AuthService.setActiveRole(nextRole);
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                          }
                        } catch (e) {
                          if (mounted) {
                            _snack(e.toString().replaceFirst('Exception: ', ''));
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSwitchingRole = false);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.tune_rounded,
                title: 'Dados cadastrais e restrições',
                subtitle: '${d?.name ?? "Editar"} • ${d?.restrictions.length ?? 0} restrições',
                onTap: _openEditProfileSheet,
              ),
              SettingsTile(
                icon: Icons.public_rounded,
                title: 'Fuso horário',
                trailingText: d?.timezone ?? 'UTC',
                onTap: _openEditProfileSheet,
              ),
              if (_roles.contains('trainer'))
                SettingsTile(
                  icon: Icons.security_rounded,
                  title: 'Verificação em duas etapas (2FA)',
                  subtitle: _totpFactorId == null
                      ? 'Recomendado para proteger acesso de treinador'
                      : 'Autenticador ativo e verificado',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherMfaScreen()),
                    );
                    _load();
                  },
                ),
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Sair neste aparelho',
                subtitle: 'Encerrar sessão atual com segurança',
                isDestructive: true,
                onTap: () => _signOut(false),
              ),
              SettingsTile(
                icon: Icons.phonelink_erase_rounded,
                iconColor: MetaColors.subtext(context),
                title: 'Sair de todos os dispositivos',
                subtitle: 'Revogar acessos ativos em outros aparelhos',
                onTap: () => _signOut(true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const AppVersionFooter(userRole: 'student'),
        ],
      ),
    );
  }

  void _openCoachSheet() {
    final name = _trainerName ?? 'Seu Treinador';
    final subtitle = (_trainerCref != null && _trainerCref!.isNotEmpty) ? _trainerCref! : 'CREF Ativo';
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
                  name,
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
          subtitle: 'Tire dúvidas direto com seu treinador',
          onTap: _contactTrainerWhatsApp,
        ),
      ],
    );
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
          icon: Icons.edit_rounded,
          label: 'Editar Dados Cadastrais',
          subtitle: 'Nome, peso, altura e telefone',
          color: MetaColors.emerald,
          onTap: _openEditProfileSheet,
        ),
        GlassAction(
          icon: Icons.account_circle_rounded,
          label: 'Trocar Foto / Avatar',
          subtitle: 'Escolha um avatar ou foto de perfil',
          color: MetaColors.accentBlue,
          onTap: () async {
            final uid = _userId;
            final selected = await AvatarSelectorSheet.show(
              context: context,
              isTrainer: false,
              currentUrl: _original?.photoUrl,
              userId: uid,
            );
            if (selected != null && mounted && _original != null) {
              final updated = _original!.copyWith(photoUrl: selected.isEmpty ? null : selected);
              _saveFromSheet(updated);
            }
          },
        ),
        GlassAction(
          icon: Icons.explore_rounded,
          label: 'Tour do Aluno',
          subtitle: 'Apresentação rápida das funções',
          onTap: () => InteractiveTourGuideModal.show(context, role: 'student'),
        ),
        GlassAction(
          icon: Icons.logout_rounded,
          label: 'Sair deste aparelho',
          subtitle: 'Encerrar sessão com segurança',
          color: Colors.redAccent,
          onTap: () => _signOut(false),
        ),
      ],
    );
  }

  Widget _buildCoachAvatar({double size = 40}) {
    final hasPhoto = _trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty;
    final initials = (_trainerName ?? 'Personal')
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

  Widget _buildProfileHeader(bool showBackButton) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 18,
        right: 18,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            GlassIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Voltar',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meu Perfil & Conta',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Biometria • Metas • Configurações',
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_trainerName != null && _trainerName!.isNotEmpty) ...[
            GestureDetector(
              onTap: _openCoachSheet,
              behavior: HitTestBehavior.opaque,
              child: _buildCoachAvatar(size: 38),
            ),
            const SizedBox(width: 8),
          ],
          GlassIconButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'Menu',
            onTap: _openMoreMenu,
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final showBackButton = !widget.isTab && canPop;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          const AmbientGlowCanvas(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildProfileHeader(showBackButton),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
