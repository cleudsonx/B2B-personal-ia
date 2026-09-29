import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../services/workout_service.dart';
import 'anamnesis_screen.dart';

class TrainerStudentsScreen extends StatefulWidget {
  final Function(String studentId, String studentName)? onSelectStudentForPlan;

  const TrainerStudentsScreen({super.key, this.onSelectStudentForPlan});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  bool _isLoading = false;
  String _selectedFilter = 'Todos';
  String _searchQuery = '';

  // Initial demo students when Supabase has no records or offline
  final List<Map<String, dynamic>> _demoStudents = [
    {
      'id': 'st-1',
      'full_name': 'Rodrigo Silveira',
      'goal': 'Hipertrofia Muscular',
      'level': 'Intermediário',
      'days_per_week': 4,
      'has_alert': true,
      'alert_message': 'Trocou Supino Reto por Supino Máquina (Ombro)',
      'status': 'Ativo',
      'last_session': 'Hoje, 07:45',
      'active_split': 'Treino A - Peito e Tríceps',
    },
    {
      'id': 'st-2',
      'full_name': 'Camila Vasconcelos',
      'goal': 'Emagrecimento & Definição',
      'level': 'Iniciante',
      'days_per_week': 3,
      'has_alert': false,
      'alert_message': null,
      'status': 'Ativo',
      'last_session': 'Hoje, 09:15',
      'active_split': 'Treino B - Membros Inferiores',
    },
    {
      'id': 'st-3',
      'full_name': 'Lucas Andrade Mendes',
      'goal': 'Condicionamento Geral',
      'level': 'Avançado',
      'days_per_week': 5,
      'has_alert': true,
      'alert_message': 'Aparelho Ocupado: Leg Press 45° ➔ Agachamento Goblet',
      'status': 'Ativo',
      'last_session': 'Ontem, 18:30',
      'active_split': 'Treino C - Costas e Bíceps',
    },
    {
      'id': 'st-4',
      'full_name': 'Beatriz Fontes',
      'goal': 'Hipertrofia Glúteos',
      'level': 'Intermediário',
      'days_per_week': 4,
      'has_alert': false,
      'alert_message': null,
      'status': 'Ativo',
      'last_session': '2 dias atrás',
      'active_split': 'Treino A - Inferiores Ênfase Posterior',
    },
  ];

  late List<Map<String, dynamic>> _students;

  @override
  void initState() {
    super.initState();
    _students = List.from(_demoStudents);
    _loadStudentsFromDb();
  }

