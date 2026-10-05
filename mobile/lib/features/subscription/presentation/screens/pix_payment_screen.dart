import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/meta_components.dart';

class PixPaymentScreen extends StatefulWidget {
  final String pixCode;

  const PixPaymentScreen({super.key, required this.pixCode});

  @override
  State<PixPaymentScreen> createState() => _PixPaymentScreenState();
}

class _PixPaymentScreenState extends State<PixPaymentScreen> {
  bool _copied = true; // Assume it was copied when entering the screen

  @override
  void initState() {
    super.initState();
    _copyToClipboard();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.pixCode));
    setState(() => _copied = true);
  }

  void _openBankApp(String scheme, String fallbackUrl) async {
    final uri = Uri.parse(scheme);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback for when the scheme is not found (app not installed)
        final fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Não foi possível abrir o app do banco: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: MetaColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: MetaColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Finalizar',
              style: TextStyle(
                color: MetaColors.emerald, // Tonalidade Meta de ação positiva
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Success
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seu código Pix foi copiado\ncom sucesso!',
                    style: const TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Instructions List
            _buildStepRow('1', 'Agora abra o app do seu banco ou carteira digital, ou selecione um dos ícones abaixo.'),
            _buildStepRow('2', 'Escolha a opção "Pix Copia e Cola".'),
            _buildStepRow('3', 'Cole o código Pix copiado.'),
            _buildStepRow('4', 'Confirme o pagamento.'),
            _buildStepRow('5', 'Será enviado um e-mail de confirmação e a plataforma será liberada.'),

            const SizedBox(height: 40),

            // Bank Quick Links
            const Text(
              'Caso possua um dos bancos abaixo, clique no ícone para ser redirecionado:',
              style: TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Bank Grid
            Wrap(
              spacing: 16,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildBankButton('Nubank', 'Nu', const Color(0xFF8A05BE), Colors.white, 'nubank://', 'https://nubank.com.br/'),
                _buildBankButton('Caixa', 'X', const Color(0xFF005CA9), Colors.orange, 'caixa://', 'https://www.caixa.gov.br/'),
                _buildBankButton('B. Brasil', 'BB', const Color(0xFFFBE015), const Color(0xFF003DA5), 'bb://', 'https://www.bb.com.br/'),
                _buildBankButton('Itaú', 'It', const Color(0xFFEC7000), const Color(0xFF002959), 'itau://', 'https://www.itau.com.br/'),
                _buildBankButton('Bradesco', 'Br', const Color(0xFFCC092F), Colors.white, 'bradesco://', 'https://banco.bradesco/'),
                _buildBankButton('Santander', 'Sa', const Color(0xFFEC0000), Colors.white, 'santander://', 'https://www.santander.com.br/'),
                _buildBankButton('C6 Bank', 'C6', const Color(0xFF242424), Colors.white, 'c6bank://', 'https://www.c6bank.com.br/'),
                _buildBankButton('PicPay', 'P', const Color(0xFF11C76F), Colors.white, 'picpay://', 'https://picpay.com/'),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Pix Code display and copy again
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MetaColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MetaColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Código Pix',
                    style: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.pixCode,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SquircleButton(
                    label: _copied ? 'Copiado!' : 'Copiar Código',
                    isPrimary: !_copied,
                    icon: _copied ? Icons.check : Icons.copy,
                    onPressed: _copyToClipboard,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: MetaColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankButton(
    String name,
    String initials,
    Color bgColor,
    Color textColor,
    String scheme,
    String fallbackUrl,
  ) {
    return GestureDetector(
      onTap: () => _openBankApp(scheme, fallbackUrl),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
