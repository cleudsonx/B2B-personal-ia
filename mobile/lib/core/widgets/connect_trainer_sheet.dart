import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../features/landing/public_trainer_directory_screen.dart';
import 'meta_components.dart';

class ConnectTrainerSheet extends StatefulWidget {
  final VoidCallback? onLinked;

  const ConnectTrainerSheet({super.key, this.onLinked});

  static Future<void> show(BuildContext context, {VoidCallback? onLinked}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConnectTrainerSheet(onLinked: onLinked),
    );
  }

  @override
  State<ConnectTrainerSheet> createState() => _ConnectTrainerSheetState();
}

class _ConnectTrainerSheetState extends State<ConnectTrainerSheet> {
  final _codeCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeemCode() async {
    final raw = _codeCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorMessage = 'Informe o link ou código de convite.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final token = raw.contains('/') ? raw.split('/').last.split('?').first : raw;

    try {
      await AuthService.consumeInviteToken(token);
      if (!mounted) return;
      Navigator.pop(context); // Fecha sheet
      widget.onLinked?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Vinculado com sucesso ao seu Personal Trainer!'),
          backgroundColor: MetaColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF131722) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final cardBg = isDark ? MetaColors.surfaceHighlight : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: cardBorder),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header com Badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.handshake_rounded, color: MetaColors.emerald, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conectar Personal Trainer',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Treinos personalizados com IA e acompanhamento',
                        style: TextStyle(color: subtextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Opção 1: Escolher na Vitrine
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: MetaColors.accentBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Ainda não tem personal?',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explore nossa vitrine de treinadores credenciados, confira especialidades e contrate seu plano.',
                    style: TextStyle(color: subtextColor, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PublicTrainerDirectoryScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: const Text(
                        'Explorar Vitrine de Personais',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Divisor "OU"
            Row(
              children: [
                Expanded(child: Divider(color: cardBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OU',
                    style: TextStyle(color: subtextColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(child: Divider(color: cardBorder)),
              ],
            ),
            const SizedBox(height: 16),

            // Opção 2: Já tem convite / código
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key_rounded, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Já recebeu um convite?',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cole o link de convite recebido pelo WhatsApp ou digite o código/token enviado pelo seu personal:',
                    style: TextStyle(color: subtextColor, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeCtrl,
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ex: mrcoach.app/#/invite/token123',
                      hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.5), fontSize: 12.5),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      prefixIcon: Icon(Icons.link_rounded, color: subtextColor, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _redeemCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Vincular com Código',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
