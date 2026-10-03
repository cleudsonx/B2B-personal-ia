import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
        // Fallback para ambiente local/desenvolvimento
        if (prefix == 'mrcoach') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MrCoachLandingScreen()),
          );
        } else if (prefix == 'app') {
          // No app, envia para AuthGate ou Login (via push named se houver, ou recarrega a raiz simulada)
          Navigator.pushNamed(context, '/');
        }
        return;
      }

      // Ambiente de Produção
      final url = Uri.parse('https://.shaipados.com');
      launchUrl(url, webOnlyWindowName: '_self');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final bgColor = const Color(0xFF09090B);
    final cardColor = const Color(0xFF18181B);
    final borderColor = Colors.white.withValues(alpha: 0.1);
    final primaryGlow = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.layers_rounded, color: primaryGlow, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'SHAIPADOS LABS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _navigateToSubdomain(context, 'app'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Login Ecossistema'),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),

            // HERO SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGlow.withValues(alpha: 0.1),
                        border: Border.all(color: primaryGlow.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.rocket_launch,
                            color: primaryGlow,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SOFTWARE STUDIO & VENTURE BUILDER',
                            style: TextStyle(
                              color: primaryGlow,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).scale(),

                    const SizedBox(height: 32),

                    Text(
                          'Nós esculpimos ideias.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 72 : 48,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: -2.0,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 24),

                    Text(
                      'Software em alta performance e produtos escaláveis movidos a Inteligência Artificial.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: isDesktop ? 24 : 18,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
                  ],
                ),
              ),
            ),

            // BENTO GRID
            Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child:
                        isDesktop
                            ? _buildDesktopGrid(
                              cardColor,
                              borderColor,
                              primaryGlow,
                            )
                            : _buildMobileGrid(
                              cardColor,
                              borderColor,
                              primaryGlow,
                            ),
                  ),
                )
                .animate()
                .fadeIn(delay: 800.ms, duration: 800.ms)
                .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 120),

            // FOOTER
            Container(
              padding: const EdgeInsets.all(48),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Center(
                child: Text(
                  '© 2026 Shaipados Labs. Todos os direitos reservados.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ).animate().fadeIn(delay: 1000.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(
    Color cardColor,
    Color borderColor,
    Color primaryGlow,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildTechCard(cardColor, borderColor),
              const SizedBox(height: 24),
              _buildComingSoonCard(cardColor, borderColor),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column (Flagship)
        Expanded(
          flex: 6,
          child: _buildFlagshipCard(cardColor, borderColor, primaryGlow),
        ),
      ],
    );
  }

  Widget _buildMobileGrid(
    Color cardColor,
    Color borderColor,
    Color primaryGlow,
  ) {
    return Column(
      children: [
        _buildFlagshipCard(cardColor, borderColor, primaryGlow),
        const SizedBox(height: 24),
        _buildTechCard(cardColor, borderColor),
        const SizedBox(height: 24),
        _buildComingSoonCard(cardColor, borderColor),
      ],
    );
  }

  Widget _buildTechCard(Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arquitetura Serverless',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nossos produtos suportam milhões de requisições com latência zero.',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('Flutter', borderColor),
              _buildChip('Google Gemini', borderColor),
              _buildChip('FastAPI', borderColor),
              _buildChip('Supabase', borderColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildComingSoonCard(Color cardColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'EM BREVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nutri IA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'O próximo lançamento da fábrica.',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagshipCard(
    Color cardColor,
    Color borderColor,
    Color primaryGlow,
  ) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'PRODUTO B2B DESTAQUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // IMAGEM DESTAQUE DO APP (Logo grande)
          Center(
                child: Image.asset(
                  'assets/images/mr_coach_logo_full.png',
                  height: 100, // Maior destaque como pedido pelo CEO
                  errorBuilder:
                      (context, error, stackTrace) => Icon(
                        Icons.fitness_center,
                        size: 80,
                        color: Colors.grey[700],
                      ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.05,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),

          const SizedBox(height: 32),

          const Text(
            'A primeira plataforma inteligente que gera periodizações para personal trainers em 30 segundos.',
            style: TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToSubdomain(context, 'mrcoach'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGlow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Conhecer o Produto ->',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ).animate().shimmer(
            delay: 2.seconds,
            duration: 1.seconds,
            color: Colors.white24,
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: primaryGlow,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 1.0, duration: 800.ms),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUILD IN PUBLIC',
                      style: TextStyle(
                        color: primaryGlow,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '+2.400',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Treinos gerados via IA esta semana',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
