import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class ShaipadosStudioScreen extends StatefulWidget {
  const ShaipadosStudioScreen({super.key});

  @override
  State<ShaipadosStudioScreen> createState() => _ShaipadosStudioScreenState();
}

class _ShaipadosStudioScreenState extends State<ShaipadosStudioScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    // ForÃƒÆ’Ã‚Â§ando um tema ultra-dark para a fÃƒÆ’Ã‚Â¡brica
    final bgColor = const Color(0xFF09090B);
    final cardColor = const Color(0xFF18181B);
    final borderColor = Colors.white.withValues(alpha: 0.1);
    final primaryGlow = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER
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
                    onPressed: () {
                      if (kIsWeb) {
                        launchUrl(Uri.parse('https://app.shaipados.com'));
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Login Ecossistema'),
                  ),
                ],
              ),
            ),

            // 2. HERO SECTION
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGlow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: primaryGlow.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rocket_launch_rounded,
                          color: primaryGlow,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SOFTWARE STUDIO & VENTURE BUILDER',
                          style: TextStyle(
                            color: primaryGlow,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'NÃƒÆ’Ã‚Â³s esculpimos ideias.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Software em alta performance e produtos escalÃƒÆ’Ã‚Â¡veis\nmovidos a InteligÃƒÆ’Ã‚Âªncia Artificial.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 18,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // 3. BENTO GRID ECOSISTEMA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child:
                    isDesktop
                        ? _buildDesktopGrid(cardColor, borderColor, primaryGlow)
                        : _buildMobileGrid(cardColor, borderColor, primaryGlow),
              ),
            ),

            const SizedBox(height: 80),

            // FOOTER
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Center(
                child: Text(
                  'Ãƒâ€šÃ‚Â© 2026 Shaipados Labs. Todos os direitos reservados.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
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
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _BentoCard(
                cardColor: cardColor,
                borderColor: borderColor,
                height: 340,
                child: _MrCoachHighlight(primaryGlow: primaryGlow),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _BentoCard(
                    cardColor: cardColor,
                    borderColor: borderColor,
                    height: 160,
                    child: _MetricsHighlight(primaryGlow: primaryGlow),
                  ),
                  const SizedBox(height: 20),
                  _BentoCard(
                    cardColor: cardColor,
                    borderColor: borderColor,
                    height: 160,
                    child: _CustomSoftwareHighlight(),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _BentoCard(
                cardColor: cardColor,
                borderColor: borderColor,
                height: 200,
                child: _TechStackHighlight(),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _BentoCard(
                cardColor: cardColor,
                borderColor: borderColor,
                height: 200,
                child: _FutureProductHighlight(),
              ),
            ),
          ],
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
        _BentoCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: _MrCoachHighlight(primaryGlow: primaryGlow),
        ),
        const SizedBox(height: 16),
        _BentoCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: _MetricsHighlight(primaryGlow: primaryGlow),
        ),
        const SizedBox(height: 16),
        _BentoCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: _CustomSoftwareHighlight(),
        ),
        const SizedBox(height: 16),
        _BentoCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: _TechStackHighlight(),
        ),
        const SizedBox(height: 16),
        _BentoCard(
          cardColor: cardColor,
          borderColor: borderColor,
          child: _FutureProductHighlight(),
        ),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Widget child;
  final double? height;

  const _BentoCard({
    required this.cardColor,
    required this.borderColor,
    required this.child,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ==========================================
// BENTO COMPONENTS
// ==========================================

class _MrCoachHighlight extends StatelessWidget {
  final Color primaryGlow;
  const _MrCoachHighlight({required this.primaryGlow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRODUTO B2B DESTAQUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/mr_coach_logo_full.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Mr. Coach IA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A primeira plataforma inteligente que gera periodizaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes para personal trainers em 30 segundos.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (kIsWeb) {
              launchUrl(Uri.parse('https://mrcoach.shaipados.com'));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGlow,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Conhecer o Produto ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _MetricsHighlight extends StatelessWidget {
  final Color primaryGlow;
  const _MetricsHighlight({required this.primaryGlow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: primaryGlow,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'BUILD IN PUBLIC',
              style: TextStyle(
                color: primaryGlow,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '+2.400',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'Treinos gerados via IA esta semana',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CustomSoftwareHighlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.code_rounded, color: Colors.white, size: 28),
        const SizedBox(height: 16),
        const Text(
          'Sua Startup em Semanas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Desenvolvimento sob medida de SaaS.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TechStackHighlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Arquitetura Serverless',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Nossos produtos suportam milhÃƒÆ’Ã‚Âµes de requisiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes com latÃƒÆ’Ã‚Âªncia zero.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag('Flutter'),
            _Tag('Google Gemini 3.8'),
            _Tag('FastAPI'),
            _Tag('Supabase'),
          ],
        ),
      ],
    );
  }
}

class _FutureProductHighlight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'EM BREVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Nutri IA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'O prÃƒÆ’Ã‚Â³ximo lanÃƒÆ’Ã‚Â§amento da fÃƒÆ’Ã‚Â¡brica.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

