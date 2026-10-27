import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meta_components.dart';

/// Modelo de dados de um passo individual do Tour Guiado.
class TourStep {
  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<String> bulletPoints;
  final String tip;
  final String actionLabel;

  const TourStep({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.bulletPoints,
    required this.tip,
    this.actionLabel = 'Próximo Passo',
  });
}

/// Modal interativo de Onboarding & Tour Guiado em 3 Passos para Treinadores e Alunos.
///
/// Implementa o padrão visual Meta Obsidian / Light, com navegação sequencial fluida,
/// atalhos de passos táteis (step pills), persistência local via [SharedPreferences]
/// e método de verificação de primeiro acesso [checkAndShowAuto].
class InteractiveTourGuideModal extends StatefulWidget {
  final String role; // 'trainer' ou 'student' (ou 'client')
  final VoidCallback? onCompleted;
  final VoidCallback? onDismiss;

  const InteractiveTourGuideModal({
    super.key,
    required this.role,
    this.onCompleted,
    this.onDismiss,
  });

  /// Permite desabilitar o popup automático globalmente em testes automatizados.
  static bool enableAutoTour = true;
  static bool _isCheckingOrShowing = false;

  static String _storageKey(String role, String? userId) {
    final normalizedRole = (role.toLowerCase() == 'trainer' ||
            role.toLowerCase() == 'coach' ||
            role.toLowerCase() == 'personal')
        ? 'trainer'
        : 'student';
    final uid = userId?.trim().isNotEmpty == true ? userId!.trim() : 'default';
    return 'interactive_tour_completed_${normalizedRole}_$uid';
  }

