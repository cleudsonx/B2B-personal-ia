import '../../../../services/workout_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';
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

  @override
  void initState() {
    super.initState();
    student = widget.studentData;
    _fetchWorkout();
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
    await Navigator.push<void>(
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
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar Perfil do Aluno'),
          scrollable: true,
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('student_full_name'),
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Informe o nome do aluno.'
                      : null,
                ),
                TextFormField(
                  key: const Key('student_email_read_only'),
                  initialValue: student['email'] as String? ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'E-mail de acesso',
                    helperText: 'A alteração do e-mail exige confirmação da conta.',
                  ),
                ),
                TextFormField(
                  key: const Key('student_phone'),
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  key: const Key('student_goal'),
                  controller: goalController,
                  decoration: const InputDecoration(labelText: 'Objetivo'),
                ),
                TextFormField(
                  key: const Key('student_restrictions'),
                  controller: restrictionsController,
                  decoration: const InputDecoration(
                    labelText: 'Lesões e restrições',
                  ),
                  maxLines: 3,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    key: const Key('student_edit_error'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              key: const Key('save_student_profile'),
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
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

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        backgroundColor: MetaColors.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: MetaColors.text(context)),
          onPressed: () => Navigator.pop(context),
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
                      radius: 40,
                      backgroundColor: MetaColors.highlight(context),
                      child: Text(
                        name.trim().isEmpty ? 'A' : name.trim().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: MetaColors.primaryColor(context),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
              const SizedBox(height: 32),

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
              else
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ficha Atual',
                        style: TextStyle(color: MetaColors.subtext(context), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeWorkout.workoutPlanTitle ?? 'Periodização',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ativa',
                        style: TextStyle(color: MetaColors.primaryColor(context), fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SquircleButton(
                              label: 'Criar ficha com IA',
                              icon: Icons.visibility,
                              isPrimary: true,
                              onPressed: _openWorkoutPrescription,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SquircleButton(
                              label: 'Renovar',
                              icon: Icons.refresh,
                              isPrimary: false,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Renovação de ficha ainda não disponível. Nada foi alterado.'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Exclusão de ficha ainda não disponível. Nenhum dado foi excluído.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Excluir Ficha', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // 4. ADMINISTRAÇÃO (Menu de Configurações)
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
    );
  }
}
