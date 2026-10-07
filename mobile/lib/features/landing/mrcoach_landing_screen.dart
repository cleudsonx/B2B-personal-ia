// ignore_for_file: unused_element, unused_import, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/meta_components.dart';

class MrCoachLandingScreen extends StatelessWidget {
  const MrCoachLandingScreen({super.key});

  // Future<void> _openWhatsApp() async {
  //   final Uri url = Uri.parse('https://wa.me/5511999999999?text=Ol%C3%A1%2C%20quero%20conhecer%20o%20Mr.%20Coach!');
  //   if (!await launchUrl(url)) {
  //     debugPrint('Não foi possível abrir o WhatsApp');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // Aplica o padrão Edge-to-Edge da Meta
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: MetaColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: MetaColors.background,
            floating: true,
            title: const Text(
              'Mr. Coach B2B',
              style: TextStyle(
                color: MetaColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.login, color: MetaColors.textPrimary),
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO SECTION
                  const MetaSectionTitle(
                    title: 'O seu aplicativo de personal trainer movido a IA.',
                    subtitle: 'Gere periodizações completas em 30 segundos, atraia mais alunos online e tenha a mesma tecnologia dos maiores estúdios do país.',
                  ),
                  const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: SquircleButton(
                        label: 'Criar Conta Grátis',
                        icon: Icons.person_add,
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                      ),
                    ),
                  const SizedBox(height: 48),

                  // FEATURES SECTION
                  const MetaSectionTitle(title: 'Por que o Mr. Coach?'),
                  const SizedBox(height: 24),
                  
                  _buildFeatureCard(
                    icon: Icons.flash_on,
                    title: 'Prescrição com IA em 30s',
                    description: 'Diga adeus às planilhas lentas. Nossa IA lê as metas e monta divisões completas, séries, repetições e intervalos científicos.',
                  ),
                  const SizedBox(height: 16),
                  
                  _buildFeatureCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Botão de Pânico: Aparelho Ocupado',
                    description: 'Se o leg press estiver lotado, o aluno toca no botão e a IA sugere na hora uma variação biomecânica equivalente.',
                  ),
                  const SizedBox(height: 16),

                  _buildFeatureCard(
                    icon: Icons.shield,
                    title: 'Blindagem de Lesões',
                    description: 'O aluno tem hérnia ou dor no ombro? A anamnese filtra e bloqueia automaticamente qualquer exercício de risco contraindicado.',
                  ),
                  const SizedBox(height: 48),

                  // PRICING SECTION
                  const MetaSectionTitle(
                    title: 'Condição Especial de Lançamento',
                    subtitle: 'Desbloqueie recursos premium.',
                  ),
                  const SizedBox(height: 24),
                  
                  MetaCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Starter Grátis',
                              style: TextStyle(
                                color: MetaColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: MetaColors.accentBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Plano atual',
                                style: TextStyle(
                                  color: MetaColors.accentBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Até 5 alunos ativos para você testar na prática.',
                          style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        _buildCheckItem('Botão de emergência básico'),
                        _buildCheckItem('Anamnese clínica completa'),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: SquircleButton(
                            label: 'Ativar Plano',
                            isPrimary: false,
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 64),
                  // FOOTER
                  const Center(
                    child: Text(
                      '© 2026 Mr. Coach - Plataforma B2B\nTodos os direitos reservados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String description}) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: MetaColors.textPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: MetaColors.textPrimary, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: MetaColors.textPrimary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
