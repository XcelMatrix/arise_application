import 'package:flutter/material.dart' as m show Theme, Brightness;
import 'package:flutter/widgets.dart' as w;
import 'package:arise_application/translations/translation.dart';

/// Tells widgets the language changed. Placed above the Navigator in main.dart.
class LangScope extends w.InheritedWidget {
  const LangScope({super.key, required this.language, required super.child});

  /// language code, e.g. 'en' or 'fil'
  final String language;

  static String of(w.BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LangScope>();
    return scope?.language ?? Tr.current.code;
  }

  @override
  bool updateShouldNotify(LangScope old) => old.language != language;
}

/// Translate a plain string for a place that is not a Text widget
/// (hints, labels, tooltips). Rebuilds when the language changes.
String tr(w.BuildContext context, String text) {
  LangScope.of(context);
  return Tr.t(text);
}

/// Drop-in replacement for Flutter's Text. It looks the string up in the
/// translation table, so the same code shows English or Filipino.
/// Use Text.verbatim for text that must never be translated
/// (chat messages, people's names).
class Text extends w.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  }) : _translate = true;

  const Text.verbatim(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.semanticsLabel,
  }) : _translate = false;

  final String data;
  final w.TextStyle? style;
  final w.TextAlign? textAlign;
  final bool? softWrap;
  final w.TextOverflow? overflow;
  final int? maxLines;
  final String? semanticsLabel;
  final bool _translate;

  /// In dark mode the app's dark cyan text becomes a lighter cyan and light
  /// grey text becomes white, so everything stays readable.
  static w.TextStyle? _forTheme(w.BuildContext context, w.TextStyle? s) {
    final c = s?.color;
    if (c == null || m.Theme.of(context).brightness != m.Brightness.dark) {
      return s;
    }
    final v = c.toARGB32();
    if (v == 0xFF3C6E87) return s!.copyWith(color: const w.Color(0xFF8DBFD6));
    final r = (v >> 16) & 0xFF, g = (v >> 8) & 0xFF, b = v & 0xFF;
    final grey = r == g && g == b && r >= 0x60 && r <= 0xC8 && (v >> 24) == 0xFF;
    if (grey) return s!.copyWith(color: const w.Color(0xFFFFFFFF));
    return s;
  }

  @override
  w.Widget build(w.BuildContext context) {
    if (_translate) LangScope.of(context);
    return w.Text(
      _translate ? Tr.t(data) : data,
      style: _forTheme(context, style),
      textAlign: textAlign,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
    );
  }
}
