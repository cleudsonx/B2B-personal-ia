import 'dart:ui';
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

/// Helper para carregar avatares e imagens tanto de rede (HTTP) quanto locais (assets/)
ImageProvider? safeImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final clean = url.trim();
  if (clean.startsWith('assets/')) {
    return AssetImage(clean);
  }
  return NetworkImage(clean);
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
  final EdgeInsetsGeometry? padding;
  final double? fontSize;

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
    this.padding,
    this.fontSize,
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
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize ?? 15,
                          fontWeight: FontWeight.bold,
                          color: fg,
                          letterSpacing: 0.2,
                        ),
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
  final double? fontSize;

  const MetaSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.start,
    this.fontSize,
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
            fontSize: fontSize ?? 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.25,
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

/// Item de destino para a barra de navegação flutuante estilo Samsung Health (One UI).
class OneUiNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showDot;

  const OneUiNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showDot = false,
  });
}

/// Barra de Navegação Flutuante em Cápsula (Floating Pill Dock) inspirada no Samsung Health (One UI 7).
/// Suporta efeito translúcido (glassmorphism) sobre conteúdo Edge-to-Edge (`extendBody: true`)
/// e um botão circular de ação destacada opcional à direita.
class OneUiFloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<OneUiNavItem> items;
  final IconData? trailingActionIcon;
  final String? trailingActionTooltip;
  final VoidCallback? onTrailingActionTap;

  const OneUiFloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.trailingActionIcon,
    this.trailingActionTooltip,
    this.onTrailingActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final capsuleBg = isDark
        ? const Color(0xFF151D2E).withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.90);
    final selectedPillBg = isDark
        ? const Color(0xFF28354E)
        : const Color(0xFFE6ECEF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final activeColor = isDark ? MetaColors.emerald : MetaColors.lightEmerald;
    final activeTextColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final inactiveColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 0 ? bottomInset + 8 : 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: BoxDecoration(
                      color: capsuleBg,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: borderColor, width: 1.0),
                    ),
                    child: Row(
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isSelected = index == selectedIndex;
                        return Expanded(
                          child: Semantics(
                            selected: isSelected,
                            button: true,
                            label: item.label,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => onDestinationSelected(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? selectedPillBg
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            isSelected ? item.selectedIcon : item.icon,
                                            size: 21,
                                            color: isSelected ? activeColor : inactiveColor,
                                          ),
                                          if (item.showDot)
                                            Positioned(
                                              right: -3,
                                              top: -2,
                                              child: Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFF6B00),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            item.label,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? activeTextColor
                                                  : inactiveColor,
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (trailingActionIcon != null && onTrailingActionTap != null) ...[
            const SizedBox(width: 10),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    color: capsuleBg,
                    shape: CircleBorder(
                      side: BorderSide(color: borderColor, width: 1.0),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onTrailingActionTap,
                      child: Tooltip(
                        message: trailingActionTooltip ?? '',
                        child: Center(
                          child: Icon(
                            trailingActionIcon,
                            color: activeColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Botão Circular Flutuante Translúcido (estilo botão `<` Voltar do Samsung Health One UI no scroll).
class OneUiFloatingCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  const OneUiFloatingCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark
        ? const Color(0xFF151D2E).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: bg,
            shape: CircleBorder(side: BorderSide(color: borderColor, width: 1)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Tooltip(
                message: tooltip ?? '',
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: MetaColors.text(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pílula Superior Flutuante Translúcida (ex: botão `Redefinir` ou cápsula de ações no topo).
class OneUiFloatingPillAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const OneUiFloatingPillAction({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark
        ? const Color(0xFF151D2E).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: borderColor, width: 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: MetaColors.text(context)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cápsula Flutuante de Confirmação `[ Cancelar | Salvar ]` estilo Samsung Health (Prints 10, 11, 12).
class OneUiFloatingConfirmBar extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;

  const OneUiFloatingConfirmBar({
    super.key,
    this.cancelLabel = 'Cancelar',
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark
        ? const Color(0xFF1A2234).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.10);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isLoading ? null : onCancel,
                          child: Center(
                            child: Text(
                              cancelLabel,
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 22,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isLoading ? null : onConfirm,
                          child: Center(
                            child: isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: MetaColors.primaryColor(context),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        confirmLabel,
                                        style: TextStyle(
                                          color: MetaColors.primaryColor(context),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item do Menu Popover Flutuante estilo Samsung Health (Print 8).
class OneUiPopoverItem {
  final String label;
  final IconData? icon;
  final bool showOrangeDot;
  final VoidCallback onTap;

  const OneUiPopoverItem({
    required this.label,
    this.icon,
    this.showOrangeDot = false,
    required this.onTap,
  });
}

/// Botão de Menu Popover Super-Arredondado (`⋮` com ponto laranja de novidade) estilo Samsung Health (Print 8).
class OneUiPopoverMenuButton extends StatelessWidget {
  final List<OneUiPopoverItem> items;
  final bool showBadgeDot;

  const OneUiPopoverMenuButton({
    super.key,
    required this.items,
    this.showBadgeDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final menuBg = isDark ? const Color(0xFF1E2638) : Colors.white;

    return PopupMenuButton<int>(
      tooltip: 'Mais opções',
      offset: const Offset(0, 44),
      color: menuBg,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      onSelected: (index) {
        if (index >= 0 && index < items.length) {
          items[index].onTap();
        }
      },
      itemBuilder: (ctx) {
        return List.generate(items.length, (i) {
          final item = items[i];
          return PopupMenuItem<int>(
            value: i,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: 18,
                    color: MetaColors.subtext(ctx),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: MetaColors.text(ctx),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (item.showOrangeDot) ...[
                  const SizedBox(width: 6),
                  Transform.translate(
                    offset: const Offset(0, -4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B00),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        });
      },
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.more_vert_rounded,
              color: MetaColors.text(context),
              size: 22,
            ),
            if (showBadgeDot)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

