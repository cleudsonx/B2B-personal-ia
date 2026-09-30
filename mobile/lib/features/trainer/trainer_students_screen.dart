import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../subscription/subscription_screen.dart';
import 'anamnesis_screen.dart';

class TrainerStudentsScreen extends StatefulWidget {
  final Function(String studentId, String studentName)? onSelectStudentForPlan;

  const TrainerStudentsScreen({super.key, this.onSelectStudentForPlan});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  bool _isLoading = false;
  String _selectedFilter = 'Todos'; // 'Todos', 'Ativos', 'Convidados', 'Arquivados', 'Com Alerta'
  String _searchQuery = '';
  MySubscriptionModel? _mySubscription;

  // Lista demo rica com estados reais do Hub Mr. Coach
  final List<Map<String, dynamic>> _demoStudents = [
    {
      'id': 'st-1',
      'full_name': 'Rodrigo Silveira',
      'email': 'rodrigo.silveira@email.com',
      'phone': '(11) 98765-4321',
      'goal': 'Hipertrofia Muscular',
      'level': 'Intermediário',
      'days_per_week': 4,
      'has_alert': true,
      'alert_id': 'alt-1',
      'alert_message': 'Relatou dor no Ombro Anterior durante Supino Reto ➔ Adaptado para Supino Máquina',
      'status': 'Ativo',
      'last_session': 'Hoje, 07:45',
      'active_split': 'Treino A - Peito e Tríceps',
      'injuries_or_restrictions': 'Leve desconforto no manguito rotador direito',
    },
    {
      'id': 'st-2',
      'full_name': 'Camila Vasconcelos',
      'email': 'camila.vasconcelos@email.com',
      'phone': '(21) 99876-5432',
      'goal': 'Emagrecimento & Definição',
      'level': 'Iniciante',
      'days_per_week': 3,
      'has_alert': false,
      'alert_id': null,
      'alert_message': null,
      'status': 'Ativo',
      'last_session': 'Hoje, 09:15',
      'active_split': 'Treino B - Membros Inferiores',
      'injuries_or_restrictions': 'Condromalácia patelar grau 1',
    },
    {
      'id': 'st-3',
      'full_name': 'Lucas Andrade Mendes',
      'email': 'lucas.mendes@email.com',
      'phone': '(11) 91234-5678',
      'goal': 'Condicionamento Geral',
      'level': 'Iniciante',
      'days_per_week': 3,
      'has_alert': false,
      'alert_id': null,
      'alert_message': null,
      'status': 'Pendente Confirmação',
      'last_session': 'Convite enviado por e-mail',
      'active_split': 'Aguardando primeiro acesso',
      'injuries_or_restrictions': 'Nenhuma restrição articular',
    },
    {
      'id': 'st-4',
      'full_name': 'Mariana Castro',
      'email': 'mariana.castro@email.com',
      'phone': '(31) 97654-3210',
      'goal': 'Reabilitação Postural',
      'level': 'Intermediário',
      'days_per_week': 3,
      'has_alert': false,
      'alert_id': null,
      'alert_message': null,
      'status': 'Arquivado',
      'last_session': 'Ciclo concluído em 15/08',
      'active_split': 'Contrato pausado',
      'injuries_or_restrictions': 'Escoliose torácica leve',
    },
  ];

  late List<Map<String, dynamic>> _students;

  @override
  void initState() {
    super.initState();
    SubscriptionService.activeSubscriptionNotifier.addListener(_onSubscriptionChanged);
    _students = List.from(_demoStudents);
    _loadStudentsFromDb();
  }

  @override
  void dispose() {
    SubscriptionService.activeSubscriptionNotifier.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (mounted) {
      final updated = SubscriptionService.activeSubscriptionNotifier.value;
      if (updated != null && updated != _mySubscription) {
        setState(() {
          _mySubscription = updated;
        });
      }
    }
  }

