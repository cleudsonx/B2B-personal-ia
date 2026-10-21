import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo 5: Auditoria Avançada de Logs, Sessões Ativas & Telemetria IA
class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  List<AdminAuditEntry> _logs = [];
  List<AdminAiUsageStat> _aiStats = [];
  List<AdminServiceHealth> _services = [];
  AdminSecuritySessionsOverview? _securityOverview;
  String _severityFilter = 'all';

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final logsFuture = AdminDataService.getAuditLogs(
      severityFilter: _severityFilter,
      searchQuery: _searchCtrl.text,
    );
    final aiFuture = AdminDataService.getAiUsageStats();
    final healthFuture = AdminDataService.getServicesHealth();
    final secFuture = AdminDataService.getSecuritySessionsOverview();

    final results = await Future.wait([logsFuture, aiFuture, healthFuture, secFuture]);

    if (mounted) {
      setState(() {
        _logs = results[0] as List<AdminAuditEntry>;
        _aiStats = results[1] as List<AdminAiUsageStat>;
        _services = results[2] as List<AdminServiceHealth>;
        _securityOverview = results[3] as AdminSecuritySessionsOverview;
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeSession(AdminActiveSessionItem session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Encerrar Sessão?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja forçar o encerramento da sessão de ${session.userName} no dispositivo ${session.device} (${session.ipAddress})?\nO usuário será desconectado imediatamente.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Encerrar Imediatamente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminDataService.revokeActiveSession(session.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Sessão encerrada com sucesso!' : 'Falha ao encerrar sessão.'),
            backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
          ),
        );
        _loadAll();
      }
    }
  }

  Future<void> _resolveAlert(AdminSecurityAlertItem alert, String action) async {
    final success = await AdminDataService.resolveSecurityAlert(alert.id, action: action);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Medida aplicada com sucesso!' : 'Falha ao aplicar medida.'),
          backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
        ),
      );
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header do Módulo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security_rounded, color: Color(0xFF818CF8), size: 24),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Auditoria, Sessões & Segurança',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Controle de sessões ativas, detecção de acessos concorrentes e telemetria Gemini',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loadAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF818CF8)),
                    label: const Text('Atualizar', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1F2937)),
                      backgroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Barra de 4 Abas
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF6366F1),
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Sessões & Segurança'),
                    Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Logs de Auditoria'),
                    Tab(icon: Icon(Icons.psychology_rounded, size: 18), text: 'Telemetria IA'),
                    Tab(icon: Icon(Icons.speed_rounded, size: 18), text: 'Health Check & Ping'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Conteúdo Dinâmico por Aba
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    switch (_tabController.index) {
                      case 0:
                        return _buildSecuritySessionsTab();
                      case 1:
                        return _buildLogsTab();
                      case 2:
                        return _buildAiTab();
                      case 3:
                        return _buildHealthTab();
                      default:
                        return _buildSecuritySessionsTab();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ABA 0: SESSÕES ATIVAS & SEGURANÇA
  // ==========================================
  Widget _buildSecuritySessionsTab() {
    final overview = _securityOverview;
    final alerts = overview?.securityAlerts ?? [];
    final sessions = overview?.sessions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 4 KPI Cards Responsivos
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            final isTablet = constraints.maxWidth > 550 && !isDesktop;

            final kpi1 = _buildKpiCard(
              title: 'Sessões Ativas',
              value: '${overview?.totalActiveSessions ?? 0}',
              subtitle: 'Dispositivos conectados',
              icon: Icons.devices_rounded,
              accentColor: const Color(0xFF818CF8),
            );
            final kpi2 = _buildKpiCard(
              title: 'Acessos Simultâneos',
              value: '${overview?.simultaneousUsersCount ?? 0}',
              subtitle: 'Contas em múltiplos devices',
              icon: Icons.supervised_user_circle_rounded,
              accentColor: (overview?.simultaneousUsersCount ?? 0) > 0 ? Colors.amber : MetaColors.emerald,
            );
            final kpi3 = _buildKpiCard(
              title: 'Falhas de Login (24h)',
              value: '${overview?.failedLogins24h ?? 0}',
              subtitle: 'Tentativas bloqueadas',
              icon: Icons.gpp_maybe_rounded,
              accentColor: (overview?.failedLogins24h ?? 0) > 5 ? Colors.redAccent : Colors.white70,
            );
            final kpi4 = _buildKpiCard(
              title: 'Alertas de Ameaça',
              value: '${overview?.activeAlertsCount ?? 0}',
              subtitle: 'Requerem atenção imediata',
              icon: Icons.notifications_active_rounded,
              accentColor: (overview?.activeAlertsCount ?? 0) > 0 ? Colors.redAccent : MetaColors.emerald,
            );

            if (isDesktop) {
              return Row(
                children: [
                  Expanded(child: kpi1),
                  const SizedBox(width: 14),
                  Expanded(child: kpi2),
                  const SizedBox(width: 14),
                  Expanded(child: kpi3),
                  const SizedBox(width: 14),
                  Expanded(child: kpi4),
                ],
              );
            } else if (isTablet) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: kpi1),
                      const SizedBox(width: 14),
                      Expanded(child: kpi2),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: kpi3),
                      const SizedBox(width: 14),
                      Expanded(child: kpi4),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  kpi1,
                  const SizedBox(height: 12),
                  kpi2,
                  const SizedBox(height: 12),
                  kpi3,
                  const SizedBox(height: 12),
                  kpi4,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // Radar de Ameaças (se houver alertas)
        if (alerts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1528),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Radar de Incidentes & Ameaças em Tempo Real',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Atividades suspeitas de força bruta, acessos simultâneos ou violações de política',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return _buildThreatAlertCard(alert);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Sessões Ativas Header & Lista
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispositivos & Sessões Conectadas',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Monitoramento de IP, User-Agent, localização e kill-switch imediato',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${sessions.length} ativas',
                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Nenhuma sessão ativa encontrada.', style: TextStyle(color: Colors.white60)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return _buildSessionCard(s);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: accentColor, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatAlertCard(AdminSecurityAlertItem alert) {
    Color sevColor;
    if (alert.severity == 'critical') {
      sevColor = Colors.redAccent;
    } else if (alert.severity == 'high') {
      sevColor = Colors.deepOrangeAccent;
    } else {
      sevColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sevColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: sevColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                alert.timestamp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Usuário: ${alert.targetUser}',
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'IP: ${alert.ipAddress}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'Tentativas: ${alert.attemptsCount}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _resolveAlert(alert, 'block_ip'),
                icon: const Icon(Icons.block_rounded, size: 14),
                label: const Text('Bloquear IP', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _resolveAlert(alert, 'force_reset_pwd'),
                icon: const Icon(Icons.lock_reset_rounded, size: 14),
                label: const Text('Forçar Reset de Senha', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _resolveAlert(alert, 'mark_safe'),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: const Text('Marcar como Seguro', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF374151)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(AdminActiveSessionItem session) {
    IconData devIcon = Icons.laptop_rounded;
    final lowerPlatform = session.platform.toLowerCase();
    if (lowerPlatform.contains('android') || lowerPlatform.contains('ios') || lowerPlatform.contains('mobile')) {
      devIcon = Icons.smartphone_rounded;
    } else if (lowerPlatform.contains('tablet') || lowerPlatform.contains('ipad')) {
      devIcon = Icons.tablet_rounded;
    }

    final isSuspicious = session.status == 'suspicious';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuspicious
              ? Colors.redAccent.withValues(alpha: 0.5)
              : (session.isCurrentSession ? const Color(0xFF6366F1) : const Color(0xFF1F2937)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: session.isCurrentSession
                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                  : const Color(0xFF1F2937),
              shape: BoxShape.circle,
            ),
            child: Icon(
              devIcon,
              color: session.isCurrentSession ? const Color(0xFF818CF8) : Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      session.userName,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.userRole.toUpperCase(),
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (session.isCurrentSession)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Sua Sessão Atual',
                          style: TextStyle(color: MetaColors.emerald, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (session.isSimultaneous)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Acesso Simultâneo',
                          style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isSuspicious)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Suspeito',
                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${session.device} • ${session.platform}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'IP: ${session.ipAddress} • ${session.location}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    Text(
                      'Ativo: ${session.lastActive}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!session.isCurrentSession) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Encerrar esta sessão (Kill Switch)',
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 20),
              onPressed: () => _revokeSession(session),
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // ABA 1: LOGS DE AUDITORIA & SEGURANÇA
  // ==========================================
  Widget _buildLogsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Busca e Filtros de Severidade
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (_) => _loadAll(),
                decoration: InputDecoration(
                  hintText: 'Buscar logs por ator, usuário afetado ou tipo de ação...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white38),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadAll();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF090D16),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2937)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1F2937)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildLogChip('all', 'Todos os Logs'),
                    _buildLogChip('info', 'Informativos', color: const Color(0xFF818CF8)),
                    _buildLogChip('warning', 'Avisos & Suspensões', color: Colors.amber),
                    _buildLogChip('critical', 'Críticos / Permissões', color: Colors.redAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Logs
        if (_logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 44, color: Colors.white24),
                SizedBox(height: 12),
                Text('Nenhum registro de auditoria encontrado', style: TextStyle(color: Colors.white60)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = _logs[index];
              return _buildLogCard(log);
            },
          ),
      ],
    );
  }

  Widget _buildLogChip(String key, String label, {Color? color}) {
    final isSelected = _severityFilter == key;
    final activeColor = color ?? const Color(0xFF818CF8);

    return InkWell(
      onTap: () {
        setState(() => _severityFilter = key);
        _loadAll();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(AdminAuditEntry log) {
    Color sevColor;
    IconData sevIcon;

    if (log.severity == 'critical') {
      sevColor = Colors.redAccent;
      sevIcon = Icons.shield_rounded;
    } else if (log.severity == 'warning') {
      sevColor = Colors.amber;
      sevIcon = Icons.warning_amber_rounded;
    } else {
      sevColor = const Color(0xFF818CF8);
      sevIcon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: sevColor.withValues(alpha: 0.3)),
            ),
            child: Icon(sevIcon, color: sevColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        log.summary,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Ator: ${log.actorName}',
                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Alvo: ${log.targetUserName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (log.ipAddress != null)
                      Text(
                        'IP: ${log.ipAddress}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TELEMETRIA IA (GEMINI 3.1 PRO)
  // ==========================================
  Widget _buildAiTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card de Visão Geral do Modelo
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF818CF8), size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motor IA Oficial: Gemini 3.1 Pro Preview',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Geração de treinos periodizados, análises biomecânicas e copiloto de salão com reserva atômica de cota.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Consumo por Treinador
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _aiStats.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final stat = _aiStats[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stat.trainerName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          stat.planName,
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stat.isUnlimited
                            ? '${stat.generationsUsed} gerações (Ilimitado)'
                            : '${stat.generationsUsed} / ${stat.maxGenerations} gerações utilizadas',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        stat.isUnlimited ? '100% OK' : '${(stat.percentageUsed * 100).toInt()}%',
                        style: TextStyle(
                          color: stat.percentageUsed > 0.8 ? Colors.amber : MetaColors.emerald,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stat.isUnlimited ? 0.3 : stat.percentageUsed,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF090D16),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        stat.isUnlimited
                            ? MetaColors.emerald
                            : (stat.percentageUsed > 0.8 ? Colors.amber : const Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // ABA 3: HEALTH CHECK & LATÊNCIAS
  // ==========================================
  Widget _buildHealthTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _services.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final s = _services[index];
            final latencyColor = s.latencyMs < 100
                ? MetaColors.emerald
                : (s.latencyMs < 300 ? const Color(0xFF818CF8) : Colors.amber);

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: MetaColors.emerald,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: MetaColors.emerald, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${s.endpoint} • ${s.statusMessage}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: latencyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: latencyColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${s.latencyMs} ms',
                      style: TextStyle(color: latencyColor, fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
