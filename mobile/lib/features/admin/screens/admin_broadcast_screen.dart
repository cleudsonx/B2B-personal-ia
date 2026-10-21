import 'package:flutter/material.dart';
import '../services/admin_data_service.dart';

/// Módulo 6: Central de Notificações Push & WhatsApp em Massa (Broadcast Segmentado)
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  int _selectedTab = 0; // 0: Composer Multicanal, 1: Histórico & Telemetria, 2: Banners In-App
  bool _isLoading = true;
  bool _isSending = false;

  // Estatísticas de Audiência
  AdminBroadcastAudienceStats _audienceStats = const AdminBroadcastAudienceStats(
    audienceCounts: {
      'all': 1392,
      'trainers_all': 142,
      'trainers_starter': 48,
      'trainers_pro': 68,
      'trainers_studio': 26,
      'trainers_full_capacity': 19,
      'trainers_inactive': 12,
      'students_all': 1250,
      'students_inactive': 168,
      'students_expiring': 54,
    },
    totalUsers: 1392,
    totalTrainers: 142,
    totalStudents: 1250,
    activePushTokens: 1280,
    connectedWhatsAppInstances: 138,
    whatsappCostPerMsg: 0.05,
    estimatedDeliveryRatePct: 98.5,
  );

  List<AdminBroadcastCampaignItem> _campaigns = [];
  List<AdminBroadcastMessage> _broadcasts = [];

  // Controladores do Composer
  final TextEditingController _titleCtrl = TextEditingController(
    text: '🚀 Novidades Incríveis na v1.9.0 do Mr. Coach!',
  );
  final TextEditingController _messageCtrl = TextEditingController(
    text: 'Liberamos hoje o fechamento automático Asaas via Pix/Cartão, indução ao app PWA e gestão estrita de vagas na consultoria. Acesse e confira!',
  );
  final TextEditingController _actionLabelCtrl = TextEditingController(text: 'Ver Novidades');
  final TextEditingController _actionUrlCtrl = TextEditingController(text: 'app://changelog');

  Set<String> _selectedChannels = {'push', 'whatsapp'};
  String _selectedAudience = 'all';
  String _selectedSeverity = 'info';
  int _previewChannel = 0; // 0: Push, 1: WhatsApp, 2: In-App

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _actionLabelCtrl.dispose();
    _actionUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final stats = await AdminDataService.getBroadcastAudienceStats();
    final campaigns = await AdminDataService.getBroadcastCampaigns();
    final broadcasts = await AdminDataService.getBroadcasts();

    if (mounted) {
      setState(() {
        _audienceStats = stats;
        _campaigns = campaigns;
        _broadcasts = broadcasts;
        _isLoading = false;
      });
    }
  }

  int get _currentTargetCount {
    return _audienceStats.audienceCounts[_selectedAudience] ?? _audienceStats.totalUsers;
  }

  double get _currentEstimatedCost {
    if (!_selectedChannels.contains('whatsapp')) return 0.0;
    return _currentTargetCount * _audienceStats.whatsappCostPerMsg;
  }

  void _applyTemplate({
    required String title,
    required String message,
    required String severity,
    required Set<String> channels,
    required String audience,
    String actionLabel = '',
    String actionUrl = '',
  }) {
    setState(() {
      _titleCtrl.text = title;
      _messageCtrl.text = message;
      _selectedSeverity = severity;
      _selectedChannels = Set.from(channels);
      _selectedAudience = audience;
      _actionLabelCtrl.text = actionLabel;
      _actionUrlCtrl.text = actionUrl;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Template "$title" aplicado com sucesso!'),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSendBroadcast() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o título e a mensagem antes de disparar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um canal de envio (Push, WhatsApp ou In-App).'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    // Modal de Confirmação Executiva de Segurança
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Text(
              'Confirmar Disparo em Massa',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta ação enviará notificações reais para a base segmentada:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  _buildModalDetailRow('Público Alvo:', _getAudienceLabel(_selectedAudience)),
                  const SizedBox(height: 6),
                  _buildModalDetailRow('Destinatários Estimados:', '$_currentTargetCount usuários'),
                  const SizedBox(height: 6),
                  _buildModalDetailRow('Canais Ativos:', _selectedChannels.join(', ').toUpperCase()),
                  const SizedBox(height: 6),
                  _buildModalDetailRow(
                    'Custo Estimado WhatsApp:',
                    'R\$ ${_currentEstimatedCost.toStringAsFixed(2)}',
                    color: _currentEstimatedCost > 0 ? const Color(0xFF10B981) : Colors.white70,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Os envios via Push e WhatsApp são instantâneos e irreversíveis.',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autorizar Disparo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);

    final result = await AdminDataService.sendBroadcastCampaign(
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      channels: _selectedChannels.toList(),
      targetAudience: _selectedAudience,
      severity: _selectedSeverity,
      actionLabel: _actionLabelCtrl.text.trim().isEmpty ? null : _actionLabelCtrl.text.trim(),
      actionUrl: _actionUrlCtrl.text.trim().isEmpty ? null : _actionUrlCtrl.text.trim(),
      authorName: 'SuperAdmin Cleudson',
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🚀 Broadcast disparado com sucesso! ${result.delivered} de ${result.totalSent} mensagens entregues.',
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
      _loadAllData();
      setState(() => _selectedTab = 1); // Alterna para aba de histórico
    }
  }

  Widget _buildModalDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _getAudienceLabel(String key) {
    switch (key) {
      case 'all':
        return 'Toda a Base (B2B + B2C)';
      case 'trainers_all':
        return 'Todos os Treinadores (B2B)';
      case 'trainers_starter':
        return 'Treinadores Plano Starter';
      case 'trainers_pro':
        return 'Treinadores Plano Pro';
      case 'trainers_studio':
        return 'Treinadores Plano Studio VIP';
      case 'trainers_full_capacity':
        return 'Treinadores Quase Lotados (>=90%)';
      case 'trainers_inactive':
        return 'Treinadores Inativos (>14 dias)';
      case 'students_all':
        return 'Todos os Alunos (B2C)';
      case 'students_inactive':
        return 'Alunos Inativos (>7 dias sem treino)';
      case 'students_expiring':
        return 'Alunos com Consultoria a Vencer';
      default:
        return 'Público Selecionado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildAudienceMetricsBanner(),
              const SizedBox(height: 20),
              _buildTabSelector(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_selectedTab == 0)
                _buildComposerTab()
              else if (_selectedTab == 1)
                _buildHistoryTab()
              else
                _buildInAppBannersTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Central de Notificações & Broadcast Multicanal',
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
                'Envio em massa segmentado por perfil com Push Notification, WhatsApp Oficial e Avisos In-App',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceMetricsBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
          ),
          child: isMobile
              ? Column(
                  children: [
                    _buildAudienceMetricItem(
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF6366F1),
                      title: 'Base Total de Usuários',
                      value: '${_audienceStats.totalUsers}',
                      subtitle: '${_audienceStats.totalTrainers} Personals • ${_audienceStats.totalStudents} Alunos',
                    ),
                    const Divider(color: Color(0xFF1F2937), height: 24),
                    _buildAudienceMetricItem(
                      icon: Icons.notifications_active_rounded,
                      color: const Color(0xFF38BDF8),
                      title: 'Tokens Push Ativos',
                      value: '${_audienceStats.activePushTokens}',
                      subtitle: 'PWA iOS/Android & Mobile Nativo',
                    ),
                    const Divider(color: Color(0xFF1F2937), height: 24),
                    _buildAudienceMetricItem(
                      icon: Icons.chat_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Instâncias WhatsApp',
                      value: '${_audienceStats.connectedWhatsAppInstances} Online',
                      subtitle: 'Evolution API / Meta Cloud Ativas',
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildAudienceMetricItem(
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF6366F1),
                        title: 'Base Total de Usuários',
                        value: '${_audienceStats.totalUsers}',
                        subtitle: '${_audienceStats.totalTrainers} Personals • ${_audienceStats.totalStudents} Alunos',
                      ),
                    ),
                    Container(height: 44, width: 1, color: const Color(0xFF1F2937)),
                    Expanded(
                      child: _buildAudienceMetricItem(
                        icon: Icons.notifications_active_rounded,
                        color: const Color(0xFF38BDF8),
                        title: 'Tokens Push Ativos',
                        value: '${_audienceStats.activePushTokens}',
                        subtitle: 'PWA iOS/Android & Mobile Nativo',
                      ),
                    ),
                    Container(height: 44, width: 1, color: const Color(0xFF1F2937)),
                    Expanded(
                      child: _buildAudienceMetricItem(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF10B981),
                        title: 'Instâncias WhatsApp',
                        value: '${_audienceStats.connectedWhatsAppInstances} Online',
                        subtitle: 'Evolution API / Meta Cloud Ativas',
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAudienceMetricItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          _buildTabButton(
            index: 0,
            icon: Icons.send_rounded,
            title: 'Disparo de Broadcast',
          ),
          _buildTabButton(
            index: 1,
            icon: Icons.history_rounded,
            title: 'Histórico & Telemetria (${_campaigns.length})',
          ),
          _buildTabButton(
            index: 2,
            icon: Icons.bookmark_border_rounded,
            title: 'Banners In-App (${_broadcasts.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: COMPOSER DE BROADCAST MULTICANAL
  // ============================================================================

  Widget _buildComposerTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 960;
        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildComposerForm(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: _buildComposerSidebar(),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildComposerForm(),
              const SizedBox(height: 24),
              _buildComposerSidebar(),
            ],
          );
        }
      },
    );
  }

  Widget _buildComposerForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passo 1: Canais de Envio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '1. Canais de Envio Multicanal',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedChannels.length == 3) {
                      _selectedChannels = {'push'};
                    } else {
                      _selectedChannels = {'push', 'whatsapp', 'in_app'};
                    }
                  });
                },
                child: Text(
                  _selectedChannels.length == 3 ? 'Desmarcar Todos' : 'Selecionar Todos (Combo)',
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChannelCard(
                channel: 'push',
                icon: Icons.notifications_active_rounded,
                title: 'Push Mobile',
                subtitle: 'PWA & App Nativo',
                badge: 'GRÁTIS',
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 10),
              _buildChannelCard(
                channel: 'whatsapp',
                icon: Icons.chat_rounded,
                title: 'WhatsApp Oficial',
                subtitle: 'Evolution API',
                badge: 'R\$ 0,05/msg',
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 10),
              _buildChannelCard(
                channel: 'in_app',
                icon: Icons.campaign_rounded,
                title: 'Banner In-App',
                subtitle: 'Topo do Cockpit',
                badge: 'PERSISTENTE',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Passo 2: Segmentação de Público Alvo
          const Text(
            '2. Segmentação Inteligente do Público-Alvo',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAudience,
                dropdownColor: const Color(0xFF111827),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                isExpanded: true,
                items: [
                  _buildDropdownItem('all', '🌐 Toda a Base de Usuários (B2B + B2C)', '${_audienceStats.totalUsers} destinatários'),
                  _buildDropdownItem('trainers_all', '🏋️ Todos os Treinadores (B2B)', '${_audienceStats.totalTrainers} personals'),
                  _buildDropdownItem('trainers_starter', '🥉 Treinadores Plano Starter (Gratuito)', '${_audienceStats.audienceCounts['trainers_starter'] ?? 48} personals'),
                  _buildDropdownItem('trainers_pro', '🥈 Treinadores Plano Pro', '${_audienceStats.audienceCounts['trainers_pro'] ?? 68} personals'),
                  _buildDropdownItem('trainers_studio', '🥇 Treinadores Plano Studio VIP', '${_audienceStats.audienceCounts['trainers_studio'] ?? 26} personals'),
                  _buildDropdownItem('trainers_full_capacity', '🔥 Treinadores com Turma Quase Lotada (>=90%)', '${_audienceStats.audienceCounts['trainers_full_capacity'] ?? 19} personals'),
                  _buildDropdownItem('trainers_inactive', '⚠️ Treinadores Inativos (>14 dias sem prescrever)', '${_audienceStats.audienceCounts['trainers_inactive'] ?? 12} personals'),
                  _buildDropdownItem('students_all', '👥 Todos os Alunos (B2C)', '${_audienceStats.totalStudents} alunos'),
                  _buildDropdownItem('students_inactive', '💤 Alunos Inativos (>7 dias sem treino)', '${_audienceStats.audienceCounts['students_inactive'] ?? 168} alunos'),
                  _buildDropdownItem('students_expiring', '⏰ Alunos com Consultoria a Vencer (<7 dias)', '${_audienceStats.audienceCounts['students_expiring'] ?? 54} alunos'),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAudience = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Passo 3: Templates Pré-Configurados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  '3. Modelos & Templates de Alta Conversão',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Clique para aplicar',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTemplateChip(
                  label: '🚀 Lançamento v1.9',
                  onTap: () => _applyTemplate(
                    title: '🚀 Novidades Incríveis na v1.9.0 do Mr. Coach!',
                    message: 'Liberamos hoje o fechamento automático Asaas via Pix/Cartão, indução ao app PWA e gestão estrita de vagas na consultoria. Acesse e confira!',
                    severity: 'info',
                    channels: {'push', 'in_app'},
                    audience: 'all',
                    actionLabel: 'Ver Novidades',
                    actionUrl: 'app://changelog',
                  ),
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: '💪 Reengajamento Alunos',
                  onTap: () => _applyTemplate(
                    title: '💪 Sentimos sua falta nos treinos desta semana!',
                    message: 'Seu treinador preparou uma rotina focada nos seus objetivos. Não deixe o ritmo cair! Dê o check-in hoje mesmo.',
                    severity: 'warning',
                    channels: {'push', 'whatsapp'},
                    audience: 'students_inactive',
                    actionLabel: 'Abrir Meu Treino',
                    actionUrl: 'app://workouts',
                  ),
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: '💼 Upgrade de Vagas (B2B)',
                  onTap: () => _applyTemplate(
                    title: '🔥 Alerta de Alta Demanda: Vagas da sua consultoria esgotando!',
                    message: 'Sua turma atingiu o limite de alunos cadastrados. Faça o upgrade agora para o Plano Studio VIP e aceite novos clientes sem travas.',
                    severity: 'urgent',
                    channels: {'push', 'whatsapp'},
                    audience: 'trainers_full_capacity',
                    actionLabel: 'Fazer Upgrade VIP',
                    actionUrl: 'app://plans',
                  ),
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: '⚙️ Manutenção do Sistema',
                  onTap: () => _applyTemplate(
                    title: '⚙️ Manutenção Preventiva Programada',
                    message: 'Neste domingo, das 03:00 às 03:15, realizaremos atualização de infraestrutura para acelerar o app. Todos os dados permanecem 100% seguros.',
                    severity: 'info',
                    channels: {'in_app', 'push'},
                    audience: 'all',
                  ),
                ),
                const SizedBox(width: 8),
                _buildTemplateChip(
                  label: '💰 Repasse Financeiro Asaas',
                  onTap: () => _applyTemplate(
                    title: '💰 Relatório Financeiro: Repasses e Baixas do Ciclo',
                    message: 'Todos os recebimentos dos seus alunos via Pix e Cartão já foram compensados e o saldo líquido está disponível para saque na sua carteira.',
                    severity: 'success',
                    channels: {'whatsapp', 'push'},
                    audience: 'trainers_all',
                    actionLabel: 'Ver Carteira',
                    actionUrl: 'app://wallet',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Passo 4: Conteúdo da Mensagem
          const Text(
            '4. Conteúdo do Comunicado',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Severidade
          Row(
            children: [
              _buildSeverityChip('info', 'Informativo', Colors.blueAccent),
              const SizedBox(width: 8),
              _buildSeverityChip('warning', 'Atenção', Colors.amber),
              const SizedBox(width: 8),
              _buildSeverityChip('urgent', 'Urgente', Colors.redAccent),
              const SizedBox(width: 8),
              _buildSeverityChip('success', 'Sucesso', const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _titleCtrl,
            label: 'Título da Notificação / Banner',
            hint: 'Ex: 🚀 Atualização v1.9 disponível!',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _messageCtrl,
            label: 'Corpo da Mensagem',
            hint: 'Descreva a mensagem clara para os usuários...',
            maxLines: 3,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _actionLabelCtrl,
                  label: 'Texto do Botão de Ação (Opcional)',
                  hint: 'Ex: Ver Novidades',
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _actionUrlCtrl,
                  label: 'Link / Rota do App (Opcional)',
                  hint: 'Ex: app://changelog',
                  onChanged: () => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botão de Disparo
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _handleSendBroadcast,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 20),
              label: Text(
                _isSending
                    ? 'Disparando Notificações...'
                    : 'Disparar Broadcast para $_currentTargetCount Destinatários',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, String title, String count) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          Text(
            count,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCard({
    required String channel,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
  }) {
    final isSelected = _selectedChannels.contains(channel);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedChannels.remove(channel);
            } else {
              _selectedChannels.add(channel);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFF090D16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF1F2937),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: isSelected ? color : Colors.white38, size: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: isSelected ? color : Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: const Color(0xFF090D16),
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      side: const BorderSide(color: Color(0xFF1F2937)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildSeverityChip(String value, String label, Color color) {
    final isSelected = _selectedSeverity == value;
    return InkWell(
      onTap: () => setState(() => _selectedSeverity = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF1F2937),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: (_) => onChanged?.call(),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF090D16),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
      ],
    );
  }

  // ============================================================================
  // SIDEBAR DO COMPOSER: RADAR DE ALCANCE & LIVE PREVIEW
  // ============================================================================

  Widget _buildComposerSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Radar de Alcance e Custo
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.radar_rounded, color: Color(0xFF818CF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Radar de Alcance & Custo',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildImpactRow(
                title: 'Destinatários Filtrados:',
                value: '$_currentTargetCount usuários',
                highlight: true,
              ),
              const SizedBox(height: 8),
              _buildImpactRow(
                title: 'Taxa de Entrega Estimada:',
                value: '${_audienceStats.estimatedDeliveryRatePct}%',
              ),
              const SizedBox(height: 8),
              _buildImpactRow(
                title: 'Custo WhatsApp (Meta/Evolution):',
                value: _currentEstimatedCost > 0
                    ? 'R\$ ${_currentEstimatedCost.toStringAsFixed(2)}'
                    : 'R\$ 0,00 (Grátis)',
                color: _currentEstimatedCost > 0 ? const Color(0xFF10B981) : Colors.white70,
              ),
              const SizedBox(height: 8),
              _buildImpactRow(
                title: 'Custo Push / In-App:',
                value: 'R\$ 0,00 (Ilimitado)',
                color: const Color(0xFF38BDF8),
              ),
              const Divider(color: Color(0xFF1F2937), height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rastreamento em tempo real ativado em todas as mensagens.',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Preview Interativo
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.remove_red_eye_rounded, color: Color(0xFF38BDF8), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Live Preview em Tempo Real',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Segmentador de Preview
              Row(
                children: [
                  _buildPreviewTabItem(0, 'Push Mobile', Icons.phone_android_rounded),
                  const SizedBox(width: 6),
                  _buildPreviewTabItem(1, 'WhatsApp', Icons.chat_bubble_outline_rounded),
                  const SizedBox(width: 6),
                  _buildPreviewTabItem(2, 'In-App', Icons.web_rounded),
                ],
              ),
              const SizedBox(height: 16),
              if (_previewChannel == 0)
                _buildPushPreview()
              else if (_previewChannel == 1)
                _buildWhatsAppPreview()
              else
                _buildInAppPreview(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactRow({
    required String title,
    required String value,
    bool highlight = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: color ?? (highlight ? const Color(0xFF818CF8) : Colors.white),
            fontSize: highlight ? 13 : 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTabItem(int index, String label, IconData icon) {
    final isSelected = _previewChannel == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _previewChannel = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1F2937) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1F2937)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.white38),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPushPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              const Text(
                'MR. COACH • AGORA',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _titleCtrl.text.isEmpty ? 'Título da Notificação' : _titleCtrl.text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _messageCtrl.text.isEmpty ? 'Corpo da mensagem...' : _messageCtrl.text,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3),
          ),
          if (_actionLabelCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '▶ ${_actionLabelCtrl.text}',
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWhatsAppPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF047857).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
              SizedBox(width: 6),
              Text(
                'Mr. Coach Bot (WhatsApp Business)',
                style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '*${_titleCtrl.text.isEmpty ? "Título" : _titleCtrl.text}*',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _messageCtrl.text.isEmpty ? 'Mensagem no WhatsApp...' : _messageCtrl.text,
            style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11, height: 1.3),
          ),
          if (_actionLabelCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '🔗 Acesse aqui: ${_actionUrlCtrl.text.isEmpty ? "app://mrcoach" : _actionUrlCtrl.text}',
              style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10, decoration: TextDecoration.underline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInAppPreview() {
    Color sevColor;
    if (_selectedSeverity == 'urgent') {
      sevColor = Colors.redAccent;
    } else if (_selectedSeverity == 'warning') {
      sevColor = Colors.amber;
    } else if (_selectedSeverity == 'success') {
      sevColor = const Color(0xFF10B981);
    } else {
      sevColor = const Color(0xFF38BDF8);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sevColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sevColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: sevColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleCtrl.text.isEmpty ? 'Aviso In-App' : _titleCtrl.text,
                  style: TextStyle(color: sevColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _messageCtrl.text.isEmpty ? 'Mensagem exibida no topo do app...' : _messageCtrl.text,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: HISTÓRICO & TELEMETRIA DE ENTREGAS
  // ============================================================================

  Widget _buildHistoryTab() {
    if (_campaigns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          children: const [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Nenhuma campanha disparada ainda',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _campaigns.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final cmp = _campaigns[index];
            return _buildCampaignCard(cmp);
          },
        ),
      ],
    );
  }

  Widget _buildCampaignCard(AdminBroadcastCampaignItem cmp) {
    Color sevColor;
    if (cmp.severity == 'urgent') {
      sevColor = Colors.redAccent;
    } else if (cmp.severity == 'warning') {
      sevColor = Colors.amber;
    } else if (cmp.severity == 'success') {
      sevColor = const Color(0xFF10B981);
    } else {
      sevColor = const Color(0xFF38BDF8);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sevColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      cmp.severity.toUpperCase(),
                      style: TextStyle(color: sevColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_rounded, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          cmp.targetAudienceLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    cmp.status,
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cmp.createdAt,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            cmp.title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            cmp.message,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          // Canais e Métricas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ch in cmp.channels) ...[
                    _buildChannelBadge(ch),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${cmp.deliveredCount}/${cmp.sentCount} entregues (${cmp.deliveryRatePct}%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  if (cmp.estimatedCostBrl > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Custo: R\$ ${cmp.estimatedCostBrl.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBadge(String channel) {
    IconData icon;
    String label;
    Color color;

    if (channel == 'push') {
      icon = Icons.notifications_active_rounded;
      label = 'Push';
      color = const Color(0xFF38BDF8);
    } else if (channel == 'whatsapp') {
      icon = Icons.chat_rounded;
      label = 'WhatsApp';
      color = const Color(0xFF10B981);
    } else {
      icon = Icons.campaign_rounded;
      label = 'In-App';
      color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: BANNERS IN-APP ATIVOS
  // ============================================================================

  Widget _buildInAppBannersTab() {
    if (_broadcasts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          children: const [
            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Nenhum comunicado ativo no momento',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _broadcasts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final bc = _broadcasts[index];
        return _buildInAppBannerCard(bc);
      },
    );
  }

  Widget _buildInAppBannerCard(AdminBroadcastMessage bc) {
    Color sevColor;
    String sevLabel;
    IconData sevIcon;

    if (bc.severity == 'urgent') {
      sevColor = Colors.redAccent;
      sevLabel = 'URGENTE';
      sevIcon = Icons.error_outline_rounded;
    } else if (bc.severity == 'warning') {
      sevColor = Colors.amber;
      sevLabel = 'AVISO';
      sevIcon = Icons.warning_amber_rounded;
    } else {
      sevColor = const Color(0xFF818CF8);
      sevLabel = 'INFO';
      sevIcon = Icons.info_outline_rounded;
    }

    String audienceLabel = bc.targetAudience == 'trainers'
        ? 'Somente Treinadores'
        : (bc.targetAudience == 'students' ? 'Somente Alunos' : 'Todos os Usuários');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bc.isActive ? sevColor.withValues(alpha: 0.5) : const Color(0xFF1F2937),
          width: bc.isActive ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sevColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sevIcon, color: sevColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          sevLabel,
                          style: TextStyle(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.group_rounded, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          audienceLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    bc.isActive ? 'ATIVO' : 'PAUSADO',
                    style: TextStyle(
                      color: bc.isActive ? const Color(0xFF10B981) : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: bc.isActive,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) async {
                      await AdminDataService.toggleBroadcast(bc.id, val);
                      _loadAllData();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Excluir Comunicado',
                    onPressed: () async {
                      await AdminDataService.deleteBroadcast(bc.id);
                      _loadAllData();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bc.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            bc.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
