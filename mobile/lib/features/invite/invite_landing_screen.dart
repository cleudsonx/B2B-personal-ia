import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/invite_service.dart';
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
  bool _hasValidationError = false;
  String _trainerName = 'Carregando...';
  String? _targetEmail;
  String? _targetPhone;
  String? _targetName;

  @override
  void initState() {
    super.initState();
    _fetchTrainerData();
  }

  Future<void> _fetchTrainerData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasValidationError = false;
      });
    }
    try {
      final res = await InviteService.validateInvite(widget.token);
      if (mounted) {
        setState(() {
          _trainerName = res['trainer_name'] ?? 'Seu Personal Trainer';
          _targetEmail = res['target_email'];
          _targetPhone = res['target_phone'];
          _targetName = res['target_name'];
          _hasValidationError = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Se der erro, mostra erro e esconde botão
        setState(() {
          _trainerName = 'Convite inválido ou expirado';
          _hasValidationError = true;
          _isLoading = false;
        });
      }
    }
  }

  bool _isConsuming = false;

  Future<void> _acceptInvite() async {
    if (_hasValidationError) return;
    if (_isConsuming) return;
    setState(() => _isConsuming = true);

    try {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(
              initialRole: 'client',
              initialEmail: _targetEmail,
              initialPhone: _targetPhone,
              initialName: _targetName,
              inviteToken: widget.token,
              trainerName: _trainerName,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConsuming = false);
      }
    }
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
                    MetaSectionTitle(
                      title: _hasValidationError
                          ? 'Este convite não está disponível'
                          : 'Seu convite chegou',
                      subtitle: _hasValidationError
                          ? 'O link pode ter expirado ou já ter sido usado. Tente validar novamente ou peça um novo convite ao treinador.'
                          : 'Confirme o convite do seu treinador para criar sua conta e preparar seu plano de treino.',
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
                    else if (_hasValidationError) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: 'Tentar novamente',
                          icon: Icons.refresh_rounded,
                          isPrimary: true,
                          onPressed: _fetchTrainerData,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Voltar'),
                      ),
                    ] else ...[
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
                        title: 'Plano alinhado ao seu objetivo',
                        description: 'Seu treinador prepara uma rotina considerando sua avaliação inicial.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(
                        icon: Icons.speed_rounded,
                        title: 'Acompanhamento de evolução',
                        description: 'Veja suas sessões, cargas e orientações em um só lugar.',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(
                        icon: Icons.swap_calls_rounded,
                        title: 'Treino adaptável',
                        description: 'Ajuste o exercício quando precisar e mantenha sua rotina em movimento.',
                      ),
                      const SizedBox(height: 32),

                      // Botão CTA
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: _isConsuming ? 'Abrindo cadastro...' : 'Aceitar convite',
                          icon: _isConsuming ? Icons.hourglass_top_rounded : Icons.check_circle_outline,
                          isPrimary: true,
                          onPressed: _isConsuming ? () {} : _acceptInvite,
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
