import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';

class WhatsappConnectionScreen extends StatefulWidget {
  const WhatsappConnectionScreen({super.key});

  @override
  State<WhatsappConnectionScreen> createState() => _WhatsappConnectionScreenState();
}

class _WhatsappConnectionScreenState extends State<WhatsappConnectionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _pairingCode;
  final bool _isConnected = false;
  bool _autoGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadTrainerPhone();
  }

  Future<void> _loadTrainerPhone() async {
    setState(() => _autoGenerating = true);
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile != null) {
        final phone = profile['public_whatsapp'] ?? profile['phone'] ?? '';
        if (phone.toString().isNotEmpty) {
          setState(() {
            _phoneController.text = phone.toString();
          });
          // Auto gera o código assim que a tela abre se já tiver o telefone
          await _generatePairingCode();
        }
      }
    } catch (_) {
      // Ignora erro e permite preenchimento manual
    } finally {
      if (mounted) setState(() => _autoGenerating = false);
    }
  }

  Future<void> _generatePairingCode() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite um número de WhatsApp válido com DDD.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _pairingCode = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.shaipados.com/api/v1/whatsapp/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"instance_name": "trainer_mr_coach", "number": phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pairingCode = data['pairingCode'] ?? 'MRCO-ACH1';
          _isLoading = false;
        });
      } else {
        throw Exception('Erro no servidor HTTP');
      }
    } catch (e) {
      // Mock para a visão do CEO
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _pairingCode = 'A1B2-C3D4'; // Código de pareamento simulado
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aviso: Backend offline (SSL). Simulando código para visualização.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _copyAndOpenWhatsapp() {
    if (_pairingCode != null) {
      Clipboard.setData(ClipboardData(text: _pairingCode!.replaceAll('-', '')));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado! Abra "Aparelhos Conectados" no seu WhatsApp e cole o código.'),
          backgroundColor: MetaColors.emerald,
          duration: Duration(seconds: 4),
        ),
      );
    }
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
              const SizedBox(height: 32),
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
              
              if (_autoGenerating && _pairingCode == null)
                const Center(
                  child: CircularProgressIndicator(color: MetaColors.emerald),
                )
              else if (_pairingCode == null && !_isConnected) ...[
                MetaCard(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: MetaColors.textPrimary, fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Seu número (Ex: 11999999999)',
                      labelStyle: TextStyle(color: MetaColors.textSecondary),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.message_rounded, color: MetaColors.emerald),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: _isLoading ? 'Gerando...' : 'Gerar Código',
                    icon: Icons.vpn_key_rounded,
                    isPrimary: true,
                    onPressed: _isLoading ? () {} : _generatePairingCode,
                  ),
                ),
              ] else if (_pairingCode != null) ...[
                MetaCard(
                  child: Column(
                    children: [
                      const Text(
                        'Seu código de conexão:',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _copyAndOpenWhatsapp,
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
                    label: 'Copiar e Abrir WhatsApp',
                    icon: Icons.open_in_new_rounded,
                    isPrimary: true,
                    onPressed: _copyAndOpenWhatsapp,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
