import 'package:flutter/material.dart';

import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../client/welcome_onboarding_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole;
  final String? initialEmail;
  final String? initialPhone;
  final String? inviteToken;
  final String? trainerId;
  final String? trainerName;

  const RegisterScreen({
    super.key,
    this.initialRole = 'trainer',
    this.initialEmail,
    this.initialPhone,
    this.inviteToken,
    this.trainerId,
    this.trainerName,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _passwordCtrl;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('55') && digits.length > 11
        ? digits.substring(2)
        : digits;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await AuthService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        role: widget.initialRole,
        phone: _phoneCtrl.text.trim(),
        trainerId: widget.trainerId,
        inviteToken: widget.inviteToken,
      );
      if (mounted) {
        if (response.session == null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                initialRole: widget.initialRole,
                initialEmail: _emailCtrl.text.trim(),
                confirmationRequired: true,
              ),
            ),
            (route) => false,
          );
          return;
        }
        if (widget.initialRole == 'client') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => WelcomeOnboardingScreen(
                studentName: _nameCtrl.text.trim(),
                trainerName: widget.trainerName,
              ),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInviteRegistration = widget.inviteToken != null;

    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: MetaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Criar sua conta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: MetaColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isInviteRegistration
                        ? 'Complete seus dados para continuar com ${widget.trainerName ?? 'seu treinador'}.'
                        : widget.initialRole == 'client'
                            ? 'Informe seus dados para falar com seu treinador.'
                            : 'Comece a prescrever com Inteligência Artificial.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: MetaColors.textSecondary,
                    ),
                  ),
                  if (isInviteRegistration) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_outlined, color: MetaColors.emerald, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Convite de ${widget.trainerName ?? 'seu treinador'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: MetaColors.emerald, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),

                  // Nome
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: MetaColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nome Completo',
                      labelStyle: const TextStyle(color: MetaColors.textSecondary),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: MetaColors.emerald,
                      ),
                      filled: true,
                      fillColor: MetaColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MetaColors.emerald),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe seu nome' : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: isInviteRegistration && widget.initialEmail != null,
                    style: const TextStyle(color: MetaColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: MetaColors.textSecondary),
                      helperText: isInviteRegistration && widget.initialEmail != null
                          ? 'Vinculado a este convite'
                          : null,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: MetaColors.emerald,
                      ),
                      filled: true,
                      fillColor: MetaColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MetaColors.emerald),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())) {
                        return 'Informe um email válido.';
                      }
                      if (widget.inviteToken != null &&
                          widget.initialEmail != null &&
                          value.trim().toLowerCase() != widget.initialEmail!.trim().toLowerCase()) {
                        return 'Use o e-mail indicado no convite';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    readOnly: isInviteRegistration && widget.initialPhone != null,
                    style: const TextStyle(color: MetaColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Telefone / WhatsApp',
                      labelStyle: const TextStyle(color: MetaColors.textSecondary),
                      helperText: isInviteRegistration && widget.initialPhone != null
                          ? 'Vinculado a este convite'
                          : null,
                      prefixIcon: const Icon(Icons.phone_outlined, color: MetaColors.emerald),
                      filled: true,
                      fillColor: MetaColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MetaColors.emerald),
                      ),
                    ),
                    validator: (value) {
                      if (widget.initialRole == 'client' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Informe seu telefone para contato do treinador';
                      }
                      if (widget.inviteToken != null &&
                          widget.initialPhone != null &&
                          _normalizePhone(value) != _normalizePhone(widget.initialPhone)) {
                        return 'Confirme o telefone indicado no convite';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Senha
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: MetaColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      labelStyle: const TextStyle(color: MetaColors.textSecondary),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: MetaColors.emerald,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: MetaColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: MetaColors.surfaceHighlight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MetaColors.emerald),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 6 ? 'A senha deve ter no mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 32),

                  // Botão Criar Conta
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: SquircleButton(
                      label: _isLoading
                          ? 'Criando sua conta...'
                          : isInviteRegistration
                              ? 'Criar conta e continuar'
                              : 'Criar conta grátis',
                      isPrimary: true,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? () {} : _handleRegister,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Já tem conta?
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Já tem uma conta? ',
                        style: TextStyle(color: MetaColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                initialRole: widget.initialRole,
                                initialEmail: _emailCtrl.text.trim(),
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
