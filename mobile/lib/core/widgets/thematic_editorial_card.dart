import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';
import 'meta_components.dart';
import 'thematic_watermarks.dart';

/// Tema cromático e de gradiente pré-definido para os cards editoriais do Mr. Coach
enum ThematicCardPalette {
  /// Biomecânica & Sobrecarga IA (Ciano / Azul Atlântico)
  biomechanicsCyan(
    editorialGradient: LinearGradient(
      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7), Color(0xFF0369A1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF0369A1),
    defaultWatermark: ThematicWatermarkType.biomechanics,
  ),

  /// Carga Cardiovascular & VO2 Max (Azul Cobalto Profundo)
  cardioCobalt(
    editorialGradient: LinearGradient(
      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF1E40AF),
    defaultWatermark: ThematicWatermarkType.cardioLoad,
  ),

  /// Fadiga Muscular & RPE (Framboesa / Magenta Carmesim)
  muscleMagenta(
    editorialGradient: LinearGradient(
      colors: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFFFE4E6), Color(0xFFFECDD3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF9F1239),
    defaultWatermark: ThematicWatermarkType.muscleFatigue,
  ),

  /// Copiloto WhatsApp 24h (Violeta / Orquídea Profundo)
  aiOrchid(
    editorialGradient: LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF5B21B6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF5B21B6),
    defaultWatermark: ThematicWatermarkType.aiCopilot,
  ),

  /// Nutrição & Glicose / Carboidratos (Âmbar Dourado / Terracota)
  nutritionAmber(
    editorialGradient: LinearGradient(
      colors: [Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFF9A3412)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF9A3412),
    defaultWatermark: ThematicWatermarkType.nutritionMetabolism,
  ),

  /// Vitrine B2B & Carteira Pix (Verde Esmeralda WhatsApp)
  businessEmerald(
    editorialGradient: LinearGradient(
      colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightPastelGradient: LinearGradient(
      colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    lightTextColor: Color(0xFF065F46),
    defaultWatermark: ThematicWatermarkType.walletFinance,
  );

  final Gradient editorialGradient;
  final Gradient lightPastelGradient;
  final Color lightTextColor;
  final ThematicWatermarkType defaultWatermark;

  const ThematicCardPalette({
    required this.editorialGradient,
    required this.lightPastelGradient,
    required this.lightTextColor,
    required this.defaultWatermark,
  });
}

/// Card Editorial de Alta Fidelidade no Padrão One UI 7 / Samsung Health
/// Suporta alternância automática entre:
/// - Editorial 3D (Samsung Health degradê rico + marca d'água 3D)
/// - Minimalista Executivo (Meta Slate neutro)
/// - Pastel Suave (Light Mode de alto contraste)
class ThematicEditorialCard extends StatelessWidget {
  final String category;
  final String title;
  final String? description;
  final ThematicCardPalette palette;
  final ThematicWatermarkType? customWatermark;
  final CardVisualThemeMode? overrideMode;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final Widget? trailingBadge;
  final Widget? footerAction;

  const ThematicEditorialCard({
    super.key,
    required this.category,
    required this.title,
    this.description,
    required this.palette,
    this.customWatermark,
    this.overrideMode,
    this.onTap,
    this.minHeight = 148.0,
    this.padding = const EdgeInsets.all(20.0),
    this.trailingBadge,
    this.footerAction,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final mode = overrideMode ?? ThemeController.instance.cardThemeMode;
        final isDark = MetaColors.isDark(context);

        // Define estilo conforme o modo ativo
        final isEditorial = mode == CardVisualThemeMode.editorial3D;
        final isMinimal = mode == CardVisualThemeMode.minimalist;
        final isLightPastel = mode == CardVisualThemeMode.lightPastel || (!isDark && !isMinimal && !isEditorial);

        // Cores de fundo e borda
        final BoxDecoration decoration;
        final Color textColor;
        final Color subtextColor;

        if (isMinimal) {
          decoration = BoxDecoration(
            color: MetaColors.card(context),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: MetaColors.cardBorder(context), width: 1.0),
          );
          textColor = MetaColors.text(context);
          subtextColor = MetaColors.subtext(context);
        } else if (isLightPastel) {
          decoration = BoxDecoration(
            gradient: palette.lightPastelGradient,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: palette.lightTextColor.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.lightTextColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          );
          textColor = palette.lightTextColor;
          subtextColor = palette.lightTextColor.withValues(alpha: 0.85);
        } else {
          // Editorial 3D (Samsung Health)
          decoration = BoxDecoration(
            gradient: palette.editorialGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          );
          textColor = Colors.white;
          subtextColor = Colors.white.withValues(alpha: 0.92);
        }

        final watermarkType = customWatermark ?? palette.defaultWatermark;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              decoration: decoration,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Iluminação especular superior contínua no modo editorial
                  if (isEditorial)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Marca d'água volumétrica 3D no canto superior direito
                  if (!isMinimal)
                    Positioned(
                      top: -12,
                      right: -10,
                      child: ThematicWatermark(
                        type: watermarkType,
                        size: 150,
                        opacity: isLightPastel ? 0.35 : 0.85,
                        baseColor: isLightPastel ? palette.lightTextColor : Colors.white,
                      ),
                    ),

                  // Conteúdo do Cartão
                  Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Cabeçalho (Rótulo superior + Badge opcional)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (trailingBadge != null) trailingBadge!,
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Título de Impacto
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.25,
                          ),
                        ),

                        // Descrição contextual (se fornecida)
                        if (description != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 64.0),
                            child: Text(
                              description!,
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],

                        // Ação de Rodapé opcional
                        if (footerAction != null) ...[
                          const SizedBox(height: 14),
                          footerAction!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

