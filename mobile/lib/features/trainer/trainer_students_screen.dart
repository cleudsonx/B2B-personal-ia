// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'presentation/screens/student_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';

class TrainerStudentsScreen extends StatefulWidget {
  final Function(String studentId, String studentName)? onSelectStudentForPlan;

  const TrainerStudentsScreen({super.key, this.onSelectStudentForPlan});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  // Lista mockada de alunos no estilo WhatsApp / Meta
  List<Map<String, dynamic>> _students = [];
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStudentsFromDb();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsFromDb() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final dbStudents = await WorkoutService.getTrainerStudents();
      final alerts = await WorkoutService.getTrainerAlerts();

      if (mounted) {
        setState(() {
          _students = dbStudents.map((st) {
            final stId = st['id'] ?? 'db-id';
            final stName = (st['full_name'] as String? ?? '').toLowerCase();

            final matchingAlert = alerts.firstWhere(
              (a) =>
                  (a['student_id'] == stId ||
                      (a['student_name'] as String? ?? '').toLowerCase() ==
                          stName) &&
                  a['acknowledged'] == false,
              orElse: () => <String, dynamic>{},
            );

            final hasAlert = matchingAlert.isNotEmpty;
            final alertMsg = hasAlert
                ? (matchingAlert['message'] ?? 'Alerta biomecânico registrado')
                : null;

            final activeSplit = st['active_split'] as String?;
            final hasActivePrescription =
              st['has_active_prescription'] as bool? ??
              (activeSplit?.isNotEmpty == true ? true : null);
            final lastSession = st['last_session'] as String? ?? 'Sincronizado';
            final status = st['status'] as String? ?? 'Ativo';
            final isPendingInvite = status.trim().toLowerCase() == 'convite pendente';
            final isArchived =
                status.toLowerCase().contains('arquivado') ||
                status.toLowerCase().contains('inativo');

            return {
              'id': stId,
              'full_name': st['full_name'] ?? 'Aluno',
              'email': st['email'] ?? '',
              'phone': st['phone'] ?? '',
              'goal': st['goal'] ?? 'Treino',
                  'recent_status': isPendingInvite
                    ? 'Convite pendente · aguardando cadastro'
                    : isArchived
                  ? 'Arquivado'
                  : hasActivePrescription == true
                  ? (activeSplit?.isNotEmpty == true
                    ? 'Ficha ativa: $activeSplit'
                    : 'Ficha ativa')
                  : hasActivePrescription == false
                    ? 'Aguardando ficha'
                    : 'Status da ficha indisponível',
              'last_session': lastSession,
              'status': status,
              'has_alert': hasAlert,
              'alert_message': alertMsg,
              'avatar_url': st['avatar_url'],
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openWhatsApp(Map<String, dynamic> student) async {
    final phone = student['phone'] as String? ?? '';
    final name = student['full_name'] as String? ?? 'Aluno';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final isPending = (student['status'] as String? ?? '').toLowerCase().contains('pendente');
    final user = AuthService.currentUser;
    final trainerName =
        user?.userMetadata?['full_name'] as String? ?? 'Seu Treinador';

    if (cleanPhone.isNotEmpty) {
      final inviteUrl = student['whatsapp_url'] as String?;
      if (isPending && (inviteUrl == null || inviteUrl.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('O link do convite não está disponível. Copie o link do cadastro e tente novamente.'),
            ),
          );
        }
        return;
      }

      final finalNumber = cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
      final message =
          'Olá $name! 💪 Aqui é o Prof. $trainerName. Como estão os treinos essa semana?';
      final url = isPending
          ? Uri.tryParse(inviteUrl!)
          : Uri.parse('https://wa.me/$finalNumber?text=${Uri.encodeComponent(message)}');
      if (url == null) return;
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.surfaceHighlight,
          content: Text(
            phone.isNotEmpty
                ? 'Telefone de $name: $phone'
                : 'Aluno não possui telefone cadastrado.',
            style: const TextStyle(color: MetaColors.textPrimary),
          ),
        ),
      );
    }
  }

  Future<void> _showInviteCreatedDialog(Map<String, dynamic> student) async {
    final emailStatus = (student['email_status'] as String? ?? 'unknown').toLowerCase();
    final emailWasSent = emailStatus == 'sent';
    final emailFailed = emailStatus == 'error' || emailStatus == 'failed';
    final emailIsMock = emailStatus == 'success';
    final inviteLink = student['invitation_link'] as String? ?? '';
    final hasWhatsApp = (student['whatsapp_url'] as String? ?? '').isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MetaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MetaColors.border),
        ),
        icon: Icon(
          emailFailed ? Icons.mark_email_unread_outlined : Icons.check_circle_outline_rounded,
          color: emailFailed ? Colors.orangeAccent : MetaColors.emerald,
          size: 42,
        ),
        title: Text(
          emailWasSent ? 'Convite enviado' : 'Aluno adicionado',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MetaColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emailWasSent
                  ? 'Enviamos o convite para ${student['email']}. O aluno já pode acessar o link e concluir o cadastro.'
                  : emailFailed
                      ? 'Tudo certo: ${student['full_name']} já está na sua lista. Não conseguimos enviar o e-mail agora. Compartilhe o link abaixo para ele começar.'
                      : emailIsMock
                          ? 'Tudo certo: ${student['full_name']} já está na sua lista. O envio automático de e-mail ainda não está disponível. Compartilhe o link abaixo para ele começar.'
                          : 'Tudo certo: ${student['full_name']} já está na sua lista. Não foi possível confirmar o envio do e-mail. Compartilhe o link abaixo para ele começar.',
              style: const TextStyle(color: MetaColors.textSecondary, height: 1.45),
            ),
            if (inviteLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MetaColors.border),
                ),
                child: SelectableText(
                  inviteLink,
                  style: const TextStyle(color: MetaColors.textPrimary, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (inviteLink.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteLink));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link do convite copiado.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar link'),
            ),
          if (hasWhatsApp)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _openWhatsApp(student);
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Abrir WhatsApp'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStudentDetails(Map<String, dynamic> student) async {
    if (widget.onSelectStudentForPlan != null) {
      widget.onSelectStudentForPlan!(
        student['id'] as String,
        student['full_name'] as String,
      );
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailsScreen(studentData: student),
      ),
    );
    if (changed == true && mounted) await _loadStudentsFromDb();
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSubmitting = false;
    String? submitError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: MetaColors.surface,
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: MetaColors.border),
          ),
          title: const Text(
            'Convidar aluno',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o nome do aluno.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email para receber o convite',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? 'Informe um email válido.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'WhatsApp (opcional)',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    hintText: '(61) 99999-9999',
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (submitError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      submitError!,
                      style: const TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: MetaColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        submitError = null;
                      });

                      try {
                        final result = await WorkoutService.createStudent(
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim().toLowerCase(),
                          phone: phoneCtrl.text.trim().isNotEmpty
                              ? phoneCtrl.text.trim()
                              : null,
                          goal: 'Geral',
                        );
                        final newStudent = {
                          ...result,
                          'full_name': nameCtrl.text.trim(),
                          'email': emailCtrl.text.trim().toLowerCase(),
                          'phone': phoneCtrl.text.trim(),
                          'goal': 'Geral',
                          'recent_status': 'Convite enviado; aguardando cadastro',
                          'last_session': 'Agora',
                          'status': result['status'] ?? 'Pendente Confirmação',
                          'has_alert': false,
                          'alert_message': null,
                          'avatar_url': null,
                        };

                        if (!mounted) return;
                        setState(() => _students.insert(0, newStudent));
                        Navigator.pop(dialogContext);
                        await _showInviteCreatedDialog(newStudent);
                      } catch (error) {
                        setDialogState(() {
                          isSubmitting = false;
                          submitError = error
                              .toString()
                              .replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: isSubmitting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Enviando...'),
                      ],
                    )
                  : const Text(
                      'Enviar convite',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'AL';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final filteredStudents = _students.where((st) {
      final name = (st['full_name'] as String? ?? '').toLowerCase();
      final status = (st['recent_status'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || status.contains(q);
    }).toList();

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
        body: Stack(
          children: [
            Column(
              children: [
                // Topo: Cabeçalho & Barra de Pesquisa em Pílula
                Padding(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Alunos',
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (_isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  MetaColors.emerald,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: MetaColors.textSecondary,
                                size: 22,
                              ),
                              onPressed: _loadStudentsFromDb,
                              tooltip: 'Recarregar',
                              splashRadius: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Barra de Pesquisa: Formato de Pílula, sem sombras
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: MetaColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: MetaColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                                style: const TextStyle(
                                  color: MetaColors.textPrimary,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Pesquisar...',
                                  hintStyle: TextStyle(
                                    color: MetaColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: MetaColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de Alunos (ListView)
                Expanded(
                  child: _hasError 
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Não foi possível carregar os alunos.\n$_errorMessage',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadStudentsFromDb,
                                  child: const Text('Tentar Novamente'),
                                )
                              ],
                            ),
                          ),
                        )
                      : _isLoading && _students.isEmpty
                        ? const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
                        : filteredStudents.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 48,
                                      color: MetaColors.textSecondary,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Sua lista começa aqui',
                                      style: TextStyle(color: MetaColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Adicione um aluno para enviar o convite e iniciar o acompanhamento.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: MetaColors.textSecondary, fontSize: 14, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                          // Padding dinâmico respeitando a Safe Area inferior e o SquircleButton
                          padding: EdgeInsets.only(
                            top: 4,
                            bottom: bottomPadding + 88,
                            left: 8,
                            right: 8,
                          ),
                          itemCount: filteredStudents.length,
                          // Removido qualquer Divider() - separação exclusivamente por espaçamento
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            final fullName =
                                student['full_name'] as String? ?? 'Aluno';
                            final recentStatus =
                                student['recent_status'] as String? ??
                                    'Treino pendente hoje';
                            final lastSession =
                                student['last_session'] as String? ?? '';
                            final hasAlert = student['has_alert'] == true;
                            final avatarUrl = student['avatar_url'] as String?;

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: (student['status'] as String? ?? '')
                                  .trim()
                                  .toLowerCase() ==
                                  'convite pendente'
                                  ? null
                                  : () => _showStudentDetails(student),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    tileColor: Colors.transparent,
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          MetaColors.surfaceHighlight,
                                      backgroundImage: avatarUrl != null
                                          ? NetworkImage(avatarUrl)
                                          : null,
                                      child: avatarUrl == null
                                          ? Text(
                                              _getInitials(fullName),
                                              style: const TextStyle(
                                                color: MetaColors.emerald,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      fullName,
                                      style: const TextStyle(
                                        color: MetaColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      recentStatus,
                                      style: const TextStyle(
                                        color: MetaColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          lastSession,
                                          style: TextStyle(
                                            color: hasAlert
                                                ? MetaColors.emerald
                                                : MetaColors.textSecondary,
                                            fontSize: 12,
                                            fontWeight: hasAlert
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (hasAlert) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: MetaColors.emerald
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Alerta',
                                              style: TextStyle(
                                                color: MetaColors.emerald,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // Botão Principal (FAB): SquircleButton posicionado no canto inferior direito
            Positioned(
              right: 16,
              bottom: bottomPadding + 16,
              child: SquircleButton(
                icon: Icons.person_add,
                label: 'Novo',
                isPrimary: true,
                onPressed: _showAddStudentDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
