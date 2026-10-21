import 'package:flutter/material.dart';
import '../../core/widgets/meta_components.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_finance_screen.dart';
import 'screens/admin_exercises_screen.dart';
import 'screens/admin_audit_screen.dart';
import 'screens/admin_broadcast_screen.dart';
import 'screens/admin_retention_screen.dart';
import 'screens/admin_whatsapp_screen.dart';

class AdminShellScreen extends StatefulWidget {
  final VoidCallback onExitAdmin;

  const AdminShellScreen({
    super.key,
    required this.onExitAdmin,
  });

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentSectionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF111827),
              elevation: 0,
              title: const Row(
                children: [
                  Text('⚡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Mr. Coach • Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: widget.onExitAdmin,
                  icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Color(0xFF818CF8)),
                  label: const Text(
                    'Sair do Admin',
                    style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(),
          Expanded(
            child: _buildCurrentSection(),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              backgroundColor: const Color(0xFF111827),
              indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
              selectedIndex: _currentSectionIndex.clamp(0, 3),
              onDestinationSelected: (idx) {
                setState(() => _currentSectionIndex = idx);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.insights_rounded, color: Colors.grey),
                  selectedIcon: Icon(Icons.insights_rounded, color: Color(0xFF818CF8)),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_alt_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.people_alt_rounded, color: Color(0xFF818CF8)),
                  label: 'Usuários',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF818CF8)),
                  label: 'Financeiro',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined, color: Colors.grey),
                  selectedIcon: Icon(Icons.fitness_center_rounded, color: Color(0xFF818CF8)),
                  label: 'Exercícios',
                ),
              ],
            ),
    );
  }

  Widget _buildCurrentSection() {
    switch (_currentSectionIndex) {
      case 0:
        return AdminDashboardScreen(
          onNavigateToUsers: () => setState(() => _currentSectionIndex = 1),
          onNavigateToFinance: () => setState(() => _currentSectionIndex = 2),
          onNavigateToExercises: () => setState(() => _currentSectionIndex = 3),
          onNavigateToRetention: () => setState(() => _currentSectionIndex = 6),
          onNavigateToWhatsApp: () => setState(() => _currentSectionIndex = 7),
        );
      case 1:
        return const AdminUsersScreen();
      case 2:
        return const AdminFinanceScreen();
      case 3:
        return const AdminExercisesScreen();
      case 4:
        return const AdminAuditScreen();
      case 5:
        return const AdminBroadcastScreen();
      case 6:
        return const AdminRetentionScreen();
      case 7:
        return const AdminWhatsAppScreen();
      default:
        return AdminDashboardScreen(
          onNavigateToUsers: () => setState(() => _currentSectionIndex = 1),
          onNavigateToFinance: () => setState(() => _currentSectionIndex = 2),
          onNavigateToExercises: () => setState(() => _currentSectionIndex = 3),
          onNavigateToRetention: () => setState(() => _currentSectionIndex = 6),
          onNavigateToWhatsApp: () => setState(() => _currentSectionIndex = 7),
        );
    }
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(
          right: BorderSide(color: Color(0xFF1F2937), width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MR. COACH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Mission Control • Admin',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),

          // Menu de Navegação
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildSidebarItem(
                  index: 0,
                  icon: Icons.insights_rounded,
                  label: 'Pulse & Métricas',
                  badge: 'LIVE',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 1,
                  icon: Icons.people_alt_rounded,
                  label: 'Usuários & Personals',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 2,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Financeiro & Splits',
                  badge: '5% TAKE',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 3,
                  icon: Icons.fitness_center_rounded,
                  label: 'Catálogo de Exercícios',
                  badge: 'GLOBAL',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 4,
                  icon: Icons.security_rounded,
                  label: 'Auditoria & Telemetria',
                  badge: 'LOGS',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 5,
                  icon: Icons.campaign_rounded,
                  label: 'Broadcast & Avisos',
                  badge: 'PUSH',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 6,
                  icon: Icons.radar_rounded,
                  label: 'Retenção & Alunos 360°',
                  badge: 'CHURN RADAR',
                ),
                const SizedBox(height: 4),
                _buildSidebarItem(
                  index: 7,
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp & Evolution',
                  badge: 'HEALTH',
                ),
              ],
            ),
          ),

          const Spacer(),

          // Rodapé do Sidebar: Voltar ao App
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF6366F1),
                        child: Text(
                          '⚡',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Acesso SuperAdmin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: widget.onExitAdmin,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF818CF8)),
                  label: const Text(
                    'Voltar ao Modo Padrão',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1F2937)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    String? badge,
  }) {
    final isSelected = _currentSectionIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentSectionIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: MetaColors.emerald,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.shield_rounded, color: Color(0xFF818CF8)),
              title: Text('Mission Control', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('God Mode • Mr. Coach', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const Divider(color: Color(0xFF1F2937)),
            ListTile(
              leading: const Icon(Icons.insights_rounded, color: Color(0xFF818CF8)),
              title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 0,
              onTap: () {
                setState(() => _currentSectionIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF818CF8)),
              title: const Text('Usuários & Personals', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 1,
              onTap: () {
                setState(() => _currentSectionIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF818CF8)),
              title: const Text('Financeiro & Splits', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 2,
              onTap: () {
                setState(() => _currentSectionIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_rounded, color: Color(0xFF818CF8)),
              title: const Text('Catálogo de Exercícios', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 3,
              onTap: () {
                setState(() => _currentSectionIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded, color: Color(0xFF818CF8)),
              title: const Text('Auditoria & Telemetria', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 4,
              onTap: () {
                setState(() => _currentSectionIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign_rounded, color: Color(0xFF818CF8)),
              title: const Text('Broadcast & Avisos', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 5,
              onTap: () {
                setState(() => _currentSectionIndex = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.radar_rounded, color: Color(0xFF818CF8)),
              title: const Text('Retenção & Alunos 360°', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 6,
              onTap: () {
                setState(() => _currentSectionIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: Color(0xFF818CF8)),
              title: const Text('WhatsApp & Evolution', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 7,
              onTap: () {
                setState(() => _currentSectionIndex = 7);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
              title: const Text('Voltar ao App', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                widget.onExitAdmin();
              },
            ),
          ],
        ),
      ),
    );
  }
}
