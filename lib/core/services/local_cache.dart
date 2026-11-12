import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny on-device copy of server data so the app still shows the last
/// known guidelines, contacts, announcements, calendar and class lists
/// when there is no connection.
class LocalCache {
  static Future<void> save(String key, Object json) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('cache_$key', jsonEncode(json));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>?> readRows(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('cache_$key');
      if (s == null) return null;
      return [
        for (final e in jsonDecode(s) as List)
          Map<String, dynamic>.from(e as Map),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().where((k) => k.startsWith('cache_'))) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}
