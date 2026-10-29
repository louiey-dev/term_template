import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import 'app_theme.dart';

/// Supported application theme modes.
enum AppThemeMode {
  light('Light', Icons.light_mode_outlined),
  dark('Dark', Icons.dark_mode_outlined),
  darkBlue('Dark Blue', Icons.nights_stay_outlined),
  green('Green', Icons.eco_outlined);

  const AppThemeMode(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Returns the [ThemeData] corresponding to this mode.
  ThemeData get themeData => switch (this) {
    AppThemeMode.light => AppTheme.lightTheme,
    AppThemeMode.dark => AppTheme.darkTheme,
    AppThemeMode.darkBlue => AppTheme.darkBlueTheme,
    AppThemeMode.green => AppTheme.greenTheme,
  };

  /// Returns the next [AppThemeMode] in the cycle:
  /// light -> dark -> darkBlue -> green -> light.
  AppThemeMode get next =>
      AppThemeMode.values[(index + 1) % AppThemeMode.values.length];
}

/// Provider for managing application theme mode (light, dark, darkBlue, green),
/// persisted in the `app_settings` Hive box.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

/// Notifier that handles theme mode state and persistence.
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() {
    if (Hive.isBoxOpen('app_settings')) {
      return _parse(Hive.box<String>('app_settings').get(_key));
    }
    return AppThemeMode.darkBlue;
  }

  /// Sets the active [AppThemeMode] and persists it to Hive.
  void set(AppThemeMode mode) {
    state = mode;
    if (Hive.isBoxOpen('app_settings')) {
      Hive.box<String>('app_settings').put(_key, mode.name);
    }
  }

  /// Cycles through light, dark, darkBlue, and green themes.
  void toggle() => set(state.next);

  AppThemeMode _parse(String? raw) => switch (raw) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    'darkBlue' => AppThemeMode.darkBlue,
    'green' => AppThemeMode.green,
    _ => AppThemeMode.darkBlue,
  };
}
