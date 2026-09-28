import 'package:flutter/material.dart';
import '../config/app_config.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save(String url) {
    if (url.trim().isNotEmpty) {
      AppConfig.apiBaseUrl = url.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Servidor configurado: ${AppConfig.apiBaseUrl}'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: Colors.blueAccent),
          SizedBox(width: 8),
          Text('Configurar Servidor API'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para conectar seu celular ao backend:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              '• No Celular Físico: Digite o IP local do seu computador na mesma rede Wi-Fi (ex: http://192.168.1.15:8000/api/v1).\n'
              '• No Emulador Android: Use http://10.0.2.2:8000/api/v1\n'
              '• Na Nuvem (Cloud Run / Render): Digite a URL HTTPS da API.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'URL da API Backend',
                hintText: 'http://192.168.x.x:8000/api/v1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => _save(_controller.text),
          child: const Text('Salvar e Conectar'),
        ),
      ],
    );
  }
}
