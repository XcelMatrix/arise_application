import 'package:flutter/material.dart';

/// Box + text colours for the Present / Absent / Missing / Injured (and drill)
/// number boxes. Used on the Attendance page and in Reports so they match.
/// Lighter box, stronger text, in both light and dark mode. The grey "Absent"
/// text is kept as it was.
class StatColors {
  const StatColors(this.box, this.text);
  final Color box;
  final Color text;

  static const _absentGrey = Color(0xFF757575);

  static StatColors of(BuildContext context, Color base) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (base == _absentGrey) {
      return StatColors(
        base.withValues(alpha: dark ? 0.30 : 0.14),
        dark ? Color.lerp(base, Colors.white, 0.55)! : base,
      );
    }
    return dark
        ? StatColors(base.withValues(alpha: 0.38),
            Color.lerp(base, Colors.white, 0.78)!)
        : StatColors(Color.lerp(base, Colors.white, 0.84)!,
            Color.lerp(base, Colors.black, 0.42)!);
  }
}
