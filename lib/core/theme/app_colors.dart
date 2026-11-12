import 'package:flutter/material.dart';

/// Surface colours that change in dark mode.
/// In light mode every value is the original colour from the app.
class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Set from Settings. High contrast = pure black/white surfaces,
  /// black/white text and clear borders.
  static bool highContrast = false;

  static const _darkBg = Color(0xFF12181C);

  /// page background (was Colors.white)
  static Color bg(BuildContext c) => highContrast
      ? (isDark(c) ? Colors.black : Colors.white)
      : (isDark(c) ? _darkBg : Colors.white);

  /// cards (was 0xFFF2F5F8)
  static Color card(BuildContext c) => highContrast
      ? (isDark(c) ? const Color(0xFF111111) : const Color(0xFFEDEDED))
      : (isDark(c) ? const Color(0xFF1E2A31) : const Color(0xFFF2F5F8));

  /// light-blue panels / buttons (was 0xFFE4F2F9)
  static Color soft(BuildContext c) => highContrast
      ? (isDark(c) ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0))
      : (isDark(c) ? const Color(0xFF1F3542) : const Color(0xFFE4F2F9));

  /// text fields and borders (was 0xFFD3D3D3 / 0xFFEFEFEF)
  static Color field(BuildContext c) => highContrast
      ? (isDark(c) ? const Color(0xFF333333) : const Color(0xFFBDBDBD))
      : (isDark(c) ? const Color(0xFF2D383F) : const Color(0xFFD3D3D3));

  /// dark-blue text on cards (was 0xFF2C4C5E)
  static Color text(BuildContext c) => highContrast
      ? (isDark(c) ? Colors.white : Colors.black)
      : (isDark(c) ? const Color(0xFFDCE9F0) : const Color(0xFF2C4C5E));

  /// near-black text (was Colors.black87)
  static Color body(BuildContext c) => highContrast
      ? (isDark(c) ? Colors.white : Colors.black)
      : (isDark(c) ? const Color(0xDDFFFFFF) : Colors.black87);
}

class AppTheme {
  /// High-contrast theme (light or dark): black/white with clear borders.
  static ThemeData contrast({required bool dark}) {
    final fg = dark ? Colors.white : Colors.black;
    final bg = dark ? Colors.black : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(surface: bg, onSurface: fg, outline: fg);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: fg,
      drawerTheme: DrawerThemeData(backgroundColor: bg),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderSide: BorderSide(color: fg, width: 1.5)),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: fg, width: 1.5)),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    );
  }

  static const _blue = Color(0xFF3C6E87);

  /// Light mode is the app's original look (Flutter's default theme), so
  /// MaterialApp.theme is left alone. Only dark mode is defined here.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF12181C));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF12181C),
      canvasColor: const Color(0xFF12181C),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF12181C),
      ),
      dividerColor: const Color(0xFF2D383F),
    );
  }
}
