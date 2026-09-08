import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

/// Provider for managing application theme mode (dark, light, system),
/// persisted in the `app_settings` Hive box.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Notifier that handles theme mode state and persistence.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    if (Hive.isBoxOpen('app_settings')) {
      return _parse(Hive.box<String>('app_settings').get(_key));
    }
    return ThemeMode.dark;
  }

  /// Sets the active [ThemeMode] and persists it to Hive.
  void set(ThemeMode mode) {
    state = mode;
    if (Hive.isBoxOpen('app_settings')) {
      Hive.box<String>('app_settings').put(_key, mode.name);
    }
  }

  /// Toggles between dark and light themes.
  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  ThemeMode _parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
