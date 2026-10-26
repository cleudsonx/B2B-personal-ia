import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estilo visual dos cards hero e destaques editoriais (Samsung Health vs Minimalista)
enum CardVisualThemeMode {
  /// Modo Editorial com degradês ricos e ilustrações 3D claymorphic (Samsung Health)
  editorial3D,

  /// Modo Minimalista executivo, monocromático e discreto (Meta Slate)
  minimalist,

  /// Modo Pastel Claro de alto contraste e suavidade visual
  lightPastel;

  String get label {
    switch (this) {
      case CardVisualThemeMode.editorial3D:
        return 'Editorial 3D (Samsung Health)';
      case CardVisualThemeMode.minimalist:
        return 'Minimalista Executivo';
      case CardVisualThemeMode.lightPastel:
        return 'Pastel Suave';
    }
  }

  String get description {
    switch (this) {
      case CardVisualThemeMode.editorial3D:
        return 'Cores ricas em degradê com marcas d\'água 3D integradas.';
      case CardVisualThemeMode.minimalist:
        return 'Visual sóbrio e limpo sem ilustrações volumétricas.';
      case CardVisualThemeMode.lightPastel:
        return 'Tons pastel suaves ideais para ambientes iluminados.';
    }
  }
}

/// Controlador global reativo para alternância entre Modo Claro e Modo Escuro
class ThemeController extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode_v2';
  static const String _cardThemePrefKey = 'card_visual_theme_mode_v1';

  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal() {
    _loadFromPrefs();
  }

  // Padrão de fábrica: inicia em ThemeMode.system (segue o sistema operacional do aparelho)
  ThemeMode _themeMode = ThemeMode.system;

  // Padrão dos cards: Editorial 3D inspirado no Samsung Health
  CardVisualThemeMode _cardThemeMode = CardVisualThemeMode.editorial3D;

  ThemeMode get themeMode => _themeMode;
  CardVisualThemeMode get cardThemeMode => _cardThemeMode;

  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get isEditorialCards => _cardThemeMode == CardVisualThemeMode.editorial3D;

  /// Retorna se o tema é efetivamente escuro (considerando ThemeMode.system e platform brightness)
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  /// Retorna se o tema é efetivamente escuro no contexto visual atual
  bool isEffectiveDark([BuildContext? context]) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    if (context != null) {
      return Theme.of(context).brightness == Brightness.dark;
    }
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Modo Claro';
      case ThemeMode.dark:
        return 'Modo Escuro';
      case ThemeMode.system:
        return 'Automático (Sistema)';
    }
  }

  /// Alterna diretamente entre Claro e Escuro
  Future<void> toggleTheme([BuildContext? context]) async {
    final effectiveDark = isEffectiveDark(context);
    _themeMode = effectiveDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  /// Define um modo específico (dark, light ou system)
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final strMode = mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system');
      await prefs.setString(_prefKey, strMode);
    } catch (_) {}
  }

  /// Define o estilo visual dos cards (Editorial 3D, Minimalista, Pastel Claro)
  Future<void> setCardThemeMode(CardVisualThemeMode mode) async {
    if (_cardThemeMode == mode) return;
    _cardThemeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cardThemePrefKey, mode.name);
    } catch (_) {}
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        if (saved == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (saved == 'light') {
          _themeMode = ThemeMode.light;
        } else if (saved == 'system') {
          _themeMode = ThemeMode.system;
        }
      } else {
        _themeMode = ThemeMode.system;
      }

      final savedCardTheme = prefs.getString(_cardThemePrefKey);
      if (savedCardTheme != null) {
        for (final mode in CardVisualThemeMode.values) {
          if (mode.name == savedCardTheme) {
            _cardThemeMode = mode;
            break;
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Recarrega as preferências do SharedPreferences (usado em testes automatizados)
  Future<void> reloadFromPrefs() => _loadFromPrefs();
}
