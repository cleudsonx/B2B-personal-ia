import 'package:flutter/material.dart';

/// Tokens semânticos e paletas do Design System:
/// "Modern Editorial Clean / Apple Fitness & Whoop Style"
class AppColors {
  // ==========================================
  // 1. MODO CLARO (Modern Editorial Clean)
  // ==========================================
  static const Color lightBg = Color(0xFFF8FAFC); // Off-White Slate
  static const Color lightCard = Color(0xFFFFFFFF); // Pure White
  static const Color lightCardBorder = Color(0xFFE2E8F0); // 1px sutil
  static const Color lightCardShadow = Color(0x0D0F172A); // 0 10px 30px rgba(15,23,42,0.05)
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate Black
  static const Color lightTextSecondary = Color(0xFF64748B); // Muted Slate
  static const Color lightPillBg = Color(0xFFF1F5F9); // Slate 100
  static const Color lightPillBorder = Color(0xFFE2E8F0);

  // Acentos Semânticos (Modo Claro) - Pastel Suave
  static const Color emeraldPrimary = Color(0xFF059669); // Pastel Mint
  static const Color emeraldSurface = Color(0xFFD1FAE5); // Mint 50
  static const Color emeraldBorder = Color(0xFFC1F5D0); // Mint 200

  static const Color tangerinePrimary = Color(0xFFEA580C); // Pastel Peach
  static const Color tangerineSurface = Color(0xFFFFF7ED); // Peach 50
  static const Color tangerineBorder = Color(0xFFFED7AA); // Peach 200

  static const Color cobaltPrimary = Color(0xFF0284C7); // Sky Blue / Pastel Blue
  static const Color cobaltSurface = Color(0xFFF0F9FF); // Sky 50

  // ==========================================
  // 2. MODO ESCURO (Whoop & Apple Midnight Edition)
  // ==========================================
  static const Color darkBg = Color(0xFF090D16); // Obsidian Fosco
  static const Color darkCard = Color(0xFF131B2E); // Carbon Slate Elevado
  static const Color darkCardBorder = Color(0x1FFFFFFF); // 1px luminescente suave
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Off-White
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkPillBg = Color(0xFF1E293B); // Slate 800
  static const Color darkPillBorder = Color(0xFF334155);

  // Acentos Semânticos (Modo Escuro Neon)
  static const Color emeraldNeon = Color(0xFF34D399); // Emerald 400 neon
  static const Color emeraldDarkSurface = Color(0x2634D399); // 15% opacity

  static const Color tangerineNeon = Color(0xFFFB923C); // Orange 400 neon
  static const Color tangerineDarkSurface = Color(0x26FB923C); // 15% opacity

  static const Color cyanNeon = Color(0xFF38BDF8); // Sky 400 neon
  static const Color cyanDarkSurface = Color(0x2638BDF8);

  // ==========================================
  // 3. COMUNS & STATUS
  // ==========================================
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  // ==========================================
  // 4. CONSTANTES RETROCOMPATÍVEIS (Legacy Screens)
  // ==========================================
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color trainerEmerald = emeraldPrimary;
  static const Color trainerEmeraldDark = Color(0xFF047857);
  static const Color trainerEmeraldGlow = Color(0x33059669);
  static const Color trainerSurface = lightCard;
  static const Color trainerSurfaceElevated = Color(0xFFFFFFFF);
  static const Color trainerBorder = lightCardBorder;
  static const Color trainerIndigo = Color(0xFF6366F1);
  static const Color trainerBg = lightBg;

  static const Color studentCyan = cobaltPrimary;
  static const Color studentCyanGlow = Color(0x330284C7);
  static const Color studentSurface = lightCard;
  static const Color studentBorder = lightCardBorder;
  static const Color studentBg = lightBg;
  static const Color studentAmber = tangerinePrimary;
  static const Color studentAmberGlow = Color(0x33EA580C);

  // ==========================================
  // 5. HELPERS DINÂMICOS BASEADOS NO TEMA ATUAL
  // ==========================================
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBg : lightBg;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color cardBorder(BuildContext context) =>
      isDark(context) ? darkCardBorder : lightCardBorder;

  static Color text(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color subtext(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color pillBg(BuildContext context) =>
      isDark(context) ? darkPillBg : lightPillBg;

  static Color pillBorder(BuildContext context) =>
      isDark(context) ? darkPillBorder : lightPillBorder;

  static Color emerald(BuildContext context) =>
      isDark(context) ? emeraldNeon : emeraldPrimary;

  static Color emeraldBg(BuildContext context) =>
      isDark(context) ? emeraldDarkSurface : emeraldSurface;

  static Color tangerine(BuildContext context) =>
      isDark(context) ? tangerineNeon : tangerinePrimary;

  static Color tangerineBg(BuildContext context) =>
      isDark(context) ? tangerineDarkSurface : tangerineSurface;

  static Color accentBlue(BuildContext context) =>
      isDark(context) ? cyanNeon : cobaltPrimary;
}
