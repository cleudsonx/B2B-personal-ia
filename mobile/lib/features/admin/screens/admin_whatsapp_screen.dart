import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminWhatsAppScreen extends StatefulWidget {
  const AdminWhatsAppScreen({super.key});

  @override
  State<AdminWhatsAppScreen> createState() => _AdminWhatsAppScreenState();
}

class _AdminWhatsAppScreenState extends State<AdminWhatsAppScreen> {
  bool _isLoading = true;
  AdminWhatsAppOverview _overview = const AdminWhatsAppOverview(
    totalInstances: 0,
    connectedCount: 0,
    disconnectedCount: 0,
    messagesSent24h: 0,
    instances: [],
  );
  String _selectedStatus = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getWhatsAppInstancesOverview(
      statusFilter: _selectedStatus,
      searchQuery: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _overview = data;
      _isLoading = false;
    });
  }

  Future<void> _handleInstanceAction(
    AdminWhatsAppInstance instance,
    String action, {
    String? confirmTitle,
    String? confirmMsg,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (confirmTitle != null && confirmMsg != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Text(
            confirmTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            confirmMsg,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Executando $action na instância ${instance.instanceName}...'),
          ],
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    final res = await AdminDataService.performWhatsAppInstanceAction(
      instanceName: instance.instanceName,
      action: action,
    );

    if (!mounted) return;

    final msg = res['message']?.toString() ?? 'Ação $action concluída com sucesso.';
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: MetaColors.emerald,
        content: Text('✓ $msg'),
      ),
    );

    _loadOverview();
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
                    title: 'TOTAL INSTÂNCIAS',
                    value: '${_overview.totalInstances}',
                    icon: Icons.hub_rounded,
                    color: const Color(0xFF6366F1),
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'ONLINE / ATIVAS',
                    value: '${_overview.connectedCount}',
                    icon: Icons.check_circle_rounded,
                    color: MetaColors.emerald,
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'DESCONECTADAS',
                    value: '${_overview.disconnectedCount}',
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFEF4444),
                    cardBg: cardBg,
                    border: borderColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildKpiCard(
                    title: 'DISPAROS 24H',
                    value: '${_overview.messagesSent24h}',
                    icon: Icons.outgoing_mail,
                    color: Colors.amber,
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
                    onChanged: (_) => _loadOverview(),
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Buscar por personal, instância, telefone...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _loadOverview();
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
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Atualizar Status ao Vivo',
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF818CF8)),
                  onPressed: _loadOverview,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filtros por Status (Chips Horizontais)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('all', 'Todas (${_overview.instances.length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('connected', 'Conectadas (${_overview.connectedCount})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('disconnected', 'Desconectadas (${_overview.disconnectedCount})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('qrcode_pending', 'QR Code Pendente'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Instâncias
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                    )
                  : _overview.instances.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma instância encontrada com os filtros atuais.',
                            style: TextStyle(color: textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _overview.instances.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final inst = _overview.instances[index];
                            final isConnected = inst.isConnected;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isConnected
                                      ? MetaColors.emerald.withValues(alpha: 0.3)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isConnected ? MetaColors.emerald : const Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isConnected ? MetaColors.emerald : const Color(0xFFEF4444)).withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
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
                                                inst.trainerName,
                                                style: TextStyle(
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (isConnected ? MetaColors.emerald : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isConnected ? 'ONLINE' : 'OFFLINE',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: isConnected ? MetaColors.emerald : const Color(0xFFEF4444),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Instância: ${inst.instanceName} • ${inst.phone ?? 'Sem telefone'}',
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
                                                'Plano: ${inst.plan}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${inst.messagesSent24h} disparos (24h)',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF818CF8),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Botões de Ação Operacional
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: Key('admin_wa_ping_${inst.instanceName}'),
                                        icon: const Icon(Icons.bolt_rounded, size: 18),
                                        tooltip: 'Testar Sinal / Ping',
                                        color: Colors.amber,
                                        onPressed: () => _handleInstanceAction(inst, 'ping'),
                                      ),
                                      IconButton(
                                        key: Key('admin_wa_restart_${inst.instanceName}'),
                                        icon: const Icon(Icons.refresh_rounded, size: 18),
                                        tooltip: 'Reiniciar Socket',
                                        color: const Color(0xFF818CF8),
                                        onPressed: () => _handleInstanceAction(inst, 'restart'),
                                      ),
                                      IconButton(
                                        key: Key('admin_wa_logout_${inst.instanceName}'),
                                        icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                                        tooltip: 'Desconectar Sessão (Logout)',
                                        color: const Color(0xFFEF4444),
                                        onPressed: () => _handleInstanceAction(
                                          inst,
                                          'logout',
                                          confirmTitle: 'Desconectar Instância?',
                                          confirmMsg: 'Deseja realmente desconectar a instância ${inst.instanceName} do professor ${inst.trainerName}? O professor precisará escanear o QR Code novamente para reativar as mensagens.',
                                        ),
                                      ),
                                    ],
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

  Widget _buildStatusFilterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedStatus = statusKey);
        _loadOverview();
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
}
