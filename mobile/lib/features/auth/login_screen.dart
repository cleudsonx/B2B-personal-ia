import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
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
    _emailCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
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
      final profile = await AuthService.getCurrentProfile();
      final user = AuthService.currentUser;
      final userName = (profile?['full_name'] as String?)?.isNotEmpty == true
          ? profile!['full_name'] as String
          : (user?.userMetadata?['full_name'] as String?)?.isNotEmpty == true
              ? user!.userMetadata!['full_name'] as String
              : (_selectedRole == 'trainer' ? 'Personal Trainer' : 'Aluno no Salão');

      if (mounted) {
        _navigateToDashboard(
          role: _selectedRole,
          name: userName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return AlertDialog(
          backgroundColor: AppColors.card(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.cardBorder(ctx)),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.tangerine(ctx)),
              const SizedBox(width: 8),
              Text(
                'Recuperar Senha',
                style: TextStyle(
                  color: AppColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informe o e-mail cadastrado para receber o link de redefinição de acesso:',
                style: TextStyle(color: AppColors.subtext(ctx), fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resetEmailCtrl,
                style: TextStyle(color: AppColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  labelStyle: TextStyle(color: AppColors.subtext(ctx)),
                  filled: true,
                  fillColor: AppColors.pillBg(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder(ctx)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.cardBorder(ctx)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.emerald(ctx), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: AppColors.subtext(ctx))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue(ctx),
                foregroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isTrainer = _selectedRole == 'trainer';
    final primaryAccent = isTrainer ? AppColors.emerald(context) : AppColors.accentBlue(context);
    final buttonTextColor = isDark ? const Color(0xFF090D16) : Colors.white;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar: Brand Pill & Theme Switcher
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.pillBg(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.pillBorder(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: primaryAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PRO EDITION 2026',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: AppColors.subtext(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const ThemeToggleButton(compact: false),
                      ],
                    ),
                    const SizedBox(height: 24),

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
                              color: primaryAccent.withValues(alpha: isDark ? 0.35 : 0.18),
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
                          color: AppColors.text(context),
                          shadows: isDark
                              ? [
                                  Shadow(
                                    color: primaryAccent.withValues(alpha: 0.5),
                                    blurRadius: 18,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Prescrição Biomecânica & Adaptação no Salão',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subtext(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Role Selector Toggle (Treinador Pro vs Aluno no Salão)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder(context)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleTab(
                              context: context,
                              title: 'Treinador Pro',
                              icon: Icons.assignment_ind_outlined,
                              isSelected: isTrainer,
                              activeColor: AppColors.emerald(context),
                              onTap: () => _onRoleChanged('trainer'),
                            ),
                          ),
                          Expanded(
                            child: _buildRoleTab(
                              context: context,
                              title: 'Aluno no Salão',
                              icon: Icons.fitness_center_rounded,
                              isSelected: !isTrainer,
                              activeColor: AppColors.accentBlue(context),
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
                      style: TextStyle(color: AppColors.text(context)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe seu e-mail';
                        if (!val.contains('@')) return 'Informe um e-mail válido';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                        prefixIcon: Icon(Icons.email_outlined, color: primaryAccent, size: 20),
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder(context)),
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
                      style: TextStyle(color: AppColors.text(context)),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Informe sua senha';
                        if (val.length < 6) return 'A senha deve ter no mínimo 6 dígitos';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: TextStyle(color: AppColors.subtext(context), fontSize: 13),
                        prefixIcon: Icon(Icons.lock_outline, color: primaryAccent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.subtext(context),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppColors.card(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.cardBorder(context)),
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
                              checkColor: buttonTextColor,
                              side: BorderSide(color: AppColors.cardBorder(context)),
                              onChanged: (val) => setState(() => _rememberMe = val ?? true),
                            ),
                            Text(
                              'Lembrar acesso',
                              style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
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
                        foregroundColor: buttonTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: primaryAccent.withValues(alpha: isDark ? 0.4 : 0.2),
                      ),
                      onPressed: _isLoading ? null : _handleSignIn,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: buttonTextColor, strokeWidth: 2),
                            )
                          : Text(
                              'Entrar como ${isTrainer ? 'Treinador Pro' : 'Aluno no Salão'}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ainda não tem conta? ',
                          style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
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
                          icon: Icon(Icons.settings_ethernet, size: 16, color: AppColors.subtext(context)),
                          label: Text(
                            'Configurar IP da API Backend (Dev)',
                            style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
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
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor.withValues(alpha: 0.15) : activeColor.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.subtext(context)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.subtext(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
