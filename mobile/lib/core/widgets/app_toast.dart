import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'meta_components.dart';

/// Tipos semânticos de feedback visual
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// Sistema de Feedback Toast Premium do Mr. Coach / Shaipados
/// Substitui o SnackBar plano legado por uma pílula flutuante (Estilo Dynamic Island / Apple Fitness+ / One UI).
class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3800),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // 1. Háptico suave ao disparar alerta
    try {
      if (type == ToastType.error) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}

    // 2. Determina cores e ícones padrão com base no tipo
    final isDark = MetaColors.isDark(context);
    final Color accentColor;
    final IconData defaultIcon;
    final String? defaultTitle;

    switch (type) {
      case ToastType.success:
        accentColor = MetaColors.emerald;
        defaultIcon = Icons.check_circle_rounded;
        defaultTitle = title ?? 'Sucesso';
        break;
      case ToastType.error:
        accentColor = AppColors.danger;
        defaultIcon = Icons.error_outline_rounded;
        defaultTitle = title ?? 'Atenção';
        break;
      case ToastType.warning:
        accentColor = const Color(0xFFF59E0B);
        defaultIcon = Icons.warning_amber_rounded;
        defaultTitle = title ?? 'Aviso';
        break;
      case ToastType.info:
        accentColor = MetaColors.accentBlue;
        defaultIcon = Icons.info_outline_rounded;
        defaultTitle = title;
        break;
    }

    final effectiveIcon = icon ?? defaultIcon;
    final effectiveTitle = title ?? (message.length > 50 ? defaultTitle : null);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        duration: duration,
        content: _ToastCard(
          title: effectiveTitle,
          message: message,
          icon: effectiveIcon,
          accentColor: accentColor,
          isDark: isDark,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  /// Atalho para mensagens de sucesso
  static void success(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3800),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.success,
      icon: icon,
      duration: duration,
    );
  }

  /// Atalho para mensagens de erro
  static void error(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 4500),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.error,
      icon: icon,
      duration: duration,
    );
  }

  /// Atalho para avisos
  static void warning(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 4000),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.warning,
      icon: icon,
      duration: duration,
    );
  }

  /// Atalho para mensagens informativas
  static void info(
    BuildContext context,
    String message, {
    String? title,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 3800),
  }) {
    show(
      context,
      message: message,
      title: title,
      type: ToastType.info,
      icon: icon,
      duration: duration,
    );
  }
}

/// Card de exibição visual do Toast com design moderno e luminescência sutil
class _ToastCard extends StatelessWidget {
  final String? title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastCard({
    this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF131B2E).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.98);

    final textColor = isDark ? MetaColors.textPrimary : const Color(0xFF0F172A);
    final subtextColor = isDark ? MetaColors.textSecondary : const Color(0xFF475569);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge de Ícone Estilo Squircle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Conteúdo (Título opcional + Mensagem)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null && title!.isNotEmpty) ...[
                      Text(
                        title!,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                    ],
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        color: (title != null && title!.isNotEmpty) ? subtextColor : textColor,
                        fontSize: 12.5,
                        fontWeight: (title != null && title!.isNotEmpty)
                            ? FontWeight.w500
                            : FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // Ação Opcional (ex: "Desfazer", "Ver")
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extensão no BuildContext para acesso instantâneo em qualquer tela
extension BuildContextToastX on BuildContext {
  void showSuccessToast(String message, {String? title, IconData? icon, Duration? duration}) {
    AppToast.success(this, message, title: title, icon: icon, duration: duration ?? const Duration(milliseconds: 3800));
  }

  void showErrorToast(String message, {String? title, IconData? icon, Duration? duration}) {
    AppToast.error(this, message, title: title, icon: icon, duration: duration ?? const Duration(milliseconds: 4500));
  }

  void showWarningToast(String message, {String? title, IconData? icon, Duration? duration}) {
    AppToast.warning(this, message, title: title, icon: icon, duration: duration ?? const Duration(milliseconds: 4000));
  }

  void showInfoToast(String message, {String? title, IconData? icon, Duration? duration}) {
    AppToast.info(this, message, title: title, icon: icon, duration: duration ?? const Duration(milliseconds: 3800));
  }
}

