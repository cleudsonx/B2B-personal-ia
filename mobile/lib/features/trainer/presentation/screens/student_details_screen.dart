import '../../../../core/widgets/theme_toggle_button.dart';
import '../../../../services/workout_service.dart';
import '../../../../services/evolution_photo_service.dart';
import '../../../../services/body_metrics_service.dart';
import '../../../../core/widgets/split_photo_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/widgets/exercise_media_sheet.dart';
import '../../../../models/exercise_model.dart';
import '../../../../models/split_model.dart';
import '../../../../models/workout_plan_model.dart';
import '../../../../services/invite_service.dart';
import '../../../../services/subscription_service.dart';
import '../../../../models/subscription_model.dart';
import '../../../../features/subscription/subscription_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../anamnesis_screen.dart';

typedef StudentUpdateAction = Future<bool> Function({
  required String studentId,
  String? fullName,
  String? phone,
  String? goal,
  String? injuriesOrRestrictions,
});
typedef StudentStatusAction = Future<bool> Function({
  required String studentId,
  required String status,
});
typedef StudentDeleteAction = Future<bool> Function(String studentId);
typedef ActiveWorkoutLoader = Future<dynamic> Function(String studentId);
typedef EvolutionPhotosLoader = Future<Map<String, EvolutionPhoto?>> Function(String studentId);

class StudentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final StudentUpdateAction? onUpdateStudent;
  final StudentStatusAction? onUpdateStudentStatus;
  final StudentDeleteAction? onDeleteStudent;
  final ActiveWorkoutLoader? loadActiveWorkout;
  final EvolutionPhotosLoader? loadEvolutionPhotos;

  const StudentDetailsScreen({
    super.key,
    required this.studentData,
    this.onUpdateStudent,
    this.onUpdateStudentStatus,
    this.onDeleteStudent,
    this.loadActiveWorkout,
    this.loadEvolutionPhotos,
  });

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  late Map<String, dynamic> student;
  bool _isLoadingWorkout = true;
  bool _isResendingInvite = false;
  dynamic _activeWorkout;
  Map<String, dynamic>? _studentBioFeedback;
  bool _isLoadingBioFeedback = true;
  EvolutionPhoto? _studentBeforePhoto;
  EvolutionPhoto? _studentAfterPhoto;
  bool _isLoadingPhotos = true;
  bool _useSplitSlider = true;
  List<BodyMetricsRecord> _studentMetrics = [];
  bool _isLoadingMetrics = true;
  Map<String, dynamic>? _studentRecovery;
  List<Map<String, dynamic>> _studentOverloads = [];
  Map<String, dynamic>? _studentAlert;

  @override
  void initState() {
    super.initState();
    student = widget.studentData;
    _fetchWorkout();
    _fetchBioFeedback();
  }

  Future<void> _fetchBioFeedback() async {
    try {
      final studentId = student['id']?.toString();
      if (studentId == null || studentId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingBioFeedback = false;
            _isLoadingPhotos = false;
            _isLoadingMetrics = false;
          });
        }
        return;
      }

      // Sincronizar dados cadastrais, objetivo e restrições atualizados pelo aluno (profiles + anamnesis)
      try {
        final profileRes = await WorkoutService.getStudentProfile(studentId);
        final latestAnamnesis = await WorkoutService.getLatestStudentAnamnesis(studentId);
        if (mounted) {
          setState(() {
            if (profileRes != null) {
              student['full_name'] = profileRes['full_name'] ?? student['full_name'];
              student['age'] = profileRes['age'] ?? student['age'];
              student['weight_kg'] = profileRes['weight_kg'] ?? student['weight_kg'];
              student['height_cm'] = profileRes['height_cm'] ?? student['height_cm'];
              student['phone'] = profileRes['phone'] ?? student['phone'];
              student['goal'] = profileRes['goal'] ?? student['goal'];
              student['clinical_restrictions'] = profileRes['clinical_restrictions'] ?? student['clinical_restrictions'];
              student['injuries_or_restrictions'] = profileRes['injuries_or_restrictions'] ??
                  profileRes['clinical_restrictions'] ??
                  student['injuries_or_restrictions'];
              student['avatar_url'] = profileRes['avatar_url'] ?? profileRes['photo_url'] ?? student['avatar_url'];
              student['photo_url'] = profileRes['photo_url'] ?? profileRes['avatar_url'] ?? student['photo_url'];
            }
            if (latestAnamnesis != null) {
              if (latestAnamnesis['objective'] != null && latestAnamnesis['objective'].toString().trim().isNotEmpty) {
                student['goal'] = latestAnamnesis['objective'].toString().trim();
              }
              final med = latestAnamnesis['medical_conditions'] ?? latestAnamnesis['injuries'];
              if (med != null && med.toString().trim().isNotEmpty) {
                student['injuries_or_restrictions'] = med.toString().trim();
                student['clinical_restrictions'] = med.toString().trim();
              }
              if (latestAnamnesis['weight'] != null) {
                student['weight_kg'] = latestAnamnesis['weight'];
              }
              if (latestAnamnesis['height'] != null) {
                student['height_cm'] = latestAnamnesis['height'];
              }
              if (latestAnamnesis['age'] != null) {
                student['age'] = latestAnamnesis['age'];
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Aviso ao sincronizar perfil do aluno em tempo real: $e');
      }

      // Buscar telemetria de RPE e Dores
      final fb = await WorkoutService.getStudentWorkoutFeedback(studentId);
      if (mounted) {
        setState(() {
          _studentBioFeedback = fb;
          _isLoadingBioFeedback = false;
        });
      }

      // Buscar Recovery Diário (Prontidão, Sono, DOMS)
      try {
        final rec = await WorkoutService.getLatestDailyRecovery(studentId);
        if (mounted) setState(() => _studentRecovery = rec);
      } catch (_) {}

      // Buscar Cargas de Sobrecarga Progressiva Real
      try {
        final overloads = await WorkoutService.getStudentProgressiveOverload(studentId);
        if (mounted) setState(() => _studentOverloads = overloads);
      } catch (_) {}

      // Buscar alertas biomecânicos pendentes de adaptação
      try {
        final alerts = await WorkoutService.getTrainerAlerts();
        final pendingAlert = alerts.firstWhere(
          (a) =>
              (a['student_id']?.toString() == studentId ||
                  a['client_id']?.toString() == studentId) &&
              (a['status'] == 'active' || a['acknowledged'] == false),
          orElse: () => <String, dynamic>{},
        );
        if (mounted) {
          setState(() {
            _studentAlert = pendingAlert.isNotEmpty ? pendingAlert : null;
          });
        }
      } catch (_) {}

      // Buscar fotos confidenciais de evolução (Antes x Depois)
      try {
        final photos = widget.loadEvolutionPhotos != null
            ? await widget.loadEvolutionPhotos!(studentId)
            : await EvolutionPhotoService.getStudentBeforeAndAfter(studentId);
        if (mounted) {
          setState(() {
            _studentBeforePhoto = photos['before'];
            _studentAfterPhoto = photos['after'];
            _isLoadingPhotos = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingPhotos = false);
      }

      // Buscar Medidas Corporais Antropométricas (Bio-Hub 2.0)
      try {
        final metrics = await BodyMetricsService.getMetricsHistory(studentId);
        if (mounted) {
          setState(() {
            _studentMetrics = metrics;
            _isLoadingMetrics = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingMetrics = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingBioFeedback = false;
          _isLoadingPhotos = false;
          _isLoadingMetrics = false;
        });
      }
    }
  }

  Color _getRpeColor(double val) {
    if (val <= 4.0) return MetaColors.emerald;
    if (val <= 6.5) return const Color(0xFFF59E0B); // Amber
    if (val <= 8.5) return Colors.orange;
    return const Color(0xFFEF4444); // Red
  }

  String _getRpeLabel(double val) {
    if (val <= 3.0) return 'Muito Leve';
    if (val <= 5.0) return 'Moderado';
    if (val <= 7.0) return 'Vigoroso';
    if (val <= 8.5) return 'Muito Intenso';
    return 'Exaustão Máxima';
  }

  Future<void> _fetchWorkout() async {
    try {
      final studentId = student['id'] as String;
      final workout = widget.loadActiveWorkout != null
          ? await widget.loadActiveWorkout!(studentId)
          : await WorkoutService.getActiveWorkoutForClient(clientId: studentId);
      if (mounted) {
        setState(() {
          _activeWorkout = workout;
          _isLoadingWorkout = false;
          if (workout != null) {
            student['has_active_prescription'] = true;
            if (workout is WorkoutPlanModel) {
              student['active_split'] = workout.workoutPlanTitle;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWorkout = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefone não cadastrado. Edite os dados do aluno para informar o número de WhatsApp.')),
        );
      }
      return;
    }
    final cleanPhone = digits.startsWith('55') ? digits : '55$digits';
    setState(() => _isResendingInvite = true);
    try {
      String? inviteUrl = student['invitation_link'] as String?;
      final studentEmail = (student['email'] as String?)?.trim();

      try {
        final invite = await InviteService.createInvite(
          channel: 'whatsapp',
          targetPhone: cleanPhone,
          targetEmail: (studentEmail != null && studentEmail.isNotEmpty) ? studentEmail : null,
          targetName: name,
        );
        final url = invite['invite_url'] as String?;
        if (url != null && url.isNotEmpty) {
          inviteUrl = url;
          if (mounted) {
            setState(() {
              student['invitation_link'] = url;
            });
          }
        }
      } catch (createErr) {
        debugPrint('[StudentDetails] Erro ao obter novo link de convite pela API: $createErr');
        // Se a API falhou mas já tínhamos o link guardado localmente, usamos o fallback
        if (inviteUrl == null || inviteUrl.isEmpty) {
          rethrow;
        }
      }

      if (inviteUrl == null || inviteUrl.isEmpty) {
        throw StateError('O link de convite não está disponível no momento.');
      }

      final messageText =
          'Olá, $name! Seu convite para acessar o Mr. Coach está pronto. '
          'Acesse pelo link abaixo para começar seus treinos:\n$inviteUrl\n\n'
          'Será um prazer acompanhar sua evolução!';
      final encodedMsg = Uri.encodeComponent(messageText);

      final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
      final webApiUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');
      final waMeUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

      var launched = false;
      try {
        launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(webApiUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      if (!launched) {
        try {
          launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      if (!launched && mounted) {
        await Clipboard.setData(ClipboardData(text: '$messageText\n\n$inviteUrl'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link de convite copiado para a área de transferência! Cole na conversa com o aluno.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      debugPrint('Falha ao reenviar convite pelo WhatsApp: $error');
      if (mounted) {
        final errStr = error.toString().toLowerCase();
        String userMessage = 'Não foi possível gerar o convite para WhatsApp.';
        if (errStr.contains('limite') || errStr.contains('23514')) {
          userMessage = 'Limite de alunos ativos atingido no seu plano. Faça upgrade para liberar novas vagas.';
        } else if (errStr.contains('telefone')) {
          userMessage = 'Telefone inválido ou não informado.';
        } else {
          final cleanDetail = error.toString().replaceAll('Exception: ', '').trim();
          if (cleanDetail.isNotEmpty && cleanDetail.length < 120) {
            userMessage = cleanDetail;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: MetaColors.surfaceHighlight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResendingInvite = false);
    }
  }

  Future<void> _resendInvitationEmail(String name, String phone) async {
    final email = student['email'] as String?;
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este aluno não possui e-mail cadastrado.')),
      );
      return;
    }
    setState(() => _isResendingInvite = true);
    try {
      final sent = await WorkoutService.resendInvitationEmail(
        fullName: name,
        email: email,
        phone: phone,
        goal: student['goal'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sent
                ? 'Convite reenviado para $email.'
                : 'Não foi possível reenviar o convite por e-mail.'),
          ),
        );
      }
    } catch (error) {
      debugPrint('Falha ao reenviar convite por e-mail: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reenviar o convite por e-mail.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResendingInvite = false);
    }
  }

  Future<void> _openWorkoutPrescription() async {
    await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAnamnesisScreen(
          initialStudentId: student['id'] as String?,
          initialStudentName: student['full_name'] as String?,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isLoadingWorkout = true);
    await _fetchWorkout();
    WorkoutService.studentsRefreshNotifier.value++;
  }

  Future<void> _deleteActiveWorkout() async {
    final name = student['full_name'] as String? ?? 'Aluno';
    final isDark = MetaColors.isDark(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? MetaColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Excluir Ficha',
                style: TextStyle(
                  color: MetaColors.text(dialogCtx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja desativar a periodização ativa de $name? O aluno não terá fichas ativas até que você prescreva um novo treino.',
          style: TextStyle(
            color: MetaColors.subtext(dialogCtx),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: MetaColors.subtext(dialogCtx), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Excluir Ficha', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingWorkout = true);
    try {
      final studentId = student['id'] as String;
      String? workoutId;
      if (_activeWorkout is WorkoutPlanModel) {
        workoutId = (_activeWorkout as WorkoutPlanModel).id;
      }
      await WorkoutService.deleteWorkoutPlan(clientId: studentId, workoutId: workoutId);
      if (mounted) {
        setState(() {
          _activeWorkout = null;
          _isLoadingWorkout = false;
          student['has_active_prescription'] = false;
          student['active_split'] = null;
        });
        WorkoutService.studentsRefreshNotifier.value++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFF1E293B),
            content: const Text('Ficha de treino desativada com sucesso.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkout = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Erro ao excluir ficha: $e'),
          ),
        );
      }
    }
  }

  Future<void> _renewActiveWorkout() async {
    final name = student['full_name'] as String? ?? 'Aluno';
    final studentId = student['id'] as String;
    final isDark = MetaColors.isDark(context);

    // Trava clínica: verifica se o aluno registrou nova dor/lesão pós emissão da ficha
    final safety = await WorkoutService.checkAnamnesisRenewalSafety(
      clientId: studentId,
      workoutUpdatedAt: _activeWorkout is WorkoutPlanModel
          ? (_activeWorkout as WorkoutPlanModel).createdAt?.toIso8601String()
          : null,
    );

    if (safety['has_recent_changes'] == true && safety['has_restrictions'] == true) {
      if (!mounted) return;
      final injuries = safety['injuries_summary'] ?? 'Dores/Limitações relatadas';
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: MetaColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MetaColors.subtext(context).withValues(alpha: 0.4),
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
                        color: Colors.amber.shade900.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Atenção Clínica • Trava de Segurança',
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Alteração recente na anamnese do aluno',
                            style: TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$name atualizou a anamnese após a emissão desta ficha e relatou: "$injuries".\n\n'
                    'Recomendamos gerar uma nova periodização personalizada com a IA para poupar as articulações afetadas.',
                    style: const TextStyle(color: MetaColors.textPrimary, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
                SquircleButton(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Prescrever Nova Periodização Adaptada',
                  isPrimary: true,
                  onPressed: () {
                    Navigator.pop(ctx, 'prescribe');
                  },
                ),
                const SizedBox(height: 10),
                SquircleButton(
                  icon: Icons.autorenew_rounded,
                  label: 'Confirmar Renovação Sem Alterar Ficha',
                  isPrimary: false,
                  onPressed: () {
                    Navigator.pop(ctx, 'renew');
                  },
                ),
              ],
            ),
          );
        },
      );

      if (action == 'prescribe') {
        _openWorkoutPrescription();
        return;
      } else if (action != 'renew') {
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? MetaColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MetaColors.primaryColor(dialogCtx).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.replay_rounded, color: MetaColors.primaryColor(dialogCtx), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Renovar Periodização',
                style: TextStyle(
                  color: MetaColors.text(dialogCtx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja renovar o ciclo da periodização ativa de $name? A data de validade será estendida e o ciclo continuará ativo no aplicativo do aluno.',
          style: TextStyle(
            color: MetaColors.subtext(dialogCtx),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: MetaColors.subtext(dialogCtx), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.primaryColor(dialogCtx),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Confirmar Renovação', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingWorkout = true);
    try {
      final studentId = student['id'] as String;
      String? workoutId;
      if (_activeWorkout is WorkoutPlanModel) {
        workoutId = (_activeWorkout as WorkoutPlanModel).id;
      }
      await WorkoutService.renewWorkoutPlan(clientId: studentId, workoutId: workoutId);
      await _fetchWorkout();
      student['has_active_prescription'] = true;
      if (_activeWorkout is WorkoutPlanModel) {
        student['active_split'] = (_activeWorkout as WorkoutPlanModel).workoutPlanTitle;
      }
      WorkoutService.studentsRefreshNotifier.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('Periodização de $name renovada com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWorkout = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Erro ao renovar periodização: $e'),
          ),
        );
      }
    }
  }

  void _viewFullWorkoutDetails(WorkoutPlanModel initialPlan) {
    final isDark = MetaColors.isDark(context);
    var currentPlan = initialPlan;
    final studentId = student['id']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            final splits = currentPlan.splits;

            Future<void> savePlanChanges(WorkoutPlanModel nextPlan, String feedbackMessage) async {
              setSheetState(() {
                currentPlan = nextPlan;
              });
              final saved = await WorkoutService.updateActiveWorkoutPlan(
                clientId: studentId,
                updatedPlan: nextPlan,
              );
              if (mounted) {
                setState(() {
                  _activeWorkout = saved ?? nextPlan;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: MetaColors.surfaceHighlight,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feedbackMessage,
                            style: const TextStyle(color: MetaColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }

            Future<void> openExerciseEditor({
              required int splitIndex,
              ExerciseModel? existingExercise,
              int? exerciseIndex,
            }) async {
              final isNew = existingExercise == null;
              final nameCtrl = TextEditingController(text: existingExercise?.name ?? '');
              final muscleCtrl = TextEditingController(text: existingExercise?.targetMuscleGroup ?? '');
              final setsCtrl = TextEditingController(text: (existingExercise?.sets ?? 3).toString());
              final repsCtrl = TextEditingController(text: existingExercise?.reps ?? '10-12');
              final restCtrl = TextEditingController(text: (existingExercise?.restSeconds ?? 60).toString());
              final notesCtrl = TextEditingController(text: existingExercise?.notes ?? '');

              await showDialog<void>(
                context: bottomSheetCtx,
                builder: (dialogCtx) {
                  return AlertDialog(
                    backgroundColor: isDark ? MetaColors.surface : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isNew ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                            color: MetaColors.emerald,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isNew ? 'Adicionar Exercício' : 'Editar Exercício',
                            style: TextStyle(
                              color: MetaColors.text(dialogCtx),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameCtrl,
                            style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Nome do Exercício',
                              labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                              filled: true,
                              fillColor: MetaColors.highlight(dialogCtx),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: muscleCtrl,
                            style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Grupo Muscular (ex: Peitoral, Dorsais)',
                              labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                              filled: true,
                              fillColor: MetaColors.highlight(dialogCtx),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: setsCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Séries',
                                    labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                                    filled: true,
                                    fillColor: MetaColors.highlight(dialogCtx),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: repsCtrl,
                                  style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Repetições',
                                    labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                                    filled: true,
                                    fillColor: MetaColors.highlight(dialogCtx),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: restCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Descanso (s)',
                                    labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                                    filled: true,
                                    fillColor: MetaColors.highlight(dialogCtx),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 2,
                            style: TextStyle(color: MetaColors.text(dialogCtx), fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Observações / Cadência / Dica Técnica',
                              labelStyle: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 12),
                              filled: true,
                              fillColor: MetaColors.highlight(dialogCtx),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      if (!isNew && exerciseIndex != null)
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            final targetSplit = currentPlan.splits[splitIndex];
                            final updatedExList = List<ExerciseModel>.from(targetSplit.exercises)
                              ..removeAt(exerciseIndex);
                            for (var i = 0; i < updatedExList.length; i++) {
                              updatedExList[i] = updatedExList[i].copyWith(order: i + 1);
                            }
                            final nextSplits = List<SplitModel>.from(currentPlan.splits);
                            nextSplits[splitIndex] = targetSplit.copyWith(exercises: updatedExList);
                            await savePlanChanges(
                              currentPlan.copyWith(splits: nextSplits),
                              'Exercício removido da ficha ativa!',
                            );
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          label: const Text('Excluir', style: TextStyle(color: Colors.redAccent)),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(dialogCtx))),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetaColors.emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final cleanName = nameCtrl.text.trim();
                          if (cleanName.isEmpty) return;
                          Navigator.pop(dialogCtx);

                          final parsedSets = int.tryParse(setsCtrl.text.trim()) ?? 3;
                          final parsedRest = int.tryParse(restCtrl.text.trim()) ?? 60;
                          final cleanReps = repsCtrl.text.trim().isEmpty ? '10-12' : repsCtrl.text.trim();
                          final targetSplit = currentPlan.splits[splitIndex];
                          final updatedExList = List<ExerciseModel>.from(targetSplit.exercises);

                          if (isNew) {
                            updatedExList.add(
                              ExerciseModel(
                                order: updatedExList.length + 1,
                                name: cleanName,
                                targetMuscleGroup: muscleCtrl.text.trim(),
                                sets: parsedSets,
                                reps: cleanReps,
                                restSeconds: parsedRest,
                                notes: notesCtrl.text.trim(),
                                substitutionVector: '',
                              ),
                            );
                          } else if (exerciseIndex != null) {
                            updatedExList[exerciseIndex] = existingExercise.copyWith(
                              name: cleanName,
                              targetMuscleGroup: muscleCtrl.text.trim(),
                              sets: parsedSets,
                              reps: cleanReps,
                              restSeconds: parsedRest,
                              notes: notesCtrl.text.trim(),
                            );
                          }

                          final nextSplits = List<SplitModel>.from(currentPlan.splits);
                          nextSplits[splitIndex] = targetSplit.copyWith(exercises: updatedExList);
                          await savePlanChanges(
                            currentPlan.copyWith(splits: nextSplits),
                            isNew
                                ? '"$cleanName" adicionado ao Split ${targetSplit.splitIdentifier}!'
                                : '"$cleanName" atualizado na ficha ativa!',
                          );
                        },
                        child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
              );
            }

            return Container(
              height: MediaQuery.of(bottomSheetCtx).size.height * 0.88,
              decoration: BoxDecoration(
                color: isDark ? MetaColors.background : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: MetaColors.cardBorder(bottomSheetCtx)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: MetaColors.cardBorder(bottomSheetCtx),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: MetaColors.emerald.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text(
                                      'FICHA INTERATIVA • EDIÇÃO RÁPIDA',
                                      style: TextStyle(
                                        color: MetaColors.emerald,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${splits.length} divisões',
                                    style: TextStyle(
                                      color: MetaColors.subtext(bottomSheetCtx),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentPlan.workoutPlanTitle,
                                style: TextStyle(
                                  color: MetaColors.text(bottomSheetCtx),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: MetaColors.subtext(bottomSheetCtx)),
                          onPressed: () => Navigator.pop(bottomSheetCtx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: MetaColors.cardBorder(bottomSheetCtx), height: 1),
                  if (splits.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Nenhum split detalhado nesta ficha.',
                          style: TextStyle(color: MetaColors.subtext(bottomSheetCtx)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: DefaultTabController(
                        length: splits.length,
                        child: Column(
                          children: [
                            Container(
                              color: isDark ? MetaColors.surface : Colors.white,
                              child: TabBar(
                                isScrollable: splits.length > 3,
                                tabAlignment: splits.length > 3 ? TabAlignment.start : null,
                                indicatorColor: MetaColors.primaryColor(bottomSheetCtx),
                                labelColor: MetaColors.primaryColor(bottomSheetCtx),
                                unselectedLabelColor: MetaColors.subtext(bottomSheetCtx),
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                tabs: splits.map((s) {
                                  return Tab(
                                    text: 'Split ${s.splitIdentifier}: ${s.splitName}',
                                  );
                                }).toList(),
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: splits.asMap().entries.map((splitEntry) {
                                  final splitIdx = splitEntry.key;
                                  final split = splitEntry.value;
                                  return ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isDark ? MetaColors.surface : Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: MetaColors.cardBorder(bottomSheetCtx)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timer_outlined, size: 18, color: MetaColors.primaryColor(bottomSheetCtx)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Duração: ${split.estimatedDurationMin} min',
                                              style: TextStyle(
                                                color: MetaColors.text(bottomSheetCtx),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () => openExerciseEditor(splitIndex: splitIdx),
                                              style: TextButton.styleFrom(
                                                foregroundColor: MetaColors.emerald,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                              label: const Text(
                                                'Novo Exercício',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ...split.exercises.asMap().entries.map((entry) {
                                        final exIdx = entry.key;
                                        final idx = exIdx + 1;
                                        final ex = entry.value;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: isDark ? MetaColors.surface : Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: MetaColors.cardBorder(bottomSheetCtx)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: MetaColors.primaryColor(bottomSheetCtx).withValues(alpha: 0.15),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      '$idx',
                                                      style: TextStyle(
                                                        color: MetaColors.primaryColor(bottomSheetCtx),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          ex.name,
                                                          style: TextStyle(
                                                            color: MetaColors.text(bottomSheetCtx),
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        if (ex.targetMuscleGroup.isNotEmpty) ...[
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            ex.targetMuscleGroup,
                                                            style: TextStyle(
                                                              color: MetaColors.primaryColor(bottomSheetCtx),
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    onPressed: () => ExerciseMediaSheet.show(
                                                      bottomSheetCtx,
                                                      exerciseName: ex.name,
                                                    ),
                                                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20, color: MetaColors.emerald),
                                                    tooltip: 'Vídeo Demonstrativo',
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                  IconButton(
                                                    onPressed: () => openExerciseEditor(
                                                      splitIndex: splitIdx,
                                                      existingExercise: ex,
                                                      exerciseIndex: exIdx,
                                                    ),
                                                    icon: const Icon(Icons.edit_outlined, size: 18, color: MetaColors.emerald),
                                                    tooltip: 'Editar exercício',
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 6,
                                                children: [
                                                  _buildDetailBadge(
                                                    bottomSheetCtx,
                                                    Icons.repeat_rounded,
                                                    '${ex.sets} séries × ${ex.reps}',
                                                  ),
                                                  _buildDetailBadge(
                                                    bottomSheetCtx,
                                                    Icons.hourglass_bottom_rounded,
                                                    'Descanso: ${ex.restSeconds}s',
                                                  ),
                                                ],
                                              ),
                                              if (ex.notes.isNotEmpty) ...[
                                                const SizedBox(height: 10),
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Icon(Icons.info_outline, size: 16, color: MetaColors.subtext(bottomSheetCtx)),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          ex.notes,
                                                          style: TextStyle(
                                                            color: MetaColors.text(bottomSheetCtx),
                                                            fontSize: 12,
                                                            height: 1.3,
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
                                      }),
                                      const SizedBox(height: 6),
                                      OutlinedButton.icon(
                                        onPressed: () => openExerciseEditor(splitIndex: splitIdx),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: MetaColors.emerald,
                                          side: BorderSide(color: MetaColors.emerald.withValues(alpha: 0.45)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                        label: Text('Adicionar Exercício ao Split ${split.splitIdentifier}'),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBadge(BuildContext context, IconData icon, String label) {
    final isDark = MetaColors.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? MetaColors.highlight(context) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MetaColors.primaryColor(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editStudent() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: student['full_name'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: student['phone'] as String? ?? '',
    );
    final goalController = TextEditingController(
      text: student['goal'] as String? ?? '',
    );
    final restrictionsController = TextEditingController(
      text: student['injuries_or_restrictions'] as String? ?? '',
    );
    var isSaving = false;
    String? errorMessage;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = MetaColors.isDark(dialogContext);

          InputDecoration buildInputDecoration({
            required String labelText,
            required IconData prefixIcon,
            Widget? suffixIcon,
            String? helperText,
            String? hintText,
            bool isReadOnly = false,
          }) {
            final fillColor = isReadOnly
                ? (isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9))
                : MetaColors.highlight(dialogContext);
            final borderColor = MetaColors.cardBorder(dialogContext);

            return InputDecoration(
              labelText: labelText,
              hintText: hintText,
              helperText: helperText,
              helperMaxLines: 2,
              labelStyle: TextStyle(
                color: MetaColors.subtext(dialogContext),
                fontSize: 13,
              ),
              floatingLabelStyle: TextStyle(
                color: isReadOnly
                    ? MetaColors.subtext(dialogContext)
                    : MetaColors.primaryColor(dialogContext),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                prefixIcon,
                size: 20,
                color: isReadOnly
                    ? MetaColors.subtext(dialogContext)
                    : MetaColors.primaryColor(dialogContext),
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isReadOnly ? borderColor : MetaColors.primaryColor(dialogContext),
                  width: 1.5,
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: MetaColors.card(dialogContext),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MetaColors.primaryColor(dialogContext).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: MetaColors.primaryColor(dialogContext),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar Perfil do Aluno',
                        style: TextStyle(
                          color: MetaColors.text(dialogContext),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atualize os dados cadastrais',
                        style: TextStyle(
                          color: MetaColors.subtext(dialogContext),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            scrollable: true,
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('student_full_name'),
                      controller: nameController,
                      style: TextStyle(color: MetaColors.text(dialogContext), fontSize: 15),
                      decoration: buildInputDecoration(
                        labelText: 'Nome completo',
                        hintText: 'Nome do aluno',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Informe o nome do aluno.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('student_email_read_only'),
                      initialValue: student['email'] as String? ?? '',
                      readOnly: true,
                      style: TextStyle(
                        color: MetaColors.subtext(dialogContext),
                        fontSize: 15,
                      ),
                      decoration: buildInputDecoration(
                        labelText: 'E-mail de acesso',
                        prefixIcon: Icons.email_outlined,
                        suffixIcon: Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: MetaColors.subtext(dialogContext),
                        ),
                        helperText: 'A alteração do e-mail exige confirmação da conta.',
                        isReadOnly: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('student_phone'),
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: MetaColors.text(dialogContext), fontSize: 15),
                      decoration: buildInputDecoration(
                        labelText: 'WhatsApp / Telefone',
                        hintText: '(DD) 99999-9999',
                        prefixIcon: Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('student_goal'),
                      controller: goalController,
                      style: TextStyle(color: MetaColors.text(dialogContext), fontSize: 15),
                      decoration: buildInputDecoration(
                        labelText: 'Objetivo',
                        hintText: 'Ex: Hipertrofia, Emagrecimento, Saúde',
                        prefixIcon: Icons.flag_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('student_restrictions'),
                      controller: restrictionsController,
                      maxLines: 3,
                      style: TextStyle(color: MetaColors.text(dialogContext), fontSize: 15),
                      decoration: buildInputDecoration(
                        labelText: 'Lesões e restrições',
                        hintText: 'Ex: Condromalácia patelar, hérnia de disco',
                        prefixIcon: Icons.healing_outlined,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                key: const Key('student_edit_error'),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: MetaColors.subtext(dialogContext),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      key: const Key('save_student_profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.primaryColor(dialogContext),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() {
                                isSaving = true;
                                errorMessage = null;
                              });
                              try {
                                final update = widget.onUpdateStudent ??
                                    WorkoutService.updateStudent;
                                final success = await update(
                                  studentId: student['id'] as String,
                                  fullName: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  goal: goalController.text.trim(),
                                  injuriesOrRestrictions:
                                      restrictionsController.text.trim(),
                                );
                                if (!success) {
                                  throw StateError('O servidor não confirmou a atualização.');
                                }
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (error) {
                                setDialogState(() {
                                  isSaving = false;
                                  errorMessage = _formatErrorMessage(error);
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Salvar Alterações',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
      goalController.dispose();
      restrictionsController.dispose();
    });

    if (saved == true && mounted) {
      setState(() {
        student['full_name'] = nameController.text.trim();
        student['phone'] = phoneController.text.trim();
        student['goal'] = goalController.text.trim();
        student['injuries_or_restrictions'] = restrictionsController.text.trim();
        student['clinical_restrictions'] = restrictionsController.text.trim();
      });
      WorkoutService.studentsRefreshNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.surfaceHighlight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Perfil e restrições do aluno atualizados com sucesso!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _formatErrorMessage(Object error) {
    final str = error.toString();
    if (str.contains('TimeoutException')) {
      return 'Tempo limite esgotado ao contatar o servidor. Tente novamente.';
    }
    return str.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

  Future<void> _archiveStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar aluno?'),
        content: Text(
          'O histórico de ${student['full_name'] ?? 'este aluno'} será preservado, '
          'mas ele deixará de ocupar uma vaga ativa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('confirm_archive_student'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Arquivar aluno'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updateStatus =
          widget.onUpdateStudentStatus ?? WorkoutService.updateStudentStatus;
      final success = await updateStatus(
        studentId: student['id'] as String,
        status: 'Arquivado',
      );
      if (!success) throw StateError('O servidor não confirmou o arquivamento.');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = _formatErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível arquivar o aluno: $message')),
        );
      }
    }
  }

  /// Exibe o BottomSheet premium de limite de quota de alunos.
  /// Padrão Spotify/Notion: ícone animado, contexto claro do plano,
  /// e duas ações acionáveis: arquivar aluno ou fazer upgrade.
  Future<void> _showQuotaLimitModal() async {
    MySubscriptionModel? subscription;
    try {
      subscription = await SubscriptionService.getMySubscription();
    } catch (_) {
      // Se não conseguir buscar, exibe modal com dados genéricos
    }

    if (!mounted) return;

    final planName = subscription?.planName ?? 'seu plano atual';
    final maxStudents = subscription?.maxStudents ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: MetaColors.bg(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: MetaColors.cardBorder(ctx), width: 0.5),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.cardBorder(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Ícone + Headline
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.group_off_rounded,
                      color: Color(0xFFF59E0B),
                      size: 26,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: const Duration(milliseconds: 220)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Limite de Alunos Atingido',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        )
                            .animate()
                            .fadeIn(
                              delay: const Duration(milliseconds: 100),
                              duration: const Duration(milliseconds: 300),
                            )
                            .slideX(
                              begin: 0.12,
                              curve: Curves.easeOut,
                            ),
                        const SizedBox(height: 4),
                        Text(
                          'Plano $planName · $maxStudents vagas',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 13,
                          ),
                        )
                            .animate()
                            .fadeIn(
                              delay: const Duration(milliseconds: 160),
                              duration: const Duration(milliseconds: 280),
                            ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: MetaColors.cardBorder(ctx), height: 1),
              const SizedBox(height: 20),

              // Contexto explicativo
              Text(
                'Todas as vagas do seu plano $planName estão ocupadas. '
                'Para reativar este aluno, você tem duas opções:',
                style: TextStyle(
                  color: MetaColors.subtext(ctx),
                  fontSize: 14,
                  height: 1.5,
                ),
              )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 200),
                    duration: const Duration(milliseconds: 300),
                  ),

              const SizedBox(height: 20),

              // Opção A — Arquivar outro aluno
              _QuotaOptionTile(
                icon: Icons.archive_outlined,
                title: 'Arquivar outro aluno',
                subtitle: 'Libera uma vaga sem custos extras. O histórico é preservado.',
                delay: 240,
              )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 240),
                    duration: const Duration(milliseconds: 280),
                  )
                  .slideY(
                    begin: 0.08,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 10),

              // Opção B — Fazer upgrade
              _QuotaOptionTile(
                icon: Icons.bolt_rounded,
                title: 'Fazer upgrade de plano',
                subtitle: 'Aumente o limite de alunos ativos da sua consultoria.',
                isHighlighted: true,
                delay: 300,
              )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 300),
                    duration: const Duration(milliseconds: 280),
                  )
                  .slideY(
                    begin: 0.08,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 28),

              // CTAs
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SquircleButton(
                    label: 'Ver lista de alunos para arquivar',
                    icon: Icons.people_outline_rounded,
                    isPrimary: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 360),
                        duration: const Duration(milliseconds: 280),
                      )
                      .slideY(begin: 0.1, curve: Curves.easeOut),
                  const SizedBox(height: 12),
                  SquircleButton(
                    label: 'Ver planos e fazer upgrade',
                    icon: Icons.upgrade_rounded,
                    isPrimary: false,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 400),
                        duration: const Duration(milliseconds: 260),
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reactivateStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reativar aluno?'),
        content: Text(
          '${student['full_name'] ?? 'Este aluno'} voltará a constar como ativo '
          'e ocupará uma vaga no seu plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('confirm_reactivate_student'),
            style: ElevatedButton.styleFrom(backgroundColor: MetaColors.emerald),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reativar aluno', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updateStatus =
          widget.onUpdateStudentStatus ?? WorkoutService.updateStudentStatus;
      final success = await updateStatus(
        studentId: student['id'] as String,
        status: 'Ativo',
      );
      if (!success) throw StateError('O servidor não confirmou a reativação.');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final errStr = error.toString().toLowerCase();
        final isQuotaError = errStr.contains('limite') ||
            errStr.contains('máximo') ||
            errStr.contains('maximo') ||
            errStr.contains('23514') ||
            errStr.contains('max_students') ||
            errStr.contains('quota');
        if (isQuotaError) {
          await _showQuotaLimitModal();
        } else {
          final message = _formatErrorMessage(error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível reativar o aluno: $message')),
          );
        }
      }
    }
  }

  Future<void> _deleteStudent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir aluno definitivamente?'),
        content: Text(
          'Esta ação remove ${student['full_name'] ?? 'o aluno'} e não pode ser desfeita. '
          'O histórico associado também poderá ser removido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('confirm_delete_student'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final delete = widget.onDeleteStudent ?? WorkoutService.deleteStudent;
      final success = await delete(student['id'] as String);
      if (!success) throw StateError('O servidor não confirmou a exclusão.');
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = _formatErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível excluir o aluno: $message')),
        );
      }
    }
  }

  void _openPhotoViewer(EvolutionPhoto photo, String title) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dateFormatted =
            '${photo.takenAt.day.toString().padLeft(2, '0')}/${photo.takenAt.month.toString().padLeft(2, '0')}/${photo.takenAt.year}';
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: MetaColors.emerald, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$title • $dateFormatted',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.65,
                    maxWidth: double.infinity,
                  ),
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: EvolutionPhotoService.buildPhotoImage(
                      photo.photoUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        photo.weightKg != null ? 'Peso: ${photo.weightKg} kg' : 'Sem peso registrado',
                        style: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Text(
                        'Privativo • Treinador & Aluno',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrainerPhotoPreview({
    required String label,
    required EvolutionPhoto? photo,
    required BuildContext context,
    required bool isDark,
  }) {
    if (photo == null) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MetaColors.cardBorder(context), width: 0.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_box_outlined, size: 28, color: MetaColors.subtext(context)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Pendente',
              style: TextStyle(color: MetaColors.subtext(context), fontSize: 10),
            ),
          ],
        ),
      );
    }

    final dateFormatted =
        '${photo.takenAt.day.toString().padLeft(2, '0')}/${photo.takenAt.month.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _openPhotoViewer(photo, label),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              EvolutionPhotoService.buildPhotoImage(
                photo.photoUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateFormatted,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (photo.weightKg != null)
                      Text(
                        '${photo.weightKg}kg',
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  Future<void> _openTrainerAddMetricsModal() async {
    final studentId = student['id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final latest = _studentMetrics.isNotEmpty ? _studentMetrics.first : null;
    final weightCtrl = TextEditingController(
      text: latest?.weightKg?.toString() ?? (student['weight_kg']?.toString() ?? ''),
    );
    final heightCtrl = TextEditingController(
      text: latest?.heightCm?.toString() ?? (student['height_cm']?.toString() ?? ''),
    );
    final bfCtrl = TextEditingController(text: latest?.bodyFatPct?.toString() ?? '');
    final chestCtrl = TextEditingController(text: latest?.chestCm?.toString() ?? '');
    final waistCtrl = TextEditingController(text: latest?.waistCm?.toString() ?? '');
    final hipCtrl = TextEditingController(text: latest?.hipCm?.toString() ?? '');
    final armRightCtrl = TextEditingController(text: latest?.armRightCm?.toString() ?? '');
    final armLeftCtrl = TextEditingController(text: latest?.armLeftCm?.toString() ?? '');
    final thighCtrl = TextEditingController(text: (latest?.thighRightCm ?? latest?.thighLeftCm)?.toString() ?? '');
    final notesCtrl = TextEditingController();
    var isSaving = false;

    double? parseNum(String s) {
      final cleaned = s.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return null;
      return double.tryParse(cleaned);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = MetaColors.isDark(modalCtx);
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            Widget buildField(String label, TextEditingController ctrl, {String? suffix}) {
              return TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: label,
                  suffixText: suffix,
                  labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                  filled: true,
                  fillColor: MetaColors.highlight(modalCtx),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? MetaColors.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: MetaColors.cardBorder(modalCtx)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MetaColors.subtext(modalCtx).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
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
                                  'Nova Avaliação Antropométrica',
                                  style: TextStyle(
                                    color: MetaColors.text(modalCtx),
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Registrar medidas presenciais ou online de ${student['full_name'] ?? 'Aluno'}',
                                  style: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            icon: Icon(Icons.close_rounded, color: MetaColors.subtext(modalCtx)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: buildField('Peso (kg)', weightCtrl, suffix: 'kg')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('Altura (cm)', heightCtrl, suffix: 'cm')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('% Gordura', bfCtrl, suffix: '%')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: buildField('Tórax (cm)', chestCtrl, suffix: 'cm')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('Cintura (cm)', waistCtrl, suffix: 'cm')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('Quadril (cm)', hipCtrl, suffix: 'cm')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: buildField('Braço Dir.', armRightCtrl, suffix: 'cm')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('Braço Esq.', armLeftCtrl, suffix: 'cm')),
                          const SizedBox(width: 8),
                          Expanded(child: buildField('Coxa (cm)', thighCtrl, suffix: 'cm')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Observações da Avaliação (opcional)',
                          labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                          filled: true,
                          fillColor: MetaColors.highlight(modalCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MetaColors.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final w = parseNum(weightCtrl.text);
                                  final h = parseNum(heightCtrl.text);
                                  setModalState(() => isSaving = true);
                                  final record = await BodyMetricsService.saveMetrics(
                                    targetStudentId: studentId,
                                    weightKg: w,
                                    heightCm: h,
                                    bodyFatPct: parseNum(bfCtrl.text),
                                    chestCm: parseNum(chestCtrl.text),
                                    waistCm: parseNum(waistCtrl.text),
                                    hipCm: parseNum(hipCtrl.text),
                                    armRightCm: parseNum(armRightCtrl.text),
                                    armLeftCm: parseNum(armLeftCtrl.text),
                                    thighRightCm: parseNum(thighCtrl.text),
                                    thighLeftCm: parseNum(thighCtrl.text),
                                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                  );
                                  if (modalCtx.mounted) Navigator.pop(modalCtx);
                                  if (record != null && mounted) {
                                    final refreshed = await BodyMetricsService.getMetricsHistory(studentId);
                                    setState(() {
                                      _studentMetrics = refreshed;
                                      if (w != null) student['weight_kg'] = w;
                                      if (h != null) student['height_cm'] = h;
                                    });
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: MetaColors.surfaceHighlight,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Avaliação antropométrica registrada com sucesso no Bio-Hub!',
                                                style: TextStyle(color: MetaColors.textPrimary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: const Text(
                            'Salvar Avaliação Antropométrica',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTrainerAddLoadModal() async {
    final studentId = student['id']?.toString() ?? '';
    if (studentId.isEmpty) return;

    final exerciseSuggestions = <String>{};
    if (_activeWorkout != null && _activeWorkout.splits != null) {
      for (final split in _activeWorkout.splits) {
        if (split.exercises != null) {
          for (final ex in split.exercises) {
            final name = ex.name?.toString().trim();
            if (name != null && name.isNotEmpty) {
              exerciseSuggestions.add(name);
            }
          }
        }
      }
    }

    final exerciseCtrl = TextEditingController(
      text: exerciseSuggestions.isNotEmpty ? exerciseSuggestions.first : '',
    );
    final weightCtrl = TextEditingController();
    final repsCtrl = TextEditingController(text: '10');
    final rpeCtrl = TextEditingController(text: '8');
    final notesCtrl = TextEditingController();
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = MetaColors.isDark(modalCtx);
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? MetaColors.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: MetaColors.cardBorder(modalCtx)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MetaColors.subtext(modalCtx).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
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
                                  'Calibrar Carga do Aluno',
                                  style: TextStyle(
                                    color: MetaColors.text(modalCtx),
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Registrar carga oficial para ${student['full_name'] ?? 'Aluno'}',
                                  style: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            icon: Icon(Icons.close_rounded, color: MetaColors.subtext(modalCtx)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (exerciseSuggestions.isNotEmpty) ...[
                        Text(
                          'Exercício Prescrito',
                          style: TextStyle(
                            color: MetaColors.text(modalCtx),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(modalCtx),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: exerciseSuggestions.contains(exerciseCtrl.text)
                                  ? exerciseCtrl.text
                                  : exerciseSuggestions.first,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: exerciseSuggestions.map((e) {
                                return DropdownMenuItem<String>(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => exerciseCtrl.text = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: exerciseCtrl,
                        style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13.5),
                        decoration: InputDecoration(
                          labelText: 'Nome do Exercício',
                          labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                          filled: true,
                          fillColor: MetaColors.highlight(modalCtx),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Carga (kg)',
                                suffixText: 'kg',
                                labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                                filled: true,
                                fillColor: MetaColors.highlight(modalCtx),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: repsCtrl,
                              keyboardType: TextInputType.text,
                              style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'Repetições',
                                labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                                filled: true,
                                fillColor: MetaColors.highlight(modalCtx),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: rpeCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13.5),
                              decoration: InputDecoration(
                                labelText: 'RPE (Percepção)',
                                labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                                filled: true,
                                fillColor: MetaColors.highlight(modalCtx),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        style: TextStyle(color: MetaColors.text(modalCtx), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Observação Biomecânica / Ajuste do Treinador',
                          labelStyle: TextStyle(color: MetaColors.subtext(modalCtx), fontSize: 11.5),
                          filled: true,
                          fillColor: MetaColors.highlight(modalCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MetaColors.emerald,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final exName = exerciseCtrl.text.trim();
                                  final w = double.tryParse(weightCtrl.text.trim().replaceAll(',', '.'));
                                  if (exName.isEmpty || w == null) {
                                    ScaffoldMessenger.of(modalCtx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Informe o exercício e a carga em kg.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  setModalState(() => isSaving = true);
                                  await WorkoutService.recordExerciseLoad(
                                    targetStudentId: studentId,
                                    exerciseName: exName,
                                    loadKg: w,
                                    reps: int.tryParse(repsCtrl.text.trim()) ?? 10,
                                  );
                                  if (modalCtx.mounted) Navigator.pop(modalCtx);
                                  if (mounted) {
                                    final refreshed = await WorkoutService.getStudentProgressiveOverload(studentId);
                                    setState(() {
                                      _studentOverloads = refreshed;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: MetaColors.surfaceHighlight,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Carga de $exName calibrada (${w.toStringAsFixed(1)} kg)!',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            isSaving ? 'Salvando...' : 'Salvar Calibração de Carga',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSocialEncouragementWhatsAppSheet() async {
    final name = (student['full_name'] as String? ?? 'Aluno').trim();
    final firstName = name.split(' ').first;
    final phone = (student['phone'] as String? ?? '').trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = digits.startsWith('55') ? digits : '55$digits';

    final bestExercise = _studentOverloads.isNotEmpty
        ? ' no ${_studentOverloads.first['exercise']}'
        : '';

    final templates = <Map<String, String>>[
      {
        'title': 'Consistência & Foco 🔥',
        'badge': 'Streak',
        'text': 'Fala $firstName! 🔥 Vi aqui no Mr. Coach que você tá mantendo o foco total nos treinos. Parabéns pela disciplina! Seguimos firmes na periodização. Conta comigo pra ajustar as cargas se precisar!',
      },
      {
        'title': 'Sobrecarga de Carga 🚀',
        'badge': 'Progressão',
        'text': 'Grande $firstName! 🚀 Analisei sua evolução de cargas no app e você tá progredindo de verdade$bestExercise! Esse é o caminho da hipertrofia consistente. Bora manter essa intensidade!',
      },
      {
        'title': 'Check-in Semanal 💬',
        'badge': 'Acompanhamento',
        'text': 'Olá $firstName! Tudo bem? Passando pra checar como você tá se sentindo com os treinos desta semana. Teve alguma dor ou dificuldade em algum exercício? Qualquer coisa ajustamos a ficha!',
      },
      {
        'title': 'Recuperação & Sono 💤',
        'badge': 'Recovery',
        'text': 'Fala $firstName! Notei pelo seu check-in diário no app que sua recuperação/sono tá pedindo um pouco de atenção hoje. Hidrate-se bem e me avisa se sentir fadiga excessiva durante as séries!',
      },
    ];

    var selectedIndex = 0;
    final messageCtrl = TextEditingController(text: templates.first['text']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = MetaColors.isDark(sheetCtx);
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? MetaColors.surface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: MetaColors.cardBorder(sheetCtx)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: MetaColors.subtext(sheetCtx).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
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
                            child: const Icon(Icons.forum_rounded, color: MetaColors.emerald, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Incentivo & Feedbacks Sociais',
                                  style: TextStyle(
                                    color: MetaColors.text(sheetCtx),
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Envie uma mensagem personalizada no WhatsApp de $firstName',
                                  style: TextStyle(color: MetaColors.subtext(sheetCtx), fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetCtx),
                            icon: Icon(Icons.close_rounded, color: MetaColors.subtext(sheetCtx)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Templates Rápidos',
                        style: TextStyle(
                          color: MetaColors.text(sheetCtx),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(templates.length, (i) {
                          final isSelected = selectedIndex == i;
                          return ChoiceChip(
                            label: Text(templates[i]['title']!),
                            selected: isSelected,
                            selectedColor: MetaColors.emerald,
                            backgroundColor: MetaColors.highlight(sheetCtx),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : MetaColors.text(sheetCtx),
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setSheetState(() {
                                  selectedIndex = i;
                                  messageCtrl.text = templates[i]['text']!;
                                });
                              }
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Mensagem Personalizada',
                        style: TextStyle(
                          color: MetaColors.text(sheetCtx),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 4,
                        style: TextStyle(color: MetaColors.text(sheetCtx), fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Digite a mensagem de incentivo...',
                          hintStyle: TextStyle(color: MetaColors.subtext(sheetCtx), fontSize: 12),
                          filled: true,
                          fillColor: MetaColors.highlight(sheetCtx),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MetaColors.emerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final text = messageCtrl.text.trim();
                                if (text.isEmpty) return;
                                if (digits.isEmpty) {
                                  await Clipboard.setData(ClipboardData(text: text));
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Aluno sem telefone cadastrado. Mensagem copiada!'),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                final encodedMsg = Uri.encodeComponent(text);
                                final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedMsg');
                                final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanPhone&text=$encodedMsg');
                                final waMeUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

                                var launched = false;
                                try {
                                  launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                                if (!launched) {
                                  try {
                                    launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
                                  } catch (_) {}
                                }
                                if (!launched) {
                                  try {
                                    launched = await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
                                  } catch (_) {}
                                }
                                if (!launched && mounted) {
                                  await Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Mensagem copiada para a área de transferência!')),
                                  );
                                }
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              },
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text(
                                'Enviar no WhatsApp',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Copiar Mensagem',
                            style: IconButton.styleFrom(
                              backgroundColor: MetaColors.highlight(sheetCtx),
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: messageCtrl.text.trim()));
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mensagem copiada com sucesso!')),
                                );
                              }
                            },
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
      },
    );
  }

  Widget _buildBiomechanicalAlertBanner(BuildContext context) {
    if (_studentAlert == null) return const SizedBox.shrink();
    final isDark = MetaColors.isDark(context);
    final alert = _studentAlert!;
    final alertId = alert['id']?.toString() ?? '';
    final origEx = alert['original_exercise']?.toString() ?? 'Exercício';
    final adaptEx = alert['adapted_exercise']?.toString() ?? '';
    final reason = alert['reason']?.toString() ?? alert['message']?.toString() ?? 'Desconforto ou adaptação';
    final studentId = student['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C14) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alerta Biomecânico de Treino',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Adaptação solicitada durante o treino ativo',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'O aluno relatou "$reason" no exercício "$origEx".',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 12.5,
            ),
          ),
          if (adaptEx.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: MetaColors.emerald, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sugestão IA: $adaptEx',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final ok = await WorkoutService.swapExerciseInActivePlan(
                      studentId: studentId,
                      originalExercise: origEx,
                      adaptedExercise: adaptEx.isNotEmpty ? adaptEx : origEx,
                      alertId: alertId,
                    );
                    if (ok && mounted) {
                      setState(() {
                        _studentAlert = null;
                      });
                      _fetchWorkout();
                      _fetchBioFeedback();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: MetaColors.surfaceHighlight,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Substituição oficializada na periodização: $adaptEx!',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Oficializar Troca (1-Toque)',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: MetaColors.subtext(context),
                  side: BorderSide(color: MetaColors.cardBorder(context)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  if (alertId.isNotEmpty) {
                    await WorkoutService.acknowledgeAlert(alertId);
                  }
                  if (mounted) {
                    setState(() => _studentAlert = null);
                  }
                },
                child: const Text('Dispensar', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerBodyMetrics(BuildContext context, bool isDark) {
    if (_isLoadingMetrics) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
          ),
        ),
      );
    }

    if (_studentMetrics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MetaColors.cardBorder(context), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(Icons.straighten_outlined, size: 20, color: MetaColors.subtext(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nenhuma medida antropométrica registrada ainda.',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 12,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openTrainerAddMetricsModal,
              style: TextButton.styleFrom(
                foregroundColor: MetaColors.emerald,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
              label: const Text(
                'Nova Medida',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final latest = _studentMetrics.first;
    final previous = _studentMetrics.length > 1 ? _studentMetrics[1] : null;

    final dateFormatted =
        '${latest.measuredAt.day.toString().padLeft(2, '0')}/${latest.measuredAt.month.toString().padLeft(2, '0')}/${latest.measuredAt.year}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.cardBorder(context), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten_rounded, color: MetaColors.emerald, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antropometria Recente',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      'Aferido em $dateFormatted',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _openTrainerAddMetricsModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: MetaColors.emerald),
                      SizedBox(width: 3),
                      Text(
                        'Nova Medida',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Linha de Destaques: Peso & IMC
          Row(
            children: [
              Expanded(
                child: _buildTrainerMetricTile(
                  context: context,
                  label: 'Peso Atual',
                  value: latest.weightKg != null ? '${latest.weightKg!.toStringAsFixed(1)} kg' : '--',
                  delta: previous?.weightKg != null && latest.weightKg != null
                      ? latest.weightKg! - previous!.weightKg!
                      : null,
                  unit: 'kg',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTrainerMetricTile(
                  context: context,
                  label: 'IMC',
                  value: latest.bmi != null ? latest.bmi!.toStringAsFixed(1) : '--',
                  subLabel: latest.bmiCategory,
                  isDark: isDark,
                  isEmerald: true,
                ),
              ),
              if (latest.bodyFatPct != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTrainerMetricTile(
                    context: context,
                    label: '% Gordura',
                    value: '${latest.bodyFatPct!.toStringAsFixed(1)}%',
                    delta: previous?.bodyFatPct != null ? latest.bodyFatPct! - previous!.bodyFatPct! : null,
                    unit: '%',
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Circunferências em Mini-Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (latest.waistCm != null)
                _buildTrainerCircumferenceChip(context, 'Cintura', '${latest.waistCm}cm', isDark),
              if (latest.armRightCm != null || latest.armLeftCm != null)
                _buildTrainerCircumferenceChip(
                  context,
                  'Braço',
                  '${latest.armRightCm ?? latest.armLeftCm}cm',
                  isDark,
                ),
              if (latest.chestCm != null)
                _buildTrainerCircumferenceChip(context, 'Tórax', '${latest.chestCm}cm', isDark),
              if (latest.hipCm != null)
                _buildTrainerCircumferenceChip(context, 'Quadril', '${latest.hipCm}cm', isDark),
              if (latest.thighRightCm != null || latest.thighLeftCm != null)
                _buildTrainerCircumferenceChip(
                  context,
                  'Coxa',
                  '${latest.thighRightCm ?? latest.thighLeftCm}cm',
                  isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    String? subLabel,
    double? delta,
    String? unit,
    required bool isDark,
    bool isEmerald = false,
  }) {
    Color? deltaColor;
    String deltaText = '';
    if (delta != null && delta != 0) {
      final sign = delta > 0 ? '+' : '';
      deltaText = '$sign${delta.toStringAsFixed(1)}${unit ?? ''}';
      deltaColor = delta < 0 ? MetaColors.emerald : Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MetaColors.cardBorder(context), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isEmerald ? MetaColors.emerald : MetaColors.text(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (deltaText.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                color: isEmerald ? MetaColors.emerald : MetaColors.subtext(context),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainerCircumferenceChip(BuildContext context, String part, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MetaColors.cardBorder(context), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$part: ',
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10.5,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = student['status'] ?? 'Aguardando Ativação';
    final name = student['full_name'] ?? 'Aluno';
    final phone = student['phone'] ?? '';
    final isArchived = status.toString().toLowerCase().contains('arquivado') ||
        status.toString().toLowerCase().contains('inativo');
    final isPendingInvite = status.toString().toLowerCase().contains('pendente');
    
    // Status colors
    Color statusColor = MetaColors.subtext(context);
    if (status == 'Ativo' || status == 'Treinando') statusColor = MetaColors.primaryColor(context);
    if (status == 'Aguardando Ativação' || status == 'Pendente Confirmação') statusColor = const Color(0xFFF59E0B); // Amber
    if (status == 'Inativo' || status == 'Arquivado') statusColor = Colors.redAccent;
    final isDark = MetaColors.isDark(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        WorkoutService.studentsRefreshNotifier.value++;
      },
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
        appBar: AppBar(
          backgroundColor: MetaColors.bg(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: MetaColors.text(context)),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: Text(
            'Perfil do Aluno',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            const ThemeToggleButton(compact: true),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.forum_outlined, color: MetaColors.emerald),
              tooltip: 'Incentivo no WhatsApp',
              onPressed: _openSocialEncouragementWhatsAppSheet,
            ),
          ],
        ),
        body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER (Info Básica & Gamificação)
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: MetaColors.highlight(context),
                      backgroundImage: safeImageProvider(student['avatar_url'] ?? student['photo_url']),
                      child: safeImageProvider(student['avatar_url'] ?? student['photo_url']) == null
                          ? Text(
                              name.trim().isEmpty ? 'A' : name.trim().substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: MetaColors.primaryColor(context),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        InkWell(
                          onTap: _openSocialEncouragementWhatsAppSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.forum_rounded, color: MetaColors.emerald, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Incentivar no WhatsApp',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _openTrainerAddLoadModal,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: MetaColors.cardBorder(context)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fitness_center_rounded, color: MetaColors.emerald, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Calibrar Cargas',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // DADOS FÍSICOS & ANAMNESE
              const MetaSectionTitle(title: 'Dados Físicos & Anamnese'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: MetaCard(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      child: Column(
                        children: [
                          Icon(Icons.cake_outlined, size: 20, color: MetaColors.primaryColor(context)),
                          const SizedBox(height: 6),
                          Text(
                            'Idade',
                            style: TextStyle(fontSize: 11, color: MetaColors.subtext(context)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student['age'] != null ? '${student['age']} anos' : 'Não inf.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: MetaColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaCard(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      child: Column(
                        children: [
                          Icon(Icons.monitor_weight_outlined, size: 20, color: MetaColors.primaryColor(context)),
                          const SizedBox(height: 6),
                          Text(
                            'Peso',
                            style: TextStyle(fontSize: 11, color: MetaColors.subtext(context)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student['weight_kg'] != null ? '${student['weight_kg']} kg' : 'Não inf.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: MetaColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaCard(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      child: Column(
                        children: [
                          Icon(Icons.height_rounded, size: 20, color: MetaColors.primaryColor(context)),
                          const SizedBox(height: 6),
                          Text(
                            'Altura',
                            style: TextStyle(fontSize: 11, color: MetaColors.subtext(context)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student['height_cm'] != null ? '${student['height_cm']} cm' : 'Não inf.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: MetaColors.text(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MetaCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.track_changes_rounded, size: 18, color: MetaColors.primaryColor(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Objetivo Principal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MetaColors.text(context),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _editStudent,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 12, color: MetaColors.emerald),
                                SizedBox(width: 4),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      student['goal'] as String? ?? 'Consultoria Personalizada',
                      style: TextStyle(
                        fontSize: 14,
                        color: MetaColors.subtext(context),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.healing_outlined, size: 18, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Restrições e Cuidados Biomecânicos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MetaColors.text(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (student['injuries_or_restrictions'] as String?)?.isNotEmpty == true
                          ? student['injuries_or_restrictions'] as String
                          : ((student['clinical_restrictions'] as String?)?.isNotEmpty == true
                              ? student['clinical_restrictions'] as String
                              : 'Nenhuma restrição articular ou biomecânica relatada.'),
                      style: TextStyle(
                        fontSize: 14,
                        color: MetaColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 2. CONVITE E INTEGRAÇÃO (Se Pendente)
              if (status == 'Aguardando Ativação' || status == 'Pendente Confirmação') ...[
                const MetaSectionTitle(title: 'Ações de Convite'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Reenviar via WhatsApp',
                    icon: Icons.chat_bubble,
                    isPrimary: true,
                    onPressed: _isResendingInvite
                      ? null
                      : () => _launchWhatsApp(phone, name),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Reenviar via E-mail',
                    icon: Icons.email,
                    isPrimary: false,
                    onPressed: _isResendingInvite
                        ? null
                        : () => _resendInvitationEmail(name, phone),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // 3. PERIODIZAÇÃO (Treino)
              if (_studentAlert != null) ...[
                _buildBiomechanicalAlertBanner(context),
              ],
              const MetaSectionTitle(title: 'Periodização'),
              const SizedBox(height: 16),
              if (_isLoadingWorkout)
                Center(child: CircularProgressIndicator(color: MetaColors.primaryColor(context)))
              else if (_activeWorkout == null)
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, color: MetaColors.subtext(context), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma ficha ativa ainda.',
                        style: TextStyle(color: MetaColors.subtext(context), fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      if (isPendingInvite) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_clock_rounded,
                                color: Color(0xFFF59E0B),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Aguardando $name ativar o convite. Para proteger seus créditos de IA, a prescrição será liberada assim que o cadastro for ativado.',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: SquircleButton(
                            label: _isResendingInvite ? 'Preparando envio...' : 'Lembrar no WhatsApp',
                            icon: Icons.chat_bubble_outline_rounded,
                            isPrimary: true,
                            onPressed: _isResendingInvite ? null : () => _launchWhatsApp(phone, name),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: SquircleButton(
                            label: '✨ Prescrever com IA em 30s',
                            isPrimary: true,
                            onPressed: _openWorkoutPrescription,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else ...[
                Builder(
                  builder: (workoutContext) {
                    final isDark = MetaColors.isDark(workoutContext);
                    final plan = _activeWorkout is WorkoutPlanModel
                        ? (_activeWorkout as WorkoutPlanModel)
                        : (_activeWorkout is Map<String, dynamic>
                            ? WorkoutPlanModel.fromJson(_activeWorkout as Map<String, dynamic>)
                            : const WorkoutPlanModel(
                                workoutPlanTitle: 'Periodização',
                                notesForTrainer: '',
                                splits: [],
                              ));
                    final splits = plan.splits;
                    final totalExercises = splits.fold<int>(
                      0,
                      (acc, s) => acc + s.exercises.length,
                    );
                    final createdAt = plan.createdAt;

                    return MetaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: MetaColors.emerald.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fitness_center_rounded,
                                  color: MetaColors.emerald,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'PERIODIZAÇÃO ATIVA',
                                          style: TextStyle(
                                            color: MetaColors.subtext(workoutContext),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: MetaColors.emerald.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: MetaColors.emerald.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 12),
                                              SizedBox(width: 4),
                                              Text(
                                                'ATIVA',
                                                style: TextStyle(
                                                  color: MetaColors.emerald,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.workoutPlanTitle,
                                      style: TextStyle(
                                        color: MetaColors.text(workoutContext),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.25,
                                      ),
                                    ),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 12,
                                            color: MetaColors.subtext(workoutContext),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Prescrito em ${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                                            style: TextStyle(
                                              color: MetaColors.subtext(workoutContext),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (splits.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Divider(color: MetaColors.cardBorder(workoutContext), height: 1),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Divisões do Treino',
                                  style: TextStyle(
                                    color: MetaColors.subtext(workoutContext),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '$totalExercises exercícios totais',
                                  style: TextStyle(
                                    color: MetaColors.primaryColor(workoutContext),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: splits.map((split) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? MetaColors.highlight(workoutContext)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: MetaColors.cardBorder(workoutContext),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: MetaColors.primaryColor(workoutContext),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          split.splitIdentifier,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          split.splitName,
                                          style: TextStyle(
                                            color: MetaColors.text(workoutContext),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? MetaColors.surface
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: MetaColors.cardBorder(workoutContext),
                                            width: 0.6,
                                          ),
                                        ),
                                        child: Text(
                                          '${split.exercises.length} ex',
                                          style: TextStyle(
                                            color: MetaColors.subtext(workoutContext),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (plan.notesForTrainer.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      plan.notesForTrainer,
                                      style: TextStyle(
                                        color: MetaColors.subtext(workoutContext),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: SquircleButton(
                              label: 'Ver Ficha Completa',
                              icon: Icons.visibility_rounded,
                              isPrimary: true,
                              height: 48,
                              onPressed: () => _viewFullWorkoutDetails(plan),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SquircleButton(
                                  label: 'Nova com IA',
                                  icon: Icons.auto_awesome,
                                  isPrimary: false,
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                  fontSize: 11.5,
                                  onPressed: _openWorkoutPrescription,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SquircleButton(
                                  label: 'Renovar',
                                  icon: Icons.replay_rounded,
                                  isPrimary: false,
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                  fontSize: 11.5,
                                  onPressed: _renewActiveWorkout,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SquircleButton(
                                  label: 'Clonar Ciclo',
                                  icon: Icons.content_copy_rounded,
                                  isPrimary: false,
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                  fontSize: 11.5,
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final res = await BatchPrescriptionModalSheet.show(
                                      context,
                                      initialWorkoutId: _activeWorkout is WorkoutPlanModel
                                          ? (_activeWorkout as WorkoutPlanModel).id
                                          : null,
                                      initialWorkoutTitle: _activeWorkout is WorkoutPlanModel
                                          ? (_activeWorkout as WorkoutPlanModel).workoutPlanTitle
                                          : 'Ficha Atual',
                                      initialStudentId: student['id']?.toString(),
                                      initialStudentName: student['full_name']?.toString(),
                                      sourcePlan: _activeWorkout is WorkoutPlanModel
                                          ? (_activeWorkout as WorkoutPlanModel)
                                          : null,
                                    );
                                    if (!mounted || res == null) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(res.message),
                                        backgroundColor: MetaColors.emerald,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    _fetchWorkout();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _deleteActiveWorkout,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              label: const Text(
                                'Desativar / Excluir Ficha',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 28),

              // 4. BIO-HUB & PERFORMANCE DO ALUNO
              const MetaSectionTitle(title: '🧬 Bio-Hub & Telemetria do Aluno'),
              const SizedBox(height: 14),
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
                          child: const Icon(
                            Icons.biotech_rounded,
                            color: MetaColors.emerald,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Painel Biomecânico de $name',
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isLoadingBioFeedback
                                    ? 'Carregando telemetria...'
                                    : (_studentBioFeedback != null
                                        ? '${_studentBioFeedback!['total_feedbacks']} treinos registrados na nuvem'
                                        : 'Aguardando 1º registro de treino'),
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_studentBioFeedback != null)
                                ? MetaColors.emerald.withValues(alpha: 0.2)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (_studentBioFeedback != null) ? 'CONECTADO' : 'PENDENTE',
                            style: TextStyle(
                              color: (_studentBioFeedback != null)
                                  ? MetaColors.emerald
                                  : MetaColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Alerta Biomecânico de Dor Relatada (se houver)
                    if (_studentBioFeedback != null &&
                        (_studentBioFeedback!['recent_pain_points'] as List).isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.healing_rounded,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ALERTA BIOMECÂNICO • DORES RELATADAS',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Desconforto recente em: ${(_studentBioFeedback!['recent_pain_points'] as List).join(", ")}',
                                    style: TextStyle(
                                      color: MetaColors.text(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_studentBioFeedback!['latest_notes'] != null &&
                                      (_studentBioFeedback!['latest_notes'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '"${_studentBioFeedback!['latest_notes']}"',
                                      style: TextStyle(
                                        color: MetaColors.subtext(context),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_studentBioFeedback != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle_outline_rounded,
                                color: MetaColors.emerald, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tolerância Biomecânica Perfeita: Sem dores relatadas.',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        // Card 1: Prontidão
                        // Card 1: Prontidão & Recovery Real
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HealthMetricsCard.showSheet(
                                context,
                                userId: student['id']?.toString(),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.battery_charging_full_rounded,
                                        size: 16,
                                      color: _studentRecovery != null
                                          ? (((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 80
                                              ? MetaColors.emerald
                                              : (((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 60
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFFEF4444)))
                                          : MetaColors.emerald,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('Recovery', style: TextStyle(fontSize: 11, color: MetaColors.subtext(context))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _studentRecovery != null
                                      ? '${((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80).toInt()}% • ${((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 80 ? "Alta" : (((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 60 ? "Moderada" : "Baixa")}'
                                      : (_studentBioFeedback != null ? 'Pendente' : '--'),
                                  style: TextStyle(
                                    color: _studentRecovery != null
                                        ? (((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 80
                                            ? MetaColors.emerald
                                            : (((_studentRecovery!['readiness_score'] as num?)?.toDouble() ?? 80) >= 60
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFFEF4444)))
                                        : MetaColors.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _studentRecovery != null
                                      ? 'Sono: ${((_studentRecovery!['sleep_hours'] as num?)?.toDouble() ?? 8.0).toStringAsFixed(1)}h • DOMS: ${_studentRecovery!['doms_level'] ?? "Leve"}'
                                      : 'Sem registro hoje',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                        const SizedBox(width: 10),
                        // Card 2: RPE Real
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: _studentBioFeedback != null
                                          ? _getRpeColor(_studentBioFeedback!['latest_rpe'] as double)
                                          : MetaColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('Esforço RPE', style: TextStyle(fontSize: 11, color: MetaColors.subtext(context))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _studentBioFeedback != null
                                      ? '${(_studentBioFeedback!['latest_rpe'] as double).toStringAsFixed(1)} / 10'
                                      : 'Pendente',
                                  style: TextStyle(
                                    color: _studentBioFeedback != null
                                        ? _getRpeColor(_studentBioFeedback!['latest_rpe'] as double)
                                        : MetaColors.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _studentBioFeedback != null
                                      ? '${_getRpeLabel(_studentBioFeedback!['latest_rpe'] as double)} (Méd. ${(_studentBioFeedback!['average_rpe'] as double).toStringAsFixed(1)})'
                                      : 'Aguardando treino',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progressão de Carga Real
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetaColors.cardBorder(context), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up_rounded, color: MetaColors.emerald, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                StudentOverloadCenterSheet.show(
                                  context,
                                  studentId: student['id']?.toString(),
                                  exerciseName: _studentOverloads.isNotEmpty
                                      ? _studentOverloads.first['exercise'] as String?
                                      : null,
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _studentOverloads.isNotEmpty
                                        ? (_studentOverloads.first['is_baseline'] == true
                                            ? 'Marco Inicial Ativo (${_studentOverloads.first['exercise']})'
                                            : 'Sobrecarga: ${_studentOverloads.first['gain_percent']} (${_studentOverloads.first['exercise']})')
                                        : 'Curva de Sobrecarga em Calibração',
                                    style: TextStyle(
                                      color: MetaColors.text(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _studentOverloads.isNotEmpty
                                        ? _studentOverloads.map((e) => '${e['exercise']}: ${e['start_load']} ➔ ${e['current_load']}').take(2).join(' • ')
                                        : 'Nenhuma carga registrada. Toque para ver ou calibrar.',
                                    style: TextStyle(
                                      color: MetaColors.subtext(context),
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              StudentOverloadCenterSheet.show(
                                context,
                                studentId: student['id']?.toString(),
                                exerciseName: _studentOverloads.isNotEmpty
                                    ? _studentOverloads.first['exercise'] as String?
                                    : null,
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.insights_rounded, size: 13, color: Color(0xFF06B6D4)),
                                  SizedBox(width: 3),
                                  Text(
                                    '1RM',
                                    style: TextStyle(
                                      color: Color(0xFF06B6D4),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              StudentAchievementsModalSheet.show(
                                context,
                                userId: student['id']?.toString(),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.military_tech_rounded, size: 13, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Selos',
                                    style: TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _openTrainerAddLoadModal,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 13, color: MetaColors.emerald),
                                  SizedBox(width: 3),
                                  Text(
                                    'Calibrar',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 10.5,
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
                    const SizedBox(height: 16),

                    // Galeria Sigilosa de Fotos de Evolução (Antes vs. Atual)
                    Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: MetaColors.emerald, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'Galeria Sigilosa Antes & Depois',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CONFIDENCIAL',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acompanhe visualmente a postura e a transformação física de $name.',
                      style: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
                    ),
                    if (_studentBeforePhoto != null && _studentAfterPhoto != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _useSplitSlider = true);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _useSplitSlider
                                    ? MetaColors.emerald.withValues(alpha: 0.2)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _useSplitSlider ? MetaColors.emerald : MetaColors.cardBorder(context),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.compare_arrows_rounded,
                                    size: 13,
                                    color: _useSplitSlider ? MetaColors.emerald : MetaColors.subtext(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Split-Slider',
                                    style: TextStyle(
                                      color: _useSplitSlider ? MetaColors.emerald : MetaColors.subtext(context),
                                      fontSize: 11,
                                      fontWeight: _useSplitSlider ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _useSplitSlider = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: !_useSplitSlider
                                    ? MetaColors.emerald.withValues(alpha: 0.2)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: !_useSplitSlider ? MetaColors.emerald : MetaColors.cardBorder(context),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.view_column_rounded,
                                    size: 13,
                                    color: !_useSplitSlider ? MetaColors.emerald : MetaColors.subtext(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lado a Lado',
                                    style: TextStyle(
                                      color: !_useSplitSlider ? MetaColors.emerald : MetaColors.subtext(context),
                                      fontSize: 11,
                                      fontWeight: !_useSplitSlider ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_isLoadingPhotos)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                        ),
                      )
                    else if (_studentBeforePhoto == null && _studentAfterPhoto == null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MetaColors.cardBorder(context), width: 0.8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_outlined, size: 20, color: MetaColors.subtext(context)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Nenhuma foto de evolução enviada ainda. O aluno pode registrar fotos pelo Bio-Hub do app dele.',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_useSplitSlider && _studentBeforePhoto != null && _studentAfterPhoto != null)
                      SplitPhotoSlider(
                        beforeImageUrl: _studentBeforePhoto!.photoUrl,
                        afterImageUrl: _studentAfterPhoto!.photoUrl,
                        beforeLabel: 'Início',
                        afterLabel: 'Atual',
                        beforeWeightKg: _studentBeforePhoto!.weightKg,
                        afterWeightKg: _studentAfterPhoto!.weightKg,
                        beforeDate: _studentBeforePhoto!.takenAt,
                        afterDate: _studentAfterPhoto!.takenAt,
                        height: 300,
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildTrainerPhotoPreview(
                              label: 'Início',
                              photo: _studentBeforePhoto,
                              context: context,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTrainerPhotoPreview(
                              label: 'Atual',
                              photo: _studentAfterPhoto,
                              context: context,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),
                    // Antropometria Corporal (Bio-Hub 2.0)
                    _buildTrainerBodyMetrics(context, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 5. ADMINISTRAÇÃO (Menu de Configurações)
              const MetaSectionTitle(title: 'Administração'),
              const SizedBox(height: 16),
              MetaCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.edit, color: MetaColors.subtext(context)),
                      title: Text(
                        'Editar Perfil do Aluno',
                        style: TextStyle(color: MetaColors.text(context)),
                      ),
                      trailing: Icon(Icons.chevron_right, color: MetaColors.subtext(context)),
                      onTap: _editStudent,
                    ),
                    if (isArchived) ...[
                      Divider(color: MetaColors.cardBorder(context), height: 1),
                      ListTile(
                        key: const Key('action_reactivate_student'),
                        leading: Icon(Icons.play_circle_outline, color: MetaColors.primaryColor(context)),
                        title: Text(
                          'Reativar Aluno',
                          style: TextStyle(color: MetaColors.primaryColor(context), fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.chevron_right, color: MetaColors.primaryColor(context)),
                        onTap: _reactivateStudent,
                      ),
                    ] else if (!isPendingInvite) ...[
                      Divider(color: MetaColors.cardBorder(context), height: 1),
                      ListTile(
                        key: const Key('action_archive_student'),
                        leading: Icon(Icons.pause_circle_outline, color: MetaColors.subtext(context)),
                        title: Text(
                          'Arquivar Aluno',
                          style: TextStyle(color: MetaColors.text(context)),
                        ),
                        trailing: Icon(Icons.chevron_right, color: MetaColors.subtext(context)),
                        onTap: _archiveStudent,
                      ),
                    ],
                    Divider(color: MetaColors.cardBorder(context), height: 1),
                    ListTile(
                      key: const Key('action_delete_student'),
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: Text(
                        isPendingInvite ? 'Cancelar / Excluir Convite' : 'Excluir Definitivamente',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      onTap: _deleteStudent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),);
  }
}

class _QuotaOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isHighlighted;
  final int delay;

  const _QuotaOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isHighlighted = false,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted
            ? MetaColors.emerald.withValues(alpha: 0.08)
            : MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? MetaColors.emerald.withValues(alpha: 0.3)
              : MetaColors.cardBorder(context),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? MetaColors.emerald.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isHighlighted ? MetaColors.emerald : Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
    );
  }
}

