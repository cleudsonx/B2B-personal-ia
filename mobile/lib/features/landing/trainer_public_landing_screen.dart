import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

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
      final apiUrl = '${AppConfig.apiBaseUrl}/api/v1/public/trainers/${widget.username}';
      
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          _trainerData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Treinador nÃ£o encontrado.';
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
        _errorMessage = 'Falha de conexÃ£o. Tente novamente mais tarde.';
        _isLoading = false;
      });
    }
  }

    void _openWhatsApp() {
    if (_trainerData == null || _trainerData!['public_whatsapp'] == null) return;
    
    var phone = _trainerData!['public_whatsapp'].replaceAll(RegExp(r'[^\d]'), '');
    if (!phone.startsWith('55')) {
      phone = '55$phone';
    }
    
    final text = Uri.encodeComponent("Olá, Prof. ${_trainerData!['full_name']}! Vi seu método inteligente e cansei de treinos genéricos. Quero saber como funciona a consultoria personalizada para o meu objetivo!");
    final url = Uri.parse("https://wa.me/$phone?text=$text");
    
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Fallback UI para Loading / Erro
    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 80, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      );
    }

    // Tela de ConversÃ£o B2B
    final name = _trainerData!['full_name'] ?? 'Personal Trainer';
    final bio = _trainerData!['bio'] ?? 'Transformando vidas atravÃ©s do movimento e da hipertrofia funcional.';
    final List<dynamic> specialties = _trainerData!['specialties'] ?? ['Hipertrofia', 'Emagrecimento', 'SaÃºde'];
    final photoUrl = _trainerData!['photo_url'];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (photoUrl != null)
                    Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholderPhoto(colorScheme),
                    )
                  else
                    _buildPlaceholderPhoto(colorScheme),
                  
                  // Gradiente escuro para legibilidade
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          colorScheme.surface.withValues(alpha: 0.8),
                          colorScheme.surface,
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // Tags de Especialidade
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: specialties.map((spec) => Chip(
                      label: Text(spec.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    )).toList(),
                  ).animate().fadeIn(delay: 200.ms).scale(),

                  const SizedBox(height: 32),
                  
                  // Bio
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Text(
                      bio,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 48),

                  // Diferenciais (Social Proof)
                  _buildProofRow(context, Icons.fitness_center, "Periodização 100% Sob Medida", "Montada para sua anatomia e rotina."),
                  const SizedBox(height: 16),
                  _buildProofRow(context, Icons.insights, "Evolução Monitorada no App", "Acompanhe seus pesos e consistência."),
                  const SizedBox(height: 16),
                  _buildProofRow(context, Icons.workspace_premium, "Aparelho Ocupado? Zero Espera", "App indica substituições com 1 toque."),
                  
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
          height: 64,
          child: FloatingActionButton.extended(
            onPressed: _openWhatsApp,
            backgroundColor: const Color(0xFF25D366), // WhatsApp Green
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: const Icon(Icons.rocket_launch, size: 28),
            label: const Text(
              'Quero Minha Consultoria',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scaleXY(begin: 1.0, end: 1.02, duration: 1.5.seconds, curve: Curves.easeInOut),
      ),
    );
  }

  Widget _buildPlaceholderPhoto(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(Icons.person, size: 120, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _buildProofRow(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

