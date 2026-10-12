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

class TeacherMfaScreen extends StatefulWidget {
  final Future<void> Function()? onVerified;
  final bool allowEnrollment;

  const TeacherMfaScreen({
    super.key,
    this.onVerified,
    this.allowEnrollment = true,
  });

  @override
  State<TeacherMfaScreen> createState() => _TeacherMfaScreenState();
}

class _TeacherMfaScreenState extends State<TeacherMfaScreen> {
  final _codeController = TextEditingController();
  AuthMFAEnrollResponse? _enrollment;
  String? _factorId;
  bool _loading = true;
  bool _submitting = false;
  bool _alreadyEnabled = false;
  String? _error;

  bool get _isEnrolling => _enrollment != null;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final factorId = await AuthService.getVerifiedTotpFactorId();
      if (factorId != null) {
        if (await AuthService.isCurrentSessionAal2()) {
          if (widget.onVerified != null) {
            await widget.onVerified!.call();
          } else if (mounted) {
            setState(() {
              _factorId = factorId;
              _alreadyEnabled = true;
            });
          }
          return;
        }
        if (mounted) setState(() => _factorId = factorId);
        return;
      }
      if (!widget.allowEnrollment) {
        throw StateError('Configure a verificação em duas etapas antes de continuar.');
      }
      final enrollment = await AuthService.enrollTeacherTotp();
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.formatMfaError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenerateEnrollment() async {
    setState(() {
      _loading = true;
      _error = null;
      _codeController.clear();
    });
    try {
      final enrollment = await AuthService.enrollTeacherTotp();
      if (mounted) {
        setState(() => _enrollment = enrollment);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nova chave de configuração gerada com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.formatMfaError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInAuthenticator() async {
    final uriStr = _enrollment?.totp?.uri;
    if (uriStr != null && uriStr.isNotEmpty) {
      try {
        final uri = Uri.parse(uriStr);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          _copySecret();
        }
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

  Future<void> _verify() async {
    final factorId = _enrollment?.id ?? _factorId;
    final sanitizedCode = _codeController.text.replaceAll(RegExp(r'\D'), '').trim();

    if (factorId == null || sanitizedCode.length != 6) {
      setState(() => _error = 'Digite o código de exatamente seis dígitos do aplicativo autenticador.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await AuthService.verifyTotp(
        factorId: factorId,
        code: sanitizedCode,
      );
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

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secret = _enrollment?.totp?.secret;
    final isDark = MetaColors.isDark(context);

    final isConfirming = _factorId != null && !_isEnrolling;

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        title: Text(
          'Segurança do treinador',
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
              const SizedBox(height: 20),
              Text(
                isConfirming
                    ? 'Confirme sua identidade'
                    : 'Ative a verificação em duas etapas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isConfirming
                    ? 'Digite o código de 6 dígitos gerado pelo seu aplicativo autenticador para liberar o painel do treinador.'
                    : 'Adicione a chave abaixo ao seu aplicativo autenticador (Google Authenticator, Microsoft ou 1Password) para proteger o acesso às ferramentas de treinador.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 40),
                const Center(
                  child: CircularProgressIndicator(color: MetaColors.emerald),
                ),
                const SizedBox(height: 40),
              ] else if (secret != null) ...[
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
                        'CHAVE DE CONFIGURAÇÃO',
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
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _loading ? null : _regenerateEnrollment,
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Gerar nova chave'),
                    style: TextButton.styleFrom(
                      foregroundColor: MetaColors.subtext(context),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
              if (_alreadyEnabled) ...[
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
                              'Verificação em duas etapas ativa',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sua conta de treinador já está protegida.',
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
              ],
              if (!_loading && !_alreadyEnabled && (_isEnrolling || _factorId != null)) ...[
                const SizedBox(height: 16),
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
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10,
                    ),
                    onChanged: (val) {
                      if (val.replaceAll(RegExp(r'\D'), '').length == 6 && !_submitting) {
                        _verify();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Código de 6 dígitos',
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
                const SizedBox(height: 18),
                SquircleButton(
                  label: _isEnrolling ? 'Ativar e continuar' : 'Verificar código',
                  icon: Icons.lock_open,
                  isLoading: _submitting,
                  isPrimary: true,
                  onPressed: _submitting ? null : _verify,
                ),
                if (isConfirming) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showGuideDialog(context),
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text('Onde encontro este código?'),
                      style: TextButton.styleFrom(
                        foregroundColor: MetaColors.subtext(context),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
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
                            if (_isEnrolling) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _regenerateEnrollment,
                                child: Text(
                                  '→ Toque aqui para gerar uma nova chave limpa',
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
                if (_factorId == null && _enrollment == null) ...[
                  const SizedBox(height: 16),
                  SquircleButton(
                    label: 'Tentar novamente',
                    icon: Icons.refresh,
                    isPrimary: true,
                    onPressed: _prepare,
                  ),
                ],
              ],
              if (!_loading && !_alreadyEnabled) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaColors.cardBorder(context).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: MetaColors.subtext(context),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'O código expira a cada 30 segundos. Caso o erro persista, verifique se a data e a hora do seu smartphone estão configuradas como automáticas (padrão de rede).',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
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

  void _showGuideDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAuthenticatorGuide(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            'Para a segurança dos seus alunos e faturamento, o Mr. Coach utiliza autenticação em dois fatores. O app autenticador gera tokens temporários de 6 dígitos que mudam a cada 30 segundos.',
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'PASSO 1: BAIXE UM AUTENTICADOR GRATUITO',
            style: TextStyle(
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
            style: TextStyle(
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
            text: 'Selecione "Inserir chave de configuração" e cole a chave abaixo (ou toque em "Abrir no App").',
          ),
          const SizedBox(height: 8),
          _buildGuideStepItem(
            context,
            number: '3',
            text: 'O autenticador começará a gerar um código de 6 dígitos. Digite esse código no campo de verificação.',
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