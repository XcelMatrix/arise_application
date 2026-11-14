import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/reports/services/export_files.dart';

/// Admin backup and restore. A backup is one JSON file with everything the
/// 30-day clean-up deletes (drills, attendance reports, alerts, check-ins,
/// audit log) plus guidelines, emergency contacts and class lists.
class BackupService {
  static const _lastKey = 'arise_last_backup';
  static final _sb = Supabase.instance.client;

  /// When this phone last made a backup (null = never).
  static Future<DateTime?> lastBackup() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_lastKey);
      return v == null ? null : DateTime.tryParse(v)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Download everything and hand the file to the share sheet.
  /// Returns the number of records saved.
  static Future<int> exportAndShare() async {
    final data = await _sb.rpc('admin_export_backup');
    final tables = Map<String, dynamic>.from((data as Map)['tables'] as Map);
    final count = tables.values.fold<int>(0, (n, v) => n + (v as List).length);

    final now = DateTime.now();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${ExportFiles.stem('backup', now)}.json');
    await file.writeAsString(jsonEncode(data), flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'ARISE backup ${ExportFiles.date(now)}',
    ));
    try {
      await (await SharedPreferences.getInstance())
          .setString(_lastKey, now.toUtc().toIso8601String());
    } catch (_) {}
    return count;
  }

  /// Let the admin pick a backup file. Returns null when nothing was picked.
  static Future<Map<String, dynamic>?> pickBackup() async {
    // different file_picker versions return a list or an object with .files
    final dynamic res = await FilePicker.pickFiles(type: FileType.any);
    if (res == null) return null;
    final List<PlatformFile> list = res is List
        ? res.cast<PlatformFile>()
        : List<PlatformFile>.from(res.files);
    if (list.isEmpty) return null;
    final path = list.first.path;
    if (path == null) return null;
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map || decoded['app'] != 'ARISE' || decoded['tables'] is! Map) {
      throw 'This is not an ARISE backup file.';
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// How many records each table holds, for the confirmation question.
  static int recordCount(Map<String, dynamic> backup) =>
      (backup['tables'] as Map)
          .values
          .fold<int>(0, (n, v) => n + (v is List ? v.length : 0));

  /// Put a backup back. Existing rows are left alone.
  static Future<Map<String, dynamic>> restore(Map<String, dynamic> backup) async {
    final r = await _sb.rpc('admin_restore_backup', params: {'p': backup});
    return Map<String, dynamic>.from(r as Map);
  }
}
