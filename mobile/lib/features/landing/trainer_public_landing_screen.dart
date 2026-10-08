import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/meta_components.dart';
import '../auth/register_screen.dart';

class TrainerPublicLandingScreen extends StatefulWidget {
  final String username;

  const TrainerPublicLandingScreen({super.key, required this.username});

  @override
  State<TrainerPublicLandingScreen> createState() => _TrainerPublicLandingScreenState();
}

class _TrainerPublicLandingScreenState extends State<TrainerPublicLandingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _trainerData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrainerProfile();
  }

  Future<void> _fetchTrainerProfile() async {
    try {
      final apiUrl = '${AppConfig.apiBaseUrl}/public/trainers/${Uri.encodeComponent(widget.username)}';
      
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          _trainerData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Treinador não encontrado.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro ao carregar perfil.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Falha de conexão com o servidor.';
        _isLoading = false;
      });
    }
  }

  void _startConsultation() {
    final trainer = _trainerData!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          initialRole: 'client',
          trainerId: trainer['id'] as String?,
          trainerName: trainer['full_name'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Fallback UI para Loading / Erro
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: MetaColors.background,
        body: Center(
          child: CircularProgressIndicator(color: MetaColors.emerald),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: MetaColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 80, color: MetaColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                _errorMessage!, 
                style: const TextStyle(color: MetaColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // Tela de Conversão B2B - High Performance Theme
    final name = _trainerData!['full_name'] ?? 'Personal Trainer';
    final bio = _trainerData!['bio'] ?? 'Software de alta performance e produtos digitais escaláveis movidos a Inteligência Artificial.';
    final List<dynamic> specialties = _trainerData!['specialties'] ?? ['Alta Performance', 'Hipertrofia'];
    final photoUrl = _trainerData!['photo_url'];

    return Scaffold(
      backgroundColor: MetaColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 400.0,
            floating: false,
            pinned: true,
            backgroundColor: MetaColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (photoUrl != null)
                    Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholderPhoto(),
                    )
                  else
                    _buildPlaceholderPhoto(),
                  
                  // Gradiente super escuro para fundo (Estilo Shaipados Labs)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          MetaColors.background.withValues(alpha: 0.6),
                          MetaColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Apresentação profissional do treinador
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.1),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.rocket_launch_rounded, color: MetaColors.emerald, size: 14),
                        SizedBox(width: 8),
                        Text(
                          'TREINADOR COM REGISTRO PROFISSIONAL',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 24),

                  // Headline Principal (Nome) "Nós esculpimos ideias." -> "Nome do Treinador"
                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 20),
                  
                  // Tags de Especialidade (Pills minimalistas)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: specialties.map((spec) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        spec.toString().toUpperCase(), 
                        style: const TextStyle(
                          fontWeight: FontWeight.w700, 
                          color: MetaColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        )
                      ),
                    )).toList(),
                  ).animate().fadeIn(delay: 300.ms).scale(),

                  const SizedBox(height: 32),
                  
                  // Bio - Focada no texto elegante (como o subtítulo do site)
                  Text(
                    bio,
                    style: const TextStyle(
                      color: MetaColors.textSecondary,
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

                  if ((_trainerData!['cref'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Registro profissional: ${_trainerData!['cref']}',
                      style: const TextStyle(color: MetaColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sua experiência no app',
                      style: TextStyle(color: MetaColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProofRow(Icons.assignment_outlined, 'Avaliação inicial', 'Compartilhe sua rotina, objetivos e restrições com seu treinador.'),
                  const SizedBox(height: 14),
                  _buildProofRow(Icons.fitness_center_rounded, 'Treinos acompanhados', 'Acesse sua ficha e registre sua evolução quando o treinador liberar o plano.'),
                  const SizedBox(height: 14),
                  _buildProofRow(Icons.chat_bubble_outline_rounded, 'Contato antes do plano', 'Após o cadastro, aguarde o contato do treinador para conversar sobre a consultoria.'),

                  const SizedBox(height: 40),

                  // Diferenciais (Social Proof) - Layout MetaCard escuro
                  MetaCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildProofRow(Icons.fitness_center_rounded, "Periodização Sob Medida", "Treinos esculpidos para sua anatomia e rotina."),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: MetaColors.surfaceHighlight, height: 1),
                        ),
                        _buildProofRow(Icons.insights_rounded, "Evolução Movida a Dados", "Acompanhe seus pesos e progressão no app."),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: MetaColors.surfaceHighlight, height: 1),
                        ),
                        _buildProofRow(Icons.auto_awesome_rounded, "Inteligência Artificial", "Zero espera. Aparelho ocupado? O app substitui em 1 toque."),
                      ],
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 64),

                  // Branding Footer "Tecnologia Mr. Coach | Shaipados Labs"
                  Column(
                    children: [
                      const Text(
                        'Tecnologia Mr. Coach',
                        style: TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_rounded,
                            color: MetaColors.textSecondary.withValues(alpha: 0.5),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'by Shaipados Labs',
                            style: TextStyle(
                              color: MetaColors.textSecondary.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 120), // Espaço para o botão flutuante
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _startConsultation,
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: MetaColors.emerald.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 24),
            label: const Text(
              'TENHO INTERESSE NA CONSULTORIA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scaleXY(begin: 1.0, end: 1.02, duration: 1.5.seconds, curve: Curves.easeInOut),
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      color: MetaColors.surfaceHighlight,
      child: const Center(
        child: Icon(Icons.fitness_center_rounded, size: 120, color: MetaColors.background),
      ),
    );
  }

  Widget _buildProofRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MetaColors.emerald, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 16, 
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )
              ),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                style: const TextStyle(
                  color: MetaColors.textSecondary, 
                  fontSize: 14,
                  height: 1.3,
                )
              ),
            ],
          ),
        ),
      ],
    );
  }
}
