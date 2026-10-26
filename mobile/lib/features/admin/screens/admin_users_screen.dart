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
  String _selectedPlan = 'all';
  String _selectedStatus = 'all';
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
      planFilter: _selectedPlan,
      statusFilter: _selectedStatus,
      searchQuery: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _users = list;
      _isLoading = false;
    });
  }

  int get _totalUsers => _users.length;
  int get _totalTrainers => _users.where((u) => u.role == 'trainer' || u.roles.contains('trainer')).length;
  int get _totalStudents => _users.where((u) => u.role == 'client' || u.role == 'student').length;
  int get _totalVips => _users.where((u) => u.isVip).length;

  void _showGodModeModal(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final isTrainer = user.role == 'trainer' || user.roles.contains('trainer');
    final isStudent = user.role == 'client' || user.role == 'student';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header do Usuário
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: user.isAdmin
                            ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                            : (isTrainer
                                ? Colors.amber.withValues(alpha: 0.2)
                                : MetaColors.emerald.withValues(alpha: 0.2)),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: user.isAdmin
                                ? const Color(0xFF818CF8)
                                : (isTrainer ? Colors.amber : MetaColors.emerald),
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
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
                                Flexible(
                                  child: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isVip) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                    ),
                                    child: const Text(
                                      '★ VIP',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? user.phone ?? user.id,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: user.isSuspended
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: user.isSuspended
                                ? Colors.redAccent.withValues(alpha: 0.4)
                                : MetaColors.emerald.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          user.isSuspended ? 'SUSPENSO' : 'ATIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: user.isSuspended ? Colors.redAccent : MetaColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: border, height: 1),
                  const SizedBox(height: 12),

                  // AÇÕES RÁPIDAS SUPERADMIN (1-Tap Actions: VIP, Downgrade/Upgrade, Excluir)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF818CF8)),
                            const SizedBox(width: 6),
                            Text(
                              'AÇÕES RÁPIDAS SUPERADMIN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (isTrainer) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(
                                    user.isVip ? Icons.star_border_rounded : Icons.star_rounded,
                                    size: 15,
                                    color: Colors.amber,
                                  ),
                                  label: Text(
                                    user.isVip ? 'Desativar VIP' : 'Ativar VIP',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                                    backgroundColor: Colors.amber.withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    final newVip = !user.isVip;
                                    Navigator.pop(ctx);
                                    final ok = await AdminDataService.updateTrainerPlanAndQuota(
                                      userId: user.id,
                                      planName: user.plan,
                                      maxStudents: user.maxStudents ?? 30,
                                      isVip: newVip,
                                    );
                                    if (ok && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: MetaColors.emerald,
                                          content: Text(
                                            newVip ? '✓ VIP Ativado para ${user.name}!' : '✓ VIP Desativado para ${user.name}!',
                                          ),
                                        ),
                                      );
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 15, color: Color(0xFF818CF8)),
                                  label: const Text(
                                    'Virar Aluno',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    side: BorderSide(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                                    backgroundColor: const Color(0xFF818CF8).withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    final ok = await AdminDataService.changeUserRole(user.id, 'client');
                                    if (ok && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: MetaColors.emerald,
                                          content: Text('✓ Downgrade realizado: ${user.name} agora é Aluno.'),
                                        ),
                                      );
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ),
                            ] else if (isStudent) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.sync_alt_rounded, size: 15, color: MetaColors.emerald),
                                  label: const Text(
                                    'Trocar Personal',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: MetaColors.emerald),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    side: BorderSide(color: MetaColors.emerald.withValues(alpha: 0.5)),
                                    backgroundColor: MetaColors.emerald.withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showReassignStudentDialog(user);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 15, color: Colors.amber),
                                  label: const Text(
                                    'Virar Personal',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                                    backgroundColor: Colors.amber.withValues(alpha: 0.08),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    final ok = await AdminDataService.changeUserRole(user.id, 'trainer');
                                    if (ok && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: MetaColors.emerald,
                                          content: Text('✓ Promoção realizada: ${user.name} agora é Personal Trainer!'),
                                        ),
                                      );
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Botão de Exclusão Definitiva (Em destaque no topo do modal)
                        OutlinedButton.icon(
                          key: Key('admin_modal_delete_btn_${user.id}'),
                          icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.redAccent),
                          label: const Text(
                            'Excluir Usuário Definitivamente',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDeleteUserConfirmationDialog(user);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Lista de Ações / Superpoderes
                  Expanded(
                    child: ListView(
                      children: [
                        // Seção 1: Gestão de Planos & Override de Vagas (Trainer)
                        if (isTrainer) ...[
                          _buildSectionTitle('PLANO SAAS & COTA DE VAGAS (OVERRIDE)', Icons.workspace_premium_rounded, Colors.amber),
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Plano Atual: ${user.plan}',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${user.currentStudents} / ${user.maxStudents ?? 30} vagas',
                                      style: TextStyle(
                                        color: Color(0xFF818CF8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SquircleButton(
                                  label: 'Alterar Plano & Cota Livre',
                                  icon: Icons.edit_note_rounded,
                                  isPrimary: true,
                                  backgroundColor: const Color(0xFF6366F1),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showPlanOverrideDialog(user);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Seção 2: Validação & Documento CREF
                        if (isTrainer) ...[
                          _buildSectionTitle('CREF PROFISSIONAL & COMPLIANCE', Icons.badge_rounded, const Color(0xFF818CF8)),
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      user.cref != null && user.cref!.isNotEmpty
                                          ? 'CREF: ${user.cref}'
                                          : 'Nenhum CREF cadastrado',
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: user.isCrefVerified
                                            ? MetaColors.emerald.withValues(alpha: 0.15)
                                            : Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        user.isCrefVerified ? '✓ Verificado' : '⏳ Pendente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: user.isCrefVerified ? MetaColors.emerald : Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.verified_user_rounded, size: 16),
                                  label: const Text('Validar ou Editar CREF'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF818CF8),
                                    side: const BorderSide(color: Color(0xFF818CF8)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showCrefDialog(user);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Seção 3: Reatribuição de Aluno (se Student)
                        if (isStudent) ...[
                          _buildSectionTitle('TREINADOR RESPONSÁVEL & VÍNCULO', Icons.transfer_within_a_station_rounded, MetaColors.emerald),
                          Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Personal Atual: ${user.trainerName ?? 'Sem vínculo'}',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SquircleButton(
                                  label: 'Transferir Aluno para Outro Personal',
                                  icon: Icons.sync_alt_rounded,
                                  isPrimary: true,
                                  backgroundColor: MetaColors.emerald,
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showReassignStudentDialog(user);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Seção 4: Segurança, Roles & Sessões
                        _buildSectionTitle('SEGURANÇA & GOVERNANÇA DE CONTA', Icons.shield_rounded, const Color(0xFFEF4444)),
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                          ),
                          child: Material(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  user.isAdmin
                                      ? Icons.admin_panel_settings_rounded
                                      : Icons.security_rounded,
                                  color: const Color(0xFF818CF8),
                                ),
                                title: Text(
                                  user.isAdmin ? 'Revogar Acesso de Superadmin' : 'Promover a Administrador',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  user.isAdmin
                                      ? 'Remove o acesso ao Mission Control'
                                      : 'Concede controle total ao painel executivo',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
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
                                              : 'Usuário promovido a Superadmin!',
                                        ),
                                      ),
                                    );
                                    _loadUsers();
                                  }
                                },
                              ),
                              Divider(color: border, height: 1),
                              ListTile(
                                leading: Icon(
                                  user.isSuspended
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.block_flipped,
                                  color: user.isSuspended ? MetaColors.emerald : Colors.redAccent,
                                ),
                                title: Text(
                                  user.isSuspended ? 'Reativar Conta do Usuário' : 'Suspender Conta',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: user.isSuspended ? MetaColors.emerald : Colors.redAccent,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  user.isSuspended
                                      ? 'Restaura acesso imediato à plataforma'
                                      : 'Bloqueia login e chamadas da API',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
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
                              Divider(color: border, height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.amber,
                                ),
                                title: Text(
                                  'Revogar Todas as Sessões Ativas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  'Força logout em todos os navegadores e celulares',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final ok = await AdminDataService.revokeUserSessions(user.id);
                                  if (ok && mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        backgroundColor: MetaColors.emerald,
                                        content: Text('✓ Sessões revogadas remotamente com sucesso.'),
                                      ),
                                    );
                                  }
                                },
                              ),
                              Divider(color: border, height: 1),
                              ListTile(
                                leading: Icon(
                                  isTrainer ? Icons.person_pin_circle_rounded : Icons.fitness_center_rounded,
                                  color: isTrainer ? MetaColors.emerald : Colors.amber,
                                ),
                                title: Text(
                                  isTrainer ? 'Fazer Downgrade para Aluno' : 'Promover a Personal Trainer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                subtitle: Text(
                                  isTrainer
                                      ? 'Converte o perfil para Aluno cliente (remove ferramentas SaaS)'
                                      : 'Converte para Personal (habilita prescrições, vitrine e alunos)',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final targetRole = isTrainer ? 'client' : 'trainer';
                                  final ok = await AdminDataService.changeUserRole(user.id, targetRole);
                                  if (ok && mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        backgroundColor: MetaColors.emerald,
                                        content: Text(
                                          isTrainer
                                              ? '✓ Downgrade realizado: ${user.name} agora é Aluno.'
                                              : '✓ Promoção realizada: ${user.name} agora é Personal Trainer!',
                                        ),
                                      ),
                                    );
                                    _loadUsers();
                                  }
                                },
                              ),
                              if (user.email != null && user.email!.isNotEmpty) ...[
                                Divider(color: border, height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  title: Text(
                                    'Enviar Redefinição de Senha',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Dispara e-mail de recuperação para ${user.email}',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final ok = await AdminDataService.sendPasswordResetEmail(user.email!);
                                    if (ok && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          backgroundColor: MetaColors.emerald,
                                          content: Text('✓ Link de redefinição enviado para ${user.email}.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                              if (isStudent && user.trainerId != null) ...[
                                Divider(color: border, height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.link_off_rounded,
                                    color: Colors.orangeAccent,
                                  ),
                                  title: Text(
                                    'Desvincular de Personal Atual',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Remove a associação com ${user.trainerName ?? "o treinador"}',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    final ok = await AdminDataService.unlinkStudentTrainer(user.id);
                                    if (ok && mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          backgroundColor: MetaColors.emerald,
                                          content: Text('✓ Aluno desvinculado com sucesso.'),
                                        ),
                                      );
                                      _loadUsers();
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Seção 5: Zona de Perigo / Exclusão Definitiva
                      _buildSectionTitle('ZONA DE PERIGO (AÇÃO IRREVERSÍVEL)', Icons.warning_amber_rounded, Colors.redAccent),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: Material(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: const Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.redAccent,
                              size: 26,
                            ),
                            title: const Text(
                              'Excluir Usuário Definitivamente',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.redAccent,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: const Text(
                              'Apaga o perfil, credenciais do Supabase Auth e histórico associado',
                              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showDeleteUserConfirmationDialog(user);
                            },
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showPlanOverrideDialog(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    String selectedPlan = user.plan;
    int maxStudents = user.maxStudents ?? 30;
    bool isVip = user.isVip;
    final notesCtrl = TextEditingController(text: user.adminNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: MetaColors.isDark(context) ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: MetaColors.isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Override de Plano & Cota',
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal: ${user.name}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: ['Starter', 'Pro', 'Elite Coach', 'Studio Scale']
                              .contains(selectedPlan)
                          ? selectedPlan
                          : 'Pro',
                      dropdownColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Plano Comercial',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
                    const SizedBox(height: 16),
                    Text(
                      'Cota Personalizada de Vagas: $maxStudents alunos',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: maxStudents.toDouble().clamp(5.0, 300.0),
                      min: 5.0,
                      max: 300.0,
                      divisions: 59,
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: const Color(0xFF334155),
                      label: '$maxStudents vagas',
                      onChanged: (val) {
                        setDlgState(() => maxStudents = val.toInt());
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Cortesia VIP / Parceria Comercial',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Isenta o Personal de cobrança SaaS na plataforma',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      value: isVip,
                      activeThumbColor: Colors.amber,
                      onChanged: (val) => setDlgState(() => isVip = val),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Motivo / Anotações Internas',
                        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await AdminDataService.updateTrainerPlanAndQuota(
                      userId: user.id,
                      planName: selectedPlan,
                      maxStudents: maxStudents,
                      isVip: isVip,
                      adminNotes: notesCtrl.text,
                    );
                    if (ok && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: MetaColors.emerald,
                          content: Text('✓ Plano, cota de vagas e status VIP atualizados com sucesso!'),
                        ),
                      );
                      _loadUsers();
                    }
                  },
                  child: const Text('Salvar Override', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCrefDialog(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    final crefCtrl = TextEditingController(text: user.cref ?? '');
    bool isVerified = user.isCrefVerified;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: MetaColors.isDark(context) ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: MetaColors.isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Icon(Icons.badge_rounded, color: Color(0xFF818CF8)),
                  SizedBox(width: 8),
                  Text(
                    'Validação de CREF',
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: crefCtrl,
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Número do Registro CREF',
                      hintText: 'Ex: 049281-G/SP',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'CREF Verificado & Ativo',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Exibe selo de verificação no perfil público do Personal',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    value: isVerified,
                    activeThumbColor: MetaColors.emerald,
                    onChanged: (val) => setDlgState(() => isVerified = val),
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
                    backgroundColor: const Color(0xFF818CF8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await AdminDataService.updateUserCref(
                      userId: user.id,
                      cref: crefCtrl.text.trim(),
                      isVerified: isVerified,
                    );
                    if (ok && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: MetaColors.emerald,
                          content: Text('✓ Registro de CREF atualizado com sucesso!'),
                        ),
                      );
                      _loadUsers();
                    }
                  },
                  child: const Text('Confirmar CREF', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReassignStudentDialog(AdminUserProfile user) async {
    final messenger = ScaffoldMessenger.of(context);
    final trainers = await AdminDataService.getAllTrainersQuickList();
    if (!mounted) return;

    String? selectedTrainerId = trainers.isNotEmpty ? trainers.first['id'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final targetTrainer = trainers.firstWhere(
              (t) => t['id'] == selectedTrainerId,
              orElse: () => trainers.first,
            );

            return AlertDialog(
              backgroundColor: MetaColors.isDark(context) ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: MetaColors.isDark(context) ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              title: Row(
                children: [
                  Icon(Icons.sync_alt_rounded, color: MetaColors.emerald),
                  SizedBox(width: 8),
                  Text(
                    'Reatribuir Aluno',
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aluno: ${user.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Treinador atual: ${user.trainerName ?? 'Sem vínculo'}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selecione o Novo Treinador:',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTrainerId,
                    dropdownColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: trainers.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['id'] as String,
                        child: Text('${t['name']} (${t['plan']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedTrainerId = val);
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
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (selectedTrainerId != null) {
                      final ok = await AdminDataService.reassignStudent(
                        studentId: user.id,
                        newTrainerId: selectedTrainerId!,
                        newTrainerName: targetTrainer['name'] as String,
                      );
                      if (ok && mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: MetaColors.emerald,
                            content: Text(
                              '✓ Aluno ${user.name} reatribuído com sucesso para ${targetTrainer['name']}.',
                            ),
                          ),
                        );
                        _loadUsers();
                      }
                    }
                  },
                  child: const Text('Transferir Agora', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteUserConfirmationDialog(AdminUserProfile user) {
    final messenger = ScaffoldMessenger.of(context);
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: MetaColors.isDark(context) ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Excluir Definitivamente',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                user.email ?? user.phone ?? user.id,
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Esta ação é IRREVERSÍVEL. Todos os dados associados a esta conta serão removidos permanentemente:',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text('• Perfil no banco de dados e credenciais de acesso', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  Text('• Fichas de treino, sessões gravadas e anamnese', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  Text('• Vínculos ativos e faturas pendentes', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 16),
                  Text(
                    'Deseja mesmo prosseguir com a exclusão?',
                    style: TextStyle(color: MetaColors.isDark(context) ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dlgCtx),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton.icon(
                  icon: isDeleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 16),
                  label: Text(
                    isDeleting ? 'Excluindo...' : 'Sim, Excluir Usuário',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDlgState(() => isDeleting = true);
                          final ok = await AdminDataService.deleteUser(user.id);
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: ok ? MetaColors.emerald : Colors.redAccent,
                                content: Text(
                                  ok
                                      ? '✓ Usuário ${user.name} excluído definitivamente com sucesso.'
                                      : 'Erro ao excluir usuário. Verifique as permissões de Superadmin.',
                                ),
                              ),
                            );
                            _loadUsers();
                          }
                        },
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Bar no Topo
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    title: 'TOTAL USUÁRIOS',
                    value: '$_totalUsers',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF6366F1),
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'TREINADORES',
                    value: '$_totalTrainers',
                    icon: Icons.fitness_center_rounded,
                    color: Colors.amber,
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'ALUNOS',
                    value: '$_totalStudents',
                    icon: Icons.directions_run_rounded,
                    color: MetaColors.emerald,
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'VIP / OVERRIDE',
                    value: '$_totalVips',
                    icon: Icons.star_rounded,
                    color: const Color(0xFFF59E0B),
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Controls: Busca e Filtros
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _loadUsers(),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome, e-mail, telefone, CREF ou plano...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
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
              ],
            ),
            const SizedBox(height: 12),

            // Filtros por Papel e Planos (Chips Horizontais)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRoleFilterChip('all', 'Todos ($_totalUsers)'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('trainer', 'Treinadores ($_totalTrainers)'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('client', 'Alunos ($_totalStudents)'),
                  const SizedBox(width: 8),
                  _buildRoleFilterChip('admin', 'Administradores ⚡'),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: borderColor),
                  const SizedBox(width: 16),
                  _buildPlanFilterChip('all', 'Todos Planos'),
                  const SizedBox(width: 8),
                  _buildPlanFilterChip('starter', 'Starter'),
                  const SizedBox(width: 8),
                  _buildPlanFilterChip('pro', 'Pro'),
                  const SizedBox(width: 8),
                  _buildPlanFilterChip('elite coach', 'Elite'),
                  const SizedBox(width: 8),
                  _buildPlanFilterChip('studio scale', 'Studio'),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 24, color: borderColor),
                  const SizedBox(width: 16),
                  _buildStatusFilterChip('all', 'Todos Status'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('active', 'Ativos'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('suspended', 'Suspensos'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('vip', 'VIP / Parceria'),
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
                            final isStudent = u.role == 'client' || u.role == 'student';

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showGodModeModal(u),
                                child: Container(
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
                                                Flexible(
                                                  child: Text(
                                                    u.name,
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (u.isAdmin) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'ADMIN',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF818CF8),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (u.isVip) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      '★ VIP',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              u.email ?? u.phone ?? 'Sem contato',
                                              style: TextStyle(fontSize: 11.5, color: textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                                if (isTrainer && u.maxStudents != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${u.currentStudents}/${u.maxStudents} vagas',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF818CF8),
                                                    ),
                                                  ),
                                                ],
                                                if (isTrainer && u.cref != null && u.cref!.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'CREF ${u.cref}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: u.isCrefVerified ? MetaColors.emerald : Colors.amber,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                                if (isStudent && u.trainerName != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Personal: ${u.trainerName}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: MetaColors.emerald,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        key: Key('admin_user_action_${u.id}'),
                                        icon: const Icon(Icons.tune_rounded),
                                        tooltip: 'Superpoderes (God Mode)',
                                        color: const Color(0xFF818CF8),
                                        onPressed: () => _showGodModeModal(u),
                                      ),
                                      IconButton(
                                        key: Key('admin_user_delete_direct_${u.id}'),
                                        icon: const Icon(Icons.delete_outline_rounded),
                                        tooltip: 'Excluir definitivamente',
                                        color: Colors.redAccent,
                                        onPressed: () => _showDeleteUserConfirmationDialog(u),
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
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        fontSize: 11.5,
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

  Widget _buildPlanFilterChip(String planKey, String label) {
    final isSelected = _selectedPlan == planKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedPlan = planKey);
        _loadUsers();
      },
      selectedColor: Colors.amber.withValues(alpha: 0.2),
      backgroundColor: MetaColors.isDark(context) ? const Color(0xFF111827) : Colors.white,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.amber : Colors.grey,
      ),
      side: BorderSide(
        color: isSelected
            ? Colors.amber.withValues(alpha: 0.6)
            : const Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildStatusFilterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = statusKey);
        _loadUsers();
      },
      selectedColor: MetaColors.emerald.withValues(alpha: 0.2),
      backgroundColor: MetaColors.isDark(context) ? const Color(0xFF111827) : Colors.white,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? MetaColors.emerald : Colors.grey,
      ),
      side: BorderSide(
        color: isSelected
            ? MetaColors.emerald.withValues(alpha: 0.6)
            : const Color(0xFF1F2937),
      ),
    );
  }
}
