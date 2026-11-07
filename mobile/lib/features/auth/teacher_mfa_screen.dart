import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/pwa_installer.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/smart_install_banner.dart';
import '../../services/auth_service.dart';

enum MfaMethod {
  whatsapp,
  email,
  authenticator,
  backupCode,
}

class TeacherMfaScreen extends StatefulWidget {
  final Future<void> Function()? onVerified;
  final bool allowEnrollment;
  final MfaMethod initialMethod;

  const TeacherMfaScreen({
    super.key,
    this.onVerified,
    this.allowEnrollment = true,
    this.initialMethod = MfaMethod.whatsapp,
  });

  @override
  State<TeacherMfaScreen> createState() => _TeacherMfaScreenState();
}

class _TeacherMfaScreenState extends State<TeacherMfaScreen> {
  final _codeController = TextEditingController();
  
  MfaMethod _currentMethod = MfaMethod.whatsapp;
  bool _rememberDevice = true;
  
  AuthMFAEnrollResponse? _enrollment;
  String? _factorId;
  bool _loading = true;
  bool _submitting = false;
  bool _alreadyEnabled = false;
  String? _error;
  String? _destinationHint;
  
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  bool get _isEnrollingTotp => _currentMethod == MfaMethod.authenticator && _enrollment != null;

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.initialMethod;
    _prepare();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown([int seconds = 45]) {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Verifica se já está com MFA satisfeito (AAL2 ou dispositivo confiável ativo)
      if (await AuthService.isCurrentSessionMfaSatisfied()) {
        if (widget.onVerified != null) {
          await widget.onVerified!.call();
        } else if (mounted) {
          setState(() => _alreadyEnabled = true);
        }
        return;
      }

      // 2. Verifica se o usuário tem TOTP cadastrado
      final factorId = await AuthService.getVerifiedTotpFactorId();
      _factorId = factorId;

      // 3. Define método inicial inteligente:
      // Se tiver TOTP e o usuário não especificou WhatsApp explicitamente, podemos oferecer TOTP
      // mas se o usuário entrou normalmente, WhatsApp é o canal padrão de menor atrito no Brasil.
      if (factorId != null && widget.initialMethod == MfaMethod.authenticator) {
        _currentMethod = MfaMethod.authenticator;
      } else {
        _currentMethod = MfaMethod.whatsapp;
        await _requestOtpCode(channel: 'whatsapp', showToast: false);
      }
    } catch (error) {
      // Se falhar ao solicitar no WhatsApp (ex: professor não tem telefone cadastrado ainda), faz fallback para TOTP ou Email
      if (_currentMethod == MfaMethod.whatsapp) {
        try {
          _currentMethod = MfaMethod.email;
          await _requestOtpCode(channel: 'email', showToast: false);
        } catch (_) {
          if (_factorId != null) {
            _currentMethod = MfaMethod.authenticator;
          } else if (widget.allowEnrollment) {
            _currentMethod = MfaMethod.authenticator;
            final enrollment = await AuthService.enrollTeacherTotp();
            if (mounted) setState(() => _enrollment = enrollment);
          }
        }
      } else if (mounted) {
        setState(() => _error = AuthService.formatMfaError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestOtpCode({required String channel, bool showToast = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AuthService.requestMfaCode(channel: channel);
      final dest = res['masked_target'] as String?;
      if (mounted) {
        setState(() {
          _destinationHint = dest;
        });
        _startCountdown(45);
        if (showToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Código enviado para ${dest ?? channel}!'),
              backgroundColor: MetaColors.emerald,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchMethod(MfaMethod method) async {
    if (_currentMethod == method) return;
    setState(() {
      _currentMethod = method;
      _codeController.clear();
      _error = null;
    });

    if (method == MfaMethod.whatsapp) {
      await _requestOtpCode(channel: 'whatsapp');
    } else if (method == MfaMethod.email) {
      await _requestOtpCode(channel: 'email');
    } else if (method == MfaMethod.authenticator) {
      if (_factorId == null && _enrollment == null && widget.allowEnrollment) {
        setState(() => _loading = true);
        try {
          final enrollment = await AuthService.enrollTeacherTotp();
          if (mounted) setState(() => _enrollment = enrollment);
        } catch (e) {
          if (mounted) setState(() => _error = AuthService.formatMfaError(e));
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _verify() async {
    final rawCode = _codeController.text.trim();
    final sanitizedCode = rawCode.replaceAll(RegExp(r'\s+'), '');

    if (sanitizedCode.isEmpty) {
      setState(() => _error = 'Por favor, digite o código de verificação.');
      return;
    }

    if (_currentMethod == MfaMethod.backupCode) {
      if (sanitizedCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length != 10) {
        setState(() => _error = 'O código de reserva tem 10 caracteres (ex.: ABCDE-FGHJK).');
        return;
      }
    } else {
      final digits = sanitizedCode.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 6) {
        setState(() => _error = 'O código de verificação deve ter exatamente 6 dígitos.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_currentMethod == MfaMethod.whatsapp || _currentMethod == MfaMethod.email) {
        await AuthService.verifyMfaCode(
          code: sanitizedCode,
          rememberDevice: _rememberDevice,
        );
      } else if (_currentMethod == MfaMethod.authenticator) {
        final factorId = _enrollment?.id ?? _factorId;
        if (factorId == null) {
          throw StateError('Fator de autenticação não identificado.');
        }
        await AuthService.verifyTotp(
          factorId: factorId,
          code: sanitizedCode.replaceAll(RegExp(r'\D'), ''),
        );
      } else if (_currentMethod == MfaMethod.backupCode) {
        await AuthService.verifyMfaBackupCode(
          code: sanitizedCode.toUpperCase(),
          rememberDevice: _rememberDevice,
        );
      }

      if (widget.onVerified != null) {
        await widget.onVerified!.call();
      } else if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = AuthService.formatMfaError(error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openInAuthenticator() async {
    final uriStr = _enrollment?.totp?.uri;
    if (uriStr != null && uriStr.isNotEmpty) {
      try {
        final uri = Uri.parse(uriStr);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) _copySecret();
      } catch (_) {
        _copySecret();
      }
    } else {
      _copySecret();
    }
  }

  void _copySecret() {
    final secret = _enrollment?.totp?.secret;
    if (secret != null && secret.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: secret));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chave copiada para a área de transferência!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openStore(String appName) async {
    Uri url;
    final isIos = !kIsWeb ? Platform.isIOS : PwaInstaller.isIosWeb;
    if (appName == 'google') {
      if (isIos) {
        url = Uri.parse('https://apps.apple.com/app/google-authenticator/id388497605');
      } else {
        url = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2');
      }
    } else {
      if (isIos) {
        url = Uri.parse('https://apps.apple.com/app/microsoft-authenticator/id983156458');
      } else {
        url = Uri.parse('https://play.google.com/store/apps/details?id=com.azure.authenticator');
      }
    }
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Não foi possível abrir a loja de aplicativos.'),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _showAlternativeMethodsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.bg(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Opções de verificação',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: MetaColors.subtext(context)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha como deseja receber ou validar sua verificação em duas etapas:',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _buildMethodOptionTile(
                context,
                title: 'WhatsApp (Recomendado)',
                subtitle: 'Envio rápido e direto no seu WhatsApp cadastrado',
                icon: Icons.chat_bubble_outline,
                badge: 'Sem app extra',
                badgeColor: MetaColors.emerald,
                selected: _currentMethod == MfaMethod.whatsapp,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchMethod(MfaMethod.whatsapp);
                },
              ),
              const SizedBox(height: 10),
              _buildMethodOptionTile(
                context,
                title: 'E-mail',
                subtitle: 'Código de segurança enviado para sua caixa de entrada',
                icon: Icons.mail_outline,
                selected: _currentMethod == MfaMethod.email,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchMethod(MfaMethod.email);
                },
              ),
              const SizedBox(height: 10),
              _buildMethodOptionTile(
                context,
                title: 'Aplicativo Autenticador',
                subtitle: 'Google Authenticator, Microsoft ou 1Password',
                icon: Icons.security_rounded,
                selected: _currentMethod == MfaMethod.authenticator,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchMethod(MfaMethod.authenticator);
                },
              ),
              const SizedBox(height: 10),
              _buildMethodOptionTile(
                context,
                title: 'Código de reserva',
                subtitle: 'Use um dos seus 8 códigos de emergência salvos',
                icon: Icons.vpn_key_outlined,
                selected: _currentMethod == MfaMethod.backupCode,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchMethod(MfaMethod.backupCode);
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(ctx);
                  _showResetTotpDialog();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Perdeu o autenticador ou trocou de celular?',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.orangeAccent, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? MetaColors.emerald.withValues(alpha: 0.1)
              : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? MetaColors.emerald : MetaColors.cardBorder(context),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (selected ? MetaColors.emerald : MetaColors.subtext(context)).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? MetaColors.emerald : MetaColors.text(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? MetaColors.emerald).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor ?? MetaColors.emerald,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: MetaColors.emerald, size: 20),
          ],
        ),
      ),
    );
  }

  void _showResetTotpDialog() {
    final recoveryCodeController = TextEditingController();
    String channel = 'whatsapp';
    bool requesting = false;
    bool resetting = false;
    bool codeSent = false;
    String? maskedTarget;
    String? resetError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: MetaColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Desvincular Autenticador',
                  style: TextStyle(color: MetaColors.text(context), fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se você trocou de aparelho ou não tem mais acesso ao aplicativo autenticador, enviaremos um código de segurança para seu WhatsApp ou E-mail para desvincular o app anterior.',
                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Via WhatsApp'),
                      selected: channel == 'whatsapp',
                      onSelected: (val) {
                        if (val) setDialogState(() => channel = 'whatsapp');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Via E-mail'),
                      selected: channel == 'email',
                      onSelected: (val) {
                        if (val) setDialogState(() => channel = 'email');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (codeSent) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Código enviado com sucesso para ${maskedTarget ?? (channel == "whatsapp" ? "seu WhatsApp" : "seu E-mail")}!',
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: requesting
                      ? null
                      : () async {
                          setDialogState(() {
                            requesting = true;
                            resetError = null;
                          });
                          try {
                            final res = await AuthService.requestMfaCode(channel: channel);
                            setDialogState(() {
                              codeSent = true;
                              maskedTarget = res['masked_target']?.toString();
                              resetError = null;
                            });
                            if (mounted) {
                              AppToast.success(
                                context,
                                'Código de segurança enviado para ${maskedTarget ?? (channel == "whatsapp" ? "WhatsApp" : "E-mail")}!',
                                title: 'Código Enviado',
                                icon: Icons.mark_chat_read_rounded,
                              );
                            }
                          } catch (e) {
                            final raw = e.toString().replaceAll('Exception: ', '');
                            final friendly = (raw.contains('Not Found') || raw.contains('404'))
                                ? 'Serviço de 2FA em atualização no servidor. Tente em instantes ou faça deploy das novas rotas no Render.'
                                : raw;
                            setDialogState(() => resetError = friendly);
                          } finally {
                            setDialogState(() => requesting = false);
                          }
                        },
                  icon: requesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(codeSent ? Icons.refresh_rounded : Icons.send, size: 16),
                  label: Text(requesting
                      ? 'Enviando código...'
                      : (codeSent ? 'Reenviar código de recuperação' : '1. Solicitar código de recuperação')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: codeSent ? MetaColors.emerald.withValues(alpha: 0.15) : MetaColors.highlight(context),
                    foregroundColor: codeSent ? MetaColors.emerald : MetaColors.text(context),
                    side: codeSent ? BorderSide(color: MetaColors.emerald.withValues(alpha: 0.4)) : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: recoveryCodeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: '2. Digite o código de 6 dígitos recebido',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (resetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    resetError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: resetting
                  ? null
                  : () async {
                      final code = recoveryCodeController.text.trim();
                      if (code.length != 6) {
                        setDialogState(() => resetError = 'Digite os 6 dígitos recebidos.');
                        return;
                      }
                      setDialogState(() {
                        resetting = true;
                        resetError = null;
                      });
                      try {
                        await AuthService.resetMfaTotp(
                          code: code,
                          channel: channel,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          AppToast.success(
                            context,
                            'Autenticador desvinculado com sucesso!',
                            title: '2FA Desvinculado',
                            icon: Icons.check_circle_rounded,
                          );
                          _prepare();
                        }
                      } catch (e) {
                        setDialogState(() => resetError = e.toString().replaceAll('Exception: ', ''));
                      } finally {
                        setDialogState(() => resetting = false);
                      }
                    },
              child: Text(resetting ? 'Desvinculando...' : 'Confirmar e Desvincular'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secret = _enrollment?.totp?.secret;
    final isDark = MetaColors.isDark(context);

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        title: Text(
          'Segurança do Treinador',
          style: TextStyle(
            color: MetaColors.text(context),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: MetaColors.bg(context),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: Icon(Icons.logout, color: MetaColors.subtext(context), size: 20),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shrinkWrap: true,
            children: [
              const SmartInstallBanner(),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: MetaColors.emerald,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _getHeaderTitle(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getHeaderSubtitle(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              if (_destinationHint != null && (_currentMethod == MfaMethod.whatsapp || _currentMethod == MfaMethod.email)) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.cardBorder(context)),
                    ),
                    child: Text(
                      'Destino: $_destinationHint',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              if (_loading) ...[
                const SizedBox(height: 40),
                const Center(
                  child: CircularProgressIndicator(color: MetaColors.emerald),
                ),
                const SizedBox(height: 40),
              ] else if (_alreadyEnabled) ...[
                const SizedBox(height: 24),
                MetaCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: MetaColors.emerald, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dispositivo verificado e seguro',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu acesso às ferramentas de treinador está liberado.',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Guia do Authenticator apenas se o método for Authenticator e estiver em enrollment
                if (_isEnrollingTotp && secret != null) ...[
                  const SizedBox(height: 20),
                  _buildAuthenticatorGuide(context),
                  const SizedBox(height: 20),
                  MetaCard(
                    padding: const EdgeInsets.all(18),
                    borderRadius: 16,
                    backgroundColor: MetaColors.highlight(context),
                    borderColor: MetaColors.cardBorder(context),
                    child: Column(
                      children: [
                        Text(
                          'CHAVE DE CONFIGURAÇÃO MANUAL',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          secret,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _copySecret,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copiar chave'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MetaColors.text(context),
                                side: BorderSide(color: MetaColors.cardBorder(context)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openInAuthenticator,
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Abrir no App'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MetaColors.primaryColor(context),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                // Campo de digitação de código
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _error != null
                          ? Colors.redAccent.withValues(alpha: 0.8)
                          : MetaColors.cardBorder(context),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _codeController,
                    keyboardType: _currentMethod == MfaMethod.backupCode
                        ? TextInputType.text
                        : TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: _currentMethod == MfaMethod.backupCode ? 11 : 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textCapitalization: _currentMethod == MfaMethod.backupCode
                        ? TextCapitalization.characters
                        : TextCapitalization.none,
                    inputFormatters: _currentMethod == MfaMethod.backupCode
                        ? [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                            LengthLimitingTextInputFormatter(11),
                          ]
                        : [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: _currentMethod == MfaMethod.backupCode ? 4 : 8,
                    ),
                    onChanged: (val) {
                      final isBackup = _currentMethod == MfaMethod.backupCode;
                      final typed = isBackup
                          ? val.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                          : val.trim();
                      if (typed.length == (isBackup ? 10 : 6) && !_submitting) {
                        _verify();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: _currentMethod == MfaMethod.backupCode
                          ? 'Código de reserva (10 caracteres)'
                          : 'Código de 6 dígitos',
                      labelStyle: TextStyle(
                        color: MetaColors.subtext(context),
                        letterSpacing: 0,
                        fontSize: 14,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // Checkbox "Lembrar deste dispositivo por 30 dias"
                InkWell(
                  onTap: () => setState(() => _rememberDevice = !_rememberDevice),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _rememberDevice,
                          onChanged: (v) => setState(() => _rememberDevice = v ?? true),
                          activeColor: MetaColors.emerald,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        Expanded(
                          child: Text(
                            'Confiar neste dispositivo por 30 dias (não pedir código a cada login)',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                SquircleButton(
                  label: _getSubmitButtonLabel(),
                  icon: Icons.lock_open,
                  isLoading: _submitting,
                  isPrimary: true,
                  onPressed: _submitting ? null : _verify,
                ),

                // Reenviar código (se método for WhatsApp ou Email)
                if (_currentMethod == MfaMethod.whatsapp || _currentMethod == MfaMethod.email) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: _secondsRemaining > 0
                        ? Text(
                            'Reenviar código em ${_secondsRemaining}s',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _requestOtpCode(
                                      channel: _currentMethod == MfaMethod.whatsapp ? 'whatsapp' : 'email',
                                    ),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reenviar código agora'),
                            style: TextButton.styleFrom(
                              foregroundColor: MetaColors.emerald,
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ],

                const SizedBox(height: 12),
                // Botão "Tentar de outro jeito"
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _showAlternativeMethodsModal,
                    icon: const Icon(Icons.alt_route, size: 16),
                    label: const Text('Tentar de outro jeito'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetaColors.text(context),
                      side: BorderSide(color: MetaColors.cardBorder(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_currentMethod == MfaMethod.authenticator) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _showResetTotpDialog,
                                child: Text(
                                  '→ Perdeu o autenticador? Toque aqui para desvincular com segurança',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _signOut,
                  child: Text(
                    'Entrar com outra conta',
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_currentMethod) {
      case MfaMethod.whatsapp:
        return 'Código via WhatsApp';
      case MfaMethod.email:
        return 'Código via E-mail';
      case MfaMethod.authenticator:
        return _isEnrollingTotp ? 'Ativar Autenticador' : 'Código do Autenticador';
      case MfaMethod.backupCode:
        return 'Código de Reserva';
    }
  }

  String _getHeaderSubtitle() {
    switch (_currentMethod) {
      case MfaMethod.whatsapp:
        return 'Enviamos um código temporário de 6 dígitos para o seu WhatsApp para liberar o painel com total agilidade.';
      case MfaMethod.email:
        return 'Enviamos um código de segurança de 6 dígitos para a caixa de entrada do seu e-mail.';
      case MfaMethod.authenticator:
        return _isEnrollingTotp
            ? 'Adicione a chave abaixo ao seu aplicativo autenticador preferido (Google Authenticator, Microsoft ou 1Password).'
            : 'Digite o código de 6 dígitos gerado pelo seu aplicativo autenticador.';
      case MfaMethod.backupCode:
        return 'Digite um dos seus códigos de emergência de 8 caracteres salvos na ativação da conta.';
    }
  }

  String _getSubmitButtonLabel() {
    if (_isEnrollingTotp) return 'Ativar e continuar';
    return 'Verificar código';
  }

  Widget _buildAuthenticatorGuide(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Como funciona o Autenticador?',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Se optar por app autenticador, ele gera tokens temporários de 6 dígitos que mudam a cada 30 segundos, sem depender de sinal de operadora.',
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'PASSO 1: BAIXE UM AUTENTICADOR GRATUITO',
            style: const TextStyle(
              color: MetaColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openStore('google'),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Google Auth', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetaColors.text(context),
                    side: BorderSide(color: MetaColors.cardBorder(context)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openStore('microsoft'),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Microsoft Auth', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetaColors.text(context),
                    side: BorderSide(color: MetaColors.cardBorder(context)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'PASSO 2: CONFIGURE A CONTA',
            style: const TextStyle(
              color: MetaColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _buildGuideStepItem(
            context,
            number: '1',
            text: 'Abra o Google ou Microsoft Authenticator e toque no botão (+) no aplicativo.',
          ),
          const SizedBox(height: 8),
          _buildGuideStepItem(
            context,
            number: '2',
            text: 'Selecione "Inserir chave de configuração" e cole a chave manual abaixo (ou toque em "Abrir no App").',
          ),
          const SizedBox(height: 8),
          _buildGuideStepItem(
            context,
            number: '3',
            text: 'Digite o código de 6 dígitos gerado pelo aplicativo.',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStepItem(BuildContext context, {required String number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: MetaColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
