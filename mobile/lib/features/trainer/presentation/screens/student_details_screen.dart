import '../../../../services/workout_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/invite_service.dart';
import '../../anamnesis_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const StudentDetailsScreen({super.key, required this.studentData});

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
      final workout = await WorkoutService.getActiveWorkoutForClient(clientId: student['id']);
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
          const SnackBar(content: Text('Telefone não cadastrado. Nenhuma mensagem foi enviada.')),
        );
      }
      return;
    }
    final cleanPhone = digits.startsWith('55') ? digits : '55$digits';
    setState(() => _isResendingInvite = true);
    try {
      final invite = await InviteService.createInvite(
        channel: 'whatsapp',
        targetPhone: phone,
      );
      final inviteUrl = invite['invite_url'] as String?;
      if (inviteUrl == null || inviteUrl.isEmpty) {
        throw StateError('O servidor não retornou o link do convite.');
      }
      final text = Uri.encodeComponent(
        'Oi $name, segue seu convite para acessar seu treino: $inviteUrl',
      );
      final url = Uri.parse('https://wa.me/$cleanPhone?text=$text');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite gerado, mas não foi possível abrir o WhatsApp.')),
        );
      }
    } catch (error) {
      debugPrint('Falha ao reenviar convite pelo WhatsApp: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível gerar o convite para WhatsApp.')),
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

  void _showUnavailableAdminAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action ainda não disponível. Nenhuma alteração foi feita.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = student['status'] ?? 'Aguardando Ativação';
    final name = student['full_name'] ?? 'Aluno';
    final phone = student['phone'] ?? '';
    
    // Status colors
    Color statusColor = MetaColors.textSecondary;
    if (status == 'Ativo' || status == 'Treinando') statusColor = MetaColors.emerald;
    if (status == 'Aguardando Ativação' || status == 'Pendente Confirmação') statusColor = const Color(0xFFF59E0B); // Amber
    if (status == 'Inativo' || status == 'Arquivado') statusColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: MetaColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MetaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil do Aluno',
          style: TextStyle(color: MetaColors.textPrimary, fontSize: 18),
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
                      backgroundColor: MetaColors.surfaceHighlight,
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: MetaColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(color: MetaColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
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
                const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
              else if (_activeWorkout == null)
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center, color: MetaColors.textSecondary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma ficha ativa ainda.',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: '✨ Prescrever com IA em 30s',
                          isPrimary: true,
                          onPressed: _openWorkoutPrescription,
                        ),
                      ),
                    ],
                  ),
                )
              else
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ficha Atual',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeWorkout.workoutPlanTitle ?? 'Periodização',
                        style: const TextStyle(color: MetaColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ativa',
                        style: TextStyle(color: MetaColors.emerald, fontSize: 14),
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
                      leading: const Icon(Icons.edit, color: MetaColors.textSecondary),
                      title: const Text('Editar Perfil do Aluno', style: TextStyle(color: MetaColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, color: MetaColors.textSecondary),
                      onTap: () => _showUnavailableAdminAction('Editar perfil'),
                    ),
                    const Divider(color: MetaColors.surfaceHighlight, height: 1),
                    ListTile(
                      leading: const Icon(Icons.pause_circle_outline, color: MetaColors.textSecondary),
                      title: const Text('Arquivar Aluno', style: TextStyle(color: MetaColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, color: MetaColors.textSecondary),
                      onTap: () => _showUnavailableAdminAction('Arquivar aluno'),
                    ),
                    const Divider(color: MetaColors.surfaceHighlight, height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: const Text('Excluir Definitivamente', style: TextStyle(color: Colors.redAccent)),
                      onTap: () => _showUnavailableAdminAction('Excluir aluno'),
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
