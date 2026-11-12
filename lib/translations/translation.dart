import 'package:arise_application/translations/languages/english.dart';
import 'package:arise_application/translations/registry.dart';

/// A pattern for text that has changing parts (names, numbers):
/// "Grade 11" -> "Baitang 11".
class TranslationRule {
  final RegExp pattern;
  final String Function(RegExpMatch match) build;
  TranslationRule(this.pattern, this.build);
}

/// One language. Every file in `translations/languages/` defines one of
/// these. English is the source language, so it needs no words.
class AppTranslation {
  const AppTranslation({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.flag = '🌐',
    required this.months,
    required this.weekdays,
    this.words = const {},
    this.rules = const [],
  });

  /// Short unique code, e.g. 'fil', 'es'.
  final String code;

  /// Name in English and in the language itself (shown in Settings).
  final String englishName;
  final String nativeName;

  /// Flag emoji shown next to the language in Settings, e.g. '🇵🇭'.
  final String flag;

  /// 12 month names and 7 weekday letters (Sunday first).
  final List<String> months;
  final List<String> weekdays;

  /// English text -> translated text.
  final Map<String, String> words;

  /// Patterns for text with changing parts.
  final List<TranslationRule> rules;

  /// Text a person sees in the language picker: "Filipino" or "Español (Spanish)".
  String get label =>
      nativeName == englishName ? englishName : '$nativeName ($englishName)';
}

/// Translation lookup used by the whole app.
class Tr {
  /// The language in use right now.
  static AppTranslation current = english;

  /// Every available language (English first), from `registry.dart`.
  static List<AppTranslation> get languages => [english, ...allTranslations];

  static AppTranslation byCode(String? code) {
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return english;
  }

  static String t(String text) {
    final lang = current;
    if (lang.code == english.code || text.isEmpty) return text;
    final exact = lang.words[text];
    if (exact != null) return exact;
    for (final rule in lang.rules) {
      final m = rule.pattern.firstMatch(text);
      if (m != null) return rule.build(m);
    }
    return text;
  }

  static List<String> get months => current.months;
  static List<String> get weekdays => current.weekdays;
}
