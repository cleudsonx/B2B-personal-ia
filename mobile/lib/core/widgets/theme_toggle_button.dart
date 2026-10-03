import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

/// Pílula tátil com ícones ☀️ / 🌙 para alternar instantaneamente entre
/// o Modo Claro Editorial e o Modo Escuro Midnight
class ThemeToggleButton extends StatelessWidget {
  final bool compact;
  const ThemeToggleButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDarkMode;

        if (compact) {
          return IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color:
                  isDark
                      ? AppColors.tangerineNeon
                      : AppColors.lightTextSecondary,
            ),
            tooltip: isDark ? 'Ativar Modo Claro' : 'Ativar Modo Escuro',
            onPressed: () => ThemeController.instance.toggleTheme(),
          );
        }

        return InkWell(
          onTap: () => ThemeController.instance.toggleTheme(),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isDark ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.light_mode_rounded,
                  size: 14,
                  color:
                      isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFFEA580C),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.emeraldNeon : AppColors.lightCard,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.dark_mode_rounded,
                  size: 14,
                  color: isDark ? AppColors.cyanNeon : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
