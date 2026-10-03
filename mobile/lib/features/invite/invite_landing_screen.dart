import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
    // SimulaÃƒÂ§ÃƒÂ£o de busca no Supabase (GET /api/v1/public/trainers/{slug})
    await Future.delayed(const Duration(milliseconds: 800));

    // Converte 'joao-silva' para 'Joao Silva' para mock
    final name = widget.trainerSlug
        .split('-')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');

    if (mounted) {
      setState(() {
        _trainerName = name;
        _isLoading = false;
      });
    }
  }

  void _acceptInvite() {
    // Levar para a tela de registro de Aluno (B2C)
    // Para reaproveitar, navegamos para o RegisterScreen passando initialRole = 'client'
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(initialRole: 'client'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ãƒ cone / Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.emerald(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 40,
                    color: AppColors.emerald(context),
                  ),
                ),
                const SizedBox(height: 32),

                // Texto Principal
                Text(
                  'Seu Convite Chegou!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  Text(
                    'O personal trainer',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.subtext(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _trainerName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'gerou a sua periodizaÃƒÂ§ÃƒÂ£o com InteligÃƒÂªncia Artificial.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.subtext(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // BotÃƒÂ£o CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _acceptInvite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald(context),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        'Aceitar Convite e Acessar Treino',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                // Footer
                Text(
                  'Plataforma Powered by Mr. Coach IA',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.subtext(context).withValues(alpha: 0.5),
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
