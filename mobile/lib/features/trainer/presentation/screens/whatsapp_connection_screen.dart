import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/pwa_navigation_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsappConnectionScreen extends StatefulWidget {
  final String? initialPhone;

  const WhatsappConnectionScreen({super.key, this.initialPhone});

  @override
  State<WhatsappConnectionScreen> createState() => _WhatsappConnectionScreenState();
}

class _WhatsappConnectionScreenState extends State<WhatsappConnectionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _pairingCode;
  String? _pairedPhoneDisplay;
  bool _isConnected = false;
  bool _checkingStatus = true;
  bool _isSendingTest = false;
  bool _isDisconnecting = false;
  bool _loadingTelemetry = false;
  Map<String, dynamic>? _telemetry;
  List<dynamic> _logs = [];
  Timer? _statusPollingTimer;

  @override
  void initState() {
    super.initState();
    PwaNavigationState.saveActiveSubscreen('whatsapp_connection');
    final initialPhone = widget.initialPhone?.trim();
    if (initialPhone != null && initialPhone.isNotEmpty) {
      _phoneController.text = _stripLeadingDdi55(initialPhone);
    }
    _initializeScreen();
  }

  @override
  void dispose() {
    _stopPolling();
    PwaNavigationState.clearActiveSubscreen();
    _phoneController.dispose();
    super.dispose();
  }

  String _stripLeadingDdi55(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if ((digits.length == 12 || digits.length == 13) && digits.startsWith('55')) {
      return digits.substring(2);
    }
    return digits;
  }

  String _normalizeWithDdi55(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 || digits.length == 11) {
      return '55$digits';
    }
    return digits;
  }

  
  void _startPolling() {
    _stopPolling();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _isConnected) {
        _stopPolling();
        return;
      }
      await _checkConnectionStatus(silent: true);
    });
  }

  void _stopPolling() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
  }

  Future<void> _initializeScreen() async {
    await _checkConnectionStatus();
    if (!_isConnected && mounted) {
      await _loadTrainerPhone();
    }
  }

  Future<void> _checkConnectionStatus({bool silent = false}) async {
    if (mounted && !silent) {
      setState(() => _checkingStatus = true);
    }
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawStatus = (data['status'] ??
                data['state'] ??
                data['instance']?['state'] ??
                '')
            .toString()
            .toLowerCase();
        final connected = rawStatus == 'open' ||
            rawStatus == 'connected' ||
            data['connected'] == true;

        if (mounted) {
          final wasNotConnected = !_isConnected;
          setState(() {
            _isConnected = connected;
            if (connected) {
              _pairingCode = null;
            }
          });
          if (connected) {
            _stopPolling();
            _loadTelemetryAndLogs();
            if (wasNotConnected && silent) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 WhatsApp conectado com sucesso!'),
                  backgroundColor: MetaColors.emerald,
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      // Mantém estado padrão (aguardando pareamento) caso falhe silenciosamente
    } finally {
      if (mounted && !silent) {
        setState(() => _checkingStatus = false);
      }
    }
  }

  Future<void> _loadTelemetryAndLogs() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return;
      if (mounted) setState(() => _loadingTelemetry = true);

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final telemFuture = http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/telemetry'), headers: headers)
          .timeout(const Duration(seconds: 12));
      final logsFuture = http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/logs?limit=15'), headers: headers)
          .timeout(const Duration(seconds: 12));

      final results = await Future.wait([telemFuture, logsFuture]);
      if (results[0].statusCode == 200 && mounted) {
        _telemetry = jsonDecode(results[0].body);
      }
      if (results[1].statusCode == 200 && mounted) {
        final logsData = jsonDecode(results[1].body);
        _logs = logsData['logs'] ?? [];
      }
    } catch (_) {
      // Ignora erro silencioso de telemetria
    } finally {
      if (mounted) setState(() => _loadingTelemetry = false);
    }
  }

  Future<void> _sendTestMessage() async {
    setState(() => _isSendingTest = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Sessão expirada. Faça login novamente.');

      final rawDigits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final normalizedPhone = rawDigits.isNotEmpty ? _normalizeWithDdi55(rawDigits) : null;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/test-send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (normalizedPhone != null) 'phone': normalizedPhone,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        if (!mounted) return;
        AppToast.success(
          context,
          'Mensagem de teste enviada com sucesso para o seu WhatsApp!',
          title: 'Teste Enviado',
          icon: Icons.mark_chat_read_rounded,
        );
        await _loadTelemetryAndLogs();
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Falha ao enviar teste (${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          e.toString().replaceFirst("Exception: ", ""),
          title: 'Erro de Envio',
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingTest = false);
    }
  }

  Future<void> _disconnectInstance() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.surface,
        title: const Text('Desconectar WhatsApp?', style: TextStyle(color: MetaColors.textPrimary)),
        content: const Text(
          'Isso removerá a sessão do robô no servidor para você poder gerar um novo código limpo.',
          style: TextStyle(color: MetaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: MetaColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDisconnecting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Sessão expirada.');

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/disconnect'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 && mounted) {
        _stopPolling();
        setState(() {
          _isConnected = false;
          _pairingCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp desconectado com sucesso.'),
            backgroundColor: MetaColors.surfaceHighlight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desconectar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  Future<void> _loadTrainerPhone() async {
    try {
      if (_phoneController.text.trim().isNotEmpty) {
        return;
      }

      final profile = await AuthService.getCurrentProfile();
      if (profile != null && mounted) {
        final phone = (profile['public_whatsapp'] ?? profile['phone'] ?? '').toString().trim();
        if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
          setState(() {
            _phoneController.text = _stripLeadingDdi55(phone);
          });
        }
      }
    } catch (_) {
      // Ignora erro e permite preenchimento manual
    }
  }

  Future<void> _generatePairingCode() async {
    final rawDigits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawDigits.isEmpty || rawDigits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite um número de WhatsApp válido com DDD (ex: 11999999999).'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final normalizedPhone = _normalizeWithDdi55(rawDigits);

    setState(() {
      _isLoading = true;
      _pairingCode = null;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Sessão expirada. Faça login novamente.');

      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/connect'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'number': normalizedPhone}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(response.statusCode == 503
            ? 'Integração WhatsApp ainda não está ativa no servidor.'
            : 'Não foi possível gerar o código (erro ${response.statusCode}).');
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'already_connected' || data['state'] == 'open') {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _pairingCode = null;
            _isLoading = false;
          });
          _stopPolling();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Seu WhatsApp já está conectado e online!'),
              backgroundColor: MetaColors.emerald,
            ),
          );
          _loadTelemetryAndLogs();
        }
        return;
      }

      final code = data['pairingCode'];
      if (code == null || code.toString().isEmpty) {
        throw Exception('O servidor não retornou o código de pareamento. Verifique o número e tente novamente.');
      }
      if (mounted) {
        setState(() {
          _pairingCode = code.toString();
          _pairedPhoneDisplay = '+$normalizedPhone';
          _isLoading = false;
        });
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          title: 'Pareamento',
        );
      }
    }
  }

  Future<void> _copyPairingCode() async {
    if (_pairingCode != null) {
      await Clipboard.setData(
        ClipboardData(text: _pairingCode!.replaceAll('-', '')),
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Abra "Aparelhos Conectados" no WhatsApp e cole o código copiado.',
        title: 'Código Copiado',
        icon: Icons.copy_rounded,
      );
    }
  }

  Widget _buildStatusIndicator() {
    final Color statusColor = _isConnected ? MetaColors.emerald : AppColors.warning;
    final String statusLabel = _checkingStatus
        ? 'Verificando conexão...'
        : (_isConnected ? 'Conectado • Online' : 'Aguardando pareamento');

    return GestureDetector(
      onTap: _checkingStatus ? null : _checkConnectionStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_checkingStatus)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              statusLabel,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            if (!_checkingStatus) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.refresh_rounded,
                size: 14,
                color: statusColor.withValues(alpha: 0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String badgeText,
    required String description,
  }) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MetaColors.textPrimary),
        title: Text(
          _isConnected ? 'Automação WhatsApp' : 'Conectar WhatsApp',
          style: const TextStyle(
            color: MetaColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar status',
            icon: const Icon(Icons.refresh_rounded, color: MetaColors.textPrimary),
            onPressed: () => _checkConnectionStatus(),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, MediaQuery.paddingOf(context).bottom + 24.0),
          child: _isConnected
              ? _buildConnectedSuccessView()
              : _buildPairingView(),
        ),
      ),
    );
  }

  Widget _buildConnectedSuccessView() {
    final phoneDisplay = _phoneController.text.trim().isNotEmpty
        ? '+55 ${_phoneController.text.trim()}'
        : (_pairedPhoneDisplay ?? 'Instância Própria');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildStatusIndicator(),
        const SizedBox(height: 24),

        // Glowing Pulsing Celebration Icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MetaColors.emerald.withValues(alpha: 0.12),
            border: Border.all(
              color: MetaColors.emerald.withValues(alpha: 0.45),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: MetaColors.emerald.withValues(alpha: 0.25),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_rounded,
              size: 56,
              color: MetaColors.emerald,
            ),
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.06, 1.06),
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),

        const SizedBox(height: 22),

        const Text(
          'WhatsApp Conectado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 10),

        const Text(
          'Seu robô inteligente está online 24h. Suas fichas de treino, lembretes de rotina e respostas aos alunos agora são sincronizados automaticamente pelo WhatsApp.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.textSecondary,
            fontSize: 14.5,
            height: 1.45,
          ),
        ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

        const SizedBox(height: 20),

        // Connected Phone & Active Tag Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: MetaColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: MetaColors.emerald.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android_rounded, size: 16, color: MetaColors.emerald),
              const SizedBox(width: 8),
              Text(
                phoneDisplay,
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: MetaColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Operacional 24h',
                style: TextStyle(
                  color: MetaColors.emerald,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms).scale(),

        const SizedBox(height: 26),

        // Action Buttons
        SizedBox(
          width: double.infinity,
          child: SquircleButton(
            label: _isSendingTest ? 'Disparando teste...' : '📲 Disparar Mensagem de Teste',
            icon: Icons.send_rounded,
            isPrimary: true,
            onPressed: _isSendingTest ? null : _sendTestMessage,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SquircleButton(
            label: 'Voltar ao Cockpit',
            icon: Icons.arrow_back_rounded,
            isPrimary: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isDisconnecting ? null : _disconnectInstance,
          icon: const Icon(Icons.link_off_rounded, size: 16, color: AppColors.danger),
          label: Text(
            _isDisconnecting ? 'Desconectando...' : 'Desconectar Sessão do WhatsApp',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 28),
        _buildTelemetryCard(),
        const SizedBox(height: 28),
        _buildLogsSection(),
        const SizedBox(height: 36),
        _buildAutomationsSection(),
      ],
    );
  }

  Widget _buildPairingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildStatusIndicator(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: MetaColors.surfaceHighlight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.phone_android_rounded,
            size: 48,
            color: MetaColors.emerald,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Conectar WhatsApp',
          style: TextStyle(
            color: MetaColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Como você está usando o celular, o pareamento via QR Code não é possível.\n\nConfirme seu número abaixo para gerarmos um Código de Pareamento automático de 8 dígitos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        if (_pairingCode == null) ...[
          MetaCard(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: MetaColors.textPrimary, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Seu número com DDD (Ex: 11999999999)',
                hintText: '11999999999',
                hintStyle: TextStyle(color: MetaColors.textSecondary.withValues(alpha: 0.5)),
                labelStyle: const TextStyle(color: MetaColors.textSecondary),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.message_rounded, color: MetaColors.emerald),
                suffixIcon: _phoneController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Limpar número',
                        icon: const Icon(Icons.clear_rounded, color: MetaColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _phoneController.clear();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: _isLoading ? 'Gerando...' : 'Gerar Código de Pareamento',
              icon: Icons.vpn_key_rounded,
              isPrimary: true,
              onPressed: _isLoading ? null : _generatePairingCode,
            ),
          ),
        ] else ...[
          MetaCard(
            child: Column(
              children: [
                Text(
                  _pairedPhoneDisplay != null
                      ? 'Código gerado para $_pairedPhoneDisplay:'
                      : 'Seu código de conexão:',
                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _copyPairingCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _pairingCode!,
                          style: const TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.copy_rounded, color: MetaColors.emerald),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(MetaColors.emerald),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando pareamento no seu WhatsApp...',
                      style: TextStyle(
                        color: MetaColors.emerald.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '1. Toque no código para copiar\n2. Abra as Configurações do seu WhatsApp\n3. Vá em "Aparelhos Conectados" > "Conectar Aparelho"\n4. Na tela de QR Code, clique em "Conectar com Número de Telefone" na parte inferior\n5. Cole o código copiado',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: 'Copiar código',
              icon: Icons.copy_rounded,
              isPrimary: true,
              onPressed: _copyPairingCode,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: 'Alterar número / Digitar outro telefone',
              icon: Icons.edit_rounded,
              isPrimary: false,
              onPressed: () {
                _stopPolling();
                setState(() {
                  _pairingCode = null;
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: _isLoading ? 'Gerando novo código...' : '🔄 Gerar novo código (se expirou)',
              icon: Icons.refresh_rounded,
              isPrimary: false,
              onPressed: _isLoading ? null : _generatePairingCode,
            ),
          ),
        ],

        const SizedBox(height: 40),
        _buildAutomationsSection(),
      ],
    );
  }

  Widget _buildAutomationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'AUTOMAÇÕES ATIVAS NO SEU NÚMERO',
            style: TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAutomationCard(
          icon: Icons.local_fire_department_rounded,
          accentColor: MetaColors.emerald,
          title: 'Notificador de Ficha & Ofensiva (Fase 1 & 3)',
          badgeText: 'ATIVO • CUSTO ZERO',
          description:
              'Dispara avisos de ficha nova, recuperação de alunos ausentes (Streak 🔥) e responde comandos rápidos (1 = Ver Treino, 2 = Ver Ofensiva) automaticamente.',
        ),
        const SizedBox(height: 16),
        _buildAutomationCard(
          icon: Icons.auto_awesome_rounded,
          accentColor: AppColors.warning,
          title: 'Consultor Ativo IA 24h (Fase 2)',
          badgeText: 'EXCLUSIVO PRO & STUDIO',
          description:
              'Tira dúvidas biomecânicas e sugere substituições de aparelhos pelo WhatsApp usando Gemini Flash com proteção de cota diária.',
        ),
      ],
    );
  }

  Widget _buildTelemetryCard() {
    final interactions = _telemetry?['total_interactions'] ?? 0;
    final students = _telemetry?['unique_students'] ?? 0;
    final hours = _telemetry?['hours_saved'] ?? 0.0;

    return MetaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: MetaColors.emerald, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Impacto do Robô no Mês',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (_loadingTelemetry)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Atendimentos',
                  value: '$interactions',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: MetaColors.emerald,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Alunos',
                  value: '$students',
                  icon: Icons.people_alt_outlined,
                  color: MetaColors.accentBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Poupado',
                  value: '${hours}h',
                  icon: Icons.timelapse_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: MetaColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RADAR DO ROBÔ • ATENDIMENTOS',
              style: TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            IconButton(
              tooltip: 'Atualizar histórico',
              icon: const Icon(Icons.refresh_rounded, size: 18, color: MetaColors.textSecondary),
              onPressed: _loadTelemetryAndLogs,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_logs.isEmpty)
          MetaCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: MetaColors.textSecondary.withValues(alpha: 0.7), size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nenhum atendimento registrado ainda. Dispare uma mensagem de teste no botão acima ou peça para um aluno mandar "menu" no seu WhatsApp!',
                    style: TextStyle(color: MetaColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          ..._logs.map((log) {
            final studentName = log['student_name'] ?? 'Aluno';
            final channel = log['channel'] ?? 'whatsapp';
            final msgIn = log['message_in'] ?? '';
            final msgOut = log['message_out'] ?? '';
            final isFree = log['cost_type'] == 'free';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: MetaCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              channel == 'whatsapp' ? Icons.chat_rounded : Icons.phone_android_rounded,
                              size: 14,
                              color: channel == 'whatsapp' ? MetaColors.emerald : MetaColors.accentBlue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              studentName,
                              style: const TextStyle(
                                color: MetaColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFree
                                ? MetaColors.emerald.withValues(alpha: 0.15)
                                : MetaColors.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isFree ? 'CUSTO ZERO' : 'GEMINI IA',
                            style: TextStyle(
                              color: isFree ? MetaColors.emerald : MetaColors.accentBlue,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '👤 "$msgIn"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '🤖 $msgOut',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
