import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme_controller.dart';
import 'meta_components.dart';

/// Modal interativo para seleção do Estilo Visual dos Cards (One UI 7 / Samsung Health)
class CardStyleSelectionSheet extends StatelessWidget {
  const CardStyleSelectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const CardStyleSelectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (ctx, _) {
        final currentMode = ThemeController.instance.cardThemeMode;

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.cardBorder(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Estilo dos Cards & Destaques',
                style: TextStyle(
                  color: MetaColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Personalize a aparência dos cards principais inspirados no Samsung Health / One UI 7:',
                style: TextStyle(
                  color: MetaColors.subtext(ctx),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              _buildOption(
                ctx: ctx,
                mode: CardVisualThemeMode.editorial3D,
                title: 'Editorial 3D (Samsung Health)',
                subtitle: 'Degradês ricos, cantos squircle contínuos e marcas d\'água volumétricas.',
                icon: Icons.view_carousel_rounded,
                iconColor: const Color(0xFF0EA5E9),
                isSelected: currentMode == CardVisualThemeMode.editorial3D,
              ),
              const SizedBox(height: 8),
              _buildOption(
                ctx: ctx,
                mode: CardVisualThemeMode.minimalist,
                title: 'Minimalista Executivo',
                subtitle: 'Design monocromático sóbrio e plano sem ilustrações 3D.',
                icon: Icons.dashboard_customize_rounded,
                iconColor: const Color(0xFF94A3B8),
                isSelected: currentMode == CardVisualThemeMode.minimalist,
              ),
              const SizedBox(height: 8),
              _buildOption(
                ctx: ctx,
                mode: CardVisualThemeMode.lightPastel,
                title: 'Pastel Suave',
                subtitle: 'Tons claros e suaves de alto contraste, ideais para ambientes iluminados.',
                icon: Icons.filter_vintage_rounded,
                iconColor: const Color(0xFFF59E0B),
                isSelected: currentMode == CardVisualThemeMode.lightPastel,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption({
    required BuildContext ctx,
    required CardVisualThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ThemeController.instance.setCardThemeMode(mode);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.highlight(ctx) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MetaColors.primary.withValues(alpha: 0.35)
                : MetaColors.cardBorder(ctx).withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: MetaColors.text(ctx),
                      fontSize: 14.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MetaColors.subtext(ctx),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? MetaColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? MetaColors.primary : MetaColors.subtext(ctx),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
