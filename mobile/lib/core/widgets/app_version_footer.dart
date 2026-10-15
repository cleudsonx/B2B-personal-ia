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
                  icon: Icons.bolt_rounded,
                  title: 'Smart Re-entry PWA',
                  description:
                      'Acessos subsequentes direcionam direto para o app ou tela de login, dispensando a landing page.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.view_in_ar_rounded,
                  title: 'Mr. Coach AI Biomecânico',
                  description:
                      'Motor de resposta com loop 3D anatômico e destaque do músculo primário com Raio-X interativo.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.history_edu_rounded,
                  title: 'Histórico Social Otimizado',
                  description:
                      'Visualização de treinos concluídos em cards responsivos com duração real e sem cortes de tela.',
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
                const SizedBox(height: 10),
                _buildChangelogItem(
                  icon: Icons.sync_rounded,
                  title: 'Atualizações em Segundo Plano',
                  description:
                      'Detecção inteligente de novas versões para você nunca perder a série durante o treino.',
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
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    return Padding(
      padding: padding,
      child: Center(
        child: InkWell(
          onTap: () => _showReleaseNotesModal(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: MetaColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Mr. Coach AI',
                      style: TextStyle(
                        color: subtextColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        color: subtextColor.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppConfig.fullVersionString,
                      style: TextStyle(
                        color: subtextColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Toque para ver as notas desta versão',
                  style: TextStyle(
                    color: subtextColor.withValues(alpha: 0.45),
                    fontSize: 10,
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