  Future<void> _loadStudentsFromDb() async {
    setState(() => _isLoading = true);
    try {
      final dbStudents = await WorkoutService.getTrainerStudents();
      final alerts = await WorkoutService.getTrainerAlerts();
      final sub = await SubscriptionService.getMySubscription();
      if (mounted) _mySubscription = sub;

      if (dbStudents.isNotEmpty && mounted) {
        setState(() {
          _students = dbStudents.map((st) {
            final stId = st['id'] ?? 'db-id';
            final stName = (st['full_name'] as String? ?? '').toLowerCase();

            // Cruza alertas ativos (não cientes) para este aluno
            final matchingAlert = alerts.firstWhere(
              (a) => (a['student_id'] == stId || (a['student_name'] as String? ?? '').toLowerCase() == stName) && a['acknowledged'] == false,
              orElse: () => <String, dynamic>{},
            );

            final hasAlert = matchingAlert.isNotEmpty;
            final alertMsg = hasAlert ? (matchingAlert['message'] ?? 'Adaptação biomecânica no espaço de treino') : null;
            final alertId = hasAlert ? matchingAlert['id'] : null;

            return {
              'id': stId,
              'full_name': st['full_name'] ?? 'Aluno',
              'email': st['email'] ?? '',
              'phone': st['phone'] ?? '',
              'goal': st['goal'] ?? 'Consultoria Mr. Coach',
              'level': st['level'] ?? 'Ativo',
              'days_per_week': st['days_per_week'] ?? 4,
              'has_alert': hasAlert,
              'alert_id': alertId,
              'alert_message': alertMsg,
              'status': st['status'] ?? 'Ativo',
              'last_session': st['last_session'] ?? 'Sincronizado',
              'active_split': st['active_split'] ?? 'Periodização Mr. Coach',
              'injuries_or_restrictions': st['injuries_or_restrictions'] ?? 'Nenhuma observação cadastrada',
            };
          }).toList();
        });
      }
    } catch (_) {
      // Mantém lista em memória com elegância
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acknowledgeStudentAlert(Map<String, dynamic> student) async {
    final alertId = student['alert_id'] as String?;
    if (alertId != null) {
      await WorkoutService.acknowledgeAlert(alertId);
    }
    setState(() {
      student['has_alert'] = false;
      student['alert_message'] = null;
      student['alert_id'] = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text('✓ Alerta de ${student['full_name']} marcado como ciente.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(Map<String, dynamic> student) async {
    final phone = student['phone'] as String? ?? '';
    final name = student['full_name'] as String? ?? 'Aluno';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final isPending = student['status'] == 'Pendente Confirmação' || student['status'] == 'Pendente';
    final user = AuthService.currentUser;
    final trainerName = user?.userMetadata?['full_name'] as String? ?? 'Seu Treinador';

    final String textMessage = isPending
        ? 'Olá, $name! 💪\n\n'
            'Aqui é o seu Personal Trainer Prof. $trainerName. Convidei você para o *Mr. Coach* — nossa plataforma de biomecânica e acompanhamento de treinos!\n\n'
            '🔗 Clique no link para ativar seu acesso e preencher sua avaliação em 3 min:\n'
            'https://cleudsonx.github.io/B2B-personal-ia/#onboarding?student_id=${student['id']}\n\n'
            'Bons treinos e foco na técnica!'
        : 'Olá $name! 💪 Aqui é o Prof. $trainerName pelo Mr. Coach. Como estão seus treinos presenciais essa semana?';

    final msg = Uri.encodeComponent(textMessage);

    if (cleanPhone.isNotEmpty) {
      final finalNumber = cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
      final url = Uri.parse('https://wa.me/$finalNumber?text=$msg');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cardBorder(context)),
          ),
          title: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
              const SizedBox(width: 8),
              Text('WhatsApp do Aluno', style: TextStyle(color: AppColors.text(context), fontSize: 16)),
            ],
          ),
          content: Text(
            phone.isNotEmpty
                ? 'Telefone: $phone\n\nMensagem pronta:\n"Olá $name! Como estão seus treinos no Mr. Coach?"'
                : 'O aluno $name ainda não tem telefone/WhatsApp cadastrado.\nEdite os dados do aluno para incluir o número.',
            style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Fechar', style: TextStyle(color: AppColors.text(context))),
            ),
          ],
        ),
      );
    }
  }

  void _showStudentLimitUpgradeSheet(
    BuildContext context, {
    required int currentCount,
    required int maxAllowed,
    String? actionContext,
  }) {
    final currentSub = SubscriptionService.activeSubscriptionNotifier.value ?? _mySubscription;
    final currentPlanName = currentSub?.planName ?? 'Starter Trial';
    final planId = currentSub?.planId ?? 'starter';

    String targetPlanName = 'Personal Pro';
    String targetPrice = 'R\$ 89/mês';
    int targetCapacity = 30;
    bool isMaxTier = false;

    if (planId == 'pro') {
      targetPlanName = 'Elite Coach';
      targetPrice = 'R\$ 149/mês';
      targetCapacity = 60;
    } else if (planId == 'elite') {
      targetPlanName = 'Studio Scale';
      targetPrice = 'R\$ 199/mês';
      targetCapacity = 100;
    } else if (planId == 'studio') {
      isMaxTier = true;
      targetPlanName = 'Studio Scale';
      targetPrice = 'Capacidade Máxima';
      targetCapacity = 100;
    }

    final actionText = actionContext ?? 'cadastrar novos alunos';
    final descText = isMaxTier
        ? 'Você já possui $currentCount de $maxAllowed alunos ativos cadastrados no seu plano atual ($currentPlanName), que é o limite máximo da plataforma.\n\nPara $actionText, arquive alunos inativos ou pausados da consultoria para liberar vagas.'
        : 'Você já possui $currentCount de $maxAllowed alunos ativos simultâneos no seu plano atual ($currentPlanName).\n\nPara $actionText e expandir sua consultoria, faça upgrade para o $targetPlanName (até $targetCapacity alunos com IA ilimitada) ou arquive outros alunos inativos para liberar vagas imediatas.';

    List<String> benefits = [];
    if (planId == 'starter') {
      benefits = [
        'Até 30 alunos ativos na consultoria',
        'Prescrições IA Mr. Coach Ilimitadas',
        'Alertas em tempo real de dor e adaptação no salão',
        'Raio-X Anatômico 3D com EMG e Fases',
      ];
    } else if (planId == 'pro') {
      benefits = [
        'Até 60 alunos ativos na consultoria',
        'Automação e envio de treinos via WhatsApp',
        'Alertas automáticos de dor direto no WhatsApp',
        'Relatórios de assiduidade e retenção de alunos',
      ];
    } else {
      benefits = [
        'Até 100 alunos ativos na assessoria esportiva',
        'Múltiplos personals colaboradores sob a mesma conta',
        'White-label parcial da consultoria',
        'Gerente de contas dedicado e suporte VIP',
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber),
                        SizedBox(width: 6),
                        Text(
                          'COTA DO PLANO ATINGIDA',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Limite do Plano $currentPlanName Atingido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  descText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Benefits Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.pillBg(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < benefits.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _buildUpgradeBenefitRow(context, benefits[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary CTA: Upgrade or Manage
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald(context),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 20, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          isMaxTier ? 'Ver Planos & Assinatura' : 'Fazer Upgrade para $targetPlanName • $targetPrice',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary CTA: Free up space by archiving
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.cardBorder(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedFilter = 'Todos');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dica: Use o botão de "Arquivar" em alunos antigos para liberar vagas no plano sem apagar os dados.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                    child: Text(
                      'Gerenciar / Arquivar Alunos Antigos',
                      style: TextStyle(color: AppColors.text(context), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tertiary: Ver todos os planos
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    child: Text(
                      'Ver Todos os Planos Disponíveis',
                      style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpgradeBenefitRow(BuildContext context, String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.emerald(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.text(context), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showAddStudentDialog() {
    final totalCount = _students.length;
    final archivedCount = _students.where((s) {
      final st = (s['status'] as String? ?? '').toLowerCase();
      return st.contains('arquivado') || st.contains('inativo');
    }).length;
    final activeStudentsCount = totalCount - archivedCount;
    final currentSub = SubscriptionService.activeSubscriptionNotifier.value ?? _mySubscription;
    final maxStudents = currentSub?.maxStudents ?? 3;

    if (activeStudentsCount >= maxStudents) {
      _showStudentLimitUpgradeSheet(
        context,
        currentCount: activeStudentsCount,
        maxAllowed: maxStudents,
        actionContext: 'cadastrar novos alunos',
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final restrictionsCtrl = TextEditingController();
    String goal = 'Hipertrofia Muscular';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.cardBorder(context)),
              ),
              title: Row(
                children: [
                  Icon(Icons.person_add_alt_1_outlined, color: AppColors.emerald(context)),
                  const SizedBox(width: 10),
                  Text(
                    'Novo Aluno • Mr. Coach',
                    style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Nome Completo do Aluno',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 2) return 'Informe o nome do aluno';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'E-mail para Convite e Acesso',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                            return 'Informe um e-mail válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'WhatsApp / Telefone (Opcional)',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: goal,
                        dropdownColor: AppColors.card(context),
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Objetivo Principal',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Hipertrofia Muscular', 'Emagrecimento & Definição', 'Condicionamento Geral', 'Reabilitação Postural']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => goal = val ?? goal,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: restrictionsCtrl,
                        maxLines: 2,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Restrições Articulares / Lesões (IA)',
                          hintText: 'Ex: Condromalácia, dor no ombro direito',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: AppColors.subtext(context))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            final student = await WorkoutService.createStudent(
                              fullName: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                              goal: goal,
                            );

                            final restrictions = restrictionsCtrl.text.trim().isNotEmpty
                                ? restrictionsCtrl.text.trim()
                                : 'Nenhuma observação cadastrada';

                            if (mounted) {
                              setState(() {
                                _students.insert(0, {
                                  'id': student['id'],
                                  'full_name': student['full_name'],
                                  'email': student['email'],
                                  'phone': student['phone'],
                                  'goal': student['goal'],
                                  'level': 'Iniciante',
                                  'days_per_week': 3,
                                  'has_alert': false,
                                  'alert_id': null,
                                  'alert_message': null,
                                  'status': 'Pendente Confirmação',
                                  'last_session': 'Convite enviado por e-mail',
                                  'active_split': 'Aguardando primeiro acesso',
                                  'injuries_or_restrictions': restrictions,
                                });
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (!mounted) return;

                              if (phoneCtrl.text.trim().isNotEmpty) {
                                showDialog(
                                  context: this.context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: AppColors.card(context),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: AppColors.cardBorder(context)),
                                    ),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.mark_email_read_rounded, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Convite Criado!',
                                            style: TextStyle(
                                              color: AppColors.text(context),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      'O convite oficial do Mr. Coach foi enviado para o e-mail ${student['email']}.\n\nDeseja enviar agora a mensagem com o link de ativação no WhatsApp de ${student['full_name']}?',
                                      style: TextStyle(color: AppColors.subtext(context), fontSize: 13, height: 1.4),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx),
                                        child: Text('Mais Tarde', style: TextStyle(color: AppColors.subtext(context))),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF25D366),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.chat_rounded, size: 18),
                                        label: const Text('Enviar WhatsApp Agora', style: TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () {
                                          Navigator.pop(dCtx);
                                          _openWhatsApp({
                                            'id': student['id'],
                                            'full_name': student['full_name'],
                                            'phone': student['phone'],
                                            'status': 'Pendente Confirmação',
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green.shade800,
                                    content: Text('✓ Aluno "${student['full_name']}" cadastrado e convite enviado por e-mail!'),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade800,
                                  content: Text('Erro ao salvar aluno: $e'),
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Salvar e Convidar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    final nameCtrl = TextEditingController(text: student['full_name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: student['email'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: student['phone'] as String? ?? '');
    final restrictionsCtrl = TextEditingController(text: student['injuries_or_restrictions'] as String? ?? '');
    String goal = student['goal'] as String? ?? 'Hipertrofia Muscular';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.cardBorder(context)),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppColors.emerald(context)),
                  const SizedBox(width: 10),
                  Text('Editar Aluno', style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Nome do Aluno',
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Nome obrigatório' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'WhatsApp / Telefone',
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: goal,
                        dropdownColor: AppColors.card(context),
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Objetivo',
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Hipertrofia Muscular', 'Emagrecimento & Definição', 'Condicionamento Geral', 'Reabilitação Postural']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => goal = val ?? goal,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: restrictionsCtrl,
                        maxLines: 2,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Restrições Articulares / Lesões',
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text('Cancelar', style: TextStyle(color: AppColors.subtext(context))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);

                          final studentId = student['id'] as String;
                          await WorkoutService.updateStudent(
                            studentId: studentId,
                            fullName: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                            goal: goal,
                            injuriesOrRestrictions: restrictionsCtrl.text.trim(),
                          );

                          if (mounted) {
                            setState(() {
                              student['full_name'] = nameCtrl.text.trim();
                              student['email'] = emailCtrl.text.trim();
                              student['phone'] = phoneCtrl.text.trim();
                              student['goal'] = goal;
                              student['injuries_or_restrictions'] = restrictionsCtrl.text.trim();
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.green.shade800,
                                content: Text('✓ Dados de ${student['full_name']} atualizados!'),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleArchiveStudent(Map<String, dynamic> student) async {
    final currentStatus = student['status'] as String? ?? 'Ativo';
    final isArchiving = currentStatus.toLowerCase() == 'ativo' || currentStatus.toLowerCase().contains('pendente');
    final newStatus = isArchiving ? 'Arquivado' : 'Ativo';
    final studentId = student['id'] as String;

    if (!isArchiving) {
      // Reativação de aluno: validar cota estritamente contra o limite do plano atual
      final totalCount = _students.length;
      final archivedCount = _students.where((s) {
        final st = (s['status'] as String? ?? '').toLowerCase();
        return st.contains('arquivado') || st.contains('inativo');
      }).length;
      final occupiedSlots = totalCount - archivedCount;

      final currentSub = SubscriptionService.activeSubscriptionNotifier.value ?? _mySubscription;
      final maxStudents = currentSub?.maxStudents ?? 3;

      if (occupiedSlots >= maxStudents) {
        _showStudentLimitUpgradeSheet(
          context,
          currentCount: occupiedSlots,
          maxAllowed: maxStudents,
          actionContext: 'reativar o aluno "${student['full_name']}"',
        );
        return;
      }
    }

    // Atualização otimista imediata na UI para atualizar pílulas e contadores
    setState(() {
      student['status'] = newStatus;
      final idx = _students.indexWhere((s) => s['id'] == studentId);
      if (idx != -1) {
        _students[idx]['status'] = newStatus;
      }
    });

    try {
      await WorkoutService.updateStudentStatus(studentId: studentId, status: newStatus);
    } catch (e) {
      // Se houver rejeição (ex: cota excedida no backend), reverte o estado na UI
      setState(() {
        student['status'] = currentStatus;
        final idx = _students.indexWhere((s) => s['id'] == studentId);
        if (idx != -1) {
          _students[idx]['status'] = currentStatus;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isArchiving ? Colors.orange.shade900 : Colors.green.shade800,
          content: Text(
            isArchiving
                ? '📦 Aluno ${student['full_name']} foi arquivado (vaga liberada no plano).'
                : '✓ Aluno ${student['full_name']} reativado com sucesso!',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Excluir Aluno?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Tem certeza que deseja excluir ${student['full_name']}?\nEsta ação desvinculará as fichas e histórico.',
          style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.subtext(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir Definitivamente', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final studentId = student['id'] as String;
      await WorkoutService.deleteStudent(studentId);
      setState(() {
        _students.removeWhere((s) => s['id'] == studentId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Aluno ${student['full_name']} excluído.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtragem por status e busca por nome
    final filteredStudents = _students.where((st) {
      final name = (st['full_name'] as String? ?? '').toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final status = (st['status'] as String? ?? 'Ativo').toLowerCase();
      if (_selectedFilter == 'Ativos') {
        return status == 'ativo';
      } else if (_selectedFilter == 'Convidados') {
        return status.contains('pendente') || status.contains('convidado');
      } else if (_selectedFilter == 'Arquivados') {
        return status.contains('arquivado') || status.contains('inativo');
      } else if (_selectedFilter == 'Com Alerta') {
        return st['has_alert'] == true;
      }
      return true; // 'Todos'
    }).toList();

    final totalCount = _students.length;
    final activeCount = _students.where((s) => (s['status'] as String? ?? '').toLowerCase() == 'ativo').length;
    final pendingCount = _students.where((s) {
      final st = (s['status'] as String? ?? '').toLowerCase();
      return st.contains('pendente') || st.contains('convidado');
    }).length;
    final archivedCount = _students.where((s) {
      final st = (s['status'] as String? ?? '').toLowerCase();
      return st.contains('arquivado') || st.contains('inativo');
    }).length;
    final occupiedCount = totalCount - archivedCount;
    final alertsCount = _students.where((s) => s['has_alert'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Mr. Coach • Hub de Alunos',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.emerald(context),
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Configurar IP do Servidor (Dev)',
              onPressed: () => ServerConfigDialog.show(context),
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.subtext(context)),
            tooltip: 'Recarregar Alunos',
            onPressed: _loadStudentsFromDb,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald(context),
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStudentDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudentsFromDb,
        color: AppColors.emerald(context),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Indicador Interativo do Plano Atual do Professor
            ValueListenableBuilder<MySubscriptionModel?>(
              valueListenable: SubscriptionService.activeSubscriptionNotifier,
              builder: (context, sub, _) {
                final currentSub = sub ?? _mySubscription;
                final planName = currentSub?.planName ?? 'Personal Pro';
                final maxStudents = currentSub?.maxStudents ?? 30;
                final isStarter = currentSub?.planId == 'starter';
                final isDark = AppColors.isDark(context);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isStarter
                              ? Colors.orange.withValues(alpha: 0.5)
                              : AppColors.emerald(context).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : const Color(0x060F172A),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isStarter
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : AppColors.emeraldBg(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isStarter ? Icons.rocket_launch_rounded : Icons.workspace_premium_rounded,
                              size: 16,
                              color: isStarter ? Colors.orange : AppColors.emerald(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'Plano: ',
                                  style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
                                ),
                                Text(
                                  planName,
                                  style: TextStyle(
                                    color: AppColors.text(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (occupiedCount >= maxStudents)
                                        ? Colors.redAccent.withValues(alpha: 0.15)
                                        : (isStarter
                                            ? Colors.orange.withValues(alpha: 0.15)
                                            : AppColors.emeraldBg(context)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$occupiedCount / $maxStudents alunos',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: (occupiedCount >= maxStudents)
                                          ? Colors.redAccent
                                          : (isStarter ? Colors.orange : AppColors.emerald(context)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Planos',
                                style: TextStyle(
                                  color: AppColors.emerald(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right, size: 16, color: AppColors.emerald(context)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // KPI Summary Cards
            Row(
              children: [
                _buildKpiCard(
                  label: 'TOTAL ALUNOS',
                  value: '$totalCount',
                  icon: Icons.people_outline,
                  color: AppColors.emerald(context),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'ATIVOS',
                  value: '$activeCount',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.accentBlue(context),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'CONVITES',
                  value: '$pendingCount',
                  icon: Icons.mark_email_unread_outlined,
                  color: AppColors.subtext(context),
                ),
                const SizedBox(width: 8),
                _buildKpiCard(
                  label: 'ALERTAS',
                  value: '$alertsCount',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.tangerine(context),
                  hasAlert: alertsCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              style: TextStyle(color: AppColors.text(context)),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Buscar aluno por nome...',
                hintStyle: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AppColors.subtext(context), size: 20),
                filled: true,
                fillColor: AppColors.card(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cardBorder(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cardBorder(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.emerald(context), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips (Todos, Ativos, Convidados, Arquivados, Com Alerta)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos ($totalCount)', isSelected: _selectedFilter == 'Todos', onTap: () => setState(() => _selectedFilter = 'Todos')),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ativos ($activeCount)', isSelected: _selectedFilter == 'Ativos', onTap: () => setState(() => _selectedFilter = 'Ativos')),
                  const SizedBox(width: 8),
                  _buildFilterChip('Convidados ($pendingCount)', isSelected: _selectedFilter == 'Convidados', onTap: () => setState(() => _selectedFilter = 'Convidados')),
                  const SizedBox(width: 8),
                  _buildFilterChip('Arquivados ($archivedCount)', isSelected: _selectedFilter == 'Arquivados', onTap: () => setState(() => _selectedFilter = 'Arquivados')),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Com Alerta ($alertsCount)',
                    isSelected: _selectedFilter == 'Com Alerta',
                    alertDot: alertsCount > 0,
                    onTap: () => setState(() => _selectedFilter = 'Com Alerta'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Students List
            if (filteredStudents.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: AppColors.subtext(context)),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum aluno encontrado neste filtro.',
                      style: TextStyle(color: AppColors.subtext(context), fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ...filteredStudents.map((st) => _buildStudentCard(st)),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool hasAlert = false,
  }) {
    final isDark = AppColors.isDark(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasAlert ? color.withValues(alpha: 0.7) : AppColors.cardBorder(context),
            width: hasAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0x060F172A),
              blurRadius: 14,
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
                Icon(icon, color: color, size: 18),
                if (hasAlert)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.text(context),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.subtext(context),
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    required bool isSelected,
    bool alertDot = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emeraldBg(context) : AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.emerald(context) : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alertDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.emerald(context) : AppColors.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isDark = AppColors.isDark(context);
    final hasAlert = student['has_alert'] == true;
    final fullName = student['full_name'] as String? ?? 'Aluno';
    final initials = fullName.isNotEmpty ? fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join() : 'AL';
    final status = student['status'] as String? ?? 'Ativo';
    final isPending = status.toLowerCase().contains('pendente');
    final isArchived = status.toLowerCase().contains('arquivado');

    Color statusBg = AppColors.emeraldBg(context);
    Color statusColor = AppColors.emerald(context);
    if (isPending) {
      statusBg = AppColors.tangerineBg(context);
      statusColor = AppColors.tangerine(context);
    } else if (isArchived) {
      statusBg = AppColors.pillBg(context);
      statusColor = AppColors.subtext(context);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAlert ? AppColors.tangerine(context) : AppColors.cardBorder(context),
          width: hasAlert ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x060F172A),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initials Circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isArchived ? AppColors.pillBg(context) : AppColors.emeraldBg(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                          decoration: isArchived ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student['goal']} • ${student['email']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subtext(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Menu de Opções (Editar, Arquivar, Excluir)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: AppColors.subtext(context)),
                  color: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.cardBorder(context)),
                  ),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditStudentDialog(student);
                    } else if (val == 'archive') {
                      _toggleArchiveStudent(student);
                    } else if (val == 'delete') {
                      _confirmDeleteStudent(student);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppColors.text(context)),
                          const SizedBox(width: 10),
                          Text('Editar Aluno', style: TextStyle(color: AppColors.text(context), fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 16, color: AppColors.text(context)),
                          const SizedBox(width: 10),
                          Text(isArchived ? 'Reativar Aluno' : 'Arquivar Aluno', style: TextStyle(color: AppColors.text(context), fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Excluir Aluno', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Alerta Biomecânico Presencial (Dor Articular ou Troca de Exercício)
            if (hasAlert && student['alert_message'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tangerineBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.tangerine(context).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppColors.tangerine(context), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            student['alert_message'] as String,
                            style: TextStyle(
                              color: AppColors.tangerine(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: AppColors.card(context),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.check_circle_outline, size: 14, color: AppColors.emerald(context)),
                          label: Text(
                            'Marcar como Ciente',
                            style: TextStyle(color: AppColors.emerald(context), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _acknowledgeStudentAlert(student),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Linha com Último Treino e Restrições
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.pillBg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.accentBlue(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${student['active_split']} • ${student['last_session']}',
                      style: TextStyle(color: AppColors.text(context), fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (student['injuries_or_restrictions'] != null && (student['injuries_or_restrictions'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.medical_information_outlined, size: 13, color: AppColors.subtext(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Restrições: ${student['injuries_or_restrictions']}',
                      style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            Divider(color: AppColors.cardBorder(context), height: 1),
            const SizedBox(height: 8),

            // Footer com Botões de Ação Direta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ação: WhatsApp Direto
                TextButton.icon(
                  icon: const Icon(Icons.chat_rounded, size: 15, color: Colors.green),
                  label: const Text(
                    'WhatsApp',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _openWhatsApp(student),
                ),
                // Ação: Prescrição / Nova Ficha IA
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text(
                    'Prescrição IA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () {
                    final studentId = student['id'] as String;
                    if (widget.onSelectStudentForPlan != null) {
                      widget.onSelectStudentForPlan!(studentId, fullName);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrainerAnamnesisScreen(
                            initialStudentId: studentId,
                            initialStudentName: fullName,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
