import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'meta_components.dart';

/// Cabeçalho de seção moderno (Sentence case, sem caixa-alta excessiva),
/// inspirado em Apple Health, Samsung One UI 7 e Material 3 Expressive.
class StudentSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const StudentSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? MetaColors.primaryColor(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: effectiveIconColor),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      color: MetaColors.primaryColor(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: MetaColors.primaryColor(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Anel de progresso circular animado (estilo Apple Fitness+ / Whoop).
class ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? center;
  final Duration duration;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.strokeWidth = 5.5,
    this.color,
    this.trackColor,
    this.center,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final activeColor = color ?? MetaColors.primaryColor(context);
    final isDark = MetaColors.isDark(context);
    final bgTrack = trackColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08));

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clamped),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, child) {
          return CustomPaint(
            painter: _ProgressRingPainter(
              progress: animatedValue,
              strokeWidth: strokeWidth,
              color: activeColor,
              trackColor: bgTrack,
            ),
            child: Center(child: child),
          );
        },
        child: center,
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.005) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Tile compacto de métrica biométrica ou performance com suporte a tabular figures e badge de tendência.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? badgeText;
  final Color? badgeColor;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.badgeText,
    this.badgeColor,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accentColor ?? MetaColors.primaryColor(context);
    final pillColor = badgeColor ?? tone;

    return Material(
      color: MetaColors.card(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MetaColors.cardBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 15, color: tone),
                  ),
                  if (badgeText != null && badgeText!.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: pillColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: pillColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (unit != null && unit!.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      unit!,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pílula compacta de Treinador Responsável (1 linha com avatar, status, CREF e botão rápido de WhatsApp).
class TrainerCompactPill extends StatelessWidget {
  final bool isLoading;
  final String? trainerName;
  final String? trainerCref;
  final String? trainerPhotoUrl;
  final bool hasWhatsApp;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onConnectTap;

  const TrainerCompactPill({
    super.key,
    this.isLoading = false,
    this.trainerName,
    this.trainerCref,
    this.trainerPhotoUrl,
    this.hasWhatsApp = false,
    this.onWhatsAppTap,
    this.onConnectTap,
  });

  @override
  Widget build(BuildContext context) {
    final emerald = MetaColors.primaryColor(context);
    if (isLoading) {
      return const StudentSkeletonCard(height: 68);
    }

    final hasTrainer = trainerName != null && trainerName!.trim().isNotEmpty;
    return InkWell(
      onTap: hasTrainer ? null : onConnectTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MetaColors.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasTrainer
                ? emerald.withValues(alpha: 0.30)
                : const Color(0xFFF59E0B).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emerald.withValues(alpha: 0.14),
              border: Border.all(
                color: emerald.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: (trainerPhotoUrl != null && trainerPhotoUrl!.isNotEmpty)
                ? (trainerPhotoUrl!.startsWith('assets/')
                    ? Image.asset(trainerPhotoUrl!, fit: BoxFit.cover)
                    : Image.network(
                        trainerPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_rounded,
                          color: emerald,
                          size: 22,
                        ),
                      ))
                : Icon(
                    Icons.fitness_center_rounded,
                    color: emerald,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Treinador responsável',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MetaColors.subtext(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: hasTrainer
                            ? emerald.withValues(alpha: 0.16)
                            : Colors.orange.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasTrainer ? 'Ativo' : 'Pendente',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: hasTrainer ? emerald : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasTrainer ? trainerName! : 'Nenhum treinador vinculado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (trainerCref != null && trainerCref!.trim().isNotEmpty)
                  Text(
                    trainerCref!.trim().toUpperCase().startsWith('CREF') ? trainerCref!.trim() : 'CREF ${trainerCref!.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (hasTrainer && hasWhatsApp && onWhatsAppTap != null) ...[
            const SizedBox(width: 8),
            Material(
              color: const Color(0xFF25D366).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onWhatsAppTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_rounded,
                        size: 15,
                        color: Color(0xFF25D366),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'WhatsApp',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF25D366),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (!hasTrainer && onConnectTap != null) ...[
            const SizedBox(width: 8),
            Material(
              color: emerald,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onConnectTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_link_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Conectar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}

/// Grupo de configurações estilo iOS 18 / Samsung One UI 7 com divisores indentados.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsGroup({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = MetaColors.cardBorder(context);
    final List<Widget> items = [];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(
          Divider(
            height: 1,
            thickness: 0.8,
            indent: 56,
            endIndent: 16,
            color: borderColor,
          ),
        );
      }
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items,
      ),
    );
  }
}

/// Linha individual dentro de um [SettingsGroup] com ícone em squircle tonal.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const SettingsTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDestructive
        ? Colors.redAccent
        : (iconColor ?? MetaColors.primaryColor(context));
    final titleColor = isDestructive ? Colors.redAccent : MetaColors.text(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: effectiveColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else ...[
                if (trailingText != null && trailingText!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trailingText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: MetaColors.subtext(context),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vazio elegante e acionável para telas do aluno.
class StudentEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accentColor;

  const StudentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accentColor ?? MetaColors.primaryColor(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: tone),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: tone.withValues(alpha: 0.16),
                foregroundColor: tone,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton card suave para estados de carregamento.
class StudentSkeletonCard extends StatelessWidget {
  final double height;
  final double borderRadius;

  const StudentSkeletonCard({
    super.key,
    this.height = 84,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
    );
  }
}
