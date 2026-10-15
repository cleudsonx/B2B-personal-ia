import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'meta_components.dart';

/// Rodapé elegante de versionamento para o ecossistema Mr. Coach / Shaipados.
///
/// Exibe a versão e número de compilação oficiais (`v1.2.0 • Build 2026102701`),
/// com indicador de status da nuvem e modal interativo com as novidades da versão.
class AppVersionFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const AppVersionFooter({
    super.key,
    this.padding = const EdgeInsets.only(top: 24, bottom: 32),
  });

  void _showReleaseNotesModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
        final border = isDark ? MetaColors.border : MetaColors.lightBorder;
        final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
        final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: subtextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: MetaColors.emerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mr. Coach Personal IA',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppConfig.fullVersionString,
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: border, height: 1),
                const SizedBox(height: 16),
                Text(
                  'NOVIDADES DESTA VERSÃO',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _buildChangelogItem(
                  icon: Icons.shield_moon_rounded,
                  title: 'Bio-Recovery & Prontidão Real',
                  description:
                      'Score diário de prontidão biomecânica e telemetria de RPE integrado em tempo real no Supabase.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Galeria Sigilosa Antes x Depois',
                  description:
                      'Fotos criptografadas com RLS para acompanhamento visual da evolução física do aluno pelo professor.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.trending_up_rounded,
                  title: 'Sobrecarga Progressiva Sincronizada',
                  description:
                      'Histórico real de cargas registradas pelo aluno exibido no dashboard de detalhes do professor.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.sync_rounded,
                  title: 'Versionamento & PWA Heartbeat',
                  description:
                      'Detecção automática de deploys com atualização instantânea e sem retenção de cache.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChangelogItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: MetaColors.emerald),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12,
                  height: 1.3,
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
    final isDark = MetaColors.isDark(context);
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final pillBg = isDark ? MetaColors.surfaceHighlight.withValues(alpha: 0.5) : MetaColors.lightSurfaceHighlight;
    final pillBorder = isDark ? MetaColors.border : MetaColors.lightBorder;

    return Padding(
      padding: padding,
      child: Center(
        child: InkWell(
          onTap: () => _showReleaseNotesModal(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pillBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: MetaColors.emerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6610B981),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mr. Coach AI',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppConfig.fullVersionString,
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Toque para ver as novidades',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

