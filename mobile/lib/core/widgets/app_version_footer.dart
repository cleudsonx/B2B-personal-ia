import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_changelog.dart';
import '../config/app_config.dart';
import 'meta_components.dart';

/// Rodapé elegante de versionamento para o ecossistema Mr. Coach / Shaipados.
///
/// Exibe a versão oficial (`v1.3.9 • Build 2026102817`), com modal dinâmico
/// de changelog alimentado por [AppChangelog] e suporte a auto-abertura no primeiro acesso à versão.
class AppVersionFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  static const String _lastSeenBuildKey = 'pwa_last_seen_changelog_build';

  const AppVersionFooter({
    super.key,
    this.padding = const EdgeInsets.only(top: 24, bottom: 32),
  });

  /// Verifica se o usuário já viu as novidades desta versão. Se for a primeira vez,
  /// exibe o modal automaticamente após o carregamento da tela.
  static Future<void> checkAndShowAutoModal(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt(_lastSeenBuildKey) ?? 0;
      final currentBuild = AppChangelog.current.buildNumber;

      if (currentBuild > lastSeen) {
        await prefs.setInt(_lastSeenBuildKey, currentBuild);
        if (context.mounted) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (context.mounted) {
              showReleaseNotesModal(context);
            }
          });
        }
      }
    } catch (_) {}
  }

  /// Exibe o modal interativo com as novidades da versão atual e histórico anterior
  static void showReleaseNotesModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ReleaseNotesModalContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final pillBg = isDark
        ? MetaColors.surfaceHighlight.withValues(alpha: 0.5)
        : MetaColors.lightSurfaceHighlight;
    final pillBorder = isDark ? MetaColors.border : MetaColors.lightBorder;

    return Padding(
      padding: padding,
      child: Center(
        child: InkWell(
          onTap: () => showReleaseNotesModal(context),
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

class _ReleaseNotesModalContent extends StatefulWidget {
  const _ReleaseNotesModalContent();

  @override
  State<_ReleaseNotesModalContent> createState() => _ReleaseNotesModalContentState();
}

class _ReleaseNotesModalContentState extends State<_ReleaseNotesModalContent> {
  bool _showPreviousReleases = false;

  Widget _buildBadge(String badge) {
    Color bg = MetaColors.emerald.withValues(alpha: 0.15);
    Color border = MetaColors.emerald.withValues(alpha: 0.35);
    Color text = MetaColors.emerald;

    switch (badge.toUpperCase()) {
      case 'NOVO':
        bg = MetaColors.emerald.withValues(alpha: 0.15);
        border = MetaColors.emerald.withValues(alpha: 0.4);
        text = MetaColors.emerald;
        break;
      case 'MELHORIA':
      case 'UX':
        bg = Colors.amber.withValues(alpha: 0.15);
        border = Colors.amber.withValues(alpha: 0.4);
        text = Colors.amber;
        break;
      case 'CORREÇÃO':
        bg = Colors.lightBlue.withValues(alpha: 0.15);
        border = Colors.lightBlue.withValues(alpha: 0.4);
        text = Colors.lightBlueAccent;
        break;
      case 'ESTABILIDADE':
      case 'SEGURANÇA':
      case 'PRIVACIDADE':
        bg = Colors.purple.withValues(alpha: 0.15);
        border = Colors.purple.withValues(alpha: 0.4);
        text = Colors.purpleAccent;
        break;
      case 'B2B':
      case 'IA':
        bg = const Color(0xFF6366F1).withValues(alpha: 0.18);
        border = const Color(0xFF6366F1).withValues(alpha: 0.45);
        text = const Color(0xFF818CF8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        badge,
        style: TextStyle(
          color: text,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildChangelogItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color subtextColor,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: MetaColors.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      _buildBadge(badge),
                    ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final currentRelease = AppChangelog.current;
    final previousReleases = AppChangelog.previousReleases;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
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
                        Row(
                          children: [
                            Text(
                              currentRelease.fullTitle,
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${currentRelease.date}',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'NOVIDADES DESTA VERSÃO',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentRelease.highlights.length} novidades',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...currentRelease.highlights.map(
                (item) => _buildChangelogItem(
                  icon: item.icon,
                  title: item.title,
                  description: item.description,
                  badge: item.badge,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),

              if (previousReleases.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPreviousReleases = !_showPreviousReleases;
                      });
                    },
                    icon: Icon(
                      _showPreviousReleases
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.history_rounded,
                      size: 16,
                      color: subtextColor,
                    ),
                    label: Text(
                      _showPreviousReleases
                          ? 'Ocultar versões anteriores'
                          : 'Ver versões anteriores (${previousReleases.length})',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              if (_showPreviousReleases) ...[
                const SizedBox(height: 8),
                Divider(color: border, height: 1),
                const SizedBox(height: 14),
                ...previousReleases.map((release) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              release.fullTitle,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              release.date,
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          release.summary,
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt(
                        AppVersionFooter._lastSeenBuildKey,
                        currentRelease.buildNumber,
                      );
                    } catch (_) {}
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
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
      ),
    );
  }
}
