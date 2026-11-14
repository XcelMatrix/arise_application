import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arise_application/core/utils/time_format.dart';
import 'package:arise_application/translations/translation.dart';

class SettingsState {
  final ThemeMode themeMode;

  /// language code, e.g. 'en' or 'fil' (see translations/languages)
  final String language;

  /// Base text size in pixels (like Discord's chat font scaling).
  final double fontSize;

  /// 0.0 = grey, 1.0 = normal colours
  final double saturation;

  /// true = 24-hour clock, false = 12-hour clock with AM / PM
  final bool use24h;

  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.language = 'en',
    this.fontSize = defaultFontSize,
    this.saturation = 1.0,
    this.use24h = false,
  });

  static const double defaultFontSize = 16;
  static const double minFontSize = 12;
  static const double maxFontSize = 24;

  /// The app's text is drawn at this multiple of its normal size.
  double get textScale => fontSize / defaultFontSize;

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? language,
    double? fontSize,
    double? saturation,
    bool? use24h,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        fontSize: fontSize ?? this.fontSize,
        saturation: saturation ?? this.saturation,
        use24h: use24h ?? this.use24h,
      );
}

/// Appearance, accessibility, language and time choices, remembered
/// on the device.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(const SettingsState());

  static const _themeKey = 'arise_theme_dark';
  static const _langKey = 'arise_lang_code';
  static const _fontKey = 'arise_font_px';
  static const _satKey = 'arise_saturation';
  static const _clockKey = 'arise_24h';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool(_themeKey) ?? false;
      // older versions saved a yes/no for Filipino
      final lang = prefs.getString(_langKey) ??
          ((prefs.getBool('arise_lang_fil') ?? false) ? 'fil' : 'en');
      // older versions saved a text scale (1.0 / 1.25 / 1.5)
      final font = prefs.getDouble(_fontKey) ??
          (prefs.getDouble('arise_text_scale') ?? 1.0) *
              SettingsState.defaultFontSize;
      final use24 = prefs.getBool(_clockKey) ?? false;
      Tr.current = Tr.byCode(lang);
      TimeFormat.use24h = use24;
      emit(SettingsState(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        language: lang,
        fontSize: font
            .clamp(SettingsState.minFontSize, SettingsState.maxFontSize)
            .toDouble(),
        saturation: (prefs.getDouble(_satKey) ?? 1.0).clamp(0.0, 1.0),
        use24h: use24,
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

  /// Live while the slider moves (nothing is saved yet).
  void previewFontSize(double px) => emit(state.copyWith(fontSize: px));

  Future<void> setFontSize(double px) async {
    emit(state.copyWith(fontSize: px));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontKey, px);
    } catch (_) {}
  }

  void previewSaturation(double v) => emit(state.copyWith(saturation: v));

  Future<void> setSaturation(double v) async {
    emit(state.copyWith(saturation: v));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_satKey, v);
    } catch (_) {}
  }

  /// Back to how the app looked when it was installed: light theme,
  /// English, 16 px text, full colour, 12-hour clock.
  Future<void> resetAll() async {
    Tr.current = Tr.byCode('en');
    TimeFormat.use24h = false;
    emit(const SettingsState());
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in [_themeKey, _langKey, _fontKey, _satKey, _clockKey]) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  Future<void> setUse24h(bool on) async {
    TimeFormat.use24h = on;
    emit(state.copyWith(use24h: on));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clockKey, on);
    } catch (_) {}
  }
}
