import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/whatsapp_direct_service.dart';
import '../auth/login_screen.dart';

class StudentSuspendedScreen extends StatefulWidget {
  final String studentName;
  final String? trainerId;

  const StudentSuspendedScreen({
    super.key,
    required this.studentName,
    this.trainerId,
  });

  @override
  State<StudentSuspendedScreen> createState() => _StudentSuspendedScreenState();
}

class _StudentSuspendedScreenState extends State<StudentSuspendedScreen> {
  Map<String, dynamic>? _trainerProfile;
  bool _isLoadingTrainer = true;

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
  }

  Future<void> _loadTrainerInfo() async {
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (mounted) {
        setState(() {
          _trainerProfile = trainer;
          _isLoadingTrainer = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTrainer = false);
      }
    }
  }

  Future<void> _contactTrainerWhatsapp() async {
    final trainerName = _trainerProfile?['full_name'] as String? ?? 'Professor';
    final rawNumber = _trainerProfile?['public_whatsapp']?.toString() ??
        _trainerProfile?['phone']?.toString() ??
        _trainerProfile?['whatsapp']?.toString();

    await WhatsAppDirectService.openStudentTrainerBridge(
      context: context,
      trainerPhone: rawNumber,
      trainerName: trainerName,
      trainerId: (_trainerProfile?['id'] ?? widget.trainerId)?.toString(),
      initialMessage:
          'Olá, $trainerName! Sou ${widget.studentName} e gostaria de regularizar o acesso aos meus treinos.',
      category: 'student_to_trainer',
    );
  }

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(initialRole: 'client')),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.background : MetaColors.lightBackground;
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textPrimary = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final textSecondary = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final trainerName = _trainerProfile?['full_name'] as String? ?? 'Seu Personal Trainer';
    final photoUrl = (_trainerProfile?['photo_url'] ?? _trainerProfile?['avatar_url']) as String?;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: textSecondary),
            tooltip: 'Sair da conta',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ícone de suspensão animado
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.2),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Colors.amber,
                      size: 46,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.06, 1.06),
                        duration: 1200.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
                const SizedBox(height: 28),

                // Título
                Text(
                  'Acesso Temporariamente Suspenso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),

                // Mensagem explicativa
                Text(
                  'Olá, ${widget.studentName}! O acesso aos seus treinos e registros de evolução está temporariamente pausado. Converse com seu treinador para regularizar e retomar a periodização.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 350.ms),
                const SizedBox(height: 28),

                // Card do Treinador
                if (!_isLoadingTrainer) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: MetaColors.emerald.withValues(alpha: 0.15),
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person, color: MetaColors.emerald)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trainerName,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Seu Personal Trainer',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 24),
                ],

                // Botão de Contato com o Professor no WhatsApp com Gradiente Oficial
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _contactTrainerWhatsapp,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF25D366).withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'FALAR COM MEU TREINADOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 350.ms)
                    .slideY(begin: 0.1, end: 0),
                const SizedBox(height: 12),

                // Botão de Logout
                OutlinedButton(
                  onPressed: _handleSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'SAIR DA CONTA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
