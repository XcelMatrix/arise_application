import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arise_application/l10n/translations.dart';

class SettingsState {
  final ThemeMode themeMode;
  final AppLanguage language;
  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.language = AppLanguage.english,
  });

  SettingsState copyWith({ThemeMode? themeMode, AppLanguage? language}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
      );
}

/// Theme (light / dark) and language (English / Filipino), remembered
/// on the device.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _themeKey = 'arise_theme_dark';
  static const _langKey = 'arise_lang_fil';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool(_themeKey) ?? false;
      final fil = prefs.getBool(_langKey) ?? false;
      final lang = fil ? AppLanguage.filipino : AppLanguage.english;
      Tr.current = lang;
      emit(SettingsState(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        language: lang,
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

  Future<void> setLanguage(AppLanguage lang) async {
    Tr.current = lang;
    emit(state.copyWith(language: lang));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_langKey, lang == AppLanguage.filipino);
    } catch (_) {}
  }
}
