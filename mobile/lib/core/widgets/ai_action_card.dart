import 'package:flutter/material.dart';
import 'meta_components.dart';

class AiActionCardItem {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final bool isPrimary;

  const AiActionCardItem({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
    this.isPrimary = false,
  });
}

/// Card interativo para respostas da IA (Generative UI / Action Cards)
/// Permite ao aluno e professor realizarem ações diretas em 1 toque
/// sem precisar sair do fluxo da conversa.
class AiActionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? headerIcon;
  final Color? accentColor;
  final List<AiActionCardItem> actions;

  const AiActionCard({
    super.key,
    this.title,
    this.subtitle,
    this.headerIcon,
    this.accentColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final effectiveAccent = accentColor ?? MetaColors.emerald;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: effectiveAccent.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Row(
              children: [
                if (headerIcon != null) ...[
                  Icon(headerIcon, size: 16, color: effectiveAccent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: MetaColors.text(context),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MetaColors.subtext(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((act) {
              final itemColor = act.color ?? effectiveAccent;
              return InkWell(
                onTap: act.onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: act.isPrimary
                        ? itemColor
                        : itemColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: act.isPrimary
                          ? itemColor
                          : itemColor.withValues(alpha: 0.35),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        act.icon,
                        size: 14,
                        color: act.isPrimary ? Colors.black : itemColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        act.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: act.isPrimary ? Colors.black : itemColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
