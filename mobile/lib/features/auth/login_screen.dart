import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/widgets/meta_components.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../services/auth_service.dart';
import 'auth_gate.dart';
import '../client/welcome_onboarding_screen.dart';
import 'teacher_mfa_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialRole;
  final String? initialEmail;
  final bool confirmationRequired;
  final String? invitedStudentId;
  final String? invitedTrainerId;
  final String? invitedTrainerName;
  final String? inviteToken;

  const LoginScreen({
    super.key,
    this.initialRole = 'trainer',
    this.initialEmail,
    this.confirmationRequired = false,
    this.invitedStudentId,
    this.invitedTrainerId,
    this.invitedTrainerName,
    this.inviteToken,
  });

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
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
    _passwordCtrl = TextEditingController();
    if (widget.confirmationRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirme o e-mail enviado e depois entre com sua senha.'),
          ),
        );
      });
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
      await _continueAfterAuthentication();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, 
            backgroundColor: Colors.red.shade800,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAfterAuthentication() async {
    if (widget.inviteToken != null && widget.inviteToken!.isNotEmpty) {
      await AuthService.consumeInviteToken(widget.inviteToken!);
    }
    var profile = await AuthService.getCurrentProfile();
    if (widget.invitedStudentId != null) {
      final user = AuthService.currentUser;
      final isInvitedStudent =
          user?.id == widget.invitedStudentId &&
          profile?['trainer_id'] == widget.invitedTrainerId &&
          AuthService.availableRoles(profile).contains('client');
      if (!isInvitedStudent) {
        await AuthService.signOut();
        throw StateError('Entre com a conta de aluno vinculada a este convite.');
      }
    }
    await AuthService.completePendingInvite();
    profile = await AuthService.getCurrentProfile();
    final roles = AuthService.availableRoles(profile);
    if (!roles.contains(_selectedRole)) {
      throw StateError('Esta conta não possui acesso ao perfil selecionado.');
    }
    await AuthService.setActiveRole(_selectedRole);
    if (roles.contains('trainer') &&
        !await AuthService.isCurrentSessionAal2()) {
      if (!mounted) return;
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const TeacherMfaScreen()),
      );
      if (verified != true) {
        await AuthService.signOut();
        return;
      }
      if (!mounted) return;
    }

    profile = await AuthService.getCurrentProfile();
    final role = _selectedRole;
    final user = AuthService.currentUser;
    final userName = (profile?['full_name'] as String?)?.isNotEmpty == true
        ? profile!['full_name'] as String
        : (user?.userMetadata?['full_name'] as String?)?.isNotEmpty == true
            ? user!.userMetadata!['full_name'] as String
            : role == 'trainer'
                ? 'Personal Trainer'
                : 'Aluno no Salão';
    final hasCompletedAnamnesis = profile?['has_completed_anamnesis'] == true;

    if (!mounted) return;
    if (role == 'client' && !hasCompletedAnamnesis) {
      final trainer = await AuthService.getTrainerForStudent();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WelcomeOnboardingScreen(
            studentName: userName,
            trainerName: widget.invitedTrainerName ?? (trainer?['full_name'] as String?),
          ),
        ),
      );
    } else {
      _navigateToDashboard();
    }
  }

  Future<void> _handleBiometricAuth() async {
    final localAuth = LocalAuthentication();
    try {
      final canCheckBiometrics = await localAuth.canCheckBiometrics;
      final isDeviceSupported = await localAuth.isDeviceSupported();
      if (!canCheckBiometrics && !isDeviceSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(behavior: SnackBarBehavior.floating, 
              backgroundColor: MetaColors.surfaceHighlight,
              content: Text(
                'Autenticação biométrica não disponível neste dispositivo.',
                style: TextStyle(color: MetaColors.textPrimary),
              ),
            ),
          );
        }
        return;
      }

      final didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Autentique-se com biometria para acessar sua conta',
      );

      if (didAuthenticate && mounted) {
        final user = AuthService.currentUser;
        if (user != null) {
          await _continueAfterAuthentication();
        } else {
          if (_emailCtrl.text.isNotEmpty && _passwordCtrl.text.isNotEmpty) {
            await _handleSignIn();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(behavior: SnackBarBehavior.floating, 
                backgroundColor: MetaColors.surfaceHighlight,
                content: Text(
                  'Biometria validada. Faça o primeiro login com seu e-mail e senha para vincular sua biometria.',
                  style: TextStyle(color: MetaColors.textPrimary),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, 
            backgroundColor: Colors.red.shade800,
            content: Text('Falha na autenticação biométrica: $e'),
          ),
        );
      }
    }
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate(skipBiometric: true)),
      (_) => false,
    );
  }

  void _showVerifyOtpDialog(String identifier) {
    final otpCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MetaColors.border),
            ),
            title: const Text(
              'Verificar Código OTP',
              style: TextStyle(color: MetaColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Insira o código de 6 dígitos enviado para $identifier e defina sua nova senha.',
                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpCtrl,
                  style: const TextStyle(color: MetaColors.textPrimary, letterSpacing: 4, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    hintText: '123456',
                    counterText: '',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nova Senha (mín. 6 caracteres)',
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: MetaColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting ? null : () async {
                  final otp = otpCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
                  final pwd = passwordCtrl.text.trim();
                  if (otp.length != 6 || pwd.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text('Digite o código de 6 dígitos e uma nova senha com no mínimo 6 caracteres.'),
                      ),
                    );
                    return;
                  }
                  
                  setDialogState(() => isSubmitting = true);
                  try {
                    await AuthService.verifyRecoveryOtp(identifier, otp, pwd);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating, 
                          backgroundColor: MetaColors.emerald,
                          content: Text('Senha redefinida com sucesso! Você já pode entrar com sua nova senha.'),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating, 
                          backgroundColor: Colors.red.shade800,
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                        ),
                      );
                    }
                  }
                },
                child: Text(isSubmitting ? 'Verificando...' : 'Redefinir'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final inputCtrl = TextEditingController(text: _emailCtrl.text);
    String selectedChannel = 'whatsapp'; // Padrão Brasil: WhatsApp
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MetaColors.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: MetaColors.emerald, size: 24),
                SizedBox(width: 10),
                Text(
                  'Recuperar Acesso',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
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
                const Text(
                  'Escolha por onde deseja receber seu código ou link de recuperação:',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Seletor de Canal (WhatsApp vs E-mail)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedChannel = 'whatsapp'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedChannel == 'whatsapp'
                                ? MetaColors.emerald.withValues(alpha: 0.15)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'whatsapp'
                                  ? MetaColors.emerald
                                  : MetaColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_rounded,
                                size: 16,
                                color: selectedChannel == 'whatsapp'
                                    ? MetaColors.emerald
                                    : MetaColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedChannel == 'whatsapp'
                                      ? MetaColors.emerald
                                      : MetaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => selectedChannel = 'email'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedChannel == 'email'
                                ? MetaColors.emerald.withValues(alpha: 0.15)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'email'
                                  ? MetaColors.emerald
                                  : MetaColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.email_rounded,
                                size: 16,
                                color: selectedChannel == 'email'
                                    ? MetaColors.emerald
                                    : MetaColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'E-mail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedChannel == 'email'
                                      ? MetaColors.emerald
                                      : MetaColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: inputCtrl,
                  style: const TextStyle(color: MetaColors.textPrimary),
                  keyboardType: selectedChannel == 'whatsapp' ? TextInputType.phone : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: selectedChannel == 'whatsapp' ? 'WhatsApp (com DDD)' : 'E-mail cadastrado',
                    hintText: selectedChannel == 'whatsapp' ? '11999999999' : 'seu@email.com',
                    hintStyle: TextStyle(color: MetaColors.textSecondary.withValues(alpha: 0.5)),
                    labelStyle: const TextStyle(color: MetaColors.textSecondary),
                    filled: true,
                    fillColor: MetaColors.surfaceHighlight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MetaColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MetaColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSubmitting ? null : () async {
                  final textVal = inputCtrl.text.trim();
                  if (textVal.isEmpty) return;

                  setDialogState(() => isSubmitting = true);

                  try {
                    await AuthService.requestRecoveryOtp(textVal, selectedChannel);
                    if (mounted) {
                      Navigator.pop(ctx);
                      _showVerifyOtpDialog(textVal);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating, 
                          backgroundColor: MetaColors.emerald,
                          content: Text(
                            selectedChannel == 'email'
                                ? 'Código enviado para o e-mail $textVal'
                                : 'Código enviado via WhatsApp para $textVal',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(behavior: SnackBarBehavior.floating, 
                          backgroundColor: Colors.red.shade800,
                          content: Text(e.toString().replaceAll('Exception: ', '')),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  isSubmitting ? 'Enviando...' : (selectedChannel == 'whatsapp' ? 'Enviar WhatsApp' : 'Enviar E-mail'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTrainer = _selectedRole == 'trainer';
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: topPadding + 24,
            bottom: bottomPadding + 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Logo Icon / Brand
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: MetaColors.surfaceHighlight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isTrainer
                              ? Icons.sports_gymnastics
                              : Icons.fitness_center_rounded,
                          color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Center(
                      child: Text(
                        'MR. COACH',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: MetaColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        widget.initialRole == 'client'
                            ? 'Ãrea do Aluno â€¢ Treino Inteligente'
                            : 'Plataforma para Personal Trainers & IA Biomecânica',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: MetaColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (widget.invitedStudentId != null) ...[
                      Text(
                        'Convite de ${widget.invitedTrainerName ?? 'seu treinador'}. A conta de aluno já foi criada. Use a opção Esqueceu a senha? para definir sua senha.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MetaColors.accentBlue,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Role Selector Tabs (se não for link exclusivo de aluno)
                    if (widget.initialRole != 'client') ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: MetaColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MetaColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildRoleTab(
                                title: 'Treinador Pro',
                                icon: Icons.sports_gymnastics,
                                isSelected: isTrainer,
                                activeColor: MetaColors.emerald,
                                onTap: () => _onRoleChanged('trainer'),
                              ),
                            ),
                            Expanded(
                              child: _buildRoleTab(
                                title: 'Aluno no Salão',
                                icon: Icons.fitness_center_rounded,
                                isSelected: !isTrainer,
                                activeColor: MetaColors.accentBlue,
                                onTap: () => _onRoleChanged('client'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Email Input
                    TextFormField(
                      controller: _emailCtrl,
                      style: const TextStyle(color: MetaColors.textPrimary),
                      keyboardType: TextInputType.emailAddress,
                      readOnly: widget.invitedStudentId != null,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Informe seu e-mail';
                        }
                        if (!val.contains('@')) {
                          return 'Informe um e-mail válido';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: const TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: MetaColors.textSecondary,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: MetaColors.surfaceHighlight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MetaColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MetaColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: MetaColors.textPrimary),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Informe sua senha';
                        }
                        if (val.length < 6) {
                          return 'A senha deve ter no mínimo 6 dígitos';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: const TextStyle(
                          color: MetaColors.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: MetaColors.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: MetaColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        filled: true,
                        fillColor: MetaColors.surfaceHighlight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MetaColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: MetaColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remember Me & Forgot Password Row
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: MetaColors.emerald,
                                checkColor: Colors.black,
                                side: const BorderSide(
                                  color: MetaColors.textSecondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) =>
                                    setState(() => _rememberMe = val ?? true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Lembrar acesso',
                              style: TextStyle(
                                color: MetaColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: MetaColors.textSecondary,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Esqueceu a senha?',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botão de entrar: SquircleButton (isPrimary: true, label: "Entrar")
                    SquircleButton(
                      label: 'Entrar',
                      isPrimary: true,
                      isLoading: _isLoading,
                      onPressed: _handleSignIn,
                    ),
                    const SizedBox(height: 12),

                    if (widget.invitedStudentId == null) ...[
                      SquircleButton(
                        label: 'Entrar com biometria',
                        icon: Icons.fingerprint,
                        isPrimary: false,
                        backgroundColor: MetaColors.surfaceHighlight,
                        foregroundColor: MetaColors.textSecondary,
                        onPressed: _handleBiometricAuth,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Register Link
                    if (widget.invitedStudentId == null) Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Ainda não tem conta? ',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(
                                  initialRole: _selectedRole,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Cadastre-se grátis',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Landing Web Link
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.public_rounded,
                          size: 16,
                          color: MetaColors.textSecondary,
                        ),
                        label: const Text(
                          'Conhecer o Mr. Coach B2B',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/b2b');
                        },
                      ),
                    ),

                    // API Server Config Shortcut (Only in Debug Mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.settings_ethernet,
                            size: 14,
                            color: MetaColors.textSecondary,
                          ),
                          label: const Text(
                            'Configurar IP da API Backend (Dev)',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          onPressed: () => ServerConfigDialog.show(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'from',
                            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.science_rounded, color: MetaColors.emerald, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Shaipados Labs',
                                style: TextStyle(color: MetaColors.emerald, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ],
                      ),
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.surfaceHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : MetaColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? MetaColors.textPrimary : MetaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





