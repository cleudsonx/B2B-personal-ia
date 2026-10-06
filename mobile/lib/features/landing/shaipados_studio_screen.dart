import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import 'mrcoach_landing_screen.dart';

class ShaipadosStudioScreen extends StatefulWidget {
  const ShaipadosStudioScreen({super.key});

  @override
  State<ShaipadosStudioScreen> createState() => _ShaipadosStudioScreenState();
}

class _ShaipadosStudioScreenState extends State<ShaipadosStudioScreen> {
  void _navigateToDestination(BuildContext context, String destination) {
    if (destination == 'mrcoach') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MrCoachLandingScreen()),
      );
    } else if (destination == 'app' || destination == 'login') {
      Navigator.pushNamed(context, '/login');
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
            // AMBIENT GRADIENT MESH / GLOW DE FUNDO
            // ==========================================
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
                      MetaColors.emerald.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.2, 1.2), duration: 4000.ms),

            Positioned(
              top: 350,
              right: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.12), // Ouro suave Shaipados
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.85, 0.85), duration: 5000.ms),

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
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: MetaColors.emerald.withValues(alpha: 0.3),
                                  ),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/images/logo_shaipados_gold.jpg'),
                                    fit: BoxFit.cover,
                                  ),
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
                                      color: MetaColors.textSecondary.withValues(alpha: 0.7),
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
                              SquircleButton(
                                label: 'Login',
                                icon: Icons.login_rounded,
                                isPrimary: false,
                                height: 42,
                                borderRadius: 12,
                                onPressed: () => _navigateToDestination(context, 'login'),
                              ),
                              const SizedBox(width: 12),
                              if (isDesktop)
                                SquircleButton(
                                  label: 'Mr. Coach IA',
                                  icon: Icons.auto_awesome,
                                  isPrimary: true,
                                  height: 42,
                                  borderRadius: 12,
                                  onPressed: () => _navigateToDestination(context, 'mrcoach'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
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

                          const SizedBox(height: 28),

                          Text(
                            'Onde a Biomecânica\nencontra a Inteligência Artificial.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: isDesktop ? 62 : 38,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                              letterSpacing: -1.8,
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 22),

                          Text(
                            'Desenvolvemos produtos digitais de alta precisão científica para personal trainers, academias e praticantes avançados de musculação.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: isDesktop ? 20 : 16,
                              height: 1.55,
                            ),
                          ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),

                          const SizedBox(height: 36),

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 14,
                            children: [
                              SquircleButton(
                                label: 'Explorar Mr. Coach B2B',
                                icon: Icons.arrow_forward_rounded,
                                isPrimary: true,
                                height: 52,
                                borderRadius: 14,
                                onPressed: () => _navigateToDestination(context, 'mrcoach'),
                              ),
                              SquircleButton(
                                label: 'Acessar Plataforma',
                                icon: Icons.lock_outline_rounded,
                                isPrimary: false,
                                height: 52,
                                borderRadius: 14,
                                onPressed: () => _navigateToDestination(context, 'login'),
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
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => _navigateToDestination(context, 'login'),
                                    child: const Text('Entrar', style: TextStyle(color: MetaColors.textSecondary)),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda: Showcase Biomecânico 3D e Nutri IA
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildBiomech3DCard(),
              const SizedBox(height: 24),
              _buildNutriIACard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Coluna Direita: Flagship Mr. Coach
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
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: MetaColors.emerald,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'PRODUTO FLAGSHIP (NO AR)',
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
            ],
          ),
          const SizedBox(height: 28),

          // Imagem Dourada / Logo Oficial em Alta Resolução
          Center(
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: MetaColors.emerald.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/mr_coach_logo_gold.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/mr_coach_logo_full.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Mr. Coach: Plataforma B2B para Personais de Alta Performance',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Prescrição biomecânica individualizada, substituição inteligente de aparelhos em tempo real e vitrine profissional para captação de novos alunos.',
            style: TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 15,
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
              onPressed: () => _navigateToDestination(context, 'mrcoach'),
            ),
          ),
          const SizedBox(height: 24),

          // Métrica ao vivo
          MetaCard(
            backgroundColor: MetaColors.background,
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: MetaColors.emerald,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'METRICAS DO ECOSSISTEMA',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+2.400 Treinos Prescritos',
                        style: TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Com proteção automática contra lesões articulares',
                        style: TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

          // Renderização Ultra-realista da Anatomia 3D
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/biomech_3d_chest.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/anatomical_model_chest.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 14,
                    left: 16,
                    right: 16,
                    child: Text(
                      'Mapeamento Eletromiográfico em 3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'IA treinada com mais de 300 estudos eletromiográficos para garantir torque ótimo e curvas de resistência seguras.',
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

  // Card do Nutri IA (Em Breve)
  Widget _buildNutriIACard() {
    return MetaCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: MetaColors.border),
            ),
            child: const Text(
              'EM DESENVOLVIMENTO',
              style: TextStyle(
                color: Color(0xFF60A5FA),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: Color(0xFF60A5FA), size: 28),
              SizedBox(width: 12),
              Text(
                'Nutri IA Studio',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Planejamento de macronutrientes adaptativo e contagem calórica visual via visão computacional.',
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
