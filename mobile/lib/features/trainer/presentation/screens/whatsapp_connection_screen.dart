import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class WhatsappConnectionScreen extends StatefulWidget {
  const WhatsappConnectionScreen({super.key});

  @override
  State<WhatsappConnectionScreen> createState() =>
      _WhatsappConnectionScreenState();
}

class _WhatsappConnectionScreenState extends State<WhatsappConnectionScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  Uint8List? _qrCodeBytes;
  bool _isConnected = false;

  Future<void> _connectWhatsapp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _qrCodeBytes = null;
    });

    try {
      // Endpoint to connect WhatsApp via Evolution API in the Backend
      // TODO: Replace with the actual API endpoint / repository call using Dio/Http
      final response = await http.post(
        Uri.parse('https://api.shaipados.com/api/v1/whatsapp/connect'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"instance_name": "trainer_mr_coach"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['qrcode'] != null) {
          final base64String = data['qrcode']['base64'] as String;
          final base64Data = base64String.split(',').last; // remove data:image/png;base64, if present
          setState(() {
            _qrCodeBytes = base64Decode(base64Data);
            _isLoading = false;
          });
        } else {
          setState(() {
            _isConnected = true;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Erro ao conectar com servidor. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Falha ao gerar o QR Code: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.only(
            top: padding.top + 80,
            left: 24,
            right: 24,
            bottom: padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 64, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Conectar WhatsApp',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Sincronize seu WhatsApp para notificar seus alunos sobre treinos, pagamentos e muito mais de forma automática.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_isConnected)
                Column(
                  children: [
                    Icon(Icons.check_circle, size: 80, color: Colors.green),
                    const SizedBox(height: 16),
                    Text('WhatsApp Conectado!',
                        style: theme.textTheme.titleLarge),
                  ],
                )
              else if (_qrCodeBytes != null)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Image.memory(
                        _qrCodeBytes!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Abra o WhatsApp no seu celular, vá em Aparelhos Conectados e escaneie este código.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                FilledButton.icon(
                  onPressed: _connectWhatsapp,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'Gerar QR Code',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

