import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_ia/core/theme/app_theme.dart';
import 'package:personal_ia/core/theme/theme_controller.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Meta Theme System & ThemeController Tests', () {
    test('ThemeController initializes with ThemeMode.system on fresh install without saved preference', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController.instance;
      await controller.reloadFromPrefs();

      expect(controller.themeMode, equals(ThemeMode.system));
      expect(controller.isSystemMode, isTrue);
      expect(controller.isDarkMode, isFalse);
      expect(controller.isLightMode, isFalse);
      expect(controller.themeModeName, equals('Automático (Sistema)'));
    });

    test('ThemeController restores saved dark or light preferences correctly', () async {
      final controller = ThemeController.instance;

      SharedPreferences.setMockInitialValues({'app_theme_mode_v2': 'dark'});
      await controller.reloadFromPrefs();
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);
      expect(controller.isSystemMode, isFalse);

      SharedPreferences.setMockInitialValues({'app_theme_mode_v2': 'light'});
      await controller.reloadFromPrefs();
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isLightMode, isTrue);
      expect(controller.isSystemMode, isFalse);
    });
    test('AppTheme definitions match Meta Light and Dark specifications', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      expect(lightTheme.brightness, equals(Brightness.light));
      expect(darkTheme.brightness, equals(Brightness.dark));

      expect(lightTheme.scaffoldBackgroundColor, equals(MetaColors.lightBackground));
      expect(darkTheme.scaffoldBackgroundColor, equals(MetaColors.background));

      expect(lightTheme.cardColor, equals(MetaColors.lightSurface));
      expect(darkTheme.cardColor, equals(MetaColors.surface));

      expect(lightTheme.colorScheme.primary, equals(MetaColors.lightEmerald));
      expect(darkTheme.colorScheme.secondary, equals(MetaColors.emerald));
    });

    test('ThemeController supports toggling, setting modes and names', () async {
      final controller = ThemeController.instance;

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.isDarkMode, isTrue);
      expect(controller.themeModeName, contains('Escuro'));

      await controller.toggleTheme();
      expect(controller.themeMode, equals(ThemeMode.light));
      expect(controller.isDarkMode, isFalse);
      expect(controller.themeModeName, contains('Claro'));

      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, equals(ThemeMode.system));
      expect(controller.themeModeName, contains('Sistema'));

      // Restore to dark for default behavior
      await controller.setThemeMode(ThemeMode.dark);
    });

    testWidgets('MetaColors resolves context-aware tokens dynamically', (WidgetTester tester) async {
      Color? resolvedBgDark;
      Color? resolvedPrimaryDark;
      Color? resolvedCardDark;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.darkTheme,
            child: Builder(
              builder: (context) {
                resolvedBgDark = MetaColors.bg(context);
                resolvedPrimaryDark = MetaColors.primaryColor(context);
                resolvedCardDark = MetaColors.card(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedBgDark, equals(MetaColors.background));
      expect(resolvedPrimaryDark, equals(MetaColors.emerald));
      expect(resolvedCardDark, equals(MetaColors.surface));

      Color? resolvedBgLight;
      Color? resolvedPrimaryLight;
      Color? resolvedCardLight;

      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: Builder(
              builder: (context) {
                resolvedBgLight = MetaColors.bg(context);
                resolvedPrimaryLight = MetaColors.primaryColor(context);
                resolvedCardLight = MetaColors.card(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedBgLight, equals(MetaColors.lightBackground));
      expect(resolvedPrimaryLight, equals(MetaColors.lightEmerald));
      expect(resolvedCardLight, equals(MetaColors.lightSurface));
    });

    testWidgets('SquircleButton adapts default colors to theme context', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: Scaffold(
              body: SquircleButton(
                label: 'Continuar',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style?.backgroundColor?.resolve({}), equals(MetaColors.lightEmerald));
    });
  });
}
