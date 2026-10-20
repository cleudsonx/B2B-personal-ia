import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/pwa_installer.dart';
import 'meta_components.dart';

/// Card de indução e instruções para o aluno instalar o PWA na tela inicial.
/// Renderiza apenas no ambiente Web quando o app NÃO está em modo standalone.
class PwaInstallPromptCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;
  final EdgeInsetsGeometry margin;

  const PwaInstallPromptCard({
    super.key,
    this.title = 'Instale o App na Tela Inicial',
    this.subtitle =
        'Abra seus treinos com 1 toque, sem login repetitivo e com modo offline para quando o Wi-Fi da academia oscilar.',
    this.compact = false,
    this.margin = const EdgeInsets.symmetric(vertical: 16),
  });

  /// Exibe o modal instrucional correspondente ao sistema operacional do usuário
  static void showInstallInstructions(BuildContext context) {
    if (PwaInstaller.isIosWeb) {
      _showIosInstructions(context);
    } else {
      if (PwaInstaller.canPromptInstall) {
        PwaInstaller.promptInstall();
      } else {
        _showAndroidInstructions(context);
      }
    }
  }

  static void _showIosInstructions(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final text = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtext = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtext.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apple_rounded, color: MetaColors.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar ao iPhone / iPad',
                          style: TextStyle(
                            color: text,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Apenas 3 passos no Safari',
                          style: TextStyle(
                            color: subtext,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildInstructionStep(
                step: '1',
                icon: Icons.ios_share_rounded,
                title: 'Toque em Compartilhar',
                description: 'Toque no ícone de compartilhamento (quadrado com seta para cima) na barra do Safari.',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 14),
              _buildInstructionStep(
                step: '2',
                icon: Icons.add_box_outlined,
                title: 'Adicionar à Tela de Início',
                description: 'Role as opções para baixo e toque em "Adicionar à Tela de Início".',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 14),
              _buildInstructionStep(
                step: '3',
                icon: Icons.check_circle_outline_rounded,
                title: 'Confirmar e Abrir',
                description: 'Toque em "Adicionar" no topo direito. O ícone do app estará na sua tela inicial!',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: SquircleButton(
                  label: 'Entendido!',
                  icon: Icons.check_rounded,
                  isPrimary: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showAndroidInstructions(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final text = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtext = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtext.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.android_rounded, color: MetaColors.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar no Android',
                          style: TextStyle(
                            color: text,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Passo a passo no Chrome / Navegador',
                          style: TextStyle(
                            color: subtext,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildInstructionStep(
                step: '1',
                icon: Icons.more_vert_rounded,
                title: 'Abra o Menu do Navegador',
                description: 'Toque nos três pontinhos no canto superior direito do navegador.',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 14),
              _buildInstructionStep(
                step: '2',
                icon: Icons.install_mobile_rounded,
                title: 'Instalar Aplicativo',
                description: 'Selecione "Instalar aplicativo" ou "Adicionar à tela inicial".',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 14),
              _buildInstructionStep(
                step: '3',
                icon: Icons.check_circle_outline_rounded,
                title: 'Confirmar Instalação',
                description: 'Confirme o pop-up nativo. O Mr. Coach abrirá em tela cheia com alta velocidade!',
                textColor: text,
                subtextColor: subtext,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: SquircleButton(
                  label: 'Entendido!',
                  icon: Icons.check_rounded,
                  isPrimary: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildInstructionStep({
    required String step,
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: MetaColors.emerald, width: 1.2),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: MetaColors.emerald,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: MetaColors.emerald, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || PwaInstaller.isPwaInstalled) {
      return const SizedBox.shrink();
    }

    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final cardBorder = isDark ? MetaColors.border : MetaColors.lightBorder;
    final text = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtext = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final isIos = PwaInstaller.isIosWeb;
    final buttonLabel = isIos ? 'Adicionar no iPhone (Guia Rápido)' : 'Instalar Aplicativo com 1 Toque';
    final buttonIcon = isIos ? Icons.apple_rounded : Icons.download_rounded;

    return Container(
      margin: margin,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.install_mobile_rounded,
                  color: MetaColors.emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'EXPERIÊNCIA COMPLETA',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontSize: compact ? 14 : 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: subtext,
              fontSize: compact ? 11.5 : 12.5,
              height: 1.4,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildBenefitTag('⚡ Tela Cheia', text, isDark),
                _buildBenefitTag('🔔 Alertas em Tempo Real', text, isDark),
                _buildBenefitTag('📶 Acesso Offline', text, isDark),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SquircleButton(
              label: buttonLabel,
              icon: buttonIcon,
              isPrimary: true,
              onPressed: () => showInstallInstructions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTag(String label, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? MetaColors.surfaceHighlight : MetaColors.lightSurfaceHighlight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
