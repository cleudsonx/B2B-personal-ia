import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  void _navigateToSubdomain(BuildContext context, String prefix) {
    if (kIsWeb) {
      final currentHost = Uri.base.host;
      if (currentHost.contains('localhost') ||
          currentHost.contains('render.com')) {
        // Fallback para ambiente de desenvolvimento local
        if (prefix == 'mrcoach') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MrCoachLandingScreen()),
          );
        } else if (prefix == 'app') {
          Navigator.pushNamed(context, '/');
        }
        return;
      }

      // Ambiente de Produção
      final url = Uri.parse('https://$prefix.shaipados.com');
      launchUrl(url, webOnlyWindowName: '_self');
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
        backgroundColor: MetaColors.background,
        body: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding + 48,
          ),
          child: Column(
            children: [
              // ==========================================
              // HEADER
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: MetaColors.emerald.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            color: MetaColors.emerald,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'SHAIPADOS LABS',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                    SquircleButton(
                      label: 'Login Ecossistema',
                      icon: Icons.login_rounded,
                      isPrimary: false,
                      height: 42,
                      borderRadius: 12,
                      onPressed: () => _navigateToSubdomain(context, 'app'),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0),

              // ==========================================
              // HERO SECTION
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.1),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              color: MetaColors.emerald,
                              size: 15,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'SOFTWARE STUDIO & VENTURE BUILDER',
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
                        'Nós esculpimos ideias.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: isDesktop ? 68 : 42,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -2.0,
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                      const SizedBox(height: 20),

                      Text(
                        'Software de alta performance e produtos digitais escaláveis movidos a Inteligência Artificial.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: isDesktop ? 22 : 16,
                          height: 1.5,
                        ),
                      ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
              ),

              // ==========================================
              // BENTO GRID
              // ==========================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
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
                child: const Center(
                  child: Text(
                    '© 2026 Shaipados Labs. Todos os direitos reservados.',
                    style: TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coluna Esquerda
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildTechCard(),
              const SizedBox(height: 24),
              _buildComingSoonCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Coluna Direita (Flagship Mr. Coach)
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
        _buildTechCard(),
        const SizedBox(height: 24),
        _buildComingSoonCard(),
      ],
    );
  }

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
                      'PRODUTO B2B DESTAQUE',
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

          // Logo / Marca Destaque
          Center(
            child: Image.asset(
              'assets/images/mr_coach_logo_full.png',
              height: 90,
              errorBuilder: (context, error, stackTrace) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      size: 36,
                      color: MetaColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Mr. Coach',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'A primeira plataforma inteligente que gera periodizações completas para personal trainers em apenas 30 segundos.',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 18,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: 'Conhecer o Produto →',
              icon: Icons.open_in_new_rounded,
              isPrimary: true,
              onPressed: () => _navigateToSubdomain(context, 'mrcoach'),
            ),
          ),
          const SizedBox(height: 24),

          // Métrica em tempo real
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
                        'BUILD IN PUBLIC',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+2.400',
                        style: TextStyle(
                          color: MetaColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Treinos gerados via IA nesta semana',
                        style: TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 13,
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

  Widget _buildTechCard() {
    return MetaCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: 'Arquitetura Serverless',
            subtitle: 'Infraestrutura moderna que suporta milhares de requisições simultâneas com latência ultrabaixa.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTechChip('Flutter'),
              _buildTechChip('Google Gemini'),
              _buildTechChip('FastAPI'),
              _buildTechChip('Supabase'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MetaColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: MetaColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildComingSoonCard() {
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
              'EM BREVE',
              style: TextStyle(
                color: MetaColors.accentBlue,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nutri IA',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O próximo lançamento da fábrica: planejamento nutricional e contagem de macros com inteligência artificial.',
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
