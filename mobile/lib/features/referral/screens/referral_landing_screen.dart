import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/meta_components.dart';
import '../../../services/referral_service.dart';
import '../../auth/login_screen.dart';
import '../../auth/register_screen.dart';
import '../../landing/b2b_landing_screen.dart';

/// Landing Page pública e imersiva para links de indicação e parcerias (/r/{slug}).
class ReferralLandingScreen extends StatefulWidget {
  final String slug;

  const ReferralLandingScreen({
    super.key,
    required this.slug,
  });

  @override
  State<ReferralLandingScreen> createState() => _ReferralLandingScreenState();
}

class _ReferralLandingScreenState extends State<ReferralLandingScreen> {
  bool _isLoading = true;
  ReferralPartnerInfo? _partner;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  Future<void> _loadPartner() async {
    final info = await ReferralService.getOrFetchPartner(widget.slug);
    if (mounted) {
      setState(() {
        _partner = info;
        _isLoading = false;
      });
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          initialRole: 'trainer',
          inviteToken: _partner?.slug,
          trainerName: _partner?.partnerName,
        ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(initialRole: 'trainer'),
      ),
    );
  }

  void _goToB2bLanding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const B2BLandingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    if (_isLoading) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemUiOverlayFor(isDark: true),
        child: Scaffold(
          backgroundColor: const Color(0xFF090D16),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: MetaColors.emerald),
                SizedBox(height: 16),
                Text(
                  'Carregando benefícios da parceria...',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final partner = _partner ??
        ReferralPartnerInfo(
          slug: widget.slug.toUpperCase(),
          partnerName: 'Parceiro ${widget.slug.toUpperCase()}',
          partnerType: 'influencer',
          headline: 'Parceria Oficial & Mr. Coach',
          badge: 'CONVITE ESPECIAL',
          description: 'Você recebeu um convite VIP para ingressar no ecossistema Mr. Coach.',
        );

    final couponCode = partner.associatedCouponCode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayFor(isDark: true),
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, bottomPadding + 36),
          children: [
            // Top App Bar sutil com Logo e Ação de Login
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [MetaColors.emerald, MetaColors.accentBlue],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.bolt_rounded, color: Colors.black, size: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MR. COACH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _goToLogin,
                  child: const Text(
                    'Já tenho conta',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Badge de Parceria
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handshake_rounded, color: MetaColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      partner.badge,
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Principal Hero de Boas-Vindas
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF131B2E),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: MetaColors.emerald, width: 2),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: MetaColors.emerald,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    partner.partnerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    partner.headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MetaColors.accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    partner.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  if (couponCode != null && couponCode.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.confirmation_number_rounded,
                              color: Color(0xFFF59E0B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CUPOM VINCULADO: $couponCode',
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Desconto VIP aplicado automaticamente no seu checkout.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Seção de Benefícios da Plataforma
            const Text(
              'O que você ganha com o Mr. Coach:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),

            _buildBenefitItem(
              icon: Icons.psychology_rounded,
              color: MetaColors.emerald,
              title: 'Prescrição IA com Biomecânica em 60s',
              description: 'Gere fichas completas, periodização ondulatória e substituição de aparelhos com precisão clínica.',
            ),
            const SizedBox(height: 10),
            _buildBenefitItem(
              icon: Icons.chat_rounded,
              color: const Color(0xFF22C55E),
              title: 'Copiloto de Atendimento no WhatsApp',
              description: 'Envio inteligente de fichas, lembretes de aula e reengajamento automático de alunos ausentes.',
            ),
            const SizedBox(height: 10),
            _buildBenefitItem(
              icon: Icons.fitness_center_rounded,
              color: MetaColors.accentBlue,
              title: 'App Exclusivo para Seus Alunos',
              description: 'Acompanhamento de séries, cargas, descanso guiado e histórico de evolução sem planilhas confusas.',
            ),
            const SizedBox(height: 10),
            _buildBenefitItem(
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Gestão Financeira & Split Automático',
              description: 'Receba mensalidades via Pix e cartão com taxa reduzida e controle total dos alunos adimplentes.',
            ),
            const SizedBox(height: 28),

            // Botão Principal de Ativação / Cadastro
            SquircleButton(
              label: 'Ativar Parceria e Criar Conta',
              icon: Icons.rocket_launch_rounded,
              height: 56,
              fontSize: 15,
              onPressed: _goToRegister,
            ),
            const SizedBox(height: 12),

            // Botão Secundário: Explorar Recursos
            OutlinedButton.icon(
              onPressed: _goToB2bLanding,
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF94A3B8)),
              label: const Text(
                'Conhecer Recursos da Plataforma',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E293B)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 20),

            // Rodapé Institucional
            Center(
              child: Text(
                'Mr. Coach • Parcerias Oficiais & Referral Engine\nTodos os direitos reservados.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
