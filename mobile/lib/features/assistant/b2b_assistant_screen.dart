import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';

class B2BAssistantScreen extends StatefulWidget {
  const B2BAssistantScreen({super.key});

  @override
  State<B2BAssistantScreen> createState() => _B2BAssistantScreenState();
}

class _B2BAssistantScreenState extends State<B2BAssistantScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    'Como precificar minha consultoria online para 15 alunos?',
    'Mensagem educada de cobrança de mensalidade via WhatsApp',
    'Ideias de post no Instagram sobre substituição de exercícios',
    'Como reter alunos que faltam 3 semanas seguidas?',
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt([String? textOverride]) async {
    final text = textOverride ?? _promptCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
      if (textOverride == null) _promptCtrl.clear();
    });

    try {
      final reply = await GeminiService.askB2BAssistant(prompt: text);
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Falha ao consultar assistente: $e',
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('Assistente B2B do Personal'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_messages.isEmpty) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pergunte qualquer coisa sobre seu negócio:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dicas de vendas, consultoria online, retenção de alunos e estratégias comerciais.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPrompts.map((prompt) {
                        return ActionChip(
                          avatar: const Icon(Icons.bolt, size: 16, color: Colors.amber),
                          label: Text(prompt, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _sendPrompt(prompt),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : msg.isError
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                        border: msg.isError ? Border.all(color: Colors.red.shade200) : null,
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: msg.isError ? Colors.red.shade900 : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Gerando resposta B2B...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Digite sua dúvida de negócio...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : () => _sendPrompt(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}
