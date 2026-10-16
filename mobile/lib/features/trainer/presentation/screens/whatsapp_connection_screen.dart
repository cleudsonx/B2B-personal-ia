import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/config/app_config.dart';
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

  @override
  void initState() {
    super.initState();
    final initialPhone = widget.initialPhone?.trim();
    if (initialPhone != null && initialPhone.isNotEmpty) {
      _phoneController.text = _stripLeadingDdi55(initialPhone);
    }
    _initializeScreen();
  }

  @override
  void dispose() {
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

  Future<void> _initializeScreen() async {
    await _checkConnectionStatus();
    if (!_isConnected && mounted) {
      await _loadTrainerPhone();
    }
  }

  Future<void> _checkConnectionStatus() async {
    if (mounted) {
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
          setState(() {
            _isConnected = connected;
          });
        }
      }
    } catch (_) {
      // Mantém estado padrão (aguardando pareamento) caso falhe silenciosamente
    } finally {
      if (mounted) {
        setState(() => _checkingStatus = false);
      }
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado! Abra "Aparelhos Conectados" no seu WhatsApp e cole o código.'),
          backgroundColor: MetaColors.emerald,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildStatusIndicator() {
    final Color statusColor = _isConnected ? MetaColors.emerald : AppColors.warning;
    final String statusLabel = _checkingStatus
        ? 'Verificando conexão...'
        : (_isConnected ? 'Conectado • Instância Ativa' : 'Aguardando pareamento');

    return GestureDetector(
      onTap: _checkingStatus ? null : _checkConnectionStatus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
                'Como você está usando o celular, o pareamento via QR Code não é possível.\n\nConfirme seu número abaixo para gerarmos um Código de Pareamento automático.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              if (_isConnected && _pairingCode == null) ...[
                MetaCard(
                  borderColor: MetaColors.emerald.withValues(alpha: 0.4),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: MetaColors.emerald,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Seu WhatsApp está conectado!',
                        style: TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sua instância está ativa e pronta para disparar notificações de treino e responder seus alunos automaticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: 'Trocar Número / Gerar Novo Código',
                          icon: Icons.sync_rounded,
                          isPrimary: false,
                          onPressed: () {
                            setState(() {
                              _isConnected = false;
                              _pairingCode = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_pairingCode == null && !_isConnected) ...[
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
              ] else if (_pairingCode != null) ...[
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
                      const SizedBox(height: 24),
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
                      setState(() {
                        _pairingCode = null;
                      });
                    },
                  ),
                ),
              ],

              const SizedBox(height: 40),
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
          ),
        ),
      ),
    );
  }
}
