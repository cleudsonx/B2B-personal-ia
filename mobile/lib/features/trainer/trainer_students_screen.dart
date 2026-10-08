// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'presentation/screens/student_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../services/invite_service.dart';

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
            final lastSession = st['last_session'] as String? ?? 'Sincronizado';

            return {
              'id': stId,
              'full_name': st['full_name'] ?? 'Aluno',
              'email': st['email'] ?? '',
              'phone': st['phone'] ?? '',
              'goal': st['goal'] ?? 'Treino',
              'recent_status': activeSplit != null
                  ? 'Ficha ativa: '
                  : 'Aguardando ficha',
              'last_session': lastSession,
              'status': st['status'] ?? 'Ativo',
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
    final email = student['email'] as String? ?? '';
    final name = student['full_name'] as String? ?? 'Aluno';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final isPending = (student['status'] as String? ?? '').toLowerCase().contains('pendente');
    final user = AuthService.currentUser;
    final trainerName =
        user?.userMetadata?['full_name'] as String? ?? 'Seu Treinador';
    final trainerSlug = trainerName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    String inviteLink = 'https://mrcoach.app/convite/$trainerSlug/demo-invite';

    // Se estiver pendente, gera convite com token criptográfico de 24h e auditoria
    if (isPending) {
      try {
        final inviteData = await InviteService.createInvite(
          channel: cleanPhone.isNotEmpty ? 'whatsapp' : 'email',
          targetPhone: cleanPhone.isNotEmpty ? cleanPhone : null,
          targetEmail: email.isNotEmpty ? email : null,
        );
        final token = inviteData['token'];
        if (token != null) {
          inviteLink = inviteData['invite_url'] as String? ??
              'https://mrcoach.app/#/invite/$token';
        }
      } catch (e) {
        debugPrint('[WhatsApp] Erro ao gerar token de convite via API, usando fallback: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível gerar um convite válido. Tente novamente.')),
          );
        }
        return;
      }
    }

    final String textMessage = isPending
        ? 'Olá, $name! 💪\n\n'
            'Aqui é o Prof. $trainerName. Convidei você para o app Mr. Coach com periodização inteligente e biomecânica!\n\n'
            'Toque no link exclusivo abaixo para ativar seu acesso (válido por 24h):\n'
            '$inviteLink\n\n'
            'Bons treinos!'
        : 'Olá $name! 💪 Aqui é o Prof. $trainerName. Como estão os treinos essa semana?';

    final msg = Uri.encodeComponent(textMessage);

    if (cleanPhone.isNotEmpty) {
      final finalNumber =
          cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
      final url = Uri.parse('https://wa.me/$finalNumber?text=$msg');
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

  void _showStudentDetails(Map<String, dynamic> student) {
    if (widget.onSelectStudentForPlan != null) {
      widget.onSelectStudentForPlan!(
        student['id'] as String,
        student['full_name'] as String,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailsScreen(studentData: student),
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: MetaColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: MetaColors.border),
          ),
          title: const Text(
            'Novo Aluno',
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
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nome obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'E-mail válido obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'WhatsApp / Telefone',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newStudent = {
                  'id': 'st-${DateTime.now().millisecondsSinceEpoch}',
                  'full_name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'goal': 'Geral',
                  'recent_status': 'Aguardando primeiro treino',
                  'last_session': 'Agora',
                  'status': 'Ativo',
                  'has_alert': false,
                  'alert_message': null,
                  'avatar_url': null,
                };

                setState(() {
                  _students.insert(0, newStudent);
                });

                Navigator.pop(ctx);

                try {
                  await WorkoutService.createStudent(
                    fullName: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isNotEmpty
                        ? phoneCtrl.text.trim()
                        : null,
                    goal: 'Geral',
                  );

                  // Se tiver telefone, já oferece a abertura do WhatsApp com o link de 24h
                  if (phoneCtrl.text.trim().isNotEmpty && mounted) {
                    _openWhatsApp(newStudent);
                  }
                } catch (_) {}
              },
              child: const Text(
                'Cadastrar e Convidar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
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
                                  'Erro ao carregar alunos:\n\${_errorMessage}',
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
                              child: Text(
                                'Nenhum aluno cadastrado.',
                                style: TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 15,
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
                                onTap: () => _showStudentDetails(student),
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
