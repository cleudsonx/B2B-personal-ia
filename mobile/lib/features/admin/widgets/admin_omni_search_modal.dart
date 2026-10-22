import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_data_service.dart';

/// Modal estilo Command Palette (Ctrl+K) para o Mission Control do Admin
class AdminOmniSearchModal extends StatefulWidget {
  final ValueChanged<int> onNavigateToSection;
  final VoidCallback onOpenDatabaseExplorer;
  final VoidCallback onOpenWebhookReprocess;
  final Function(String role) onViewAsRole;

  const AdminOmniSearchModal({
    super.key,
    required this.onNavigateToSection,
    required this.onOpenDatabaseExplorer,
    required this.onOpenWebhookReprocess,
    required this.onViewAsRole,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<int> onNavigateToSection,
    required VoidCallback onOpenDatabaseExplorer,
    required VoidCallback onOpenWebhookReprocess,
    required Function(String role) onViewAsRole,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => AdminOmniSearchModal(
        onNavigateToSection: onNavigateToSection,
        onOpenDatabaseExplorer: onOpenDatabaseExplorer,
        onOpenWebhookReprocess: onOpenWebhookReprocess,
        onViewAsRole: onViewAsRole,
      ),
    );
  }

  @override
  State<AdminOmniSearchModal> createState() => _AdminOmniSearchModalState();
}

