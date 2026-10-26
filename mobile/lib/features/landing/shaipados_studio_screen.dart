import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
class ShaipadosStudioScreen extends StatefulWidget {
  const ShaipadosStudioScreen({super.key});

  @override
  State<ShaipadosStudioScreen> createState() => _ShaipadosStudioScreenState();
}

class _ShaipadosStudioScreenState extends State<ShaipadosStudioScreen> {
  void _navigateToDestination(BuildContext context, String destination) {
    if (destination == 'mrcoach') {
      Navigator.pushNamed(context, '/b2b');
    } else if (destination == 'ai') {
      Navigator.pushNamed(context, '/ai');
    } else if (destination == 'entry') {
      Navigator.pushNamed(context, '/home');
    } else if (destination == 'directory') {
      Navigator.pushNamed(context, '/prof');
    } else if (destination == 'register') {
      Navigator.pushNamed(context, '/register');
    } else if (destination.startsWith('http')) {
      launchUrl(Uri.parse(destination), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 900;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ==========================================
            // ULTRA-REALISTIC BACKGROUND HERO IMAGE
            // ==========================================
            Positioned.fill(
              child: Opacity(
                opacity: 0.25,
                child: Image.network(
                  'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=2000&auto=format&fit=crop',
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: MetaColors.emerald));
                  },
                ),
              ).animate().fadeIn(duration: 1200.ms),
            ),
            // Gradient Overlay to blend image into background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black,
                      Colors.transparent,
                      Colors.black,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.4, 0.9],
                  ),
                ),
              ),
            ),

            // AMBIENT GRADIENT MESH / GLOW
            Positioned(
              top: -120,
              left: mediaQuery.size.width * 0.2,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MetaColors.emerald.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.2, 1.2), duration: 4000.ms),

            // ==========================================
            // CONTEÚDO PRINCIPAL (SCROLL)
            // ==========================================
            SingleChildScrollView(
              padding: EdgeInsets.only(
                top: topPadding,
                bottom: bottomPadding + 48,
              ),
              child: Column(
                children: [
                  // ==========================================
                  // HEADER ELEGANTE
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/app_icon_black.png',
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SHAIPADOS LABS',
                                    style: TextStyle(
                                      color: MetaColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  Text(
                                    'VENTURE BUILDER & AI STUDIO',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (isDesktop)
                                SquircleButton(
                                  label: 'Mr. Coach IA',
                                  icon: Icons.auto_awesome,
                                  isPrimary: true,
                                  height: 42,
                                  borderRadius: 12,
                                  onPressed: () => _navigateToDestination(context, 'ai'),
                                )
                              else
                                IconButton(
                                  tooltip: 'Mr. Coach IA',
                                  onPressed: () => _navigateToDestination(context, 'ai'),
                                  icon: const Icon(Icons.auto_awesome, color: MetaColors.emerald),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0),

                  // ==========================================
                  // HERO SECTION COM PROPOSTA DE VALOR
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.12),
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: MetaColors.emerald,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'A NOVA GERAÇÃO DE SOFTWARE FITNESS',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 150.ms).scale(),

                          const SizedBox(height: 32),

                          Text(
                            'Onde a Biomecânica\nencontra a Inteligência Artificial.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: isDesktop ? 72 : 42,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -2.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 28),

                          Text(
                            'Criamos produtos digitais para profissionais do movimento, academias e pessoas que treinam, conectando tecnologia e ferramentas práticas para o dia a dia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: isDesktop ? 22 : 18,
                              height: 1.6,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 5,
                                )
                              ]
                            ),
                          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 48),

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 14,
                            children: [
                              SquircleButton(
                                label: 'Explorar Mr. Coach B2B',
                                icon: Icons.arrow_forward_rounded,
                                isPrimary: true,
                                height: 56,
                                borderRadius: 14,
                                onPressed: () => _navigateToDestination(context, 'mrcoach'),
                              ),
                              SquircleButton(
                                label: 'Encontrar treinador',
                                icon: Icons.search_rounded,
                                isPrimary: false,
                                height: 56,
                                borderRadius: 14,
                                onPressed: () => _navigateToDestination(context, 'directory'),
                              ),
                              SquircleButton(
                                label: 'Acessar plataforma',
                                icon: Icons.login_rounded,
                                isPrimary: false,
                                height: 56,
                                borderRadius: 14,
                                onPressed: () => _navigateToDestination(context, 'entry'),
                              ),
                            ],
                          ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==========================================
                  // BENTO GRID ULTRA-REALISTA & ANIMADO
                  // ==========================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: isDesktop
                          ? _buildDesktopGrid(context)
                          : _buildMobileGrid(context),
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 80),

                  // ==========================================
                  // FOOTER
                  // ==========================================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: MetaColors.border, width: 1.0),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1140),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '© 2026 Shaipados Labs. Todos os direitos reservados.',
                                style: TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _navigateToDestination(context, 'mrcoach'),
                                    child: const Text('Mr. Coach', style: TextStyle(color: MetaColors.textSecondary)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Coluna Esquerda
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(child: _buildBiomech3DCard()),
              const SizedBox(height: 24),
              Expanded(child: _buildNutriIACard()),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Coluna Direita: Flagship
        Expanded(
          flex: 6,
          child: _buildFlagshipCard(context),
        ),
      ],
    );
  }

  Widget _buildMobileGrid(BuildContext context) {
    return Column(
      children: [
        _buildFlagshipCard(context),
        const SizedBox(height: 24),
        _buildBiomech3DCard(),
        const SizedBox(height: 24),
        _buildNutriIACard(),
      ],
    );
  }

  // Card do Produto Flagship: Mr. Coach
  Widget _buildFlagshipCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(0), // Removido para a imagem colar nas bordas
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Image Ultra-realista
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=1000&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, MetaColors.surface.withValues(alpha: 1.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.4, 1.0]
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: MetaColors.emerald, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'PRODUTO FLAGSHIP',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 12, 36, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mr. Coach: espaço de trabalho para treinadores e alunos',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Treinadores organizam alunos e treinos. Alunos entram por convite ou encontram profissionais no diretório, preenchem seus dados e aguardam o alinhamento antes de receber um treino.',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: SquircleButton(
                    label: 'Ver Demonstração do Mr. Coach →',
                    icon: Icons.open_in_new_rounded,
                    isPrimary: true,
                    height: 52,
                    borderRadius: 14,
                    onPressed: () => Navigator.pushNamed(context, '/demo'),
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetaColors.border.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Convites preservam o vínculo com o treinador. A avaliação fica na conta do aluno; a liberação do treino acontece depois do alinhamento profissional.',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card do Laboratório 3D Biomecânico
  Widget _buildBiomech3DCard() {
    return MetaCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: MetaColors.border),
                ),
                child: const Text(
                  'MOTOR BIOMECÂNICO',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Icon(Icons.hub_outlined, color: MetaColors.textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 20),

          // Imagem Ultra-realista
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800&auto=format&fit=crop', // Restaurant/Lab or similar dark aesthetic
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, MetaColors.surface.withValues(alpha: 0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 12,
                    left: 12,
                    child: Icon(Icons.science, color: MetaColors.emerald, size: 32),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mapeamento Articular 3D',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ferramentas digitais para apoiar a organização e a consulta de informações de treino.',
            style: TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Card de Nutrição e Visão Computacional
  Widget _buildNutriIACard() {
    return MetaCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: MetaColors.border),
                ),
                child: const Text(
                  'EM BREVE',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const Icon(Icons.restaurant_menu_rounded, color: MetaColors.textSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          
          // Imagem Ultra-realista Nutrição
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=800&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, MetaColors.surface.withValues(alpha: 0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Diet Tracker Vision',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uma experiência de apoio à organização alimentar em desenvolvimento.',
            style: TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
