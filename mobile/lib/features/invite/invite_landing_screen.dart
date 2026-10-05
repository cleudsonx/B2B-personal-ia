import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';
import '../auth/register_screen.dart';

class InviteLandingScreen extends StatefulWidget {
  final String trainerSlug;
  final String token;

  const InviteLandingScreen({
    super.key,
    required this.trainerSlug,
    required this.token,
  });

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  bool _isLoading = true;
  String _trainerName = 'Carregando...';

  @override
  void initState() {
    super.initState();
    _fetchTrainerData();
  }

  Future<void> _fetchTrainerData() async {
    // Simulação de busca dos dados públicos do personal
    await Future.delayed(const Duration(milliseconds: 600));

    // Converte slug no formato 'joao-silva' para 'Joao Silva'
    final formattedName = widget.trainerSlug
        .split('-')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join(' ');

    if (mounted) {
      setState(() {
        _trainerName = formattedName.isEmpty ? 'Seu Personal Trainer' : formattedName;
        _isLoading = false;
      });
    }
  }

  void _acceptInvite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(initialRole: 'client'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: topPadding + 24,
              bottom: bottomPadding + 32,
              left: 20,
              right: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: MetaCard(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge superior
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: MetaColors.emerald,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'CONVITE VIP',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ícone central em destaque
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        size: 36,
                        color: MetaColors.emerald,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título e subtítulo
                    const MetaSectionTitle(
                      title: 'Seu Convite Chegou!',
                      subtitle: 'Você recebeu acesso exclusivo a uma rotina de treinos de alta performance.',
                      textAlign: TextAlign.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                    ),
                    const SizedBox(height: 28),

                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(MetaColors.emerald),
                        ),
                      )
                    else ...[
                      // Card do Personal
                      MetaCard(
                        backgroundColor: MetaColors.surfaceHighlight,
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: MetaColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: MetaColors.border),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: MetaColors.accentBlue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _trainerName,
                                          style: const TextStyle(
                                            color: MetaColors.textPrimary,
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified,
                                        color: MetaColors.accentBlue,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Personal Trainer Responsável',
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
                      const SizedBox(height: 20),

                      // Diferenciais do convite
                      _buildBenefitItem(
                        icon: Icons.tune_rounded,
                        title: 'Periodização Científica',
                        description: 'Treinos planejados com Inteligência Artificial baseada nos seus objetivos.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(
                        icon: Icons.speed_rounded,
                        title: 'Acompanhamento de Cargas',
                        description: 'Monitore evolução, séries e tempo de descanso na ponta dos dedos.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(
                        icon: Icons.swap_calls_rounded,
                        title: 'Substituição Inteligente',
                        description: 'Aparelho ocupado na academia? Troque por outro equivalente com um toque.',
                      ),
                      const SizedBox(height: 32),

                      // Botão CTA
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: 'Aceitar Convite e Começar',
                          icon: Icons.check_circle_outline,
                          isPrimary: true,
                          onPressed: _acceptInvite,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Rodapé
                    Text(
                      'Plataforma Powered by Mr. Coach IA',
                      style: TextStyle(
                        fontSize: 12,
                        color: MetaColors.textSecondary.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: MetaColors.emerald,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
