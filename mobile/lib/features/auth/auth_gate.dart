import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';


import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
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
    // 1. Verificar se hÃƒÂ¡ sessÃƒÂ£o ativa no Supabase (Persistida via Token)
    final session = AuthService.currentSession;

    if (session == null) {
      _goToLogin();
      return;
    }

    // 2. Tentar biometria se estiver em dispositivo mÃƒÂ³vel (iOS/Android)
    bool biometricSuccess =
        true; // Por padrÃƒÂ£o, web ou falha no hardware aprova direto (pois jÃƒÂ¡ tem token)

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
        biometricSuccess =
            true; // Fallback para permitir entrada, jÃƒÂ¡ que a sessÃƒÂ£o existe
      } finally {
        if (mounted) setState(() => _isAuthenticating = false);
      }
    }

    if (biometricSuccess) {
      _loadProfileAndGoToDashboard();
    } else {
      // Se usuÃƒÂ¡rio cancelou a biometria, mandamos para o login
      AuthService.signOut();
      _goToLogin();
    }
  }

  Future<void> _loadProfileAndGoToDashboard() async {
    try {
      final profile = await AuthService.getCurrentProfile();
      final role = profile?['role'] as String? ?? 'client';
      final name = profile?['full_name'] as String? ?? 'UsuÃƒÂ¡rio';

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => MainShellScreen(
                  initialIndex: 0,
                  activeRole: role,
                  userName: name,
                ),
          ),
        );
      }
    } catch (e) {
      AuthService.signOut();
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/mr_coach_logo_full.png', height: 64),
            const SizedBox(height: 32),
            if (_isAuthenticating) ...[
              const Icon(
                Icons.fingerprint_rounded,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Autenticando...',
                style: TextStyle(color: AppColors.subtext(context)),
              ),
            ] else ...[
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
