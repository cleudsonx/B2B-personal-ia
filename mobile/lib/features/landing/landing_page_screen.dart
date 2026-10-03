import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../auth/login_screen.dart';

/// Landing Page oficial de conversão e vendas do Mr. Coach (B2B Personal IA).
///
/// Diretrizes Visuais:
/// - Material You (M3 Expressivo) com tons pastéis Menta (#98FF98) e Pêssego (#FFDAB9).
/// - Zero sombras artificiais (Flat com bordas de 1px sutis).
/// - Cantos super arredondados (24px a 32px e Pills 100px).
/// - Hero com Mega Botão de WhatsApp convidativo e direto.
/// - Arquitetura Edge-to-Edge estrita (sem SafeArea envolvendo o Scaffold).
class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  final ScrollController _scrollController = ScrollController();
  static const String _whatsappNumber = '5511999998888';
  static const String _defaultWaMessage =
      'Olá! Quero conhecer o Mr. Coach IA e testar a plataforma na minha consultoria fitness.';

  Future<void> _openWhatsApp([String? customMessage]) async {
    final text = Uri.encodeComponent(customMessage ?? _defaultWaMessage);
    final url = Uri.parse('https://wa.me/$_whatsappNumber?text=$text');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Abrindo canal do WhatsApp: wa.me/$_whatsappNumber'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 680 && size.width < 1024;
    final horizontalPadding = isDesktop ? 64.0 : (isTablet ? 32.0 : 20.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Sincronização dinâmica da SystemBar para Edge-to-Edge nativo
    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        body: Stack(
          children: [
            // Conteúdo Rolável Principal
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // 1. Barra de Navegação Flutuante / Topo
                SliverToBoxAdapter(
                  child: _Navbar(
                    onLoginTap: _navigateToLogin,
                    onWhatsAppTap: () => _openWhatsApp(
                      'Olá! Gostaria de falar com o time comercial do Mr. Coach.',
                    ),
                    horizontalPadding: horizontalPadding,
                  ),
                ),

                // 2. Seção Hero com o Mega Botão de WhatsApp
                SliverToBoxAdapter(
                  child: _HeroSection(
                    horizontalPadding: horizontalPadding,
                    isDesktop: isDesktop,
                    onWhatsAppPrimaryTap: () => _openWhatsApp(),
                    onLoginTap: _navigateToLogin,
                  ),
                ),

                // 3. Faixa de Métricas e Prova Social
                SliverToBoxAdapter(
                  child: _MetricsStrip(horizontalPadding: horizontalPadding),
                ),

                // 4. Bento Grid: Diferenciais & Recursos
                SliverToBoxAdapter(
                  child: _BentoGridFeatures(
                    horizontalPadding: horizontalPadding,
                    isDesktop: isDesktop,
                  ),
                ),

                // 5. Como Funciona (3 Passos)
                SliverToBoxAdapter(
                  child: _HowItWorksSection(
                    horizontalPadding: horizontalPadding,
                    onWhatsAppTap: () => _openWhatsApp(
                      'Quero iniciar meu teste gratuito de 3 passos no WhatsApp!',
                    ),
                  ),
                ),

                // 6. Depoimentos de Personals
                SliverToBoxAdapter(
                  child: _TestimonialsSection(
                    horizontalPadding: horizontalPadding,
                    isDesktop: isDesktop,
                  ),
                ),

                // 7. Planos & Preços com CTA WhatsApp
                SliverToBoxAdapter(
                  child: _PricingSection(
                    horizontalPadding: horizontalPadding,
                    isDesktop: isDesktop,
                    onSelectPlan: (plan) => _openWhatsApp(
                      'Olá! Quero assinar o plano $plan do Mr. Coach com condição especial de lançamento.',
                    ),
                  ),
                ),

                // 8. FAQ Acordeão
                SliverToBoxAdapter(
                  child: _FaqSection(
                    horizontalPadding: horizontalPadding,
                    onWhatsAppTap: () => _openWhatsApp(
                      'Oi, tenho uma dúvida sobre a plataforma antes de começar.',
                    ),
                  ),
                ),

                // 9. Mega Rodapé Institucional
                SliverToBoxAdapter(
                  child: _FooterSection(
                    horizontalPadding: horizontalPadding,
                    bottomInset: bottomInset + 80.0, // Espaço para o Floating CTA
                    onWhatsAppTap: () => _openWhatsApp(),
                    onLoginTap: _navigateToLogin,
                  ),
                ),
              ],
            ),

            // 10. Botão Flutuante de WhatsApp Fixo no Canto Inferior Direito
            Positioned(
              right: 20,
              bottom: bottomInset + 20,
              child: _FloatingWhatsAppCta(
                onTap: () => _openWhatsApp(
                  'Olá! Estou navegando na página e gostaria de tirar uma dúvida rápida.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. NAVBAR
// ============================================================================
class _Navbar extends StatelessWidget {
  final VoidCallback onLoginTap;
  final VoidCallback onWhatsAppTap;
  final double horizontalPadding;

  const _Navbar({
    required this.onLoginTap,
    required this.onWhatsAppTap,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isSmall = MediaQuery.sizeOf(context).width < 640;

    return Container(
      margin: EdgeInsets.only(
        top: topPadding + 14,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.cardBorder(context), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Marca & Logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.emerald(context).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.sports_gymnastics_rounded,
                  color: AppColors.emerald(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'MR. COACH',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tangerineBg(context),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'IA B2B',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.tangerine(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Para Personal Trainers',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.subtext(context),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Ações do Topo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ThemeToggleButton(compact: true),
              const SizedBox(width: 8),
              if (!isSmall)
                TextButton(
                  onPressed: onLoginTap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text(context),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text(
                    'Já sou Treinador',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(width: 8),
              // CTA Rápido Navbar
              InkWell(
                onTap: onWhatsAppTap,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldBg(context),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppColors.emerald(context).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WhatsAppIcon(size: 16, color: AppColors.emerald(context)),
                      const SizedBox(width: 6),
                      Text(
                        isSmall ? 'WhatsApp' : 'Falar no WhatsApp',
                        style: TextStyle(
                          color: AppColors.emerald(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. HERO SECTION COM O MEGA BOTÃO DE WHATSAPP
// ============================================================================
class _HeroSection extends StatelessWidget {
  final double horizontalPadding;
  final bool isDesktop;
  final VoidCallback onWhatsAppPrimaryTap;
  final VoidCallback onLoginTap;

  const _HeroSection({
    required this.horizontalPadding,
    required this.isDesktop,
    required this.onWhatsAppPrimaryTap,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isDesktop ? 48 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Tag de Destaque Superior (Pill Pastel Menta & Pêssego)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppColors.emerald(context).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.emerald(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'NOVA ERA FITNESS: GOOGLE GEMINI 3.8 + FASTAPI EM TEMPO REAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.emerald(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Headline Principal
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isDesktop ? 48 : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.15,
                    color: AppColors.text(context),
                  ),
                  children: [
                    const TextSpan(text: 'Prescreva treinos em '),
                    WidgetSpan(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.emerald(context).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '30 segundos',
                          style: TextStyle(
                            fontSize: isDesktop ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.emerald(context),
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' e seus alunos '),
                    WidgetSpan(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.tangerineBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.tangerine(context).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'nunca mais travam',
                          style: TextStyle(
                            fontSize: isDesktop ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tangerine(context),
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' no salão de musculação.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Subtítulo com Proposta de Valor
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'A primeira plataforma inteligente que cria periodizações personalizadas baseadas em anamnese clínica e permite que o aluno adapte exercícios ocupados ou com dor em 1 toque, com a segurança do mesmo vetor motor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 17 : 14,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: AppColors.subtext(context),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ===============================================================
              // 4. O MEGA BOTÃO DE WHATSAPP (ELEMENTO CHAVE DE VENDA)
              // ===============================================================
              _MegaWhatsAppHeroButton(onTap: onWhatsAppPrimaryTap),

              const SizedBox(height: 20),

              // 5. Garantias & Microcopy Tranquilizadora
              Wrap(
                alignment: WrapAlignment.center,
                crossBytes: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  _HeroMicroBadge(
                    icon: Icons.bolt_rounded,
                    label: 'Ativação imediata em 1 minuto',
                  ),
                  _HeroMicroBadge(
                    icon: Icons.credit_card_off_rounded,
                    label: 'Sem cartão de crédito',
                  ),
                  _HeroMicroBadge(
                    icon: Icons.verified_user_outlined,
                    label: '100% de controle pelo Personal',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MEGA BOTÃO WHATSAPP (COMPONENTE DE ALTA CONVERSÃO)
// ============================================================================
class _MegaWhatsAppHeroButton extends StatefulWidget {
  final VoidCallback onTap;

  const _MegaWhatsAppHeroButton({required this.onTap});

  @override
  State<_MegaWhatsAppHeroButton> createState() => _MegaWhatsAppHeroButtonState();
}

class _MegaWhatsAppHeroButtonState extends State<_MegaWhatsAppHeroButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;

    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(maxWidth: 620),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 26 : 18,
              vertical: isDesktop ? 20 : 16,
            ),
            decoration: BoxDecoration(
              // Sem sombras! Tons pastéis suaves com gradiente linear sutil
              gradient: LinearGradient(
                colors: _isHovered
                    ? [
                        AppColors.emerald(context).withValues(alpha: 0.28),
                        AppColors.emerald(context).withValues(alpha: 0.16),
                      ]
                    : [
                        AppColors.emeraldBg(context),
                        AppColors.emeraldBg(context).withValues(alpha: 0.7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(100), // Pill Shape generoso
              border: Border.all(
                color: _isHovered
                    ? AppColors.emerald(context)
                    : AppColors.emerald(context).withValues(alpha: 0.6),
                width: _isHovered ? 2.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Ícone Grande do WhatsApp em Container Circular
                Container(
                  width: isDesktop ? 56 : 46,
                  height: isDesktop ? 56 : 46,
                  decoration: BoxDecoration(
                    color: AppColors.emerald(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _WhatsAppIcon(
                      size: isDesktop ? 28 : 22,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 18 : 12),

                // Conteúdo Textual de Alta Intenção
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge "Online agora"
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ONLINE AGORA • RESPOSTA EM 2 MIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: AppColors.text(context).withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Título Principal Convidativo
                      Text(
                        'QUERO TESTAR GRÁTIS NO WHATSAPP',
                        style: TextStyle(
                          fontSize: isDesktop ? 17 : 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Subtexto sem fricção
                      Text(
                        'Inicie seu teste gratuito em 1 clique • Fale direto com o especialista',
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ícone de Ação / Flecha
                Container(
                  width: isDesktop ? 38 : 30,
                  height: isDesktop ? 38 : 30,
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cardBorder(context),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: isDesktop ? 20 : 16,
                    color: AppColors.emerald(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMicroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMicroBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pillBg(context),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.pillBorder(context), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.emerald(context)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. FAIXA DE MÉTRICAS & PROVA SOCIAL
// ============================================================================
class _MetricsStrip extends StatelessWidget {
  final double horizontalPadding;

  const _MetricsStrip({required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.cardBorder(context), width: 1),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                if (isNarrow) {
                  return Column(
                    children: const [
                      _MetricItem(number: '+2.400', label: 'Treinos gerados via IA'),
                      Divider(height: 24),
                      _MetricItem(number: '30s', label: 'Tempo médio de periodização'),
                      Divider(height: 24),
                      _MetricItem(number: '99.4%', label: 'Acurácia biomecânica'),
                      Divider(height: 24),
                      _MetricItem(number: '3x', label: 'Mais alunos por treinador'),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _MetricItem(number: '+2.400', label: 'Treinos gerados via IA'),
                    _VerticalDivider(),
                    _MetricItem(number: '30s', label: 'Tempo médio de periodização'),
                    _VerticalDivider(),
                    _MetricItem(number: '99.4%', label: 'Acurácia biomecânica'),
                    _VerticalDivider(),
                    _MetricItem(number: '3x', label: 'Mais alunos por treinador'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String number;
  final String label;

  const _MetricItem({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.subtext(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: AppColors.cardBorder(context),
    );
  }
}

// ============================================================================
// 4. BENTO GRID: RECURSOS & VALOR
// ============================================================================
class _BentoGridFeatures extends StatelessWidget {
  final double horizontalPadding;
  final bool isDesktop;

  const _BentoGridFeatures({
    required this.horizontalPadding,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              // Cabeçalho da Seção
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.tangerineBg(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'ARQUITETURA INTELIGENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.tangerine(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tudo o que sua consultoria precisa para escalar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Projetado especificamente para a rotina caótica de personal trainers no WhatsApp e salões de musculação.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.subtext(context),
                ),
              ),
              const SizedBox(height: 36),

              // Grid Bento
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 768;
                  if (isWide) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _BentoCard(
                                isMint: true,
                                icon: Icons.auto_awesome_rounded,
                                tag: 'PRESCRIÇÃO COM IA',
                                title: 'Splits A, B, C e Periodização em 30 Segundos',
                                description:
                                    'Diga adeus às planilhas lentas. Nossa IA baseada no Gemini 3.8 lê as metas e monta divisões completas, séries, repetições e intervalos científicos.',
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: _BentoCard(
                                isMint: false,
                                icon: Icons.change_circle_rounded,
                                tag: 'SALVADOR DO ALUNO',
                                title: 'Botão de Pânico: Aparelho Ocupado ou Dor',
                                description:
                                    'Se o leg press estiver lotado ou houver desconforto no joelho, o aluno toca no botão e a IA sugere na hora uma variação com o mesmo vetor motor.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _BentoCard(
                                isMint: false,
                                icon: Icons.medical_services_outlined,
                                tag: 'SEGURANÇA TOTAL',
                                title: 'Blindagem de Lesões & Restrições',
                                description:
                                    'O aluno tem hérnia lombar ou impacto no ombro? A anamnese filtra e bloqueia automaticamente qualquer exercício de risco contraindicado.',
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 6,
                              child: _BentoCard(
                                isMint: true,
                                icon: Icons.hub_rounded,
                                tag: 'RETENÇÃO & AUDITORIA',
                                title: 'Painel Central do Personal & Notificações',
                                description:
                                    'Veja em tempo real quem treinou, quais exercícios foram adaptados e receba relatórios prontos para mandar aos seus alunos no WhatsApp.',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  // Layout Mobile Coluna Única
                  return Column(
                    children: [
                      _BentoCard(
                        isMint: true,
                        icon: Icons.auto_awesome_rounded,
                        tag: 'PRESCRIÇÃO COM IA',
                        title: 'Splits A, B, C e Periodização em 30 Segundos',
                        description:
                            'Diga adeus às planilhas lentas. Nossa IA lê metas e monta divisões completas, repetições e intervalos científicos.',
                      ),
                      const SizedBox(height: 14),
                      _BentoCard(
                        isMint: false,
                        icon: Icons.change_circle_rounded,
                        tag: 'SALVADOR DO ALUNO',
                        title: 'Botão de Pânico: Aparelho Ocupado ou Dor',
                        description:
                            'Se o leg press estiver lotado, o aluno toca no botão e a IA sugere na hora uma variação biomecânica equivalente.',
                      ),
                      const SizedBox(height: 14),
                      _BentoCard(
                        isMint: false,
                        icon: Icons.medical_services_outlined,
                        tag: 'SEGURANÇA TOTAL',
                        title: 'Blindagem de Lesões & Restrições',
                        description:
                            'Filtro rigoroso de contraindicações articulares baseado em anamnese clínica detalhada.',
                      ),
                      const SizedBox(height: 14),
                      _BentoCard(
                        isMint: true,
                        icon: Icons.hub_rounded,
                        tag: 'RETENÇÃO & AUDITORIA',
                        title: 'Painel Central do Personal & Notificações',
                        description:
                            'Acompanhe adesão, evolução e adaptações em tempo real pelo seu painel administrativo.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final bool isMint;
  final IconData icon;
  final String tag;
  final String title;
  final String description;

  const _BentoCard({
    required this.isMint,
    required this.icon,
    required this.tag,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isMint ? AppColors.emerald(context) : AppColors.tangerine(context);
    final accentBg = isMint ? AppColors.emeraldBg(context) : AppColors.tangerineBg(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: AppColors.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. COMO FUNCIONA (3 PASSOS)
// ============================================================================
class _HowItWorksSection extends StatelessWidget {
  final double horizontalPadding;
  final VoidCallback onWhatsAppTap;

  const _HowItWorksSection({
    required this.horizontalPadding,
    required this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.cardBorder(context), width: 1),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldBg(context),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'FLUXO SIMPLES E SEM ATRITO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.emerald(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Como começar em 3 minutos no WhatsApp',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.text(context),
                  ),
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    if (isNarrow) {
                      return Column(
                        children: const [
                          _StepItem(
                            step: '1',
                            title: 'Chame nosso time no WhatsApp',
                            desc: 'Envie um "olá" e nossa equipe libera seu acesso de teste em menos de 2 minutos.',
                          ),
                          SizedBox(height: 18),
                          _StepItem(
                            step: '2',
                            title: 'Cadastre sua anamnese',
                            desc: 'Insira os dados do aluno ou importe a rotina. A IA gera o split em 30 segundos.',
                          ),
                          SizedBox(height: 18),
                          _StepItem(
                            step: '3',
                            title: 'Envie o app para seu aluno',
                            desc: 'Seu aluno treina com seu acompanhamento e você ganha horas de volta toda semana.',
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(
                          child: _StepItem(
                            step: '1',
                            title: 'Chame no WhatsApp',
                            desc: 'Envie um "olá" e nossa equipe libera seu acesso de teste em menos de 2 minutos.',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _StepItem(
                            step: '2',
                            title: 'Cadastre a Anamnese',
                            desc: 'Insira metas e restrições. A IA gera a periodização completa em 30 segundos.',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: _StepItem(
                            step: '3',
                            title: 'Escale seus Alunos',
                            desc: 'Seu aluno treina no app e você dobra sua consultoria com zero sobrecarga.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Botão de WhatsApp Convidativo da Seção
                ElevatedButton.icon(
                  onPressed: onWhatsAppTap,
                  icon: const _WhatsAppIcon(size: 18, color: Colors.black87),
                  label: const Text(
                    'Começar Passo 1 no WhatsApp Agora',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _StepItem({
    required this.step,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pillBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pillBorder(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.emerald(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.subtext(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. DEPOIMENTOS DE PERSONALS
// ============================================================================
class _TestimonialsSection extends StatelessWidget {
  final double horizontalPadding;
  final bool isDesktop;

  const _TestimonialsSection({
    required this.horizontalPadding,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.tangerineBg(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'QUEM USA RECOMENDA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.tangerine(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Personal trainers que dobraram sua carteira',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: const [
                  _TestimonialCard(
                    author: 'Rodrigo Mello, CREF 14209-G',
                    role: 'Personal & Consultor Online (42 alunos)',
                    quote:
                        '"Eu gastava meus domingos inteiros montando planilhas de treino. Com o Mr. Coach, gero uma periodização impecável com Gemini 3.8 em segundos e aprovo na hora."',
                    rating: 5,
                  ),
                  _TestimonialCard(
                    author: 'Camila Fagundes, CREF 09312-G',
                    role: 'Treinadora Funcional & Hipertrofia (68 alunos)',
                    quote:
                        '"O botão de aparelho ocupado é genial! Meus alunos me mandavam áudio desesperados do meio da academia. Agora eles resolvem sozinhos com segurança biomecânica."',
                    rating: 5,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String author;
  final String role;
  final String quote;
  final int rating;

  const _TestimonialCard({
    required this.author,
    required this.role,
    required this.quote,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 490,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              rating,
              (i) => const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            quote,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.emeraldBg(context),
                child: Text(
                  author.substring(0, 1),
                  style: TextStyle(
                    color: AppColors.emerald(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text(context),
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.subtext(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. PLANOS & PREÇOS (CTA DIRETO WHATSAPP)
// ============================================================================
class _PricingSection extends StatelessWidget {
  final double horizontalPadding;
  final bool isDesktop;
  final ValueChanged<String> onSelectPlan;

  const _PricingSection({
    required this.horizontalPadding,
    required this.isDesktop,
    required this.onSelectPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'CONDIÇÃO ESPECIAL DE LANÇAMENTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.emerald(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Planos transparentes para qualquer fase',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 30 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Converse conosco no WhatsApp para liberar condições personalizadas para sua consultoria.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _PricingCard(
                    title: 'Starter Grátis',
                    price: 'R\$ 0',
                    period: '/mês vitalício',
                    isHighlight: false,
                    features: const [
                      'Até 5 alunos ativos',
                      '10 fichas IA mensais',
                      'Botão de emergência básico',
                      'Suporte via comunidade',
                    ],
                    buttonLabel: 'Testar Starter no WhatsApp',
                    onTap: () => onSelectPlan('Starter Grátis'),
                  ),
                  _PricingCard(
                    title: 'Personal Pro',
                    badge: 'MAIS ESCOLHIDO',
                    price: 'R\$ 69',
                    period: '/mês',
                    isHighlight: true,
                    features: const [
                      'Até 30 alunos ativos',
                      'Gerações de IA Ilimitadas',
                      'Adaptação de treinos em tempo real',
                      'Anamnese clínica completa',
                      'Suporte VIP no WhatsApp',
                    ],
                    buttonLabel: 'Garantir Pro no WhatsApp',
                    onTap: () => onSelectPlan('Personal Pro'),
                  ),
                  _PricingCard(
                    title: 'Consultoria Elite',
                    price: 'R\$ 149',
                    period: '/mês',
                    isHighlight: false,
                    features: const [
                      'Alunos ilimitados',
                      'Multiusuários / Estúdios',
                      'Treinamento 1-on-1 com nossa equipe',
                      'Onboarding prioritário',
                    ],
                    buttonLabel: 'Falar com Consultor Elite',
                    onTap: () => onSelectPlan('Consultoria Elite'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String? badge;
  final String price;
  final String period;
  final bool isHighlight;
  final List<String> features;
  final String buttonLabel;
  final VoidCallback onTap;

  const _PricingCard({
    required this.title,
    this.badge,
    required this.price,
    required this.period,
    required this.isHighlight,
    required this.features,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isHighlight
            ? (AppColors.isDark(context)
                ? const Color(0xFF16233B)
                : const Color(0xFFF0FDF4))
            : AppColors.card(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isHighlight
              ? AppColors.emerald(context)
              : AppColors.cardBorder(context),
          width: isHighlight ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (badge != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.subtext(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: AppColors.cardBorder(context), height: 1),
          const SizedBox(height: 18),
          ...features.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.emerald(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.text(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isHighlight
                  ? AppColors.emerald(context)
                  : AppColors.pillBg(context),
              foregroundColor: isHighlight ? Colors.black87 : AppColors.text(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WhatsAppIcon(
                  size: 16,
                  color: isHighlight ? Colors.black87 : AppColors.emerald(context),
                ),
                const SizedBox(width: 8),
                Text(
                  buttonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. FAQ ACORDEÃO
// ============================================================================
class _FaqSection extends StatelessWidget {
  final double horizontalPadding;
  final VoidCallback onWhatsAppTap;

  const _FaqSection({
    required this.horizontalPadding,
    required this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.tangerineBg(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'TIRE SUAS DÚVIDAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.tangerine(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Perguntas Frequentes',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: AppColors.text(context),
                ),
              ),
              const SizedBox(height: 24),
              _FaqAccordionItem(
                question: 'A inteligência artificial substitui meu papel como Personal?',
                answer:
                    'Não! O Mr. Coach é uma ferramenta de escala e copiloto do treinador. A IA gera a proposta de treino baseada na sua anamnese e nada vai para o aluno sem a sua aprovação ou ajuste em 1 clique.',
              ),
              _FaqAccordionItem(
                question: 'Como funciona o botão de "Aparelho Ocupado" no app do aluno?',
                answer:
                    'Quando o aluno está na academia e o aparelho prescrito está ocupado (ex: Crossover), ele clica no botão de emergência. A IA analisa o vetor biomecânico e sugere uma substituição equivalente com halteres ou elástico, notificando você no painel.',
              ),
              _FaqAccordionItem(
                question: 'Como faço para testar na prática?',
                answer:
                    'Basta clicar em qualquer botão de WhatsApp nesta página. Nosso time cria sua conta gratuita imediatamente e envia um vídeo de demonstração rápida.',
              ),
              _FaqAccordionItem(
                question: 'Posso cadastrar restrições articulares e lesões?',
                answer:
                    'Sim. A anamnese permite marcar lesões de ombro, joelho, lombar, condromalácia, etc. A IA respeita estritamente as limitações biomecânicas.',
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onWhatsAppTap,
                icon: const _WhatsAppIcon(size: 16),
                label: const Text('Ainda com dúvidas? Fale conosco no WhatsApp'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emerald(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqAccordionItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqAccordionItem({required this.question, required this.answer});

  @override
  State<_FaqAccordionItem> createState() => _FaqAccordionItemState();
}

class _FaqAccordionItemState extends State<_FaqAccordionItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder(context), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (val) => setState(() => _expanded = val),
          title: Text(
            widget.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text(context),
            ),
          ),
          trailing: Icon(
            _expanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
            color: AppColors.emerald(context),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Text(
                widget.answer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.subtext(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 9. FOOTER INSTITUCIONAL
// ============================================================================
class _FooterSection extends StatelessWidget {
  final double horizontalPadding;
  final double bottomInset;
  final VoidCallback onWhatsAppTap;
  final VoidCallback onLoginTap;

  const _FooterSection({
    required this.horizontalPadding,
    required this.bottomInset,
    required this.onWhatsAppTap,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: 48,
        bottom: bottomInset,
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.cardBorder(context), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_gymnastics_rounded,
                    color: AppColors.emerald(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MR. COACH IA',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontSize: 13,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onLoginTap,
                    child: Text(
                      'Área do Treinador',
                      style: TextStyle(
                        color: AppColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onWhatsAppTap,
                    icon: const _WhatsAppIcon(size: 14),
                    label: Text(
                      'WhatsApp Oficial',
                      style: TextStyle(
                        color: AppColors.emerald(context),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.cardBorder(context), height: 1),
          const SizedBox(height: 16),
          Text(
            '© 2026 Mr. Coach - Plataforma B2B para Personal Trainers & Consultorias Fitness. Todos os direitos reservados.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.subtext(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. FLOATING ACTION BUTTON WHATSAPP (FIXO NO CANTO INFERIOR)
// ============================================================================
class _FloatingWhatsAppCta extends StatefulWidget {
  final VoidCallback onTap;

  const _FloatingWhatsAppCta({required this.onTap});

  @override
  State<_FloatingWhatsAppCta> createState() => _FloatingWhatsAppCtaState();
}

class _FloatingWhatsAppCtaState extends State<_FloatingWhatsAppCta> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF10B981) : const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const _WhatsAppIcon(size: 22, color: Colors.white),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Text(
                'Dúvidas? Chame no Zap',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPONENTE AUXILIAR: ÍCONE CUSTOMIZADO DO WHATSAPP
// ============================================================================
class _WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const _WhatsAppIcon({this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chat_bubble_outline_rounded,
      size: size,
      color: color ?? AppColors.emerald(context),
    );
  }
}
