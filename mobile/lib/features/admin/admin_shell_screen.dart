import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../core/utils/currency_pt_br_formatter.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../core/widgets/app_version_footer.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_finance_screen.dart';
import 'screens/admin_exercises_screen.dart';
import 'screens/admin_audit_screen.dart';
import 'screens/admin_broadcast_screen.dart';
import 'screens/admin_retention_screen.dart';
import 'screens/admin_whatsapp_screen.dart';
import 'screens/admin_ai_usage_screen.dart';
import 'screens/admin_simulator_screen.dart';
import 'screens/admin_pricing_manager_screen.dart';
import 'tabs/public_funnel_tab.dart';
import 'widgets/admin_omni_search_modal.dart';
import 'widgets/admin_database_explorer_modal.dart';
import 'widgets/admin_webhook_reprocess_modal.dart';
import 'widgets/admin_access_guard.dart';
import '../trainer/presentation/screens/trainer_main_layout.dart';
import '../../main.dart';

class AdminShellScreen extends StatefulWidget {
  final VoidCallback onExitAdmin;
  final bool isHqMode;

  const AdminShellScreen({
    super.key,
    required this.onExitAdmin,
    this.isHqMode = false,
  });

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _SaaSPortfolioItem {
  final String id;
  final String name;
  final String category;
  final String status;
  final Color statusColor;
  final IconData icon;
  final double mrr;
  final String description;

  const _SaaSPortfolioItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.mrr,
    required this.description,
  });
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int _currentSectionIndex = 0;
  String? _mirrorRole; // 'client' ou 'trainer'
  late bool _isHqView;
  String _selectedSaaS = 'mr_coach';
  String _currentRbacRole = 'CEO_FOUNDER';

  static const List<_SaaSPortfolioItem> _portfolio = [
    _SaaSPortfolioItem(
      id: 'mr_coach',
      name: 'Mr. Coach AI',
      category: 'Flagship B2B/B2C Fitness',
      status: 'PRODUÇÃO • 94% RETENÇÃO',
      statusColor: MetaColors.emerald,
      icon: Icons.fitness_center_rounded,
      mrr: 48750.0,
      description: 'Prescrição biomecânica inteligente, split Asaas 95/5 e retenção de alunos.',
    ),
    _SaaSPortfolioItem(
      id: 'nutri_ia',
      name: 'Nutri-IA Shaipados',
      category: 'Nutrição Computacional',
      status: 'INCUBAÇÃO • BETA Q1/27',
      statusColor: Color(0xFF06B6D4),
      icon: Icons.restaurant_rounded,
      mrr: 0.0,
      description: 'Planejamento de macros e cardápios dinâmicos integrados à rotina de treinos.',
    ),
    _SaaSPortfolioItem(
      id: 'studio_box',
      name: 'Studio Box Cloud',
      category: 'Gestão CrossFit & Studios',
      status: 'ROADMAP • PLANEJADO',
      statusColor: Color(0xFFF59E0B),
      icon: Icons.domain_rounded,
      mrr: 0.0,
      description: 'Controle de check-ins, WODs, planos recorrentes e faturamento de boxes.',
    ),
    _SaaSPortfolioItem(
      id: 'shaipados_core',
      name: 'Shaipados Hub Core',
      category: 'Matriz Venture Builder & APIs',
      status: 'INFRAESTRUTURA CENTRAL',
      statusColor: Color(0xFF818CF8),
      icon: Icons.hub_rounded,
      mrr: 48750.0,
      description: 'Serviços centrais: Evolution WhatsApp, FastAPI no Render, Supabase e Gateway Pix.',
    ),
  ];

  static const Map<String, String> _rbacRoles = {
    'CEO_FOUNDER': 'Nível 1 • CEO / Founder (Prof. Cleudson)',
    'CFO_FINANCE': 'Nível 2 • CFO / Diretoria Financeira',
    'CMO_GROWTH': 'Nível 3 • CMO / Growth & Marketing',
    'CTO_SRE_SUPPORT': 'Nível 4 • CTO / SRE & Engenharia',
  };

  void _openOmniSearch() {
    AdminOmniSearchModal.show(
      context,
      onNavigateToSection: (idx) {
        setState(() {
          _mirrorRole = null;
          _currentSectionIndex = idx;
        });
      },
      onOpenDatabaseExplorer: () => AdminDatabaseExplorerModal.show(context),
      onOpenWebhookReprocess: () => AdminWebhookReprocessModal.show(context),
      onViewAsRole: (role) {
        setState(() => _mirrorRole = role);
      },
    );
  }

  void _openDatabaseExplorer() {
    AdminDatabaseExplorerModal.show(context);
  }

  void _openWebhookReprocess() {
    AdminWebhookReprocessModal.show(context);
  }

  @override
  void initState() {
    super.initState();
    _isHqView = widget.isHqMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppVersionFooter.checkAndShowAutoModal(context, roleOverride: 'admin');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminAccessGuard(
      onExitAdmin: widget.onExitAdmin,
      child: _buildProtectedShell(context),
    );
  }

  Widget _buildProtectedShell(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 900;
    if (_mirrorRole != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayFor(isDark: true),
        child: Scaffold(
          backgroundColor: const Color(0xFF090D16),
          body: Column(
            children: [
              Container(
                color: const Color(0xFFD97706),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'MODO ESPELHO ATIVO — Visualizando como ${_mirrorRole == "trainer" ? "Treinador / Personal" : "Aluno / Cliente"}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _mirrorRole = null),
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Voltar ao Admin',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _mirrorRole == 'trainer'
                    ? const TrainerMainLayout()
                    : const MainShellScreen(
                        initialIndex: 0,
                        activeRole: 'client',
                        userName: 'Aluno (Modo Espelho)',
                      ),
              ),
            ],
          ),
        ),
      );
    }


    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
    final barBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _openOmniSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openOmniSearch,
      },
      child: Focus(
        autofocus: true,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemUiOverlayFor(isDark: isDark),
          child: Scaffold(
      backgroundColor: bg,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: barBg,
              elevation: 0,
              titleSpacing: 8,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_isHqView ? '🏛️' : '⚡', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _isHqView ? 'Shaipados HQ' : 'Mr. Coach',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (_isHqView) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _currentRbacRole.split('_').first,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _isHqView ? 'Alternar para Visão Operacional' : 'Alternar para Visão Executiva HQ',
                  icon: Icon(
                    _isHqView ? Icons.business_center_rounded : Icons.account_balance_rounded,
                    color: const Color(0xFF818CF8),
                  ),
                  onPressed: () => setState(() => _isHqView = !_isHqView),
                ),
                const ThemeToggleButton(compact: true),
                IconButton(
                  tooltip: 'Buscar comando (Ctrl+K)',
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                  onPressed: _openOmniSearch,
                ),
                IconButton(
                  tooltip: 'Sair do Admin',
                  icon: const Icon(Icons.exit_to_app_rounded, size: 20, color: Color(0xFF818CF8)),
                  onPressed: widget.onExitAdmin,
                ),
                const SizedBox(width: 4),
              ],
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                if (_isHqView) _buildHqTopBanner(isDark),
                Expanded(child: _buildCurrentSection()),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
              indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
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
        ),
      ),
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
          onNavigateToAiUsage: () => setState(() => _currentSectionIndex = 8),
          onNavigateToSimulator: () => setState(() => _currentSectionIndex = 9),
        );
      case 1:
        return const AdminUsersScreen();
      case 2:
        return AdminFinanceScreen(
          onNavigateToSimulator: () => setState(() => _currentSectionIndex = 9),
        );
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
      case 8:
        return const AdminAiUsageScreen();
      case 9:
        return AdminSimulatorScreen(
          onNavigateToPricingManager: () => setState(() => _currentSectionIndex = 10),
        );
      case 10:
        return AdminPricingManagerScreen(
          onNavigateToSimulator: () => setState(() => _currentSectionIndex = 9),
        );
      case 11:
        return AdminPublicFunnelTab(
          onNavigateToAffiliates: () => setState(() => _currentSectionIndex = 10),
        );
      default:
        return AdminDashboardScreen(
          onNavigateToUsers: () => setState(() => _currentSectionIndex = 1),
          onNavigateToFinance: () => setState(() => _currentSectionIndex = 2),
          onNavigateToExercises: () => setState(() => _currentSectionIndex = 3),
          onNavigateToRetention: () => setState(() => _currentSectionIndex = 6),
          onNavigateToWhatsApp: () => setState(() => _currentSectionIndex = 7),
          onNavigateToAiUsage: () => setState(() => _currentSectionIndex = 8),
          onNavigateToSimulator: () => setState(() => _currentSectionIndex = 9),
        );
    }
  }

  Widget _buildHqMetricPill(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildHqTopBanner(bool isDark) {
    final currentSaaS = _portfolio.firstWhere(
      (s) => s.id == _selectedSaaS,
      orElse: () => _portfolio.first,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: Contexto do SaaS selecionado & Role
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: currentSaaS.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(currentSaaS.icon, size: 16, color: currentSaaS.statusColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PORTFÓLIO: ${currentSaaS.name.toUpperCase()}',
                    style: TextStyle(
                      color: currentSaaS.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: currentSaaS.statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentSaaS.status,
                      style: TextStyle(
                        color: currentSaaS.statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Seletor dinâmico de RBAC
                  PopupMenuButton<String>(
                    tooltip: 'Alterar Nível de Permissão RBAC',
                    initialValue: _currentRbacRole,
                    onSelected: (role) => setState(() => _currentRbacRole = role),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            _currentRbacRole,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => _rbacRoles.entries.map((e) {
                      return PopupMenuItem<String>(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentRbacRole == e.key ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha 2: Big Numbers Consolidados da Venture & Health Bar
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildHqMetricPill('MRR CONSOLIDADO', CurrencyPtBrFormatter.format(48750.0), MetaColors.emerald),
                  _buildHqMetricPill('ARR PROJETADO', CurrencyPtBrFormatter.format(585000.0), const Color(0xFF38BDF8)),
                  _buildHqMetricPill('SPLIT 5% TAKE', CurrencyPtBrFormatter.format(2437.5), const Color(0xFF818CF8)),
                  _buildHqMetricPill('CHURN', '2.1% /mês', const Color(0xFF94A3B8)),
                  _buildHqMetricPill('NRR', '118%', MetaColors.emerald),

                  // Health checks
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 7, color: MetaColors.emerald),
                        const SizedBox(width: 5),
                        Text(
                          'Render: 200 OK (140ms) • Supabase: 99.98% • WhatsApp: 3 Instâncias • Gemini: Ativo',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isHqView
                        ? [const Color(0xFF6366F1), const Color(0xFF38BDF8)]
                        : [const Color(0xFF10B981), const Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (_isHqView ? const Color(0xFF6366F1) : MetaColors.emerald).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isHqView ? Icons.account_balance_rounded : Icons.shield_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isHqView ? 'SHAIPADOS HQ' : 'MR. COACH',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _isHqView ? 'War Room Multi-SaaS' : 'Mission Control • Admin',
                      style: TextStyle(
                        color: _isHqView ? const Color(0xFF38BDF8) : const Color(0xFF818CF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Seletor Dropdown de Produto Multi-SaaS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSaaS,
                isExpanded: true,
                dropdownColor: const Color(0xFF111827),
                icon: const Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF818CF8)),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSaaS = val);
                },
                items: _portfolio.map((s) {
                  return DropdownMenuItem<String>(
                    value: s.id,
                    child: Row(
                      children: [
                        Icon(s.icon, size: 14, color: s.statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Botão para alternar entre Visão HQ e Visão Operacional
          InkWell(
            onTap: () => setState(() => _isHqView = !_isHqView),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isHqView
                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHqView
                      ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                      : MetaColors.emerald.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isHqView ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    size: 16,
                    color: _isHqView ? const Color(0xFF818CF8) : MetaColors.emerald,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isHqView ? 'Visão: Venture Builder HQ' : 'Visão: Operacional Mr. Coach',
                      style: TextStyle(
                        color: _isHqView ? const Color(0xFF818CF8) : MetaColors.emerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    final isDark = MetaColors.isDark(context);
    final sidebarBg = isDark ? const Color(0xFF111827) : Colors.white;
    final sidebarBorder = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: sidebarBorder, width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding com Seletor Multi-SaaS
          _buildSidebarHeader(isDark),
          const Divider(color: Color(0xFF1F2937), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: InkWell(
              onTap: _openOmniSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 16, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Comandos... (Ctrl+K)',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: const Text(
                        '⌘K',
                        style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Menu de Navegação Rolável
          Expanded(
            child: SingleChildScrollView(
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
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    index: 8,
                    icon: Icons.psychology_rounded,
                    label: 'Custos IA & Gemini',
                    badge: 'TOKENS',
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    index: 9,
                    icon: Icons.calculate_rounded,
                    label: 'Simulador & Margem',
                    badge: 'UNIT ECON',
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    index: 10,
                    icon: Icons.sell_rounded,
                    label: 'Preços & Planos SaaS',
                    badge: 'PRICING',
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    index: 11,
                    icon: Icons.filter_alt_rounded,
                    label: 'Funil Público & Afiliados',
                    badge: 'NORTH STAR',
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'FERRAMENTAS GOD MODE',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionSidebarItem(
                    icon: Icons.table_chart_rounded,
                    label: 'Explorador de Banco',
                    badge: 'SQL/VIEW',
                    onTap: _openDatabaseExplorer,
                  ),
                  const SizedBox(height: 4),
                  _buildActionSidebarItem(
                    icon: Icons.sync_problem_rounded,
                    label: 'Reprocessar Webhook',
                    badge: 'IDEMPOTENTE',
                    onTap: _openWebhookReprocess,
                  ),
                  const SizedBox(height: 4),
                  _buildActionSidebarItem(
                    icon: Icons.visibility_rounded,
                    label: 'Modo Espelho (View As)',
                    badge: 'ALUNO/COACH',
                    onTap: _openOmniSearch,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

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
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: ThemeToggleButton(),
                      ),
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFF6366F1),
                            child: Text(
                              '⚡',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
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
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const AppVersionFooter(userRole: 'admin', padding: EdgeInsets.only(bottom: 8)),
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

  Widget _buildActionSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
          ],
        ),
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
            ListTile(
              leading: Icon(_isHqView ? Icons.account_balance_rounded : Icons.shield_rounded, color: const Color(0xFF818CF8)),
              title: Text(_isHqView ? 'Shaipados Studio HQ' : 'Mr. Coach Admin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(_isHqView ? 'War Room Multi-SaaS • ${_currentRbacRole.split('_').first}' : 'Mission Control • God Mode', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: IconButton(
                tooltip: 'Alternar Visão HQ / Operacional',
                icon: Icon(_isHqView ? Icons.toggle_on_rounded : Icons.toggle_off_rounded, color: const Color(0xFF818CF8)),
                onPressed: () => setState(() => _isHqView = !_isHqView),
              ),
            ),
            const Divider(color: Color(0xFF1F2937), height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
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
            ListTile(
              leading: const Icon(Icons.psychology_rounded, color: Color(0xFF818CF8)),
              title: const Text('Custos IA & Gemini', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 8,
              onTap: () {
                setState(() => _currentSectionIndex = 8);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate_rounded, color: Color(0xFF10B981)),
              title: const Text('Simulador & Margem', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 9,
              onTap: () {
                setState(() => _currentSectionIndex = 9);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sell_rounded, color: Color(0xFF818CF8)),
              title: const Text('Preços & Planos SaaS', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 10,
              onTap: () {
                setState(() => _currentSectionIndex = 10);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_alt_rounded, color: Color(0xFF818CF8)),
              title: const Text('Funil Público & Afiliados', style: TextStyle(color: Colors.white)),
              selected: _currentSectionIndex == 11,
              onTap: () {
                setState(() => _currentSectionIndex = 11);
                Navigator.pop(context);
              },
            ),
            const Divider(color: Color(0xFF1F2937)),
            ListTile(
              leading: const Icon(Icons.table_chart_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Explorador de Banco', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openDatabaseExplorer();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync_problem_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Reprocessar Webhook', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openWebhookReprocess();
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Modo Espelho / Omni-Search', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openOmniSearch();
              },
            ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1F2937), height: 1),
            const AppVersionFooter(userRole: 'admin', padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
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
