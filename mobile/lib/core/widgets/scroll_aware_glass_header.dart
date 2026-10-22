import 'dart:ui';
import 'package:flutter/material.dart';
import 'meta_components.dart';

/// Cabeçalho dinâmico com efeito de vidro fosco (Glassmorphism / One UI 7) que reage
/// ao offset de rolagem da tela (Scroll-Aware Glass Header).
///
/// À medida que o usuário rola o feed, lista ou dashboard, o componente realiza uma
/// interpolação suave de desfoque (blur de 0 a 18), opacidade de fundo translúcido e
/// borda sutil luminescente de 1px, garantindo imersão Edge-to-Edge contínua e sem cortes secos.
class ScrollAwareGlassHeader extends StatefulWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? bottom;
  final double bottomHeight;
  final ScrollController? scrollController;
  final double scrollOffset;
  final double elevationThreshold;
  final double maxBlur;
  final EdgeInsetsGeometry? contentPadding;
  final bool fillTopSafeArea;

  const ScrollAwareGlassHeader({
    super.key,
    this.leading,
    this.title,
    this.titleText,
    this.actions,
    this.bottom,
    this.bottomHeight = 52.0,
    this.scrollController,
    this.scrollOffset = 0.0,
    this.elevationThreshold = 28.0,
    this.maxBlur = 18.0,
    this.contentPadding,
    this.fillTopSafeArea = true,
  });

  @override
  Size get preferredSize {
    double h = kToolbarHeight + 12;
    if (bottom != null) h += bottomHeight;
    return Size.fromHeight(h);
  }

  @override
  State<ScrollAwareGlassHeader> createState() => _ScrollAwareGlassHeaderState();
}

class _ScrollAwareGlassHeaderState extends State<ScrollAwareGlassHeader> {
  double _currentOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.scrollOffset;
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollAwareGlassHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
    if (oldWidget.scrollOffset != widget.scrollOffset) {
      _currentOffset = widget.scrollOffset;
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || widget.scrollController == null) return;
    final offset = widget.scrollController!.hasClients
        ? widget.scrollController!.offset
        : 0.0;
    if ((offset - _currentOffset).abs() > 0.5) {
      setState(() {
        _currentOffset = offset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = widget.fillTopSafeArea ? MediaQuery.paddingOf(context).top : 0.0;
    final isDark = MetaColors.isDark(context);

    // Progresso normalizado de 0.0 a 1.0 baseado no offset de rolagem
    final progress = (_currentOffset / widget.elevationThreshold).clamp(0.0, 1.0);

    // Cores e transparências calibradas para o Meta Design System
    final baseBg = isDark ? const Color(0xFF0D1424) : Colors.white;
    final glassBg = baseBg.withValues(
      alpha: lerpDouble(0.0, isDark ? 0.85 : 0.90, progress)!,
    );
    final borderColor = isDark
        ? Colors.white.withValues(alpha: lerpDouble(0.0, 0.12, progress)!)
        : Colors.black.withValues(alpha: lerpDouble(0.0, 0.08, progress)!);

    final currentBlur = progress * widget.maxBlur;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: currentBlur, sigmaY: currentBlur),
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding,
            left: widget.contentPadding != null ? 0 : 16,
            right: widget.contentPadding != null ? 0 : 16,
            bottom: widget.bottom != null ? 6 : 6,
          ),
          decoration: BoxDecoration(
            color: glassBg,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 1.0,
              ),
            ),
            boxShadow: progress > 0.1
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: lerpDouble(0.0, isDark ? 0.35 : 0.06, progress)!,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: kToolbarHeight - 4,
                child: Row(
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: widget.title ??
                          (widget.titleText != null
                              ? Text(
                                  widget.titleText!,
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : const SizedBox.shrink()),
                    ),
                    if (widget.actions != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.actions!,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.bottom != null) ...[
                const SizedBox(height: 2),
                widget.bottom!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Versão Sliver do cabeçalho translúcido, ideal para integração em [CustomScrollView].
class SliverScrollAwareGlassHeader extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? bottom;
  final double bottomHeight;
  final double maxBlur;
  final bool pinned;
  final bool floating;

  const SliverScrollAwareGlassHeader({
    super.key,
    this.leading,
    this.title,
    this.titleText,
    this.actions,
    this.bottom,
    this.bottomHeight = 52.0,
    this.maxBlur = 18.0,
    this.pinned = true,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final totalHeight = topPadding + kToolbarHeight + 14 + (bottom != null ? bottomHeight + 4 : 0);

    return SliverPersistentHeader(
      pinned: pinned,
      floating: floating,
      delegate: _SliverGlassHeaderDelegate(
        leading: leading,
        title: title,
        titleText: titleText,
        actions: actions,
        bottom: bottom,
        bottomHeight: bottomHeight,
        maxBlur: maxBlur,
        topPadding: topPadding,
        totalHeight: totalHeight,
      ),
    );
  }
}

class _SliverGlassHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget? leading;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? bottom;
  final double bottomHeight;
  final double maxBlur;
  final double topPadding;
  final double totalHeight;

  _SliverGlassHeaderDelegate({
    required this.leading,
    required this.title,
    required this.titleText,
    required this.actions,
    required this.bottom,
    required this.bottomHeight,
    required this.maxBlur,
    required this.topPadding,
    required this.totalHeight,
  });

  @override
  double get minExtent => totalHeight;

  @override
  double get maxExtent => totalHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: ScrollAwareGlassHeader(
        leading: leading,
        title: title,
        titleText: titleText,
        actions: actions,
        bottom: bottom,
        bottomHeight: bottomHeight,
        scrollOffset: shrinkOffset + (overlapsContent ? 28.0 : 0.0),
        maxBlur: maxBlur,
        fillTopSafeArea: true,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverGlassHeaderDelegate oldDelegate) {
    return oldDelegate.titleText != titleText ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.totalHeight != totalHeight ||
        oldDelegate.actions != actions ||
        oldDelegate.bottom != bottom;
  }
}
