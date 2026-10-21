import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo 5: Auditoria, Observabilidade & Telemetria IA
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
    _tabController = TabController(length: 3, vsync: this);
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

    final results = await Future.wait([logsFuture, aiFuture, healthFuture]);

    if (mounted) {
      setState(() {
        _logs = results[0] as List<AdminAuditEntry>;
        _aiStats = results[1] as List<AdminAiUsageStat>;
        _services = results[2] as List<AdminServiceHealth>;
        _isLoading = false;
      });
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.security_rounded, color: Color(0xFF818CF8), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Auditoria, Observabilidade & IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rastreamento de ações administrativas, telemetria de tokens Gemini e health check de APIs',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
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

              // Barra de Abas
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
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
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
                        return _buildLogsTab();
                      case 1:
                        return _buildAiTab();
                      case 2:
                        return _buildHealthTab();
                      default:
                        return _buildLogsTab();
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
              Row(
                children: [
                  _buildLogChip('all', 'Todos os Logs'),
                  const SizedBox(width: 8),
                  _buildLogChip('info', 'Informativos', color: const Color(0xFF818CF8)),
                  const SizedBox(width: 8),
                  _buildLogChip('warning', 'Avisos & Suspensões', color: Colors.amber),
                  const SizedBox(width: 8),
                  _buildLogChip('critical', 'Críticos / Permissões', color: Colors.redAccent),
                ],
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
            child: Column(
              children: const [
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
                    Text(
                      log.summary,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Ator: ${log.actorName}',
                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Alvo: ${log.targetUserName}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (log.ipAddress != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'IP: ${log.ipAddress}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
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
