import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/biometric_auth_service.dart';

import '../../core/widgets/meta_components.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/smart_install_banner.dart';
import '../../services/auth_service.dart';
import 'auth_gate.dart';
import '../client/welcome_onboarding_screen.dart';
import '../client/student_suspended_screen.dart';
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

  // Smart Re-entry (Bem-vindo de volta)
  bool _isWelcomeBackMode = false;
  String _cachedUserName = '';
  String? _cachedUserPhoto;
  String _cachedUserEmail = '';

  @override
  void initState() {
    super.initState();
    final initialEmailLower = (widget.initialEmail ?? '').toLowerCase();
    final isInitialCleudson = AuthService.isCanonicalOwnerEmail(initialEmailLower);
    _selectedRole = isInitialCleudson ? 'trainer' : widget.initialRole;
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
    _emailCtrl.addListener(() {
      final text = _emailCtrl.text.trim().toLowerCase();
      if (AuthService.isCanonicalOwnerEmail(text) && _selectedRole != 'trainer') {
        setState(() => _selectedRole = 'trainer');
      }
    });
    _passwordCtrl = TextEditingController();
    _checkLastAuthenticatedUser();
    if (widget.confirmationRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirme o e-mail enviado e depois entre com sua senha.'),
          ),
        );
      });
    }
  }

  Future<void> _checkLastAuthenticatedUser() async {
    // Se o usuário clicou em um link de convite com token ou e-mail específico, respeita o fluxo de convite
    if (widget.invitedStudentId != null || (widget.initialEmail != null && widget.initialEmail!.isNotEmpty)) {
      return;
    }
    final lastUser = await AuthService.getLastAuthenticatedUser();
    if (lastUser != null && lastUser['email']?.isNotEmpty == true && mounted) {
      setState(() {
        _isWelcomeBackMode = true;
        _cachedUserName = lastUser['name'] ?? '';
        _cachedUserPhoto = lastUser['photo']?.isNotEmpty == true ? lastUser['photo'] : null;
        _cachedUserEmail = lastUser['email']!;
        final emailLower = _cachedUserEmail.toLowerCase();
        final isCleudsonEmail = AuthService.isCanonicalOwnerEmail(emailLower);
        _selectedRole = isCleudsonEmail ? 'trainer' : (lastUser['role'] ?? _selectedRole);
        _emailCtrl.text = _cachedUserEmail;
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
    final isCleudson = AuthService.isCurrentUserAdminSync() ||
        AuthService.isCanonicalOwnerEmail(profile?['email']?.toString());
    if (widget.invitedStudentId != null && !isCleudson) {
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
    if (isCleudson && _selectedRole == 'client') {
      _selectedRole = 'trainer';
    }
    if (!roles.contains(_selectedRole)) {
      if (roles.contains('client') && _selectedRole == 'trainer') {
        if (!mounted) return;
        final switchRole = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: MetaColors.card(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: MetaColors.cardBorder(ctx)),
            ),
            title: Text(
              'Perfil de Aluno',
              style: TextStyle(
                color: MetaColors.text(ctx),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Esta conta está cadastrada como Aluno. Deseja acessar o portal do Aluno agora?',
              style: TextStyle(color: MetaColors.subtext(ctx)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.subtext(ctx)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                ),
                child: Text('Acessar como Aluno'),
              ),
            ],
          ),
        );
        if (switchRole == true) {
          _selectedRole = 'client';
        } else {
          await AuthService.signOut();
          return;
        }
      } else if (roles.contains('trainer') && _selectedRole == 'client') {
        if (!mounted) return;
        final switchRole = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: MetaColors.card(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: MetaColors.cardBorder(ctx)),
            ),
            title: Text(
              'Perfil de Treinador',
              style: TextStyle(
                color: MetaColors.text(ctx),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Esta conta possui perfil de Professor/Treinador. Deseja acessar o portal do Treinador?',
              style: TextStyle(color: MetaColors.subtext(ctx)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.subtext(ctx)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                ),
                child: Text('Acessar como Treinador'),
              ),
            ],
          ),
        );
        if (switchRole == true) {
          _selectedRole = 'trainer';
        } else {
          await AuthService.signOut();
          return;
        }
      } else {
        throw StateError('Esta conta não possui acesso ao perfil selecionado.');
      }
    }
    await AuthService.setActiveRole(_selectedRole);
    final mfaEnrolled = profile?['mfa_enabled'] == true ||
        (profile?['mfa_verified_at'] != null && (profile?['mfa_factors'] as List?)?.isNotEmpty == true);
    if (roles.contains('trainer') &&
        mfaEnrolled &&
        !await AuthService.isCurrentSessionMfaSatisfied()) {
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

    // Salva perfil para reentrada inteligente (Smart Re-entry)
    final savedEmail = user?.email ?? _emailCtrl.text.trim();
    if (savedEmail.isNotEmpty) {
      await AuthService.saveLastAuthenticatedUser(
        email: savedEmail,
        name: userName,
        photoUrl: (profile?['photo_url'] ?? profile?['avatar_url']) as String?,
        role: role,
      );
      if (_passwordCtrl.text.isNotEmpty) {
        await AuthService.saveOneTouchSecret(savedEmail, _passwordCtrl.text);
      }
    }

    if (!mounted) return;
    if (role == 'client') {
      final subscriptionStatus =
          (profile?['subscription_status'] as String?)?.toLowerCase();
      if (subscriptionStatus == 'suspended') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentSuspendedScreen(
              studentName: userName,
              trainerId: profile?['trainer_id'] as String?,
            ),
          ),
        );
        return;
      }

      if (!hasCompletedAnamnesis) {
        final trainer = await AuthService.getTrainerForStudent();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WelcomeOnboardingScreen(
              studentName: userName,
              trainerName: widget.invitedTrainerName ?? (trainer?['full_name'] as String?),
              trainerId: widget.invitedTrainerId ??
                  (profile?['trainer_id'] as String?) ??
                  (trainer?['id'] as String?),
              trainerAvatarUrl: (trainer?['photo_url'] as String?) ??
                  (trainer?['avatar_url'] as String?),
            ),
          ),
        );
        return;
      }
    }
    _navigateToDashboard();
  }

  Future<void> _handleBiometricAuth() async {
    String targetEmail = _cachedUserEmail.isNotEmpty ? _cachedUserEmail : _emailCtrl.text.trim();
    if (targetEmail.isEmpty) {
      final lastUser = await AuthService.getLastAuthenticatedUser();
      if (lastUser != null && (lastUser['email']?.isNotEmpty ?? false)) {
        targetEmail = lastUser['email']!;
      }
    }

    if (targetEmail.isEmpty && AuthService.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.highlight(context),
            content: Text(
              'Para entrar em 1 toque, acesse primeiro via WhatsApp ou e-mail neste aparelho.',
              style: TextStyle(color: MetaColors.text(context)),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authResult = await BiometricAuthService.authenticate(
        localizedReason: 'Autentique-se com biometria ou Face ID para acessar sua conta',
      );

      if (!authResult.success) {
        if (mounted && authResult.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: MetaColors.highlight(context),
              content: Text(
                authResult.errorMessage!,
                style: TextStyle(color: MetaColors.text(context)),
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // 1. Se já existe usuário com sessão ativa no Supabase:
      final user = AuthService.currentUser;
      if (user != null) {
        await _continueAfterAuthentication();
        return;
      }

      // 2. Se temos a credencial de 1 toque salva neste aparelho:
      final savedSecret = await AuthService.getOneTouchSecret(targetEmail);
      if (savedSecret != null && savedSecret.isNotEmpty) {
        _passwordCtrl.text = savedSecret;
        _emailCtrl.text = targetEmail;
        await _handleSignIn();
        return;
      }

      // 3. Se a senha foi informada no campo:
      if (_passwordCtrl.text.isNotEmpty) {
        await _handleSignIn();
        return;
      }

      // 4. Biometria validada, mas precisa do primeiro login para vincular o 1 toque:
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.highlight(context),
            content: Text(
              'Biometria confirmada! Entre com sua senha ou via WhatsApp uma vez para ativar o retorno com 1 toque.',
              style: TextStyle(color: MetaColors.text(context)),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.highlight(context),
            content: Text(
              'Falha no leitor biométrico. Por favor, use sua senha ou WhatsApp.',
              style: TextStyle(color: MetaColors.text(context)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showWhatsAppPasswordlessSheet() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    bool codeSent = false;
    bool isSubmitting = false;
    String maskedPhone = '';
    String? currentError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = MetaColors.isDark(context);
          final bg = isDark ? const Color(0xFF13171F) : Colors.white;
          final border = Border.all(color: isDark ? const Color(0xFF232B39) : const Color(0xFFE2E8F0));
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header com ícone WhatsApp
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Color(0xFF25D366),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              codeSent ? 'Digite o Código de 6 Dígitos' : 'Acesso Rápido WhatsApp',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              codeSent
                                  ? 'Enviado para $maskedPhone'
                                  : 'Receba um código de 6 dígitos no WhatsApp sem senha.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (currentError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        currentError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (!codeSent) ...[
                    // Confirmação explícita do perfil (evita cadastro no perfil errado)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: MetaColors.highlight(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Sou Personal / Professor',
                              icon: Icons.sports_gymnastics,
                              isSelected: _selectedRole == 'trainer',
                              activeColor: MetaColors.emerald,
                              onTap: () {
                                _onRoleChanged('trainer');
                                setSheetState(() => currentError = null);
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Sou Aluno',
                              icon: Icons.fitness_center_rounded,
                              isSelected: _selectedRole == 'client',
                              activeColor: MetaColors.accentBlue,
                              onTap: () {
                                _onRoleChanged('client');
                                setSheetState(() => currentError = null);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedRole == 'trainer'
                          ? 'Você está criando ou acessando uma conta PROFISSIONAL de Personal Trainer.'
                          : 'Aluno entra com o WhatsApp que seu personal convidou. Ainda não tem personal? Escolha um na Vitrine.',
                      style: TextStyle(color: subColor, fontSize: 12, height: 1.35),
                    ),
                    if (_selectedRole == 'client') ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(context, '/prof');
                          },
                          icon: const Icon(Icons.search_rounded, size: 16, color: MetaColors.accentBlue),
                          label: const Text(
                            'Encontrar um Personal na Vitrine',
                            style: TextStyle(color: MetaColors.accentBlue, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Nome (opcional para novo aluno)
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: _selectedRole == 'trainer'
                            ? 'Seu nome (opcional se já tiver conta)'
                            : 'Seu nome (opcional)',
                        labelStyle: TextStyle(color: subColor, fontSize: 13),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: subColor, size: 20),
                        filled: true,
                        fillColor: MetaColors.highlight(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // WhatsApp com máscara
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Número do WhatsApp (com DDD)',
                        hintText: '61 99999-9999',
                        labelStyle: TextStyle(color: subColor, fontSize: 13),
                        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF25D366), size: 20),
                        filled: true,
                        fillColor: MetaColors.highlight(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final rawP = phoneCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
                                if (rawP.length < 10) {
                                  setSheetState(() => currentError = 'Digite seu número com DDD (mínimo 10 dígitos).');
                                  return;
                                }
                                setSheetState(() {
                                  isSubmitting = true;
                                  currentError = null;
                                });
                                try {
                                  final res = await AuthService.requestPasswordlessOtp(
                                    phone: rawP,
                                    role: _selectedRole,
                                    fullName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                                  );
                                  setSheetState(() {
                                    codeSent = true;
                                    isSubmitting = false;
                                    maskedPhone = res['masked_phone'] ?? rawP;
                                  });
                                } catch (e) {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    currentError = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          isSubmitting ? 'Enviando Código...' : 'Enviar Código via WhatsApp',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Campo Código 6 Dígitos
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        filled: true,
                        fillColor: MetaColors.highlight(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onChanged: (val) {
                        if (val.length == 6 && !isSubmitting) {
                          // Auto submeter ao digitar os 6 dígitos
                          _submitOtpVerification(
                            phoneCtrl.text.replaceAll(RegExp(r'\D'), '').trim(),
                            val,
                            nameCtrl.text.trim(),
                            ctx,
                            setSheetState,
                            (err) => setSheetState(() => currentError = err),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => _submitOtpVerification(
                                  phoneCtrl.text.replaceAll(RegExp(r'\D'), '').trim(),
                                  otpCtrl.text.trim(),
                                  nameCtrl.text.trim(),
                                  ctx,
                                  setSheetState,
                                  (err) => setSheetState(() => currentError = err),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetaColors.emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isSubmitting ? 'Autenticando...' : 'Confirmar e Acessar',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Center(
                      child: TextButton(
                        onPressed: isSubmitting ? null : () => setSheetState(() => codeSent = false),
                        child: Text(
                          'Alterar número de telefone',
                          style: TextStyle(color: subColor, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitOtpVerification(
    String cleanPhone,
    String code,
    String fullName,
    BuildContext sheetCtx,
    StateSetter setSheetState,
    void Function(String) onError,
  ) async {
    if (code.length != 6) {
      onError('Digite os 6 dígitos recebidos no WhatsApp.');
      return;
    }
    setSheetState(() => _isLoading = true);
    try {
      await AuthService.verifyPasswordlessOtp(
        phone: cleanPhone,
        code: code,
        role: _selectedRole,
        fullName: fullName.isNotEmpty ? fullName : null,
      );
      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx); // Fechar bottom sheet
      }
      await _continueAfterAuthentication();
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setSheetState(() => _isLoading = false);
    }
  }

  void _enterDemoTourMode() {
    // Redireciona diretamente para o AuthGate em modo Convidado / Navegação livre
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate(skipBiometric: true)),
      (_) => false,
    );
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
            backgroundColor: MetaColors.card(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: MetaColors.cardBorder(ctx)),
            ),
            title: Text(
              'Verificar Código OTP',
              style: TextStyle(color: MetaColors.text(context), fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Insira o código de 6 dígitos enviado para $identifier e defina sua nova senha.',
                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpCtrl,
                  style: TextStyle(color: MetaColors.text(context), letterSpacing: 4, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    hintText: '123456',
                    counterText: '',
                    labelStyle: TextStyle(color: MetaColors.subtext(context)),
                    filled: true,
                    fillColor: MetaColors.highlight(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: TextStyle(color: MetaColors.text(context)),
                  decoration: InputDecoration(
                    labelText: 'Nova Senha (mín. 6 caracteres)',
                    labelStyle: TextStyle(color: MetaColors.subtext(context)),
                    filled: true,
                    fillColor: MetaColors.highlight(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(context))),
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
                      SnackBar(
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
                        SnackBar(
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
            backgroundColor: MetaColors.card(ctx),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: MetaColors.cardBorder(ctx)),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: MetaColors.emerald, size: 24),
                SizedBox(width: 10),
                Text(
                  'Recuperar Acesso',
                  style: TextStyle(
                    color: MetaColors.text(ctx),
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
                  'Escolha por onde deseja receber seu código ou link de recuperação:',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
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
                                : MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'whatsapp'
                                  ? MetaColors.emerald
                                  : MetaColors.cardBorder(context),
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
                                    : MetaColors.subtext(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedChannel == 'whatsapp'
                                      ? MetaColors.emerald
                                      : MetaColors.subtext(context),
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
                                : MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedChannel == 'email'
                                  ? MetaColors.emerald
                                  : MetaColors.cardBorder(context),
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
                                    : MetaColors.subtext(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'E-mail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedChannel == 'email'
                                      ? MetaColors.emerald
                                      : MetaColors.subtext(context),
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
                  style: TextStyle(color: MetaColors.text(context)),
                  keyboardType: selectedChannel == 'whatsapp' ? TextInputType.phone : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: selectedChannel == 'whatsapp' ? 'WhatsApp (com DDD)' : 'E-mail cadastrado',
                    hintText: selectedChannel == 'whatsapp' ? '11999999999' : 'seu@email.com',
                    hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5)),
                    labelStyle: TextStyle(color: MetaColors.subtext(context)),
                    filled: true,
                    fillColor: MetaColors.highlight(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.cardBorder(context)),
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
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.subtext(ctx)),
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
                            style: TextStyle(color: Colors.white),
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
                  style: TextStyle(fontWeight: FontWeight.bold),
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
    final isDark = MetaColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
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
                    const SmartInstallBanner(),
                    const SizedBox(height: 12),
                    if (_isWelcomeBackMode) ...[
                      // Modo "Bem-vindo de volta" (Smart Re-entry)
                      const SizedBox(height: 8),
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: MetaColors.highlight(context),
                              backgroundImage: safeImageProvider(_cachedUserPhoto),
                              child: safeImageProvider(_cachedUserPhoto) == null
                                  ? Text(
                                      _cachedUserName.trim().isNotEmpty
                                          ? _cachedUserName.trim().substring(0, 1).toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: MetaColors.bg(context), width: 2),
                                ),
                                child: Icon(
                                  isTrainer ? Icons.sports_gymnastics : Icons.fitness_center_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Bem-vindo de volta,',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          _cachedUserName.isNotEmpty ? _cachedUserName : 'Usuário',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isTrainer ? MetaColors.emerald : MetaColors.accentBlue).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isTrainer ? MetaColors.emerald : MetaColors.accentBlue).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            isTrainer ? 'Personal Trainer Pro' : 'Aluno no Salão',
                            style: TextStyle(
                              color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Password Input
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        autofocus: true,
                        style: TextStyle(color: MetaColors.text(context)),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Informe sua senha';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Sua senha',
                          labelStyle: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: MetaColors.subtext(context),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: MetaColors.subtext(context),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          filled: true,
                          fillColor: MetaColors.highlight(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: MetaColors.subtext(context),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Esqueceu a senha?',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SquircleButton(
                        label: 'Entrar',
                        isPrimary: true,
                        isLoading: _isLoading,
                        onPressed: _handleSignIn,
                      ),
                      const SizedBox(height: 12),

                      SquircleButton(
                        label: kIsWeb ? 'Retornar com biometria (1 toque)' : 'Entrar com biometria',
                        icon: Icons.fingerprint,
                        isPrimary: false,
                        backgroundColor: MetaColors.highlight(context),
                        foregroundColor: MetaColors.text(context),
                        onPressed: _handleBiometricAuth,
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isWelcomeBackMode = false;
                              _passwordCtrl.clear();
                              _emailCtrl.clear();
                            });
                          },
                          child: Text(
                            'Entrar com outra conta',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Logo Icon / Brand
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
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
                      Center(
                        child: Text(
                          'MR. COACH',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: MetaColors.text(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          widget.initialRole == 'client'
                              ? 'Área do Aluno • Treino Inteligente'
                              : 'Plataforma para Personal Trainers & IA Biomecânica',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: MetaColors.subtext(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (widget.invitedStudentId != null) ...[
                        Text(
                          'Convite de ${widget.invitedTrainerName ?? 'seu treinador'}. A conta de aluno já foi criada. Use a opção Esqueceu a senha? para definir sua senha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: MetaColors.accentBlue,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Role Selector Tabs (se não for link exclusivo de aluno)
                      if (widget.initialRole != 'client' || _selectedRole == 'trainer') ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: MetaColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: MetaColors.cardBorder(context)),
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

                      // Acesso de Alta Segurança & Zero Fricção (Biometria / Face ID & WhatsApp OTP)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleBiometricAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MetaColors.emerald,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, size: 22),
                          label: const Text(
                            'Entrar com Face ID / Biometria (1 Toque)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _showWhatsAppPasswordlessSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF25D366),
                            side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 20, color: Color(0xFF25D366)),
                          label: Text(
                            isTrainer
                                ? 'Entrar ou Criar Conta de Professor via WhatsApp'
                                : 'Entrar na Área do Aluno via WhatsApp',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Divisor Elegante
                      Row(
                        children: [
                          Expanded(child: Divider(color: MetaColors.cardBorder(context), height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou entrar com e-mail e senha',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: MetaColors.cardBorder(context), height: 1)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Email Input
                      TextFormField(
                        controller: _emailCtrl,
                        style: TextStyle(color: MetaColors.text(context)),
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
                          labelStyle: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: MetaColors.subtext(context),
                            size: 20,
                          ),
                          filled: true,
                          fillColor: MetaColors.highlight(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Input
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: MetaColors.text(context)),
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
                          labelStyle: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: MetaColors.subtext(context),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: MetaColors.subtext(context),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          filled: true,
                          fillColor: MetaColors.highlight(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: MetaColors.cardBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isTrainer ? MetaColors.emerald : MetaColors.accentBlue, width: 1.5),
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
                                  side: BorderSide(
                                    color: MetaColors.subtext(context),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) =>
                                      setState(() => _rememberMe = val ?? true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lembrar acesso',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: MetaColors.subtext(context),
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Esqueceu a senha?',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
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
                      const SizedBox(height: 16),

                      // Botão Modo Tour / Conhecer a Plataforma sem Barreiras
                      Center(
                        child: TextButton.icon(
                          onPressed: _enterDemoTourMode,
                          icon: const Icon(Icons.explore_outlined, size: 18, color: MetaColors.emerald),
                          label: const Text(
                            'Experimentar sem cadastro (Modo Tour)',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Register Link
                      if (widget.invitedStudentId == null)
                        if (_selectedRole == 'trainer')
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Ainda não tem conta? ',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(
                                        initialRole: 'trainer',
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Cadastre-se grátis',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: MetaColors.highlight(context).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: MetaColors.cardBorder(context)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'O acesso do aluno é criado mediante convite exclusivo do seu professor.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(context, '/prof');
                                  },
                                  child: Text(
                                    'Ainda não tem treinador? Conheça nossos profissionais',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                    const SizedBox(height: 16),

                    // Landing Web Link
                    Center(
                      child: TextButton.icon(
                        icon: Icon(
                          Icons.public_rounded,
                          size: 16,
                          color: MetaColors.subtext(context),
                        ),
                        label: Text(
                          'Conhecer o Mr. Coach B2B',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
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
                          icon: Icon(
                            Icons.settings_ethernet,
                            size: 14,
                            color: MetaColors.subtext(context),
                          ),
                          label: Text(
                            'Configurar IP da API Backend (Dev)',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
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
                          Text(
                            'Mr. Coach',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Plataforma para Treinadores',
                            style: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
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
          color: isSelected ? MetaColors.highlight(context) : Colors.transparent,
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
              color: isSelected ? activeColor : MetaColors.subtext(context),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? MetaColors.text(context) : MetaColors.subtext(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





