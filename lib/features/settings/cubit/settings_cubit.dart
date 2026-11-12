import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arise_application/translations/translation.dart';

class SettingsState {
  final ThemeMode themeMode;
  /// language code, e.g. 'en' or 'fil' (see translations/languages)
  final String language;

  /// 1.0 normal, 1.25 large, 1.5 extra large
  final double textScale;
  final bool highContrast;
  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.language = 'en',
    this.textScale = 1.0,
    this.highContrast = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? language,
    double? textScale,
    bool? highContrast,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        textScale: textScale ?? this.textScale,
        highContrast: highContrast ?? this.highContrast,
      );
}

/// Theme, language and accessibility choices, remembered
/// on the device.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _themeKey = 'arise_theme_dark';
  static const _langKey = 'arise_lang_code';
  static const _scaleKey = 'arise_text_scale';
  static const _contrastKey = 'arise_high_contrast';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool(_themeKey) ?? false;
      // older versions saved a yes/no for Filipino
      final lang = prefs.getString(_langKey) ??
          ((prefs.getBool('arise_lang_fil') ?? false) ? 'fil' : 'en');
      Tr.current = Tr.byCode(lang);
      emit(SettingsState(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        language: lang,
        textScale: prefs.getDouble(_scaleKey) ?? 1.0,
        highContrast: prefs.getBool(_contrastKey) ?? false,
      ));
    } catch (_) {
      // can't read saved settings: keep the defaults
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, mode == ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> setLanguage(String code) async {
    Tr.current = Tr.byCode(code);
    emit(state.copyWith(language: code));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, code);
    } catch (_) {}
  }

  Future<void> setTextScale(double scale) async {
    emit(state.copyWith(textScale: scale));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_scaleKey, scale);
    } catch (_) {}
  }

  Future<void> setHighContrast(bool on) async {
    emit(state.copyWith(highContrast: on));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_contrastKey, on);
    } catch (_) {}
  }
}
