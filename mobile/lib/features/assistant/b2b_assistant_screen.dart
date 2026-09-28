import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../services/gemini_service.dart';

class B2BAssistantScreen extends StatefulWidget {
  final bool isStudentView;

  const B2BAssistantScreen({super.key, this.isStudentView = false});

  @override
  State<B2BAssistantScreen> createState() => _B2BAssistantScreenState();
}

class _B2BAssistantScreenState extends State<B2BAssistantScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  List<String> get _quickPrompts {
    if (widget.isStudentView) {
      return [
        'Como executar o Supino Inclinado com Halteres?',
        'Ver Raio-X Biomecânico do Agachamento Búlgaro',
        'Qual o ângulo ideal dos joelhos no Leg Press 45°?',
        'Como evitar dor nos ombros na Puxada Alta?',
        'Qual a cadência recomendada para hipertrofia máxima?',
      ];
    } else {
      return [
        'Como precificar minha consultoria online para 15 alunos?',
        'Mensagem educada de cobrança de mensalidade via WhatsApp',
        'Ideias de post no Instagram sobre substituição de exercícios',
        'Como reter alunos que faltam 3 semanas seguidas?',
        'Diferença biomecânica de Supino Halteres vs Supino Barra',
      ];
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  String? _detectExerciseInText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('supino') && (lower.contains('inclinado') || lower.contains('halteres'))) {
      return 'Supino Inclinado com Halteres';
    } else if (lower.contains('supino')) {
      return 'Supino Reto com Barra';
    } else if (lower.contains('agachamento') || lower.contains('búlgaro')) {
      return 'Agachamento Búlgaro';
    } else if (lower.contains('leg press')) {
      return 'Leg Press 45°';
    } else if (lower.contains('puxada') || lower.contains('lat pulldown')) {
      return 'Puxada Alta (Lat Pulldown)';
    } else if (lower.contains('remada')) {
      return 'Remada Curvada';
    } else if (lower.contains('elevação lateral')) {
      return 'Elevação Lateral';
    }
    return null;
  }

  Future<void> _sendPrompt([String? textOverride]) async {
    final text = textOverride ?? _promptCtrl.text.trim();
    if (text.isEmpty) return;

    final detectedExercise = _detectExerciseInText(text);

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        detectedExercise: detectedExercise,
      ));
      _isLoading = true;
      if (textOverride == null) _promptCtrl.clear();
    });

    try {
      final promptWithContext = widget.isStudentView
          ? 'Você é um assistente de musculação e biomecânica para alunos na academia. Responda de forma direta, clara, acolhedora e focada em segurança articular e hipertrofia: $text'
          : text;

      final reply = await GeminiService.askB2BAssistant(prompt: promptWithContext);
      final replyExercise = detectedExercise ?? _detectExerciseInText(reply);

      setState(() {
        _messages.add(_ChatMessage(
          text: reply,
          isUser: false,
          detectedExercise: replyExercise,
        ));
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isStudentView ? AppColors.studentCyan : AppColors.trainerIndigo;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Icon(
                widget.isStudentView ? Icons.fitness_center_rounded : Icons.smart_toy_outlined,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.isStudentView ? 'Assistente Biomecânico' : 'Assistente B2B do Personal',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Configurar IP do Servidor (Dev)',
              onPressed: () => ServerConfigDialog.show(context),
            ),
        ],
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
                    // Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.studentSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.06),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accentColor, width: 1.5),
                            ),
                            child: Icon(
                              widget.isStudentView ? Icons.biotech_rounded : Icons.psychology_outlined,
                              color: accentColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isStudentView
                                      ? 'Biomecânica & Raio-X Anatômico'
                                      : 'Inteligência Estratégica B2B',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.isStudentView
                                      ? 'Peça demonstrações de movimentos, ângulos seguros e cadência das fases.'
                                      : 'Pergunte sobre precificação, retenção de alunos e estratégias comerciais.',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      widget.isStudentView ? 'Dúvidas Frequentes no Salão:' : 'Sugestões de Perguntas B2B:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: _quickPrompts.map((prompt) {
                        final isBiomechanicsPrompt = prompt.contains('Raio-X') || prompt.contains('executar');
                        return ActionChip(
                          backgroundColor: AppColors.studentSurface,
                          side: BorderSide(
                            color: isBiomechanicsPrompt ? accentColor.withValues(alpha: 0.4) : AppColors.studentBorder,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          avatar: Icon(
                            isBiomechanicsPrompt ? Icons.biotech_rounded : Icons.bolt,
                            size: 15,
                            color: isBiomechanicsPrompt ? accentColor : AppColors.studentAmber,
                          ),
                          label: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              color: isBiomechanicsPrompt ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: isBiomechanicsPrompt ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.84,
                      ),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? accentColor.withValues(alpha: 0.18)
                            : msg.isError
                                ? Colors.red.shade900.withValues(alpha: 0.2)
                                : AppColors.studentSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: msg.isUser
                              ? accentColor.withValues(alpha: 0.4)
                              : msg.isError
                                  ? Colors.red.shade700
                                  : AppColors.studentBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: msg.isError ? Colors.red.shade200 : AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          // Biomechanical Split-View Trigger inside chat
                          if (msg.detectedExercise != null && !msg.isUser) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {
                                BiomechanicalAnalysisSheet.show(
                                  context,
                                  exerciseName: msg.detectedExercise!,
                                  onAskAI: () => _sendPrompt('Explique a biomecânica detalhada do ${msg.detectedExercise}'),
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.trainerIndigo.withValues(alpha: 0.25),
                                      AppColors.studentCyan.withValues(alpha: 0.15),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.studentCyan.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.biotech_rounded, size: 16, color: AppColors.studentCyan),
                                    const SizedBox(width: 8),
                                    Text(
                                      '🧬 Ver Raio-X & Fases: ${msg.detectedExercise}',
                                      style: const TextStyle(
                                        color: AppColors.studentCyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.chevron_right, size: 16, color: AppColors.studentCyan),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (msg.isError) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => ServerConfigDialog.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.settings, size: 14, color: Colors.redAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ajustar IP do Servidor',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.isStudentView ? 'Consultando Biomecânica IA...' : 'Gerando estratégia B2B...',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          // Input Box
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF070B12),
                border: Border(top: BorderSide(color: Color(0xFF161E2E))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: widget.isStudentView
                            ? 'Dúvida de execução, ângulo ou dor...'
                            : 'Digite sua dúvida de negócio...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: accentColor, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendPrompt(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
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
  final String? detectedExercise;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.detectedExercise,
  });
}
