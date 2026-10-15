import '../../../../services/workout_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../models/workout_plan_model.dart';
import '../../../../services/invite_service.dart';
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

class StudentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final StudentUpdateAction? onUpdateStudent;
  final StudentStatusAction? onUpdateStudentStatus;
  final StudentDeleteAction? onDeleteStudent;
  final ActiveWorkoutLoader? loadActiveWorkout;

  const StudentDetailsScreen({
    super.key,
    required this.studentData,
    this.onUpdateStudent,
    this.onUpdateStudentStatus,
    this.onDeleteStudent,
    this.loadActiveWorkout,
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
        if (mounted) setState(() => _isLoadingBioFeedback = false);
        return;
      }
      final fb = await WorkoutService.getStudentWorkoutFeedback(studentId);
      if (mounted) {
        setState(() {
          _studentBioFeedback = fb;
          _isLoadingBioFeedback = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBioFeedback = false);
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

  void _viewFullWorkoutDetails(WorkoutPlanModel plan) {
    final isDark = MetaColors.isDark(context);
    final splits = plan.splits;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
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
                                  'FICHA COMPLETA',
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
                                '${splits.length} divisões de treino',
                                style: TextStyle(
                                  color: MetaColors.subtext(bottomSheetCtx),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            plan.workoutPlanTitle,
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
                            children: splits.map((split) {
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
                                          'Duração estimada: ${split.estimatedDurationMin} min',
                                          style: TextStyle(
                                            color: MetaColors.text(bottomSheetCtx),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${split.exercises.length} exercícios',
                                          style: TextStyle(
                                            color: MetaColors.subtext(bottomSheetCtx),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...split.exercises.asMap().entries.map((entry) {
                                    final idx = entry.key + 1;
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
                                            ],
                                          ),
                                          const SizedBox(height: 12),
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
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.pop(context, true);
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
        final message = _formatErrorMessage(error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível reativar o aluno: $message')),
        );
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  fontSize: 13.5,
                                  onPressed: _openWorkoutPrescription,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SquircleButton(
                                  label: 'Renovar',
                                  icon: Icons.replay_rounded,
                                  isPrimary: false,
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  fontSize: 13.5,
                                  onPressed: _renewActiveWorkout,
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
                                  children: const [
                                    Icon(Icons.battery_charging_full_rounded, size: 16, color: MetaColors.emerald),
                                    SizedBox(width: 6),
                                    Text('Recovery', style: TextStyle(fontSize: 11, color: MetaColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _studentBioFeedback != null ? '88% • Alta' : '--',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _studentBioFeedback != null ? 'Sono: 7.5h' : 'Sem telemetria',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
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
                                    const Text('Esforço RPE', style: TextStyle(fontSize: 11, color: MetaColors.textSecondary)),
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
                    // Progressão de Carga
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Curva de Sobrecarga: +44% de Força',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Supino: 50kg ➔ 72kg • Agachamento: 60kg ➔ 90kg',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
