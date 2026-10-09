import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controlador global reativo para alternância entre Modo Claro e Modo Escuro
class ThemeController extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode_v2';

  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal() {
    _loadFromPrefs();
  }

  // Padrão de fábrica: inicia em ThemeMode.system (segue o sistema operacional do aparelho)
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Modo Claro (Meta Light)';
      case ThemeMode.dark:
        return 'Modo Escuro (Meta Dark)';
      case ThemeMode.system:
        return 'Automático (Sistema)';
    }
  }

  /// Alterna diretamente entre Claro e Escuro
  Future<void> toggleTheme() async {
    _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
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
      notifyListeners();
    } catch (_) {}
  }

  /// Recarrega as preferências do SharedPreferences (usado em testes automatizados)
  Future<void> reloadFromPrefs() => _loadFromPrefs();
}
