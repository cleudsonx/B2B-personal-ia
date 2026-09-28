import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../services/auth_service.dart';
import '../../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialRole;

  const LoginScreen({super.key, this.initialRole = 'trainer'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    if (kDebugMode) {
      _emailCtrl = TextEditingController(
        text: _selectedRole == 'trainer' ? 'treinador@demo.com' : 'aluno@demo.com',
      );
      _passwordCtrl = TextEditingController(text: '123456');
    } else {
      _emailCtrl = TextEditingController();
      _passwordCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onRoleChanged(String newRole) {
    if (_selectedRole == newRole) return;
    setState(() {
      _selectedRole = newRole;
      if (kDebugMode) {
        if (newRole == 'trainer') {
          _emailCtrl.text = 'treinador@demo.com';
        } else {
          _emailCtrl.text = 'aluno@demo.com';
        }
      }
    });
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await AuthService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      if (mounted) {
        _navigateToDashboard(
          role: _selectedRole,
          name: _selectedRole == 'trainer' ? 'Personal Trainer' : 'Aluno no Salão',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(e.toString().replaceAll('Exception: ', '')),
            action: SnackBarAction(
              label: 'Usar Modo Demo',
              textColor: Colors.yellow,
              onPressed: () => _enterDemoMode(_selectedRole),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _enterDemoMode(String role) {
    final isTrainer = role == 'trainer';
    _navigateToDashboard(
      role: role,
      name: isTrainer ? 'Carlos Personal (Demo)' : 'Rodrigo Aluno (Demo)',
    );
  }

  void _navigateToDashboard({required String role, required String name}) {
    final targetIndex = 0;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainShellScreen(
          initialIndex: targetIndex,
          activeRole: role,
          userName: name,
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.trainerSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.trainerBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppColors.studentAmber),
            SizedBox(width: 8),
            Text('Recuperar Senha', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o e-mail cadastrado para receber o link de redefinição de acesso:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'E-mail',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.trainerSurfaceElevated,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.studentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green.shade800,
                  content: Text('Instruções enviadas para ${resetEmailCtrl.text}'),
                ),
              );
            },
            child: const Text('Enviar Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTrainer = _selectedRole == 'trainer';
    final primaryAccent = isTrainer ? AppColors.trainerEmerald : AppColors.studentCyan;

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Badge with Neon Glow
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryAccent.withValues(alpha: 0.25),
                              primaryAccent.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isTrainer ? Icons.sports_gymnastics : Icons.fitness_center_rounded,
                          color: primaryAccent,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'B2B PERSONAL IA',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppColors.textPrimary,
                          shadows: [
                            Shadow(
                              color: primaryAccent.withValues(alpha: 0.5),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Prescrição Biomecânica & Adaptação no Salão',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role Selector Toggle (Treinador Pro vs Aluno no Salão)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.studentSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.studentBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Treinador Pro',
                              icon: Icons.assignment_ind_outlined,
                              isSelected: isTrainer,
                              activeColor: AppColors.trainerEmerald,
                              onTap: () => _onRoleChanged('trainer'),
                            ),
                          ),
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Aluno no Salão',
                              icon: Icons.fitness_center_rounded,
                              isSelected: !isTrainer,
                              activeColor: AppColors.studentCyan,
                              onTap: () => _onRoleChanged('client'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        isTrainer
                            ? 'Acesso à gestão de alunos, anamnese clínica e prescrição IA'
                            : 'Acesso ao treino do dia, timer de descanso e troca rápida',
                        style: TextStyle(fontSize: 11, color: primaryAccent, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email Input
                    TextFormField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe seu e-mail';
                        if (!val.contains('@')) return 'Informe um e-mail válido';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.email_outlined, color: primaryAccent, size: 20),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe sua senha';
                        if (val.length < 6) return 'A senha deve ter no mínimo 6 dígitos';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.lock_outline, color: primaryAccent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.studentBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Remember Me & Forgot Password Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: primaryAccent,
                              checkColor: Colors.black,
                              side: const BorderSide(color: AppColors.textMuted),
                              onChanged: (val) => setState(() => _rememberMe = val ?? true),
                            ),
                            const Text(
                              'Lembrar acesso',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Esqueceu a senha?',
                            style: TextStyle(color: primaryAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Primary Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: primaryAccent.withValues(alpha: 0.4),
                      ),
                      onPressed: _isLoading ? null : _handleSignIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'Entrar como ${isTrainer ? 'Treinador Pro' : 'Aluno no Salão'}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                    ),
                    // Quick 1-Click Demo Buttons (Only displayed in Debug / Development Mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.studentBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OU TESTE EM 1 CLIQUE (MODO DEV)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppColors.studentBorder)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.trainerEmerald),
                              label: const Text('Entrar Treinador'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.trainerEmerald,
                                side: BorderSide(color: AppColors.trainerEmerald.withValues(alpha: 0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _enterDemoMode('trainer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.studentCyan),
                              label: const Text('Entrar Aluno'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.studentCyan,
                                side: BorderSide(color: AppColors.studentCyan.withValues(alpha: 0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              onPressed: () => _enterDemoMode('client'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Ainda não tem conta? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => RegisterScreen(initialRole: _selectedRole)),
                            );
                          },
                          child: Text(
                            'Cadastre-se grátis',
                            style: TextStyle(
                              color: primaryAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // API Server Config Shortcut (Only displayed in Debug / Development Mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.settings_ethernet, size: 16, color: AppColors.textMuted),
                          label: const Text(
                            'Configurar IP da API Backend (Dev)',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                          onPressed: () => ServerConfigDialog.show(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
