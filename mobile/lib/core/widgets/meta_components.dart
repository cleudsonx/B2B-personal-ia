import 'package:flutter/material.dart';

/// Tokens de cor para a identidade visual "Meta" (Dark Mode e Light Mode WhatsApp Business).
class MetaColors {
  // Tokens Escuros Oficiais (Meta Dark / Obsidian)
  static const Color background = Color(0xFF090D16); // Obsidian fosco
  static const Color surface = Color(0xFF131B2E); // Card elevado
  static const Color surfaceHighlight = Color(0xFF1E293B); // Superfície interativa
  static const Color border = Color(0x1FFFFFFF); // Borda sutil luminescente
  static const Color textPrimary = Color(0xFFF8FAFC); // Off-White
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color accentBlue = Color(0xFF38BDF8); // Sky blue
  static const Color emerald = Color(0xFF10B981); // Emerald glow
  static const Color primary = emerald;

  // Tokens Claros Oficiais (Meta / WhatsApp Business Light Mode)
  static const Color lightBackground = Color(0xFFF0F2F5); // WhatsApp Canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Flat Card
  static const Color lightSurfaceHighlight = Color(0xFFE9EDEF); // Pílula e busca WhatsApp
  static const Color lightBorder = Color(0xFFE9EDEF); // 1px borda neutra
  static const Color lightTextPrimary = Color(0xFF111B21); // Charcoal Black
  static const Color lightTextSecondary = Color(0xFF667781); // Slate Muted
  static const Color lightEmerald = Color(0xFF008069); // WhatsApp Corporate Teal/Emerald
  static const Color lightAccentBlue = Color(0xFF0284C7); // Sky Blue

  // Helpers Dinâmicos Reativos ao Tema Ativo
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? background : lightBackground;

  static Color card(BuildContext context) =>
      isDark(context) ? surface : lightSurface;

  static Color highlight(BuildContext context) =>
      isDark(context) ? surfaceHighlight : lightSurfaceHighlight;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? border : lightBorder;

  static Color text(BuildContext context) =>
      isDark(context) ? textPrimary : lightTextPrimary;

  static Color subtext(BuildContext context) =>
      isDark(context) ? textSecondary : lightTextSecondary;

  static Color primaryColor(BuildContext context) =>
      isDark(context) ? emerald : lightEmerald;
}

/// Card padrão Meta: Dark surface, borda sutil de 1px e zero sombras.
class MetaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const MetaCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 20.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? MetaColors.card(context);
    final bColor = borderColor ?? MetaColors.cardBorder(context);

    Widget content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: bColor,
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Botão com formato squircle moderno, sem sombras e suporte a ícones.
class SquircleButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final double borderRadius;

  const SquircleButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 54.0,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final activeEmerald = isDark ? MetaColors.emerald : MetaColors.lightEmerald;
    final activeHighlight = isDark ? MetaColors.surfaceHighlight : MetaColors.lightSurfaceHighlight;
    final activeText = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final activeBorder = isDark ? MetaColors.border : MetaColors.lightBorder;

    final bg = backgroundColor ??
        (isPrimary ? activeEmerald : activeHighlight);
    final fg = foregroundColor ??
        (isPrimary ? Colors.white : activeText);

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: activeBorder, width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Cabeçalho de seção padronizado para telas Meta.
class MetaSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  const MetaSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: TextStyle(
            color: isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: TextStyle(
              color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}
