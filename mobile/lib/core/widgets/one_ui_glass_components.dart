import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'meta_components.dart';

/// Fundo atmosférico (Ambient Glow) com orbes de luz difusos.
/// Dá profundidade aos cards translúcidos, no estilo Samsung Health / One UI 7.
class AmbientGlowCanvas extends StatelessWidget {
  const AmbientGlowCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final emerald = isDark ? const Color(0xFF10B981) : const Color(0xFF6EE7B7);
    final blue = isDark ? const Color(0xFF38BDF8) : const Color(0xFFBAE6FD);
    final amber = isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A);
    final topAlpha = isDark ? 0.20 : 0.45;
    final midAlpha = isDark ? 0.13 : 0.35;

    Widget orb(Color c, double alpha, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)],
            ),
          ),
        );

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(top: -140, left: -120, child: orb(blue, topAlpha, 420)),
            Positioned(top: -60, right: -160, child: orb(emerald, topAlpha, 400)),
            Positioned(top: 380, left: -140, child: orb(amber, midAlpha, 380)),
          ],
        ),
      ),
    );
  }
}

/// Card translúcido (frosted glass) com borda especular sutil.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.blur = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.72);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.9);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.18 : 0.05);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: shadow, blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: fill,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: border, width: 1),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone circular translúcido para o cabeçalho.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(icon, size: 21, color: MetaColors.text(context)),
            ),
            if (showDot)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    shape: BoxShape.circle,
                    border: Border.all(color: MetaColors.bg(context), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GlassSegment {
  final String label;
  final String? badge;
  final IconData? icon;
  const GlassSegment({required this.label, this.badge, this.icon});
}

/// Cápsula translúcida única com pílula deslizante (estilo Samsung Health).
class OneUiGlassSegmentedBar extends StatelessWidget {
  final List<GlassSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const OneUiGlassSegmentedBar({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final capsule = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7);
    final capsuleBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.9);
    final pill = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : MetaColors.emerald.withValues(alpha: 0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: capsule,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: capsuleBorder),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: segments.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final selected = i == selectedIndex;
              final seg = segments[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? pill : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (seg.icon != null) ...[
                        Icon(
                          seg.icon,
                          size: 16,
                          color: selected
                              ? (isDark ? MetaColors.emerald : const Color(0xFF047857))
                              : MetaColors.subtext(context),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        seg.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? MetaColors.text(context)
                              : MetaColors.subtext(context),
                        ),
                      ),
                      if (seg.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            seg.badge!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: MetaColors.emeraldText(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class GlassAction {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  const GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });
}

/// Gaveta translúcida (bottom sheet) com cabeçalho opcional e lista de ações.
class OneUiGlassSheet {
  static Future<void> show(
    BuildContext context, {
    Widget? header,
    required List<GlassAction> actions,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131B2E).withValues(alpha: 0.88)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: MetaColors.subtext(ctx).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (header != null) ...[header, const SizedBox(height: 8)],
                      ...actions.map((a) {
                        final c = a.color ?? MetaColors.emerald;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(a.icon, color: c, size: 21),
                          ),
                          title: Text(
                            a.label,
                            style: TextStyle(
                              color: MetaColors.text(ctx),
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: a.subtitle == null
                              ? null
                              : Text(
                                  a.subtitle!,
                                  style: TextStyle(
                                    color: MetaColors.subtext(ctx),
                                    fontSize: 12,
                                  ),
                                ),
                          onTap: () {
                            Navigator.pop(ctx);
                            a.onTap();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

