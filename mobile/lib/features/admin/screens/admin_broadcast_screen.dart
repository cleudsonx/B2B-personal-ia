import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo 6: Broadcast & Comunicados Globais do Sistema
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  bool _isLoading = true;
  List<AdminBroadcastMessage> _broadcasts = [];

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
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getBroadcasts();
    if (mounted) {
      setState(() {
        _broadcasts = data;
        _isLoading = false;
      });
    }
  }

  void _showNewBroadcastDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String target = 'all';
    String severity = 'info';
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Novo Comunicado Global',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    controller: titleCtrl,
                    label: 'Título do Banner / Comunicado',
                    hint: 'Ex: 🚀 Atualização v1.9 disponível!',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: msgCtrl,
                    label: 'Mensagem do Comunicado',
                    hint: 'Descreva a mensagem clara para os usuários...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  // Público-Alvo
                  const Text('Público-Alvo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: target,
                        dropdownColor: const Color(0xFF111827),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Todos os Usuários (Treinadores e Alunos)')),
                          DropdownMenuItem(value: 'trainers', child: Text('Somente Treinadores (B2B)')),
                          DropdownMenuItem(value: 'students', child: Text('Somente Alunos (B2C)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => target = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Severidade
                  const Text('Severidade / Tipo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: severity,
                        dropdownColor: const Color(0xFF111827),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('Informativo (Azul / Novidade)')),
                          DropdownMenuItem(value: 'warning', child: Text('Atenção / Manutenção (Âmbar)')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgente / Alerta Crítico (Vermelho)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => severity = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Switch Ativar Imediatamente
                  SwitchListTile(
                    title: const Text('Publicar Imediatamente', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text('Exibe banner fixo no app dos usuários selecionados', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    value: isActive,
                    activeThumbColor: MetaColors.emerald,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final item = AdminBroadcastMessage(
                  id: 'BC-${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  message: msgCtrl.text.trim(),
                  targetAudience: target,
                  severity: severity,
                  isActive: isActive,
                  createdAt: DateTime.now(),
                  createdBy: 'SuperAdmin',
                );

                Navigator.pop(ctx);
                await AdminDataService.createBroadcast(item);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Comunicado registrado com sucesso!'),
                    backgroundColor: MetaColors.emerald,
                  ),
                );
                _loadBroadcasts();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Disparar Comunicado'),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: _loadBroadcasts,
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
                          Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Broadcast & Comunicados Globais',
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
                        'Envio de banners, notificações no topo do app e avisos de manutenção para toda a base',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showNewBroadcastDialog,
                    icon: const Icon(Icons.add_alert_rounded, size: 18),
                    label: const Text('Novo Comunicado', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lista de Comunicados
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_broadcasts.isEmpty)
                Container(
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
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _broadcasts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final bc = _broadcasts[index];
                    return _buildBroadcastCard(bc);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBroadcastCard(AdminBroadcastMessage bc) {
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
          // Cabeçalho do Card
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
                      color: bc.isActive ? MetaColors.emerald : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: bc.isActive,
                    activeThumbColor: MetaColors.emerald,
                    onChanged: (val) async {
                      await AdminDataService.toggleBroadcast(bc.id, val);
                      _loadBroadcasts();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Excluir Comunicado',
                    onPressed: () async {
                      await AdminDataService.deleteBroadcast(bc.id);
                      _loadBroadcasts();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Título e Mensagem
          Text(
            bc.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            bc.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Simulação de Como Aparece no Topo do App
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sevColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(sevIcon, color: sevColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preview no app: "${bc.title} — ${bc.message}"',
                    style: TextStyle(color: sevColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Metadados
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Criado por: ${bc.createdBy}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                _formatDateTime(bc.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