class _AdminOmniSearchModalState extends State<AdminOmniSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<AdminUserProfile> _allUsers = [];
  bool _isLoadingUsers = true;
  String _query = '';

  static const List<Map<String, dynamic>> _sections = [
    {'index': 0, 'title': 'Pulse & Métricas em Tempo Real', 'category': 'Módulos', 'icon': Icons.insights_rounded, 'badge': 'LIVE'},
    {'index': 1, 'title': 'Gestão de Usuários & Personals (God Mode)', 'category': 'Módulos', 'icon': Icons.people_alt_rounded, 'badge': 'USUÁRIOS'},
    {'index': 2, 'title': 'Financeiro, Splits Asaas & Extrato Pix', 'category': 'Módulos', 'icon': Icons.account_balance_wallet_rounded, 'badge': 'RECEITA'},
    {'index': 3, 'title': 'Catálogo Canônico de Exercícios', 'category': 'Módulos', 'icon': Icons.fitness_center_rounded, 'badge': 'EXERCÍCIOS'},
    {'index': 4, 'title': 'Auditoria de Sessões & Radar de Ameaças', 'category': 'Módulos', 'icon': Icons.security_rounded, 'badge': 'SEGURANÇA'},
    {'index': 5, 'title': 'Central de Broadcast & Push em Massa', 'category': 'Módulos', 'icon': Icons.campaign_rounded, 'badge': 'COMUNICAÇÃO'},
    {'index': 6, 'title': 'Radar Preditivo de Churn B2B & Retenção', 'category': 'Módulos', 'icon': Icons.radar_rounded, 'badge': 'CHURN'},
    {'index': 7, 'title': 'Status de Conexão WhatsApp & Evolution', 'category': 'Módulos', 'icon': Icons.chat_rounded, 'badge': 'HEALTH'},
    {'index': 8, 'title': 'Monitor de Custos de IA & Tokens Gemini', 'category': 'Módulos', 'icon': Icons.psychology_rounded, 'badge': 'TOKENS'},
    {'index': 9, 'title': 'Simulador de Margem, LTV/CAC & Runway', 'category': 'Módulos', 'icon': Icons.calculate_rounded, 'badge': 'FORECAST'},
    {'index': 10, 'title': 'Gestão Dinâmica de Preços & Planos SaaS', 'category': 'Módulos', 'icon': Icons.sell_rounded, 'badge': 'PRICING'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await AdminDataService.getUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanQ = _query.trim().toLowerCase();

    // Filtra Seções
    final filteredSections = _sections.where((s) {
      if (cleanQ.isEmpty) return true;
      final title = s['title'].toString().toLowerCase();
      final badge = s['badge'].toString().toLowerCase();
      return title.contains(cleanQ) || badge.contains(cleanQ);
    }).toList();

    // Filtra Usuários
    final filteredUsers = _allUsers.where((u) {
      if (cleanQ.isEmpty) return false;
      final name = u.name.toLowerCase();
      final email = (u.email ?? '').toLowerCase();
      final role = u.role.toLowerCase();
      return name.contains(cleanQ) || email.contains(cleanQ) || role.contains(cleanQ);
    }).take(6).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF374151), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF818CF8), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Buscar telas, alunos, comandos (ou digite ?)...',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _query = val),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF374151)),
                        ),
                        child: const Text(
                          'ESC',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1F2937), height: 1),
                if (_isLoadingUsers)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF818CF8)),
                  ),

                // Lista de Resultados
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      // Seção de Ações de Poder
                      if (cleanQ.isEmpty || 'modo espelho view as aluno professor'.contains(cleanQ)) ...[
                        _buildCategoryHeader('AÇÕES RÁPIDAS & SIMULAÇÃO'),
                        _buildActionTile(
                          icon: Icons.visibility_rounded,
                          title: 'Modo Espelho: Ver como Aluno (View As)',
                          subtitle: 'Simula a interface exata do aplicativo do aluno',
                          badge: 'VIEW AS',
                          badgeColor: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onViewAsRole('student');
                          },
                        ),
                        _buildActionTile(
                          icon: Icons.sports_gymnastics_rounded,
                          title: 'Modo Espelho: Ver como Treinador (View As)',
                          subtitle: 'Simula a cockpit do personal trainer com alunos e fichas',
                          badge: 'VIEW AS',
                          badgeColor: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onViewAsRole('trainer');
                          },
                        ),
                        _buildActionTile(
                          icon: Icons.storage_rounded,
                          title: 'Explorador Seguro de Banco de Dados',
                          subtitle: 'Inspecione tabelas do Supabase (profiles, workouts, loads)',
                          badge: 'DATABASE',
                          badgeColor: const Color(0xFF818CF8),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenDatabaseExplorer();
                          },
                        ),
                        _buildActionTile(
                          icon: Icons.bolt_rounded,
                          title: 'Reprocessamento & Diagnóstico de Webhooks Asaas',
                          subtitle: 'Simule eventos PAYMENT_RECEIVED com teste de idempotência',
                          badge: 'WEBHOOK',
                          badgeColor: const Color(0xFFEC4899),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenWebhookReprocess();
                          },
                        ),
                      ],

                      // Usuários Encontrados
                      if (filteredUsers.isNotEmpty) ...[
                        _buildCategoryHeader('USUÁRIOS & CONTAS (${filteredUsers.length})'),
                        ...filteredUsers.map((u) => _buildUserTile(u)),
                      ],

                      // Módulos do Admin
                      if (filteredSections.isNotEmpty) ...[
                        _buildCategoryHeader('MÓDULOS DO MISSION CONTROL'),
                        ...filteredSections.map((s) => _buildSectionTile(s)),
                      ],
                    ],
                  ),
                ),

                // Rodapé com atalhos de teclado
                const Divider(color: Color(0xFF1F2937), height: 1),
                if (_isLoadingUsers)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF818CF8)),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Navegue com setas ou toque para selecionar',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ctrl + K',
                        style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: badgeColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          badge,
          style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionTile(Map<String, dynamic> section) {
    final idx = section['index'] as int;
    final title = section['title'] as String;
    final icon = section['icon'] as IconData;
    final badge = section['badge'] as String;

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF818CF8), size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          badge,
          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        widget.onNavigateToSection(idx);
      },
    );
  }

  Widget _buildUserTile(AdminUserProfile user) {
    final isTrainer = user.role == 'trainer';
    final color = isTrainer ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: color.withValues(alpha: 0.2),
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${user.email ?? "Sem email"} • ${user.role.toUpperCase()}',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12),
      onTap: () {
        Navigator.pop(context);
        // Navega para aba de usuários
        widget.onNavigateToSection(1);
      },
    );
  }
}