  Future<void> _loadStudentsFromDb() async {
    setState(() => _isLoading = true);
    try {
      final dbStudents = await WorkoutService.getTrainerStudents();
      if (dbStudents.isNotEmpty && mounted) {
        setState(() {
          _students = dbStudents.map((st) {
            final goal = st['goal'] as String? ?? 'Consultoria Ativa';
            final status = st['status'] as String? ?? 'Ativo';
            return {
              'id': st['id'] ?? 'db-id',
              'full_name': st['full_name'] ?? 'Aluno',
              'email': st['email'] ?? '',
              'phone': st['phone'] ?? '',
              'goal': goal,
              'level': 'Ativo',
              'days_per_week': 4,
              'has_alert': false,
              'alert_message': null,
              'status': status,
              'last_session': status == 'Pendente Confirmação' ? 'Convite enviado' : 'Sincronizado',
              'active_split': 'Periodização Ativa',
            };
          }).toList();
        });
      }
    } catch (_) {
      // Keep demo list gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddStudentDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String goal = 'Hipertrofia Muscular';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
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
                    'Novo Aluno',
                    style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 18),
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
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome completo' : null,
                        decoration: InputDecoration(
                          labelText: 'Nome Completo do Aluno',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.emerald(context), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: AppColors.text(context)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o e-mail do aluno';
                          if (!v.contains('@') || !v.contains('.')) return 'Informe um e-mail válido';
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'E-mail para Acesso e Confirmação',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.emerald(context), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'WhatsApp / Telefone (Opcional)',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.emerald(context), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: goal,
                        dropdownColor: AppColors.card(context),
                        style: TextStyle(color: AppColors.text(context)),
                        decoration: InputDecoration(
                          labelText: 'Objetivo Inicial',
                          labelStyle: TextStyle(color: AppColors.subtext(context)),
                          filled: true,
                          fillColor: AppColors.pillBg(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.cardBorder(context)),
                          ),
                        ),
                        items: ['Hipertrofia Muscular', 'Emagrecimento & Definição', 'Condicionamento Geral', 'Reabilitação Postural']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => goal = val ?? goal,
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
                                  'alert_message': null,
                                  'status': 'Pendente Confirmação',
                                  'last_session': 'Convite enviado',
                                  'active_split': 'Sem ficha ativa',
                                });
                              });

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade800,
                                  content: Text(
                                    'Aluno "${student['full_name']}" cadastrado! Convite e validação enviados para ${student['email']}.',
                                  ),
                                ),
                              );
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
                      : const Text('Salvar Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where((st) {
      final name = (st['full_name'] as String).toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Com Alerta') {
        return st['has_alert'] == true;
      }
      return true;
    }).toList();

    final alertsCount = _students.where((s) => s['has_alert'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Painel do Treinador',
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
            // KPI Summary Cards
            Row(
              children: [
                _buildKpiCard(
                  label: 'TOTAL ALUNOS',
                  value: '${_students.length}',
                  icon: Icons.people_outline,
                  color: AppColors.emerald(context),
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  label: 'TREINARAM HOJE',
                  value: '2',
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.accentBlue(context),
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  label: 'ADAPTAÇÕES IA',
                  value: '$alertsCount',
                  icon: Icons.bolt,
                  color: AppColors.tangerine(context),
                  hasAlert: alertsCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 18),

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
            const SizedBox(height: 14),

            // Filter Chips
            Row(
              children: [
                _buildFilterChip('Todos', isSelected: _selectedFilter == 'Todos'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Com Alerta ($alertsCount)',
                  isSelected: _selectedFilter == 'Com Alerta',
                  alertDot: alertsCount > 0,
                ),
              ],
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
                      'Nenhum aluno encontrado.',
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlert ? color.withValues(alpha: 0.6) : AppColors.cardBorder(context),
            width: hasAlert ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0x060F172A),
              blurRadius: 16,
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
                Icon(icon, color: color, size: 20),
                if (hasAlert)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.subtext(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected, bool alertDot = false}) {
    return InkWell(
      onTap: () => setState(() => _selectedFilter = isSelected && label != 'Todos' ? 'Todos' : (label.contains('Alerta') ? 'Com Alerta' : 'Todos')),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald(context).withValues(alpha: 0.15) : AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.emerald(context) : AppColors.cardBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alertDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: AppColors.tangerine(context), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.emerald(context) : AppColors.subtext(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final isDark = AppColors.isDark(context);
    final fullName = student['full_name'] as String;
    final initials = fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();
    final hasAlert = student['has_alert'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasAlert ? AppColors.tangerine(context).withValues(alpha: 0.6) : AppColors.cardBorder(context),
          width: hasAlert ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x060F172A),
            blurRadius: 18,
            offset: const Offset(0, 5),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
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
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student['goal']} • ${student['level']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill (Ativo vs Pendente Confirmação)
                Builder(
                  builder: (ctx) {
                    final isPending = (student['status'] as String? ?? '').contains('Pendente');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? AppColors.tangerineBg(context) : AppColors.emeraldBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPending
                              ? AppColors.tangerine(context).withValues(alpha: 0.4)
                              : AppColors.emerald(context).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        student['status'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPending ? AppColors.tangerine(context) : AppColors.emerald(context),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Alert Box (if student requested exercise adaptation)
            if (hasAlert && student['alert_message'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tangerineBg(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.tangerine(context).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.tangerine(context), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        student['alert_message'] as String,
                        style: TextStyle(
                          color: AppColors.tangerine(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: AppColors.cardBorder(context), height: 1),
            const SizedBox(height: 10),

            // Footer with Active Split & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppColors.subtext(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student['last_session'] as String,
                          style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Se o aluno estiver pendente de confirmação, exibir ação de reenviar convite
                if ((student['status'] as String? ?? '').contains('Pendente')) ...[
                  TextButton.icon(
                    icon: Icon(Icons.send_rounded, size: 13, color: AppColors.tangerine(context)),
                    label: Text(
                      'Reenviar',
                      style: TextStyle(
                        color: AppColors.tangerine(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      final email = student['email'] ?? student['full_name'];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green.shade800,
                          content: Text('Convite de confirmação reenviado para $email!'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                ],
                // Action: Gerar Nova Ficha IA vinculada diretamente ao aluno
                TextButton.icon(
                  icon: Icon(Icons.auto_awesome, size: 15, color: AppColors.emerald(context)),
                  label: Text(
                    'Nova Ficha IA',
                    style: TextStyle(
                      color: AppColors.emerald(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
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