  /// Verifica se o usuário já concluiu o tour interativo para o perfil especificado.
  static Future<bool> isCompleted({required String role, String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_storageKey(role, userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Marca o tour como concluído localmente no dispositivo.
  static Future<void> markCompleted({required String role, String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey(role, userId), true);
    } catch (_) {}
  }

  /// Redefine o tour para poder ser visualizado novamente.
  static Future<void> resetTour({required String role, String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey(role, userId));
    } catch (_) {}
  }

  /// Abre o modal diretamente de forma forçada ou manual (ex: botão de ajuda/tour).
  static Future<void> show(
    BuildContext context, {
    required String role,
    bool force = false,
    VoidCallback? onCompleted,
    VoidCallback? onDismiss,
  }) async {
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => InteractiveTourGuideModal(
        role: role,
        onCompleted: onCompleted,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Verifica se o usuário ainda não completou o tour e o exibe suavemente após carregar a tela.
  static Future<void> checkAndShowAuto(
    BuildContext context, {
    required String role,
    String? userId,
    Duration delay = const Duration(milliseconds: 900),
  }) async {
    if (!enableAutoTour || _isCheckingOrShowing) return;
    _isCheckingOrShowing = true;
    try {
      final alreadyDone = await isCompleted(role: role, userId: userId);
      if (!alreadyDone && context.mounted) {
        Future.delayed(delay, () {
          if (context.mounted) {
            show(
              context,
              role: role,
              onCompleted: () => markCompleted(role: role, userId: userId),
            );
          }
        });
      }
    } catch (_) {
    } finally {
      Future.delayed(const Duration(milliseconds: 1600), () {
        _isCheckingOrShowing = false;
      });
    }
  }

  @override
  State<InteractiveTourGuideModal> createState() =>
      _InteractiveTourGuideModalState();
}

class _InteractiveTourGuideModalState extends State<InteractiveTourGuideModal> {
  late final PageController _pageController;
  int _currentStep = 0;
  bool _isSaving = false;

  bool get _isTrainer =>
      widget.role.toLowerCase() == 'trainer' ||
      widget.role.toLowerCase() == 'coach' ||
      widget.role.toLowerCase() == 'personal';

  List<TourStep> get _steps => _isTrainer ? _trainerSteps : _studentSteps;

  static const List<TourStep> _trainerSteps = [
    TourStep(
      badge: 'PASSO 1 DE 3 • PRESCRIÇÃO INTELIGENTE',
      title: 'Gestão de Alunos & Fichas com IA',
      subtitle: 'Prescrição Rápida & Divisões A/B/C/D',
      description:
          'Monte rotinas completas em segundos com a IA Gemini 3.1 Pro ou organize seus splits personalizados com vídeos biomecânicos e controle de repetições de reserva.',
      icon: Icons.psychology_rounded,
      accentColor: MetaColors.emerald,
      bulletPoints: [
        'Prescrição automatizada via IA com base na anamnese e histórico.',
        'Controle de volume semanal, repetições de reserva (RIR) e RPE.',
        'Biblioteca com vídeos de execução em alta definição sem sair do app.',
      ],
      tip: 'Dica Pro: Você pode clonar e adaptar fichas entre alunos com apenas 1 toque.',
      actionLabel: 'Avançar para Vendas',
    ),
    TourStep(
      badge: 'PASSO 2 DE 3 • MÁQUINA DE VENDAS',
      title: 'Vitrine Pública /r/{slug} & Cupons',
      subtitle: 'Captação Automática de Alunos 24/7',
      description:
          'Sua página de consultoria exclusiva com checkout transparente Pix e Cartão Asaas, repasse de afiliados e gestão dinâmica de cupons promocionais.',
      icon: Icons.storefront_rounded,
      accentColor: Color(0xFF38BDF8),
      bulletPoints: [
        'Link curto personalizado (shaipados.com/#/r/seunome) para a bio.',
        'Recebimento direto via Pix com 95% do valor creditado na sua carteira.',
        'Criação de campanhas e cupons de desconto (ex: VIP50, LAUNCH20).',
      ],
      tip: 'Dica Pro: Coloque o link na sua bio do Instagram para converter seguidores 24 horas por dia.',
      actionLabel: 'Avançar para Automação',
    ),
    TourStep(
      badge: 'PASSO 3 DE 3 • ESCALABILIDADE',
      title: 'Atendimento 24h & WhatsApp VIP',
      subtitle: 'Escale sua Consultoria sem Esgotamento',
      description:
          'Notificações em tempo real no WhatsApp para cada pagamento confirmado, alertas de treinos concluídos e suporte inteligente com IA.',
      icon: Icons.mark_chat_read_rounded,
      accentColor: Color(0xFF818CF8),
      bulletPoints: [
        'Avisos instantâneos no seu WhatsApp ao receber novos pagamentos.',
        'Assistente com IA para responder dúvidas pontuais dos alunos.',
        'Radar de retenção identificando alunos com risco de abandono.',
      ],
      tip: 'Pronto! Você agora conta com a estrutura completa de uma assessoria fitness de alta escala.',
      actionLabel: 'Concluir Tour & Começar! 🚀',
    ),
  ];

  static const List<TourStep> _studentSteps = [
    TourStep(
      badge: 'PASSO 1 DE 3 • SALÃO DE TREINO',
      title: 'Treino Imersivo Edge-to-Edge',
      subtitle: '100% Tela Cheia & Registro Instantâneo',
      description:
          'Zero tarjas pretas no celular. Interface imersiva desenhada especificamente para o salão de musculação com vídeos e anotação imediata de cargas.',
      icon: Icons.fitness_center_rounded,
      accentColor: MetaColors.emerald,
      bulletPoints: [
        'Toque no exercício para ver o vídeo da execução e músculos alvo.',
        'Anotação rápida de peso (kg) e repetições série por série.',
        'Histórico da última carga usada sempre visível para você nunca esquecer.',
      ],
      tip: 'Dica: Use a opção de troca caso o aparelho da sua academia esteja ocupado.',
      actionLabel: 'Avançar para Performance',
    ),
    TourStep(
      badge: 'PASSO 2 DE 3 • EVOLUÇÃO CIENTÍFICA',
      title: 'Cronômetro 3-2-1 & Sobrecarga IA',
      subtitle: 'Intervalos Precisos & Cargas Otimizadas',
      description:
          'Cronômetro de descanso circular com alertas táteis cadenciados (3-2-1-GO!) e motor de sugestão de carga em tempo real calculado pela IA.',
      icon: Icons.timer_rounded,
      accentColor: Color(0xFFF59E0B),
      bulletPoints: [
        'Vibração no bolso nos últimos 3 segundos para você nunca perder o foco.',
        'Ajuste de RPE após a série para a IA calcular sua sobrecarga ideal.',
        'Botão para aplicar a progressão recomendada (+2.5 kg ou +1 rep) em 1 toque.',
      ],
      tip: 'Dica: O cronômetro de descanso continua ativo mesmo se você trocar de app.',
      actionLabel: 'Avançar para Conquistas',
    ),
    TourStep(
      badge: 'PASSO 3 DE 3 • PROVA SOCIAL',
      title: 'Cards de Triunfo & Viral Loop',
      subtitle: 'Compartilhe seus Recordes nos Stories',
      description:
          'Ao bater o treino do dia, comemore com o modal de triunfo e gere seu Story 9:16 com volume total, recordes (PRs) e o link do seu Personal.',
      icon: Icons.emoji_events_rounded,
      accentColor: Color(0xFFEC4899),
      bulletPoints: [
        'Celebração tátil com confetes virtuais ao finalizar o treino.',
        'Card vertical 9:16 oficial com suas marcas e ofensiva de dias seguidos.',
        'Compartilhamento instantâneo para WhatsApp e Instagram Stories.',
      ],
      tip: 'Tudo pronto! Seu aplicativo está preparado para acelerar os seus resultados.',
      actionLabel: 'Bora Treinar! 🚀',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    HapticFeedback.selectionClick();
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      await _finishTour();
    }
  }

  void _handlePrevious() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finishTour() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    await InteractiveTourGuideModal.markCompleted(role: widget.role);
    widget.onCompleted?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    InteractiveTourGuideModal.markCompleted(role: widget.role);
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  void _goToStep(int index) {
    if (index == _currentStep || index < 0 || index >= _steps.length) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bgColor = MetaColors.bg(context);
    final cardColor = MetaColors.card(context);
    final borderColor = MetaColors.cardBorder(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);
    final step = _steps[_currentStep];

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.2),
                blurRadius: 36,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Barra de arraste e cabeçalho do modal
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Ícone do ecossistema
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: step.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: step.accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            _isTrainer
                                ? Icons.business_center_rounded
                                : Icons.fitness_center_rounded,
                            size: 16,
                            color: step.accentColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isTrainer
                                  ? 'Mr. Coach • Guia do Personal'
                                  : 'Mr. Coach • Guia do Aluno',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Apresentação rápida em 3 passos',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: MetaColors.emerald.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: MetaColors.emerald.withValues(alpha: 0.3),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: const Text(
                                    '100% OFFLINE',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Botão de pular tour
                        TextButton(
                          onPressed: _handleSkip,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Pular',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Indicadores interativos de progresso (Step Pills)
                    Row(
                      children: List.generate(_steps.length, (index) {
                        final isSelected = index == _currentStep;
                        final isCompleted = index < _currentStep;
                        final stepColor = _steps[index].accentColor;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: index == _steps.length - 1 ? 0 : 8,
                            ),
                            child: InkWell(
                              onTap: () => _goToStep(index),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: 36,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? stepColor.withValues(alpha: 0.16)
                                      : (isCompleted
                                          ? MetaColors.emerald
                                              .withValues(alpha: 0.12)
                                          : cardColor),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? stepColor
                                        : (isCompleted
                                            ? MetaColors.emerald
                                                .withValues(alpha: 0.5)
                                            : borderColor),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isCompleted) ...[
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: MetaColors.emerald,
                                      ),
                                      const SizedBox(width: 4),
                                    ] else ...[
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? stepColor
                                              : (isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFCBD5E1)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Flexible(
                                      child: Text(
                                        'Passo ${index + 1}',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected
                                              ? stepColor
                                              : (isCompleted
                                                  ? MetaColors.emerald
                                                  : textSecondary),
                                          fontSize: 11,
                                          fontWeight: isSelected || isCompleted
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(color: borderColor, height: 1),

              // 2. Conteúdo deslizável dos passos (PageView)
              Flexible(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentStep = index);
                  },
                  itemBuilder: (context, index) {
                    final item = _steps[index];
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge e Ícone Hero
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      item.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        item.accentColor.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  item.badge,
                                  style: TextStyle(
                                    color: item.accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      item.accentColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: item.accentColor
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 26,
                                  color: item.accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Título e Subtítulo
                          Text(
                            item.title,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              color: item.accentColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Descrição principal
                          Text(
                            item.description,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Bullets explicativos com ícones de check
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: item.bulletPoints.map((point) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: item.accentColor
                                              .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 12,
                                          color: item.accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Box de Dica Pro / Orientação
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9))
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.tip,
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Divider(color: borderColor, height: 1),

              // 3. Rodapé de Ações de Navegação
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  16 + bottomPadding,
                ),
                child: Row(
                  children: [
                    // Botão Voltar
                    if (_currentStep > 0) ...[
                      OutlinedButton(
                        onPressed: _handlePrevious,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Voltar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Botão Próximo Passo / Concluir
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: step.accentColor,
                          foregroundColor:
                              step.accentColor == const Color(0xFFF59E0B) ||
                                      step.accentColor ==
                                          const Color(0xFF38BDF8)
                                  ? Colors.black
                                  : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    step.actionLabel,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _currentStep == _steps.length - 1
                                        ? Icons.check_circle_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 16,
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
      ),
    );
  }
}

