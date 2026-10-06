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
  final List<Map<String, dynamic>> _mockStudents = [
    {
      'id': 'st-1',
      'full_name': 'Rodrigo Silveira',
      'email': 'rodrigo.silveira@email.com',
      'phone': '(11) 98765-4321',
      'goal': 'Hipertrofia Muscular',
      'recent_status': 'Treino pendente hoje • Peito & Tríceps',
      'last_session': 'Hoje, 07:45',
      'status': 'Ativo',
      'has_alert': true,
      'alert_message':
          'Relatou leve desconforto no ombro direito durante supino reto',
      'avatar_url': null,
    },
    {
      'id': 'st-2',
      'full_name': 'Camila Vasconcelos',
      'email': 'camila.vasconcelos@email.com',
      'phone': '(21) 99876-5432',
      'goal': 'Emagrecimento & Definição',
      'recent_status': 'Concluiu Treino B com êxito',
      'last_session': 'Hoje, 09:15',
      'status': 'Ativo',
      'has_alert': false,
      'alert_message': null,
      'avatar_url': null,
    },
    {
      'id': 'st-3',
      'full_name': 'Lucas Andrade Mendes',
      'email': 'lucas.mendes@email.com',
      'phone': '(11) 91234-5678',
      'goal': 'Condicionamento Geral',
      'recent_status': 'Aguardando primeiro acesso (Convite enviado)',
      'last_session': 'Ontem',
      'status': 'Pendente',
      'has_alert': false,
      'alert_message': null,
      'avatar_url': null,
    },
    {
      'id': 'st-4',
      'full_name': 'Mariana Castro',
      'email': 'mariana.castro@email.com',
      'phone': '(31) 97654-3210',
      'goal': 'Reabilitação Postural',
      'recent_status': 'Periodização concluída • Aguardando renovação',
      'last_session': 'Segunda',
      'status': 'Ativo',
      'has_alert': false,
      'alert_message': null,
      'avatar_url': null,
    },
    {
      'id': 'st-5',
      'full_name': 'Felipe Guimarães',
      'email': 'felipe.guimaraes@email.com',
      'phone': '(11) 98111-2233',
      'goal': 'Hipertrofia & Força',
      'recent_status': 'Novo recorde no Agachamento (120kg)',
      'last_session': '15/09',
      'status': 'Ativo',
      'has_alert': false,
      'alert_message': null,
      'avatar_url': null,
    },
  ];

  late List<Map<String, dynamic>> _students;

  @override
  void initState() {
    super.initState();
    _students = List.from(_mockStudents);
    _loadStudentsFromDb();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentsFromDb() async {
    setState(() => _isLoading = true);
    try {
      final dbStudents = await WorkoutService.getTrainerStudents();
      final alerts = await WorkoutService.getTrainerAlerts();

      if (dbStudents.isNotEmpty && mounted) {
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

            final recentStatus = activeSplit != null && activeSplit.isNotEmpty
                ? '$activeSplit • $lastSession'
                : 'Treino pendente hoje • $lastSession';

            return {
              'id': stId,
              'full_name': st['full_name'] ?? 'Aluno',
              'email': st['email'] ?? '',
              'phone': st['phone'] ?? '',
              'goal': st['goal'] ?? 'Consultoria',
              'recent_status': recentStatus,
              'last_session': lastSession,
              'status': st['status'] ?? 'Ativo',
              'has_alert': hasAlert,
              'alert_id': hasAlert ? matchingAlert['id'] : null,
              'alert_message': alertMsg,
              'avatar_url': st['avatar_url'],
            };
          }).toList();
        });
      }
    } catch (_) {
      // Caso não consiga conectar ao DB, mantém elegante os mock students
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

    final String textMessage = isPending
        ? 'Olá, $name! 💪\n\n'
            'Aqui é o Prof. $trainerName. Convidei você para o app de treinos e acompanhamento biomecânico!\n\n'
            'Clique no link para ativar seu acesso:\n'
            'https://cleudsonx.github.io/B2B-personal-ia/#onboarding?student_id=${student['id']}\n\n'
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
                } catch (_) {}
              },
              child: const Text(
                'Cadastrar',
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
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum aluno encontrado.',
                            style: const TextStyle(
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
