import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/meta_components.dart';
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
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final factorId = _enrollment?.id ?? _factorId;
    if (factorId == null || _codeController.text.trim().length < 6) {
      setState(() => _error = 'Digite o código de seis dígitos do autenticador.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthService.verifyTotp(
        factorId: factorId,
        code: _codeController.text,
      );
      if (widget.onVerified != null) {
        await widget.onVerified!.call();
      } else if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secret = _enrollment?.totp?.secret;
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        title: const Text('Segurança do treinador'),
        backgroundColor: MetaColors.background,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Icon(Icons.verified_user_outlined, size: 48, color: MetaColors.emerald),
              const SizedBox(height: 20),
              Text(
                _isEnrolling ? 'Ative a verificação em duas etapas' : 'Confirme sua identidade',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MetaColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                _isEnrolling
                    ? 'Adicione esta chave em um aplicativo autenticador. Ela protege o acesso às ferramentas de treinador.'
                    : 'Digite o código atual do aplicativo autenticador para liberar o acesso de treinador.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: MetaColors.textSecondary, height: 1.5),
              ),
              if (_loading) ...[
                const SizedBox(height: 28),
                const Center(child: CircularProgressIndicator()),
              ] else if (secret != null) ...[
                const SizedBox(height: 28),
                SelectableText(
                  secret,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MetaColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: secret)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar chave de configuração'),
                ),
                const SizedBox(height: 20),
              ],
              if (_alreadyEnabled) ...[
                const SizedBox(height: 28),
                const ListTile(
                  leading: Icon(Icons.check_circle, color: MetaColors.emerald),
                  title: Text('Verificação em duas etapas ativa'),
                  subtitle: Text('O acesso de treinador exige um código do autenticador.'),
                ),
              ],
              if (!_loading && !_alreadyEnabled && (_isEnrolling || _factorId != null)) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 8,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  decoration: const InputDecoration(
                    labelText: 'Código do autenticador',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _verify,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_open),
                  label: Text(_isEnrolling ? 'Ativar e continuar' : 'Verificar código'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}