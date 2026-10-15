import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/constants/ai_prompts.dart';
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
  String _selectedModelId = 'gemini-3.1-pro-preview';

  String _selectedPillar = 'Todos';

  List<String> get _quickPrompts {
    if (widget.isStudentView) {
      return [
        'Como executar o Supino Inclinado com Halteres?',
        'Ver Raio-X Biomecânico do Agachamento Búlgaro',
        'Qual o ângulo ideal dos joelhos no Leg Press 45°?',
        'Como evitar dor nos ombros na Puxada Alta?',
        'Qual a cadência recomendada para hipertrofia máxima?',
      ];
    }

    switch (_selectedPillar) {
      case 'Biomecânica':
        return [
          'Curva de resistência: Elevação Lateral Halter vs Polia',
          'Diferença biomecânica de Supino Halteres vs Supino Barra',
          'Ver Raio-X Biomecânico do Agachamento Búlgaro',
          'O que significa ativação de 92% sEMG no Deltoide?',
          'Como proteger o manguito rotador no supino pesado?',
        ];
      case 'Fisiologia':
        return [
          'Como aplicar RPE e RIR (repetições em reserva) na prática?',
          'Fadiga central vs periférica: quando prescrever deload?',
          'Intervalo de descanso ideal para hipertrofia: 60s vs 120s',
          'Estresse mecânico vs estresse metabólico na hipertrofia',
          'Como calcular volume de séries efetivas semanais por grupo?',
        ];
      case 'Treinamento':
        return [
          'Como prescrever Rest-Pause e Myo-Reps com segurança?',
          'Estrutura de treino Upper/Lower 4x por semana',
          'Divisão Push/Pull/Legs para aluno intermediário',
          'Periodização ondulatória diária (DUP) para hipertrofia',
          'Estratégia para corrigir ponto fraco em deltoides e dorsais',
        ];
      case 'Negócios B2B':
        return [
          r'Como precificar consultoria híbrida recorrente (R$ 180-250/mês)?',
          'Script de WhatsApp para reengajar aluno ausente há 15 dias',
          'Mensagem elegante de cobrança e renovação de ciclo',
          'Como apresentar os relatórios de IA para valorizar meu serviço?',
          'Como escalar de 15 para 50 alunos sem sobrecarga de horário?',
        ];
      default: // 'Todos'
        return [
          'Curva de resistência: Elevação Lateral Halter vs Polia',
          'Como aplicar RIR e RPE para controle de fadiga?',
          'Como prescrever Rest-Pause e Myo-Reps com segurança?',
          'Como precificar consultoria online recorrente?',
          'Script de WhatsApp para reengajar aluno ausente',
          'Diferença biomecânica de Supino Halteres vs Barra',
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
    if (lower.contains('supino') &&
        (lower.contains('inclinado') || lower.contains('halteres') || lower.contains('halter'))) {
      return 'Supino Inclinado com Halteres';
    } else if (lower.contains('supino')) {
      return 'Supino Reto com Barra';
    } else if (lower.contains('agachamento') || lower.contains('búlgaro') || lower.contains('bulgaro')) {
      return 'Agachamento Búlgaro';
    } else if (lower.contains('leg press') || lower.contains('legpress')) {
      return 'Leg Press 45°';
    } else if (lower.contains('puxada') || lower.contains('lat pulldown') || lower.contains('pulldown')) {
      return 'Puxada Alta (Lat Pulldown)';
    } else if (lower.contains('remada')) {
      return 'Remada Curvada';
    } else if (lower.contains('elevação lateral') || lower.contains('elevacao lateral')) {
      return 'Elevação Lateral';
    }
    return null;
  }

  String _generateBiomechanicsFallback(String exercise) {
    switch (exercise) {
      case 'Supino Inclinado com Halteres':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Peitoral Maior (Fibras Claviculares/Superior) e Deltóide Anterior.\n'
            '📐 **Ângulo do Banco:** Ajuste entre 30° e 45° (mais que isso transfere excesso de estresse para os ombros).\n'
            '⚡ **Fase Excêntrica (Descida):** Desça os halteres de forma controlada (2 a 3 segundos), mantendo os cotovelos a ~60° do tronco para proteger o manguito rotador.\n'
            '💥 **Fase Concêntrica (Subida):** Empurre convergindo suavemente os halteres sem bater no topo, mantendo o peitoral sob tensão mecânica contínua.\n'
            '🔒 **Segurança Biomecânica:** Mantenha as escápulas aduzidas e deprimidas durante todo o movimento.';
      case 'Agachamento Búlgaro':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Quadríceps e Glúteo Máximo.\n'
            '📐 **Posicionamento:** Pé traseiro no banco pelo peito do pé. Tronco levemente inclinado à frente para maior recrutamento glúteo.\n'
            '⚡ **Descida:** Desça verticalmente até o joelho traseiro quase encostar no solo, sem permitir valgo dinâmico.\n'
            '💥 **Subida:** Empurre firme através do calcanhar do pé dianteiro mantendo a pelve nivelada.\n'
            '🔒 **Segurança:** Mantenha o core rígido e olhar alinhado com o horizonte.';
      case 'Leg Press 45°':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Quadríceps, Glúteo Máximo e Isquiotibiais.\n'
            '📐 **Pés na Plataforma:** Largura dos ombros, pontas levemente rotacionadas para fora (~15°).\n'
            '⚡ **Descida:** Amplitude máxima sem descolar a região lombar do encosto (retroversão pélvica).\n'
            '💥 **Subida:** Empurre com a planta dos pés sem hiperextender ou travar os joelhos no final.\n'
            '🔒 **Segurança:** Nunca apoie as mãos nos joelhos durante cargas pesadas.';
      case 'Puxada Alta (Lat Pulldown)':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Latíssimo do Dorso (Dorsal) e Redondo Maior.\n'
            '📐 **Pegada:** Pouco além da largura dos ombros.\n'
            '⚡ **Puxada:** Puxe a barra em direção à porção superior do esterno, guiando com os cotovelos para baixo e para dentro.\n'
            '⚡ **Retorno:** Controle a fase excêntrica até alongar as dorsais sem elevar os ombros às orelhas.\n'
            '🔒 **Segurança:** Não puxe a barra atrás da nuca para não comprimir a cápsula anterior do ombro.';
      default:
        return 'Aqui está a análise biomecânica recomendada para o **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Fibras primárias e estabilizadores articulares.\n'
            '⚡ **Cadência:** 3 segundos de descida excêntrica com 1 segundo de pico isométrico.\n'
            '🔒 **Segurança:** Mantenha as escápulas alinhadas e evite impulsos do tronco durante a execução.';
    }
  }

  Future<void> _sendPrompt([String? textOverride]) async {
    final text = textOverride ?? _promptCtrl.text.trim();
    if (text.isEmpty) return;

    final detectedExercise = _detectExerciseInText(text);

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
          detectedExercise: detectedExercise,
        ),
      );
      _isLoading = true;
      if (textOverride == null) _promptCtrl.clear();
    });

    try {
      final promptWithContext =
          widget.isStudentView
              ? 'Por favor, me ajude de forma clara e acessível: $text'
              : text;

      final reply = await GeminiService.askB2BAssistant(
        prompt: promptWithContext,
        systemInstruction:
            widget.isStudentView
                ? AiPrompts.expertStudentPersona
                : AiPrompts.expertTrainerPersona,
        model: _selectedModelId,
      );
      if (!mounted) return;
      final replyExercise = detectedExercise ?? _detectExerciseInText(reply);

      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
            detectedExercise: replyExercise,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Aviso Gemini Assistant (ativando motor biomecânico local): $e');

      final fallbackExercise = detectedExercise;
      final String fallbackText;

      if (fallbackExercise != null) {
        fallbackText = _generateBiomechanicsFallback(fallbackExercise);
      } else {
        fallbackText = widget.isStudentView
            ? 'Estou temporariamente reconectando ao servidor em nuvem. Como posso te orientar na execução, postura ou biomecânica de algum exercício específico hoje?'
            : 'Conexão com o servidor da IA oscilou. Tente novamente em instantes ou consulte as diretrizes nos cards acima.';
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: fallbackText,
            isUser: false,
            detectedExercise: fallbackExercise,
            isError: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isStudentView ? MetaColors.emerald : AppColors.trainerIndigo;

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        backgroundColor: MetaColors.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.25),
                    MetaColors.accentBlue.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.isStudentView ? Icons.biotech_rounded : Icons.smart_toy_outlined,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.isStudentView ? 'Mr. Coach AI' : 'Mr. Coach B2B',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: MetaColors.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ATIVO',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.isStudentView
                        ? 'Laboratório Biomecânico & Ativação 3D'
                        : 'Inteligência Comercial & Prescrição',
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: MetaColors.subtext(context),
                size: 22,
              ),
              tooltip: 'Nova Análise / Limpar Chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
          if (!widget.isStudentView)
            PopupMenuButton<String>(
              icon: Icon(
                _selectedModelId.contains('pro') ? Icons.psychology : Icons.bolt,
                color: accentColor,
              ),
              tooltip: 'Selecionar Modelo de IA',
              onSelected: (val) => setState(() => _selectedModelId = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'gemini-3.1-pro-preview',
                  child: Row(
                    children: [
                      Icon(Icons.psychology, size: 18),
                      SizedBox(width: 8),
                      Text('Gemini 3.1 Pro (Deep Thinking)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'gemini-2.5-flash',
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 18),
                      SizedBox(width: 8),
                      Text('Gemini 2.5 Flash (Fast)'),
                    ],
                  ),
                ),
              ],
            ),
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO SPOTLIGHT CARD (Estilo Nike Training Club / Whoop)
                    _buildHeroSpotlightCard(context, accentColor),
                    const SizedBox(height: 20),

                    // 2. GRADE DE AÇÕES RÁPIDAS 2x2 (Estilo Google Gemini & Apple Fitness+)
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 15,
                          color: MetaColors.subtext(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AÇÕES RÁPIDAS DE ACADEMIA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: MetaColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildActionGrid(context),
                    const SizedBox(height: 24),

                    // 3. CARROSSEL DE PROMPTS SUGERIDOS (Estilo Chips Inteligentes)
                    _buildPromptsSection(context, accentColor),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment:
                        msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.84,
                      ),
                      decoration: BoxDecoration(
                        color:
                            msg.isUser
                                ? accentColor.withValues(alpha: 0.18)
                                : msg.isError
                                ? Colors.red.shade900.withValues(alpha: 0.2)
                                : AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              msg.isUser
                                  ? accentColor.withValues(alpha: 0.4)
                                  : msg.isError
                                  ? Colors.red.shade700
                                  : AppColors.cardBorder(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  msg.isError
                                      ? Colors.red.shade200
                                      : AppColors.text(context),
                              height: 1.4,
                            ),
                          ),
                          // Card de Execução Biomecânica em Loop + Músculo Alvo (Padrão Ouro Mr. Coach AI)
                          if (msg.detectedExercise != null && !msg.isUser) ...[
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: MetaColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: MetaColors.emerald.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mini Banner com animação de loop
                                  Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Efeito visual de gradiente e pulso biomecânico
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              colors: [
                                                MetaColors.emerald.withValues(alpha: 0.25),
                                                Colors.transparent,
                                              ],
                                              radius: 0.8,
                                            ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: MetaColors.emerald.withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: MetaColors.emerald),
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.repeat_rounded, size: 12, color: Colors.white70),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Demonstração Biomecânica em Loop',
                                                  style: TextStyle(
                                                    color: MetaColors.emerald,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 8),
                                                SizedBox(width: 4),
                                                Text(
                                                  '3D LOOP',
                                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Informações de Músculo Alvo & Execução
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.detectedExercise!,
                                          style: TextStyle(
                                            color: MetaColors.text(context),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.adjust_rounded, size: 12, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Músculo Alvo: Fibras Primárias',
                                                    style: TextStyle(
                                                      color: MetaColors.emerald,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () {
                                            BiomechanicalAnalysisSheet.show(
                                              context,
                                              exerciseName: msg.detectedExercise!,
                                              onAskAI: () => _sendPrompt(
                                                'Explique a biomecânica detalhada do ${msg.detectedExercise}',
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: MetaColors.emerald,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.biotech_rounded, size: 16, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Abrir Raio-X & Análise de Ângulos',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (msg.isError && kDebugMode) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => ServerConfigDialog.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: MetaColors.bg(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.isStudentView
                        ? 'Analisando biomecânica & torque articular...'
                        : 'Estruturando inteligência prescritiva...',
                    style: TextStyle(
                      fontSize: 12,
                      color: MetaColors.subtext(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // BARRA INFERIOR DE DIGITAÇÃO FLUTUANTE (Ergonômica & Estilo Meta Obsidian)
          _buildFloatingPromptBar(context, accentColor),
        ],
      ),
    );
  }

  /// 1. Hero Spotlight Card - Visual de alta tecnologia, gradiente escuro e CTA direto
  Widget _buildHeroSpotlightCard(BuildContext context, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A), // Dark Slate
            const Color(0xFF042F2E), // Deep Teal
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: MetaColors.emerald.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: MetaColors.emerald,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isStudentView ? 'MOTOR BIOMECÂNICO 3D' : 'MR. COACH ENTERPRISE',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.isStudentView
                ? 'Qual movimento você quer analisar agora?'
                : 'Inteligência Estratégica & Biomecânica',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isStudentView
                ? 'Consulte ângulos ideais, ativação sEMG muscular, cadência das fases e alternativas se o aparelho estiver ocupado.'
                : 'Prescrição de alta performance, fisiologia de hipertrofia, precificação de planos e engajamento no WhatsApp.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Botão Interativo do Hero Card
          InkWell(
            onTap: () {
              BiomechanicalAnalysisSheet.show(
                context,
                exerciseName: 'Agachamento Búlgaro',
                onAskAI: () => _sendPrompt(
                  'Explique a biomecânica detalhada do Agachamento Búlgaro e correção de postura',
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MetaColors.emerald,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: MetaColors.emerald.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.view_in_ar_rounded,
                    size: 16,
                    color: Colors.black,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Explorar Raio-X 3D em Tempo Real',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Grade de Ações Rápidas 2x2 com cards funcionais inspirados no Gemini e Apple Fitness+
  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      _ActionItem(
        title: 'Postura & Ângulos',
        subtitle: 'Cotovelos no Supino, Joelhos no Leg',
        icon: Icons.architecture_rounded,
        color: MetaColors.accentBlue,
        onTap: () => _sendPrompt(
          'Qual o ângulo ideal dos joelhos no Leg Press 45° e cotovelos no Supino para evitar lesões?',
        ),
      ),
      _ActionItem(
        title: 'Raio-X Muscular 3D',
        subtitle: 'Ativação sEMG e curva de força',
        icon: Icons.biotech_rounded,
        color: MetaColors.emerald,
        onTap: () {
          BiomechanicalAnalysisSheet.show(
            context,
            exerciseName: 'Supino Inclinado com Halteres',
            onAskAI: () => _sendPrompt(
              'Explique a biomecânica e ativação muscular do Supino Inclinado com Halteres',
            ),
          );
        },
      ),
      _ActionItem(
        title: 'Aparelho Ocupado?',
        subtitle: 'Substituição imediata no salão',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFFF59E0B), // Âmbar
        onTap: () => _sendPrompt(
          'O aparelho de treino está ocupado na academia. Quais as melhores variações mantendo o mesmo estímulo muscular?',
        ),
      ),
      _ActionItem(
        title: 'Cadência & RIR',
        subtitle: 'Tempo sob tensão e hipertrofia',
        icon: Icons.speed_rounded,
        color: const Color(0xFFA855F7), // Roxo
        onTap: () => _sendPrompt(
          'Qual a cadência recomendada e como aplicar repetições em reserva (RIR) para hipertrofia máxima?',
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.color,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 3. Seção de Prompts Sugeridos com Carrossel e Pilares de Conhecimento
  Widget _buildPromptsSection(BuildContext context, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isStudentView) ...[
          Row(
            children: [
              Icon(
                Icons.category_rounded,
                size: 15,
                color: MetaColors.subtext(context),
              ),
              const SizedBox(width: 6),
              Text(
                'PILARES DO TREINADOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: MetaColors.subtext(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPillarChip(context, 'Todos', Icons.auto_awesome, accentColor),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Biomecânica', Icons.biotech_rounded, MetaColors.accentBlue),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Fisiologia', Icons.bolt, Colors.amber),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Treinamento', Icons.fitness_center_rounded, Colors.orange),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Negócios B2B', Icons.trending_up_rounded, MetaColors.emerald),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 15,
              color: MetaColors.subtext(context),
            ),
            const SizedBox(width: 6),
            Text(
              widget.isStudentView
                  ? 'PERGUNTAS FREQUENTES NO SALÃO'
                  : 'PROMPTS SUGERIDOS ($_selectedPillar)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: MetaColors.subtext(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Carrossel Horizontal de Chips Estilizados
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _quickPrompts.map((prompt) {
              final is3d = prompt.contains('Raio-X') || prompt.contains('Supino');
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: MetaColors.card(context),
                  side: BorderSide(
                    color: is3d
                        ? accentColor.withValues(alpha: 0.4)
                        : MetaColors.cardBorder(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  avatar: Icon(
                    is3d ? Icons.biotech_rounded : Icons.bolt_rounded,
                    size: 15,
                    color: is3d ? accentColor : Colors.amber,
                  ),
                  label: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: is3d ? MetaColors.text(context) : MetaColors.subtext(context),
                      fontWeight: is3d ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _sendPrompt(prompt),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Barra Flutuante de Envio de Mensagem no padrão ergonômico Meta
  Widget _buildFloatingPromptBar(BuildContext context, Color accentColor) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MetaColors.bg(context),
          border: Border(
            top: BorderSide(color: MetaColors.cardBorder(context), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: MetaColors.cardBorder(context),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _promptCtrl,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isStudentView
                        ? 'Dúvida de execução, ângulo, dor ou troca...'
                        : 'Digite sua dúvida de prescrição ou negócio...',
                    hintStyle: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.smart_toy_outlined,
                      size: 18,
                      color: MetaColors.subtext(context),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendPrompt(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: MetaColors.emerald,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MetaColors.emerald.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.black),
                onPressed: _isLoading ? null : () => _sendPrompt(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarChip(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedPillar == title;
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : color),
      label: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? Colors.black : MetaColors.text(context),
        ),
      ),
      backgroundColor: MetaColors.card(context),
      selectedColor: color,
      side: BorderSide(
        color: isSelected ? color : MetaColors.cardBorder(context),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => setState(() => _selectedPillar = title),
    );
  }
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
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
