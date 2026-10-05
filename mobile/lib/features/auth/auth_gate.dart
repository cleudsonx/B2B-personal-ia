import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../trainer/presentation/screens/trainer_main_layout.dart';
import '../trainer/presentation/screens/trainer_onboarding_screen.dart';
import 'login_screen.dart';
import '../../main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    // 1. Verificar se hÃ¡ sessÃ£o ativa no Supabase (Persistida via Token)
    final session = AuthService.currentSession;

    if (session == null) {
      _goToLogin();
      return;
    }

    // 2. Tentar biometria se estiver em dispositivo mÃ³vel (iOS/Android)
    bool biometricSuccess = true;

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        setState(() => _isAuthenticating = true);

        final canCheckBiometrics = await _auth.canCheckBiometrics;
        final isDeviceSupported = await _auth.isDeviceSupported();

        if (canCheckBiometrics || isDeviceSupported) {
          biometricSuccess = await _auth.authenticate(
            localizedReason: 'Desbloqueie para acessar seus treinos e alunos',
            persistAcrossBackgrounding: true,
            biometricOnly: false,
          );
        }
      } catch (e) {
        debugPrint('Erro na biometria: $e');
        biometricSuccess = true; 
      } finally {
        if (mounted) setState(() => _isAuthenticating = false);
      }
    }

    if (biometricSuccess) {
      _loadProfileAndGoToDashboard();
    } else {
      AuthService.signOut();
      _goToLogin();
    }
  }

  Future<void> _loadProfileAndGoToDashboard() async {
    try {
      final profile = await AuthService.getCurrentProfile();
      final role = profile?['role'] as String? ?? 'client';
      final name = profile?['full_name'] as String? ?? 'UsuÃ¡rio';

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (role == 'trainer') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const TrainerOnboardingScreen(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MainShellScreen(
                  initialIndex: 0,
                  activeRole: role,
                  userName: name,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      AuthService.signOut();
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fundo puro preto para mesclar com a logo
      body: Stack(
        children: [
          // Efeito de Entrada da Logo (Fade In e leve Scale)
          Center(
            child: TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1200),
              tween: Tween<double>(begin: 0.8, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Opacity(
                  opacity: (scale - 0.8) / 0.2, // Faz um fade de 0 a 1 junto com o scale
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/mr_coach_logo_gold.jpg',
                width: MediaQuery.of(context).size.width * 0.75, // 75% da largura da tela
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fitness_center_rounded,
                  size: 80,
                  color: MetaColors.emerald,
                ),
              ),
            ),
          ),
          
          // Indicador de Carregamento posicionado no rodapé elegante
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: _isAuthenticating
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 48,
                          color: MetaColors.emerald,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Desbloqueando...',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(
                      color: MetaColors.emerald,
                      strokeWidth: 3,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


