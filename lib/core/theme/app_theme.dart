import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Semantic application color palette with dark and light variants.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.sidebar,
    required this.surface,
    required this.border,
    required this.primary,
    required this.primaryForeground,
    required this.foreground,
    required this.muted,
    required this.warning,
    required this.destructive,
    required this.success,
    required this.chartBlue,
  });

  final Color background;
  final Color card;
  final Color sidebar;
  final Color surface;
  final Color border;
  final Color primary;
  final Color primaryForeground;
  final Color foreground;
  final Color muted;
  final Color warning;
  final Color destructive;
  final Color success;
  final Color chartBlue;

  static const dark = AppColors(
    background: Color(0xFF1A1A2E),
    card: Color(0xFF222240),
    sidebar: Color(0xFF16162A),
    surface: Color(0xFF2A2A48),
    border: Color(0xFF35355A),
    primary: Color(0xFF2DD4A8),
    primaryForeground: Color(0xFF1A1A2E),
    foreground: Color(0xFFE8E8F0),
    muted: Color(0xFF8888AA),
    warning: Color(0xFFE8B84A),
    destructive: Color(0xFFE85454),
    success: Color(0xFF2DD4A8),
    chartBlue: Color(0xFF4A8AE8),
  );

  static const light = AppColors(
    background: Color(0xFFF0F0F8),
    card: Color(0xFFE8E8F4),
    sidebar: Color(0xFFE2E2EE),
    surface: Color(0xFFDADAEA),
    border: Color(0xFFCCCCDE),
    primary: Color(0xFF0D8F6F),
    primaryForeground: Color(0xFFFFFFFF),
    foreground: Color(0xFF1A1A2E),
    muted: Color(0xFF5A5A7A),
    warning: Color(0xFFAA6010),
    destructive: Color(0xFFCC2233),
    success: Color(0xFF0D8F6F),
    chartBlue: Color(0xFF2A5AB0),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? card,
    Color? sidebar,
    Color? surface,
    Color? border,
    Color? primary,
    Color? primaryForeground,
    Color? foreground,
    Color? muted,
    Color? warning,
    Color? destructive,
    Color? success,
    Color? chartBlue,
  }) {
    return AppColors(
      background: background ?? this.background,
      card: card ?? this.card,
      sidebar: sidebar ?? this.sidebar,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      warning: warning ?? this.warning,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
      chartBlue: chartBlue ?? this.chartBlue,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      success: Color.lerp(success, other.success, t)!,
      chartBlue: Color.lerp(chartBlue, other.chartBlue, t)!,
    );
  }
}

/// Convenience extension on [BuildContext] to access [AppColors].
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

/// Main application theme definitions.
class AppTheme {
  static ThemeData get darkTheme => _build(AppColors.dark, Brightness.dark);
  static ThemeData get lightTheme => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      fontFamily: 'Segoe UI',
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: brightness,
        primary: c.primary,
        surface: c.card,
        error: c.destructive,
      ),
      extensions: [c],
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerColor: c.border,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: c.foreground),
        bodyMedium: TextStyle(color: c.foreground),
        bodySmall: TextStyle(color: c.muted),
        labelSmall: TextStyle(
          color: c.muted,
          fontSize: 10,
          fontFamily: 'Consolas',
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

/// Builds an xterm [TerminalTheme] mapped from [AppColors] for high-contrast output.
TerminalTheme buildTerminalTheme(AppColors c, Brightness brightness) {
  final isLight = brightness == Brightness.light;
  return TerminalTheme(
    cursor: c.primary,
    selection: c.primary.withValues(alpha: 0.30),
    foreground: c.foreground,
    background: c.card,
    black: isLight ? const Color(0xFF2E2E2E) : const Color(0xFF000000),
    red: isLight ? const Color(0xFFC72E2E) : const Color(0xFFCD3131),
    green: isLight ? const Color(0xFF0B8A3E) : const Color(0xFF0DBC79),
    yellow: isLight ? const Color(0xFF8A6D0B) : const Color(0xFFE5E510),
    blue: isLight ? const Color(0xFF1C5DD8) : const Color(0xFF2472C8),
    magenta: isLight ? const Color(0xFFA021A0) : const Color(0xFFBC3FBC),
    cyan: isLight ? const Color(0xFF0A7E8C) : const Color(0xFF11A8CD),
    white: isLight ? const Color(0xFF2E2E2E) : const Color(0xFFE5E5E5),
    brightBlack: isLight ? const Color(0xFF6A6A6A) : const Color(0xFF666666),
    brightRed: const Color(0xFFF14C4C),
    brightGreen: const Color(0xFF23D18B),
    brightYellow: isLight ? const Color(0xFF9A7A0A) : const Color(0xFFF5F543),
    brightBlue: const Color(0xFF3B8EEA),
    brightMagenta: const Color(0xFFD670D6),
    brightCyan: const Color(0xFF29B8DB),
    brightWhite: isLight ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
    searchHitBackground: c.warning,
    searchHitBackgroundCurrent: c.primary,
    searchHitForeground: c.primaryForeground,
  );
}
