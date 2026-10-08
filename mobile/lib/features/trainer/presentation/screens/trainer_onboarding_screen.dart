import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import 'trainer_profile_setup_screen.dart';

class TrainerOnboardingScreen extends StatefulWidget {
  const TrainerOnboardingScreen({super.key});

  @override
  State<TrainerOnboardingScreen> createState() => _TrainerOnboardingScreenState();
}

class _TrainerOnboardingScreenState extends State<TrainerOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.auto_awesome,
      'title': 'Boas-vindas ao Mr. Coach',
      'description': 'A primeira plataforma que une a sua experiência com a Inteligência Artificial para revolucionar a sua consultoria.',
    },
    {
      'icon': Icons.trending_up_rounded,
      'title': 'Escale Seus Ganhos',
      'description': 'Pare de perder tempo montando planilhas manuais. Prescreva treinos em segundos e deixe a IA cuidar do suporte básico.',
    },
    {
      'icon': Icons.storefront_rounded,
      'title': 'Sua Vitrine Digital',
      'description': 'Tenha uma página exclusiva para vender seus planos. Feche contratos e receba pagamentos enquanto você dorme.',
    },
    {
      'icon': Icons.chat_rounded,
      'title': 'Consultor 24h no WhatsApp',
      'description': 'Nossa IA responde as dúvidas dos seus alunos em tempo real, garantindo um atendimento premium sem esgotar o seu tempo.',
    },
  ];

  Future<void> _nextPage() async {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final userId = AuthService.currentUser?.id;
      if (userId != null) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool('trainer_onboarding_completed_$userId', true);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TrainerProfileSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ãcone gigante
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: MetaColors.surfaceHighlight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _slides[index]['icon'],
                            size: 80,
                            color: MetaColors.emerald,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          _slides[index]['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _slides[index]['description'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Rodapé: Indicadores e Botão
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentIndex == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? MetaColors.emerald
                              : MetaColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: SquircleButton(
                      label: _currentIndex == _slides.length - 1 ? 'Montar Minha Vitrine' : 'Avançar',
                      icon: _currentIndex == _slides.length - 1 ? Icons.rocket_launch : Icons.arrow_forward,
                      isPrimary: true,
                      onPressed: _nextPage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




