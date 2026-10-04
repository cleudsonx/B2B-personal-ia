import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class WhatsappConnectionScreen extends StatefulWidget {
  const WhatsappConnectionScreen({Key? key}) : super(key: key);

  @override
  _WhatsappConnectionScreenState createState() => _WhatsappConnectionScreenState();
}

class _WhatsappConnectionScreenState extends State<WhatsappConnectionScreen> {
  bool _isLoading = false;
  String? _qrCodeBase64;
  bool _isConnected = false;

  Future<void> _fetchQrCode() async {
    setState(() {
      _isLoading = true;
      _qrCodeBase64 = null;
    });

    try {
      // Substituir pela rota correta do backend da Evolution API
      final response = await http.get(Uri.parse('https://sua-api.com/whatsapp/qr'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _qrCodeBase64 = data['qr']; // Ajustar chave conforme resposta da API
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar QR Code: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Conectar WhatsApp', style: TextStyle(color: Colors.black87)),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: padding.top + kToolbarHeight + 24,
                  bottom: padding.bottom + 24,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Integre o seu WhatsApp para enviar mensagens automáticas aos seus alunos.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_isConnected)
                      Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 80),
                          const SizedBox(height: 16),
                          Text(
                            'WhatsApp Conectado com Sucesso!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                          ),
                        ],
                      )
                    else if (_qrCodeBase64 != null)
                      Column(
                        children: [
                          Text(
                            'Escaneie o QR Code abaixo com o seu WhatsApp:',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Image.memory(
                              base64Decode(_qrCodeBase64!.split(',').last),
                              width: 250,
                              height: 250,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      )
                    else
                      Icon(
                        Icons.qr_code_scanner,
                        size: 100,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    const SizedBox(height: 48),
                    if (!_isConnected && _qrCodeBase64 == null)
                      FilledButton.tonal(
                        onPressed: _isLoading ? null : _fetchQrCode,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Gerar QR Code', style: TextStyle(fontSize: 16)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
