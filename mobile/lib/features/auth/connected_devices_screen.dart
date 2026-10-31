import 'package:flutter/material.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/device_session_service.dart';

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  DeviceSessionsOverview? _overview;
  bool _isLoading = true;
  bool _isRevokingOthers = false;
  String? _revokingDeviceId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    // 1. Garante que este aparelho seja registrado imediatamente
    await DeviceSessionService.registerCurrentSession();
    // 2. Busca todos os aparelhos ativos
    final overview = await DeviceSessionService.fetchSessions();
    if (mounted) {
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRevokeSingle(DeviceSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MetaColors.cardBorder(ctx)),
        ),
        title: Text(
          'Desconectar aparelho?',
          style: TextStyle(
            color: MetaColors.text(ctx),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'A sessão em "${session.deviceName}" (${session.platform}) será encerrada imediatamente. Será necessário fazer login novamente se for o seu aparelho.',
          style: TextStyle(color: MetaColors.subtext(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _revokingDeviceId = session.deviceId);
    final success = await DeviceSessionService.revokeSession(
      sessionId: session.id,
      deviceId: session.deviceId,
    );

    if (mounted) {
      setState(() => _revokingDeviceId = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aparelho desconectado com sucesso.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadSessions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível desconectar o aparelho.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleRevokeOthers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.card(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: MetaColors.cardBorder(ctx)),
        ),
        title: Text(
          'Desconectar todos os outros?',
          style: TextStyle(
            color: MetaColors.text(ctx),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Todos os outros celulares, computadores e navegadores conectados à sua conta serão deslogados imediatamente, mantendo apenas este aparelho ativo.',
          style: TextStyle(color: MetaColors.subtext(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(ctx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar Todos'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRevokingOthers = true);
    final success = await DeviceSessionService.revokeAllOtherSessions();

    if (mounted) {
      setState(() => _isRevokingOthers = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas as outras sessões foram encerradas com segurança.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadSessions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao desconectar outros aparelhos.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  IconData _getPlatformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ios') || p.contains('iphone') || p.contains('ipad')) {
      return Icons.phone_iphone_rounded;
    }
    if (p.contains('android')) {
      return Icons.phone_android_rounded;
    }
    if (p.contains('web') || p.contains('browser') || p.contains('chrome') || p.contains('safari')) {
      return Icons.language_rounded;
    }
    if (p.contains('windows') || p.contains('mac') || p.contains('linux') || p.contains('desktop')) {
      return Icons.computer_rounded;
    }
    return Icons.devices_other_rounded;
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'Ativo agora';
    if (diff.inMinutes < 60) return 'Ativo há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Ativo há ${diff.inHours}h';
    return 'Último acesso em ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final sessions = _overview?.sessions ?? [];
    final otherSessionsCount = sessions.where((s) => !s.isCurrent).length;

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        title: const Text('Aparelhos Conectados'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: MetaColors.text(context),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        color: MetaColors.primaryColor(context),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Banner explicativo da proteção
                  MetaCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Proteção Anti-Fraude & Multi-Acesso',
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Você pode utilizar seu celular no salão e seu computador em casa simultaneamente. Acessos de novos aparelhos disparam alerta instantâneo via WhatsApp.',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Card de Capacidade de Sessões Simultâneas
                  if (_overview != null) ...[
                    MetaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Aparelhos Simultâneos',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _overview!.isLimitExceeded
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_overview!.activeDevicesCount} de ${_overview!.allowedConcurrentDevices} permitidos',
                                  style: TextStyle(
                                    color: _overview!.isLimitExceeded
                                        ? Colors.amber
                                        : const Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_overview!.activeDevicesCount /
                                      (_overview!.allowedConcurrentDevices > 0
                                          ? _overview!.allowedConcurrentDevices
                                          : 1))
                                  .clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _overview!.isLimitExceeded
                                    ? Colors.amber
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                          if (_overview!.warningMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _overview!.warningMessage!,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Botão de emergência Kill Switch (Desconectar outros aparelhos)
                  if (otherSessionsCount > 0) ...[
                    MetaCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Desconectar outros aparelhos',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Encerra $otherSessionsCount sessão(ões) remota(s)',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                              foregroundColor: Colors.redAccent,
                              elevation: 0,
                              side: const BorderSide(color: Colors.redAccent, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isRevokingOthers ? null : _handleRevokeOthers,
                            icon: _isRevokingOthers
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : const Icon(Icons.power_settings_new_rounded, size: 16),
                            label: const Text('Encerrar'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Lista de aparelhos
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'SESSÕES ATIVAS (${sessions.length})',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Nenhuma sessão registrada.',
                          style: TextStyle(color: MetaColors.subtext(context)),
                        ),
                      ),
                    ),

                  for (final session in sessions) ...[
                    MetaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: session.isCurrent
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getPlatformIcon(session.platform),
                                  color: session.isCurrent
                                      ? const Color(0xFF10B981)
                                      : MetaColors.text(context),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            session.deviceName,
                                            style: TextStyle(
                                              color: MetaColors.text(context),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (session.isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Este aparelho',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${session.platform} • ${_formatTimeAgo(session.lastActiveAt)}',
                                      style: TextStyle(
                                        color: MetaColors.subtext(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!session.isCurrent)
                                IconButton(
                                  tooltip: 'Desconectar este aparelho',
                                  icon: _revokingDeviceId == session.deviceId
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.redAccent,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cancel_outlined,
                                          color: Colors.redAccent,
                                          size: 22,
                                        ),
                                  onPressed: _revokingDeviceId == session.deviceId
                                      ? null
                                      : () => _handleRevokeSingle(session),
                                ),
                            ],
                          ),
                          const Divider(height: 18, thickness: 0.5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 13,
                                    color: MetaColors.subtext(context),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    session.location,
                                    style: TextStyle(
                                      color: MetaColors.subtext(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'IP: ${session.ipAddress}',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 20),
                  // Rodapé de segurança
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.cardBorder(context), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          size: 16,
                          color: MetaColors.subtext(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sessões inativas por mais de 30 dias são deslogadas automaticamente pelo sistema.',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}

