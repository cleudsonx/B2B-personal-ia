import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
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
    final rawNumber = _trainerProfile?['public_whatsapp']?.toString() ??
        _trainerProfile?['phone']?.toString() ??
        '';
    var number = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (number.length == 10 || number.length == 11) {
      number = '55$number';
    }

    if (number.length != 12 && number.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O treinador não possui WhatsApp cadastrado para contato.'),
        ),
      );
      return;
    }

    final trainerName = _trainerProfile?['full_name'] as String? ?? 'Professor';
    final uri = Uri.https('wa.me', '/$number', {
      'text': 'Olá, $trainerName! Gostaria de regularizar minha consultoria na Shaipados.',
    });

    try {
      if (!await canLaunchUrl(uri) ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Não foi possível abrir o WhatsApp.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
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
    final trainerName = _trainerProfile?['full_name'] as String? ?? 'seu treinador';

    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: MetaColors.textSecondary),
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
                // Ícone de suspensão
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: Colors.amber,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Título
                const Text(
                  'Acesso Temporariamente Suspenso',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MetaColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Mensagem explicativa
                Text(
                  'Olá, ${widget.studentName}! O acesso aos seus treinos e registros de evolução está suspenso. Converse diretamente com $trainerName para regularizar sua consultoria.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: MetaColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Card do Treinador
                if (!_isLoadingTrainer && _trainerProfile != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MetaColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: MetaColors.surfaceHighlight,
                          backgroundImage: (_trainerProfile!['photo_url'] as String?)?.isNotEmpty == true
                              ? NetworkImage(_trainerProfile!['photo_url'] as String)
                              : null,
                          child: (_trainerProfile!['photo_url'] as String?)?.isNotEmpty != true
                              ? const Icon(Icons.person, color: MetaColors.textSecondary)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trainerName,
                                style: const TextStyle(
                                  color: MetaColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Seu Personal Trainer',
                                style: TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Botão de Contato com o Professor
                ElevatedButton.icon(
                  onPressed: _contactTrainerWhatsapp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                  label: const Text(
                    'FALAR COM MEU TREINADOR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botão de Logout
                OutlinedButton(
                  onPressed: _handleSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetaColors.textSecondary,
                    side: const BorderSide(color: MetaColors.surfaceHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('SAIR DA CONTA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

