import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';
import '../auth/register_screen.dart';

class InviteSuccessScreen extends StatelessWidget {
  final String trainerName;
  final String? targetEmail;
  final String? targetPhone;

  const InviteSuccessScreen({
    super.key,
    required this.trainerName,
    this.targetEmail,
    this.targetPhone,
  });

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
              constraints: const BoxConstraints(maxWidth: 480),
              child: MetaCard(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícone de Sucesso
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: MetaColors.emerald,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título de Boas-Vindas
                    const Text(
                      'Convite Confirmado!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mensagem Personalizada
                    Text(
                      'Você agora está conectado com seu Personal Trainer:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      trainerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Card de Detalhes
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MetaColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_outline, size: 16, color: MetaColors.textSecondary),
                              SizedBox(width: 8),
                              Text(
                                'Acesso Exclusivo & Seguro',
                                style: TextStyle(
                                  color: MetaColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sua ficha e anamnese serão sincronizadas em tempo real com o motor de IA e com seu treinador.',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botão de Avançar
                    SizedBox(
                      width: double.infinity,
                      child: SquircleButton(
                        label: 'Continuar Cadastro',
                        icon: Icons.arrow_forward_rounded,
                        isPrimary: true,
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterScreen(
                                initialRole: 'client',
                                initialEmail: targetEmail,
                                initialPhone: targetPhone,
                              ),
                            ),
                          );
                        },
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
}

