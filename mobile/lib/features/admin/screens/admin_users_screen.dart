import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  List<AdminUserProfile> _users = [];
  String _selectedRole = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final list = await AdminDataService.getUsers(
      roleFilter: _selectedRole,
      searchQuery: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _users = list;
      _isLoading = false;
    });
  }

  void _showUserActionModal(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Color(0xFF818CF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              user.email ?? user.phone ?? user.id,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Ação 1: Promover ou Revogar Admin
                  ListTile(
                    leading: Icon(
                      user.isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.security_rounded,
                      color: const Color(0xFF818CF8),
                    ),
                    title: Text(
                      user.isAdmin ? 'Revogar Acesso de Admin' : 'Conceder Papel de Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      user.isAdmin
                          ? 'Remove permissões de acesso ao Mission Control'
                          : 'Concede acesso total de gestão ao painel web',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await AdminDataService.setAdminStatus(user.id, !user.isAdmin);
                      if (ok && mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: MetaColors.emerald,
                            content: Text(
                              user.isAdmin
                                  ? 'Acesso de Admin revogado com sucesso.'
                                  : 'Usuário promovido a Administrador!',
                            ),
                          ),
                        );
                        _loadUsers();
                      }
                    },
                  ),

                  // Ação 2: Se for Treinador, Ajustar Plano
                  if (user.role == 'trainer' || user.roles.contains('trainer')) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.amber,
                      ),
                      title: Text(
                        'Ajustar Plano & Vagas (Cota Override)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        'Plano Atual: ${user.plan} (${user.maxStudents ?? 30} alunos)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPlanEditDialog(user);
                      },
                    ),
                  ],

                  // Ação 3: Suspender ou Reativar
                  ListTile(
                    leading: Icon(
                      user.isSuspended
                          ? Icons.check_circle_outline_rounded
                          : Icons.block_flipped,
                      color: user.isSuspended ? MetaColors.emerald : Colors.redAccent,
                    ),
                    title: Text(
                      user.isSuspended ? 'Reativar Conta de Acesso' : 'Suspender Conta',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: user.isSuspended ? MetaColors.emerald : Colors.redAccent,
                        fontSize: 14.5,
                      ),
                    ),
                    subtitle: Text(
                      user.isSuspended
                          ? 'Libera o login e uso imediato do app'
                          : 'Bloqueia temporariamente o acesso do usuário',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await AdminDataService.toggleUserSuspension(
                        user.id,
                        !user.isSuspended,
                      );
                      if (ok && mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: user.isSuspended
                                ? MetaColors.emerald
                                : Colors.redAccent,
                            content: Text(
                              user.isSuspended
                                  ? 'Conta reativada com sucesso.'
                                  : 'Conta suspensa com sucesso.',
                            ),
                          ),
                        );
                        _loadUsers();
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPlanEditDialog(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    String selectedPlan = user.plan;
    int maxStudents = user.maxStudents ?? 30;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              title: const Text(
                'Ajustar Plano do Treinador',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Treinador: ${user.name}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: ['Starter', 'Pro', 'Elite Coach', 'Studio Scale']
                            .contains(selectedPlan)
                        ? selectedPlan
                        : 'Pro',
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Plano SaaS',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Starter', child: Text('Starter (10 Alunos)')),
                      DropdownMenuItem(value: 'Pro', child: Text('Pro (30 Alunos)')),
                      DropdownMenuItem(value: 'Elite Coach', child: Text('Elite Coach (60 Alunos)')),
                      DropdownMenuItem(value: 'Studio Scale', child: Text('Studio Scale (150 Alunos)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() {
                          selectedPlan = val;
                          if (val == 'Starter') maxStudents = 10;
                          if (val == 'Pro') maxStudents = 30;
                          if (val == 'Elite Coach') maxStudents = 60;
                          if (val == 'Studio Scale') maxStudents = 150;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await AdminDataService.updateTrainerPlan(
                      user.id,
                      planName: selectedPlan,
                      maxStudents: maxStudents,
                    );
                    if (ok && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: MetaColors.emerald,
                          content: Text('Plano e cota atualizados com sucesso!'),
                        ),
                      );
                      _loadUsers();
                    }
                  },
                  child: const Text('Salvar Alterações'),
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
    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls: Busca e Filtros
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _loadUsers(),
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, e-mail, telefone...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadUsers();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.filter_list_rounded, size: 18),
                  label: const Text('Filtrar'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filtro por Papel (Segmented Tabs)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRoleFilterChip('all', 'Todos (${_users.length})'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('trainer', 'Treinadores'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('client', 'Alunos'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('admin', 'Administradores ⚡'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Usuários
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum usuário encontrado com os filtros atuais.',
                            style: TextStyle(color: textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final u = _users[index];
                            final isTrainer = u.role == 'trainer' || u.roles.contains('trainer');

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: u.isAdmin
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                      : borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: u.isAdmin
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                        : (isTrainer
                                            ? Colors.amber.withValues(alpha: 0.15)
                                            : MetaColors.emerald.withValues(alpha: 0.15)),
                                    child: Text(
                                      u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        color: u.isAdmin
                                            ? const Color(0xFF818CF8)
                                            : (isTrainer ? Colors.amber : MetaColors.emerald),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              u.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            if (u.isAdmin) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'ADMIN',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF818CF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          u.email ?? u.phone ?? 'Sem contato cadastrado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: borderColor.withValues(alpha: 0.5),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isTrainer ? 'Personal • ${u.plan}' : 'Aluno',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ),
                                            if (u.cref != null && u.cref!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                'CREF ${u.cref}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: MetaColors.emerald,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_vert_rounded),
                                    color: textSecondary,
                                    onPressed: () => _showUserActionModal(u),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleFilterChip(String roleKey, String label) {
    final isSelected = _selectedRole == roleKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedRole = roleKey);
        _loadUsers();
      },
      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
      backgroundColor: MetaColors.isDark(context) ? const Color(0xFF111827) : Colors.white,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? const Color(0xFF818CF8) : Colors.grey,
      ),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF6366F1).withValues(alpha: 0.6)
            : const Color(0xFF1F2937),
      ),
    );
  }
}
