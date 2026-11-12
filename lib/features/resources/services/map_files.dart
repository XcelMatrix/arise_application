import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Downloads uploaded evacuation map files once and keeps them on the phone,
/// so they keep working offline.
class MapFiles {
  static const bucket = 'evacuation-maps';

  /// Name of the saved copy inside the app documents folder.
  static String fileName(Map<String, dynamic> row) {
    final ext = (row['path'] as String).split('.').last;
    return 'map_${row['id']}.$ext';
  }

  /// Makes sure the file of this map row is on the phone.
  /// Returns it, or null if it could not be downloaded (offline, first time).
  static Future<File?> ensure(Map<String, dynamic> row) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${fileName(row)}');
    if (file.existsSync()) return file;
    try {
      final bytes = await Supabase.instance.client.storage
          .from(bucket)
          .download(row['path'] as String);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Map download failed: $e');
      return null;
    }
  }

  /// Temporary online link (used by AR if the saved copy can't be loaded).
  static Future<String?> signedUrl(Map<String, dynamic> row) async {
    try {
      return await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(row['path'] as String, 3600);
    } catch (_) {
      return null;
    }
  }

  /// Removes saved copies of maps that no longer exist.
  static Future<void> tidy(Iterable<String> keepFileNames) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final keep = keepFileNames.toSet();
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('map_') && !keep.contains(name)) f.deleteSync();
      }
    } catch (_) {}
  }
}
