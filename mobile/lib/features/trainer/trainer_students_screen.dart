// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'presentation/screens/student_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import '../../core/widgets/app_version_footer.dart';
import '../../core/theme/theme_controller.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../subscription/subscription_screen.dart';
import 'anamnesis_screen.dart';
import 'presentation/screens/trainer_profile_setup_screen.dart';

enum _StudentRiskFilter { all, onTrack, attention, atRisk }

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
  _StudentRiskFilter _selectedRiskFilter = _StudentRiskFilter.all;

  // Lista de alunos no estilo One UI 7 / Meta
  List<Map<String, dynamic>> _students = [];
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WorkoutService.studentsRefreshNotifier.addListener(_onStudentsRefreshed);
    _loadStudentsFromDb();
  }

  @override
  void dispose() {
    WorkoutService.studentsRefreshNotifier.removeListener(_onStudentsRefreshed);
    _searchController.dispose();
    super.dispose();
  }

  void _onStudentsRefreshed() {
    if (mounted) {
      _loadStudentsFromDb();
    }
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

            final activeSplit = st['active_split'] as String?;
            final hasActivePrescription =
                st['has_active_prescription'] as bool? ??
                (activeSplit?.isNotEmpty == true ? true : null);

            final matchingAlert = alerts.firstWhere(
              (a) {
                final matchIdOrName = (a['student_id'] == stId ||
                    (a['student_name'] as String? ?? '').toLowerCase() == stName);
                if (!matchIdOrName || a['acknowledged'] == true) return false;

                // Se o aluno já tem ficha ativa prescrita, alertas de onboarding/prescrição pendente foram sanados
                if (hasActivePrescription == true) {
                  final orig = (a['original_exercise'] as String? ?? '').toLowerCase();
                  final adap = (a['adapted_exercise'] as String? ?? '').toLowerCase();
                  final reason = (a['reason'] as String? ?? '').toLowerCase();
                  final isPrescriptionPendingAlert =
                      orig.contains('avaliação') ||
                      adap.contains('aguardando') ||
                      adap.contains('ficha') ||
                      reason.contains('avaliação') ||
                      reason.contains('periodização') ||
                      reason.contains('elaboração');
                  if (isPrescriptionPendingAlert) {
                    final aid = a['id']?.toString();
                    if (aid != null) {
                      WorkoutService.acknowledgeAlert(aid);
                    }
                    return false;
                  }
                }
                return true;
              },
              orElse: () => <String, dynamic>{},
            );

            final hasAlert = matchingAlert.isNotEmpty;
            final alertMsg = hasAlert
                ? (matchingAlert['message'] ?? 'Alerta biomecânico registrado')
                : null;

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
                          : 'Aguardando ficha',
              'last_session': lastSession,
              'status': status,
              'has_alert': hasAlert,
              'alert_message': alertMsg,
              'alert_data': hasAlert ? matchingAlert : null,
              'avatar_url': st['avatar_url'] ?? st['photo_url'],
              'photo_url': st['photo_url'] ?? st['avatar_url'],
              'age': st['age'],
              'weight_kg': st['weight_kg'],
              'height_cm': st['height_cm'],
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

  Future<void> _openWhatsApp(Map<String, dynamic> student, {String? customMessage}) async {
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
      final message = customMessage ??
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

  void _showBiomechanicsAlertModal(Map<String, dynamic> student) {
    HapticFeedback.mediumImpact();
    final alertData = (student['alert_data'] as Map<String, dynamic>?) ?? {};
    final alertId = alertData['id']?.toString() ?? '';
    final studentId = student['id'] as String? ?? '';
    final studentName = student['full_name'] as String? ?? 'Aluno';
    final alertMsg = student['alert_message'] as String? ?? 'Troca de exercício realizada';

    String original = alertData['original_exercise'] as String? ?? '';
    String adapted = alertData['adapted_exercise'] as String? ?? '';
    if (original.isEmpty && alertMsg.contains('Trocou ') && alertMsg.contains(' por ')) {
      final parts = alertMsg.replaceFirst('Trocou ', '').split(' por ');
      if (parts.length >= 2) {
        original = parts[0].trim();
        adapted = parts[1].trim();
      }
    }
    if (original.isEmpty) original = 'Exercício Original';
    if (adapted.isEmpty) adapted = 'Exercício Adaptado';

    final reason = alertData['reason'] as String? ?? 'Adaptação realizada no treino';
    final painLocation = alertData['pain_location'] as String?;
    final severity = alertData['severity'] as String? ?? 'Moderada';

    final user = AuthService.currentUser;
    final trainerName =
        user?.userMetadata?['full_name'] as String? ?? 'Seu Treinador';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        decoration: BoxDecoration(
          color: MetaColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: MetaColors.cardBorder(context)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle One UI 7
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.subtext(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabeçalho com Ícone Âmbar One UI 7
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adaptação Biomecânica',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aluno: $studentName',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: MetaColors.subtext(context)),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card Segmentado One UI 7: Comparativo dos Exercícios
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MetaColors.cardBorder(context)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PLANEJADO',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                original,
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: MetaColors.surfaceHighlight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: MetaColors.emerald,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ADAPTADO PELA IA',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                adapted,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: MetaColors.cardBorder(context), height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          reason.toLowerCase().contains('dor')
                              ? Icons.health_and_safety_outlined
                              : Icons.fitness_center_outlined,
                          size: 16,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Motivo relatado: $reason'
                            '${painLocation != null && painLocation.isNotEmpty ? ' ($painLocation - severidade: $severity)' : ''}',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Text(
                'AÇÕES RÁPIDAS EM 1 TOQUE',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Ação 1: Oficializar Troca na Ficha Ativa (1 Toque + Resolve Alerta)
              InkWell(
                onTap: () async {
                  Navigator.pop(modalCtx);
                  await _officializeSwap(
                    student: student,
                    alertId: alertId,
                    originalExercise: original,
                    adaptedExercise: adapted,
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: MetaColors.emerald, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Oficializar Troca na Ficha',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Substitui o exercício permanentemente na ficha ativa e resolve o alerta',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: MetaColors.emerald, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Ação 2: Apenas Marcar como Visto / Resolver (Troca Pontual)
              InkWell(
                onTap: () async {
                  Navigator.pop(modalCtx);
                  await _resolveAlert(student, alertId);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetaColors.cardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: MetaColors.text(context), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Marcar como Visto (Troca Pontual)',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mantém a ficha original e dá baixa no alerta para "Em dia"',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: MetaColors.subtext(context), size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Ação 3: Recriar Ficha com IA
              InkWell(
                onTap: () {
                  Navigator.pop(modalCtx);
                  _openPrescriptionForStudent(studentId, studentName);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetaColors.cardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, color: MetaColors.text(context), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Redefinir Periodização com IA',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Abrir o prescritor completo para gerar um novo ciclo de treinos',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: MetaColors.subtext(context), size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Ação 4: Falar no WhatsApp
              InkWell(
                onTap: () {
                  Navigator.pop(modalCtx);
                  final isPain = reason.toLowerCase().contains('dor') || painLocation != null;
                  final customMsg = 'Olá $studentName! 💪 Aqui é o Prof. $trainerName. '
                      'Vi no sistema que você precisou substituir "$original" por "$adapted" no seu treino'
                      '${isPain ? ' por desconforto articular' : ''}. '
                      'Como você está se sentindo? Sentiu algum incômodo ou dor?';
                  _openWhatsApp(student, customMessage: customMsg);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Falar no WhatsApp',
                              style: TextStyle(
                                color: Color(0xFF25D366),
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enviar mensagem perguntando se o aluno sentiu desconforto',
                              style: TextStyle(
                                color: Color(0xFF25D366),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF25D366), size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _officializeSwap({
    required Map<String, dynamic> student,
    required String alertId,
    required String originalExercise,
    required String adaptedExercise,
  }) async {
    HapticFeedback.mediumImpact();
    final studentId = student['id'] as String? ?? '';
    final studentName = student['full_name'] as String? ?? 'Aluno';

    setState(() {
      final idx = _students.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        _students[idx]['has_alert'] = false;
        _students[idx]['alert_message'] = null;
        _students[idx]['alert_data'] = null;
      }
    });

    final swapped = await WorkoutService.swapExerciseInActivePlan(
      studentId: studentId,
      originalExercise: originalExercise,
      adaptedExercise: adaptedExercise,
      alertId: alertId.isNotEmpty ? alertId : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.surfaceHighlight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Icon(
                swapped ? Icons.swap_horiz_rounded : Icons.check_circle_rounded,
                color: MetaColors.emerald,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  swapped
                      ? 'Troca oficializada! "$adaptedExercise" atualizado na ficha de $studentName e alerta resolvido.'
                      : 'Alerta de $studentName resolvido!',
                  style: const TextStyle(color: MetaColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _resolveAlert(Map<String, dynamic> student, String alertId) async {
    HapticFeedback.mediumImpact();
    final studentId = student['id'] as String? ?? '';
    final studentName = student['full_name'] as String? ?? 'Aluno';

    // Atualização otimista imediata na UI
    setState(() {
      final idx = _students.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        _students[idx]['has_alert'] = false;
        _students[idx]['alert_message'] = null;
        _students[idx]['alert_data'] = null;
      }
    });

    await WorkoutService.resolveBiomechanicalAlert(
      studentId: studentId,
      alertId: alertId.isNotEmpty ? alertId : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.surfaceHighlight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alerta de $studentName resolvido! Status atualizado para "Em dia".',
                  style: const TextStyle(color: MetaColors.textPrimary),
                ),
              ),
            ],
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
        backgroundColor: MetaColors.card(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: MetaColors.cardBorder(dialogContext)),
        ),
        icon: Icon(
          emailFailed ? Icons.mark_email_unread_outlined : Icons.check_circle_outline_rounded,
          color: emailFailed ? Colors.orangeAccent : MetaColors.primaryColor(dialogContext),
          size: 42,
        ),
        title: Text(
          emailWasSent ? 'Convite enviado' : 'Aluno adicionado',
          textAlign: TextAlign.center,
          style: TextStyle(color: MetaColors.text(dialogContext), fontWeight: FontWeight.bold),
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
              style: TextStyle(color: MetaColors.subtext(dialogContext), height: 1.45),
            ),
            if (inviteLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(dialogContext),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MetaColors.cardBorder(dialogContext)),
                ),
                child: SelectableText(
                  inviteLink,
                  style: TextStyle(color: MetaColors.text(dialogContext), fontSize: 12),
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
    if (mounted) await _loadStudentsFromDb();
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
          backgroundColor: MetaColors.card(dialogContext),
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: MetaColors.cardBorder(dialogContext)),
          ),
          title: Text(
            'Convidar aluno',
            style: TextStyle(
              color: MetaColors.text(dialogContext),
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
                  style: TextStyle(color: MetaColors.text(dialogContext)),
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    labelStyle: TextStyle(color: MetaColors.subtext(dialogContext)),
                    filled: true,
                    fillColor: MetaColors.highlight(dialogContext),
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
                  style: TextStyle(color: MetaColors.text(dialogContext)),
                  decoration: InputDecoration(
                    labelText: 'Email para receber o convite',
                    labelStyle: TextStyle(color: MetaColors.subtext(dialogContext)),
                    filled: true,
                    fillColor: MetaColors.highlight(dialogContext),
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
                  style: TextStyle(color: MetaColors.text(dialogContext)),
                  decoration: InputDecoration(
                    labelText: 'WhatsApp (opcional)',
                    labelStyle: TextStyle(color: MetaColors.subtext(dialogContext)),
                    hintText: '(61) 99999-9999',
                    filled: true,
                    fillColor: MetaColors.highlight(dialogContext),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (submitError != null) ...[
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final lowerError = submitError!.toLowerCase();
                      final isQuotaError = (lowerError.contains('limite') ||
                              lowerError.contains('cota') ||
                              lowerError.contains('vaga') ||
                              lowerError.contains('upgrade') ||
                              (lowerError.contains('plano') && !lowerError.contains('treino'))) &&
                          !lowerError.contains('duas etapas') &&
                          !lowerError.contains('exclusivo');

                      if (isQuotaError) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.workspace_premium_outlined,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Limite de alunos atingido',
                                    style: TextStyle(
                                      color: MetaColors.text(dialogContext),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                submitError!.contains('plano atual')
                                    ? submitError!
                                    : 'Você atingiu o limite de alunos cadastrados do seu plano atual. Para continuar adicionando novos alunos ou expandir sua consultoria, conheça nossos planos com alunos ilimitados ou arquive alunos inativos.',
                                style: TextStyle(
                                  color: MetaColors.subtext(dialogContext),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.amber),
                                    foregroundColor: Colors.amber,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                                  label: const Text(
                                    'Fazer Upgrade de Plano',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SubscriptionScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                submitError!,
                                style: TextStyle(
                                  color: MetaColors.text(dialogContext),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: MetaColors.subtext(dialogContext)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.primaryColor(dialogContext),
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

  _StudentRiskFilter _classifyStudent(Map<String, dynamic> st) {
    final status = (st['status'] as String? ?? '').toLowerCase();
    final recent = (st['recent_status'] as String? ?? '').toLowerCase();
    final lastSession = (st['last_session'] as String? ?? '').toLowerCase();
    final hasAlert = st['has_alert'] == true;

    if (status.contains('arquivado') || status.contains('inativo')) {
      return _StudentRiskFilter.atRisk;
    }
    if (hasAlert) {
      return _StudentRiskFilter.attention;
    }
    if (status.contains('pendente') ||
        recent.contains('pendente') ||
        recent.contains('aguardando')) {
      return _StudentRiskFilter.attention;
    }
    if (lastSession.contains('5') ||
        lastSession.contains('6') ||
        lastSession.contains('7') ||
        lastSession.contains('semana') ||
        lastSession.contains('mês') ||
        lastSession.contains('mes') ||
        lastSession.contains('nunca') ||
        lastSession.contains('sem registro')) {
      return _StudentRiskFilter.atRisk;
    }
    if (lastSession.contains('3') || lastSession.contains('4')) {
      return _StudentRiskFilter.attention;
    }
    return _StudentRiskFilter.onTrack;
  }

  Widget _buildTierBadge(_StudentRiskFilter tier) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (tier) {
      case _StudentRiskFilter.onTrack:
        bg = MetaColors.emerald.withValues(alpha: 0.14);
        fg = MetaColors.emerald;
        label = 'Em dia';
        icon = Icons.check_circle_outline_rounded;
        break;
      case _StudentRiskFilter.attention:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.16);
        fg = const Color(0xFFD97706);
        label = 'Atenção';
        icon = Icons.warning_amber_rounded;
        break;
      case _StudentRiskFilter.atRisk:
        bg = Colors.redAccent.withValues(alpha: 0.16);
        fg = Colors.redAccent;
        label = 'Risco';
        icon = Icons.error_outline_rounded;
        break;
      case _StudentRiskFilter.all:
        bg = Colors.transparent;
        fg = Colors.white;
        label = '';
        icon = Icons.circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required BuildContext context,
    required String label,
    required _StudentRiskFilter filter,
    required int count,
    Color? activeColor,
  }) {
    final isSelected = _selectedRiskFilter == filter;
    final color = activeColor ?? MetaColors.emerald;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedRiskFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : MetaColors.cardBorder(context),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : MetaColors.subtext(context),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.25)
                    : MetaColors.cardBorder(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? color : MetaColors.subtext(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrescriptionForStudent(
    String studentId,
    String studentName,
  ) async {
    HapticFeedback.lightImpact();
    if (widget.onSelectStudentForPlan != null) {
      widget.onSelectStudentForPlan!(studentId, studentName);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAnamnesisScreen(
          initialStudentId: studentId,
          initialStudentName: studentName,
        ),
      ),
    );
    if (mounted) await _loadStudentsFromDb();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = MetaColors.isDark(context);

    // Contadores de triagem One UI 7
    int onTrackCount = 0;
    int attentionCount = 0;
    int atRiskCount = 0;

    for (final st in _students) {
      final tier = _classifyStudent(st);
      switch (tier) {
        case _StudentRiskFilter.onTrack:
          onTrackCount++;
          break;
        case _StudentRiskFilter.attention:
          attentionCount++;
          break;
        case _StudentRiskFilter.atRisk:
          atRiskCount++;
          break;
        case _StudentRiskFilter.all:
          break;
      }
    }

    final filteredStudents = _students.where((st) {
      final name = (st['full_name'] as String? ?? '').toLowerCase();
      final status = (st['recent_status'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || status.contains(q);

      if (!matchesSearch) return false;

      if (_selectedRiskFilter == _StudentRiskFilter.all) return true;
      return _classifyStudent(st) == _selectedRiskFilter;
    }).toList();

    // Ordenação estrita One UI 7: Alunos que necessitam de atenção/risco no topo ou pendentes
    int statusPriority(Map<String, dynamic> st) {
      final tier = _classifyStudent(st);
      if (tier == _StudentRiskFilter.attention) return 0;
      if (tier == _StudentRiskFilter.atRisk) return 1;
      return 2;
    }

    filteredStudents.sort((a, b) {
      final pA = statusPriority(a);
      final pB = statusPriority(b);
      if (pA != pB) return pA.compareTo(pB);
      final nameA = (a['full_name'] as String? ?? '').toLowerCase();
      final nameB = (b['full_name'] as String? ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

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
                          Text(
                            'Alunos',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        MetaColors.primaryColor(context),
                                      ),
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
                              OneUiPopoverMenuButton(
                                showBadgeDot: true,
                                items: [
                                  OneUiPopoverItem(
                                    label: 'Novidades da versão',
                                    icon: Icons.new_releases_outlined,
                                    showOrangeDot: true,
                                    onTap: () =>
                                        AppVersionFooter.showReleaseNotesModal(
                                          context,
                                        ),
                                  ),
                                  OneUiPopoverItem(
                                    label: 'Alternar modo visual',
                                    icon: isDark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                    onTap: () =>
                                        ThemeController.instance.toggleTheme(),
                                  ),
                                  OneUiPopoverItem(
                                    label: 'Configurar Vitrine',
                                    icon: Icons.storefront_outlined,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const TrainerProfileSetupScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Barra de Pesquisa: Formato de Pílula One UI 7, sem sombras
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: MetaColors.highlight(context),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: MetaColors.cardBorder(context).withValues(alpha: 0.6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: MetaColors.subtext(context),
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
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Pesquisar alunos...',
                                  hintStyle: TextStyle(
                                    color: MetaColors.subtext(context),
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
                      const SizedBox(height: 10),
                      // Pílulas de Triagem One UI 7 (Scroll Horizontal)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterPill(
                              context: context,
                              label: 'Todos',
                              filter: _StudentRiskFilter.all,
                              count: _students.length,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              context: context,
                              label: 'Em dia',
                              filter: _StudentRiskFilter.onTrack,
                              count: onTrackCount,
                              activeColor: MetaColors.emerald,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              context: context,
                              label: 'Atenção',
                              filter: _StudentRiskFilter.attention,
                              count: attentionCount,
                              activeColor: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterPill(
                              context: context,
                              label: 'Em risco',
                              filter: _StudentRiskFilter.atRisk,
                              count: atRiskCount,
                              activeColor: Colors.redAccent,
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
                           ? Center(
                               child: Padding(
                                 padding: const EdgeInsets.all(24),
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Icon(
                                       Icons.people_outline_rounded,
                                       size: 48,
                                       color: MetaColors.subtext(context),
                                     ),
                                     const SizedBox(height: 12),
                                     Text(
                                       'Sua lista começa aqui',
                                       style: TextStyle(
                                         color: MetaColors.text(context),
                                         fontSize: 17,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                     const SizedBox(height: 6),
                                     Text(
                                       'Adicione um aluno para enviar o convite e iniciar o acompanhamento.',
                                       textAlign: TextAlign.center,
                                       style: TextStyle(
                                         color: MetaColors.subtext(context),
                                         fontSize: 14,
                                         height: 1.4,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             )
                            : ListView.separated(
                          padding: EdgeInsets.only(
                            top: 8,
                            bottom: bottomPadding + 88,
                            left: 14,
                            right: 14,
                          ),
                          itemCount: filteredStudents.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                            final tier = _classifyStudent(student);
                            final needsPrescription = recentStatus.toLowerCase().contains('aguardando') ||
                                recentStatus.toLowerCase().contains('sem ficha');
                            final studentId = student['id'] as String? ?? '';

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showStudentDetails(student);
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MetaColors.card(context),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: hasAlert
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                                          : MetaColors.cardBorder(context),
                                      width: hasAlert ? 1.4 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // 1. Avatar One UI 7 com indicador circular de triagem
                                          Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 25,
                                                backgroundColor: MetaColors.highlight(context),
                                                backgroundImage: safeImageProvider(avatarUrl),
                                                child: safeImageProvider(avatarUrl) == null
                                                    ? Text(
                                                        _getInitials(fullName),
                                                        style: TextStyle(
                                                          color: MetaColors.primaryColor(context),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 13,
                                                  height: 13,
                                                  decoration: BoxDecoration(
                                                    color: tier == _StudentRiskFilter.onTrack
                                                        ? MetaColors.emerald
                                                        : (tier == _StudentRiskFilter.attention
                                                            ? const Color(0xFFF59E0B)
                                                            : Colors.redAccent),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: MetaColors.card(context),
                                                      width: 2.2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),

                                          // 2. Informações do aluno
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        fullName,
                                                        style: TextStyle(
                                                          color: MetaColors.text(context),
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 16,
                                                          letterSpacing: -0.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: hasAlert ? () => _showBiomechanicsAlertModal(student) : null,
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: _buildTierBadge(tier),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  recentStatus,
                                                  style: TextStyle(
                                                    color: MetaColors.subtext(context),
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Linha de Rodapé do Card One UI 7: Status temporal & Micro-ações táteis
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          if (hasAlert) ...[
                                            Expanded(
                                              child: InkWell(
                                                onTap: () => _showBiomechanicsAlertModal(student),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.warning_amber_rounded,
                                                        size: 15,
                                                        color: Color(0xFFF59E0B),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          student['alert_message'] ?? 'Adaptação realizada',
                                                          style: const TextStyle(
                                                            color: Color(0xFFF59E0B),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'Resolver',
                                                          style: TextStyle(
                                                            color: Color(0xFFF59E0B),
                                                            fontSize: 10.5,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 14,
                                              color: MetaColors.subtext(context),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                lastSession.isNotEmpty ? lastSession : 'Sincronizado',
                                                style: TextStyle(
                                                  color: MetaColors.subtext(context),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 8),

                                          // Micro-ação: Prescrever Ficha rápida (se aplicável)
                                          if (needsPrescription && studentId.isNotEmpty) ...[
                                            InkWell(
                                              onTap: () => _openPrescriptionForStudent(studentId, fullName),
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: MetaColors.emerald.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: MetaColors.emerald.withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.auto_awesome, size: 13, color: MetaColors.emerald),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Prescrever',
                                                      style: TextStyle(
                                                        color: MetaColors.emerald,
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],

                                          // Micro-ação: WhatsApp 1-Toque
                                          InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _openWhatsApp(student);
                                            },
                                            borderRadius: BorderRadius.circular(16),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: MetaColors.highlight(context),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: MetaColors.cardBorder(context),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.chat_bubble_outline_rounded,
                                                    size: 13,
                                                    color: MetaColors.text(context),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Contato',
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
                                    ],
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
