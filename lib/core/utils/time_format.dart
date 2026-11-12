import 'package:flutter/material.dart';

/// 12-hour or 24-hour clock, chosen in Settings > Language and time.
class TimeFormat {
  /// Set by the settings cubit.
  static bool use24h = false;

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// "02:45:12 PM" or "14:45:12"
  static String clock(DateTime t, {bool seconds = true}) {
    final s = seconds ? ':${_two(t.second)}' : '';
    if (use24h) return '${_two(t.hour)}:${_two(t.minute)}$s';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${_two(h)}:${_two(t.minute)}$s ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "2:45 PM" or "14:45" (no seconds; the 12-hour form has no leading zero)
  static String short(DateTime t) {
    if (use24h) return '${_two(t.hour)}:${_two(t.minute)}';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${_two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Redraws every screen that is open (used after the clock format changes,
/// so times already on screen switch straight away).
void rebuildAllScreens(BuildContext context) {
  void rebuild(Element e) {
    e.markNeedsBuild();
    e.visitChildren(rebuild);
  }

  (context as Element).visitChildren(rebuild);
}
