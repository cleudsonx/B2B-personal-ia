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
          // Merge or load real DB records
          _students = dbStudents.map((st) {
            return {
              'id': st['id'] ?? 'db-id',
              'full_name': st['full_name'] ?? 'Aluno',
              'goal': 'Consultoria Ativa',
              'level': 'Ativo',
              'days_per_week': 4,
              'has_alert': false,
              'alert_message': null,
              'status': 'Ativo',
              'last_session': 'Sincronizado',
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
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String goal = 'Hipertrofia Muscular';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.trainerSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.trainerBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined, color: AppColors.trainerEmerald),
              SizedBox(width: 10),
              Text(
                'Novo Aluno',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nome Completo do Aluno',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.trainerSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'WhatsApp / Telefone',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.trainerSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: goal,
                dropdownColor: AppColors.trainerSurfaceElevated,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Objetivo Inicial',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.trainerSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => goal = val!,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.trainerEmerald,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _students.insert(0, {
                      'id': 'st-${DateTime.now().millisecondsSinceEpoch}',
                      'full_name': nameCtrl.text.trim(),
                      'goal': goal,
                      'level': 'Iniciante',
                      'days_per_week': 3,
                      'has_alert': false,
                      'alert_message': null,
                      'status': 'Novo',
                      'last_session': 'Aguardando 1º treino',
                      'active_split': 'Sem ficha ativa',
                    });
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text('Aluno "${nameCtrl.text.trim()}" cadastrado com sucesso!'),
                    ),
                  );
                }
              },
              child: const Text('Salvar Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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
      backgroundColor: AppColors.trainerBg,
      appBar: AppBar(
        title: const Text('Painel do Treinador'),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.trainerEmerald,
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar Alunos',
            onPressed: _loadStudentsFromDb,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.trainerEmerald,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo Aluno', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStudentDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudentsFromDb,
        color: AppColors.trainerEmerald,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI Summary Cards
            Row(
              children: [
                _buildKpiCard(
                  label: 'TOTAL ALUNOS',
                  value: '${_students.length}',
                  icon: Icons.people_outline,
                  color: AppColors.trainerEmerald,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  label: 'TREINARAM HOJE',
                  value: '2',
                  icon: Icons.fitness_center_rounded,
                  color: AppColors.trainerIndigo,
                ),
                const SizedBox(width: 10),
                _buildKpiCard(
                  label: 'ADAPTAÇÕES IA',
                  value: '$alertsCount',
                  icon: Icons.bolt,
                  color: AppColors.studentAmber,
                  hasAlert: alertsCount > 0,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Buscar aluno por nome...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                filled: true,
                fillColor: AppColors.trainerSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.trainerBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.trainerBorder),
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
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum aluno encontrado.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.trainerSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlert ? color.withValues(alpha: 0.6) : AppColors.trainerBorder,
            width: hasAlert ? 1.5 : 1.0,
          ),
          boxShadow: hasAlert
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)]
              : null,
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
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
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
          color: isSelected ? AppColors.trainerEmerald.withValues(alpha: 0.15) : AppColors.trainerSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.trainerEmerald : AppColors.trainerBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alertDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.studentAmber, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.trainerEmerald : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final fullName = student['full_name'] as String;
    final initials = fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();
    final hasAlert = student['has_alert'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.trainerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAlert ? AppColors.studentAmber.withValues(alpha: 0.5) : AppColors.trainerBorder,
          width: hasAlert ? 1.5 : 1.0,
        ),
        boxShadow: hasAlert
            ? [BoxShadow(color: AppColors.studentAmberGlow.withValues(alpha: 0.15), blurRadius: 12)]
            : null,
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
                      colors: [Color(0xFF1E3260), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student['goal']} • ${student['level']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.trainerEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.trainerEmerald.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    student['status'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.trainerEmerald,
                    ),
                  ),
                ),
              ],
            ),

            // Alert Box (if student requested exercise adaptation)
            if (hasAlert && student['alert_message'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.studentAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.studentAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: AppColors.studentAmber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        student['alert_message'] as String,
                        style: const TextStyle(
                          color: AppColors.studentAmber,
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
            const Divider(color: AppColors.trainerBorder, height: 1),
            const SizedBox(height: 10),

            // Footer with Active Split & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student['last_session'] as String,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action: Gerar Nova Ficha IA
                TextButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 15, color: AppColors.trainerEmerald),
                  label: const Text(
                    'Nova Ficha IA',
                    style: TextStyle(
                      color: AppColors.trainerEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainerAnamnesisScreen(),
                      ),
                    );
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
