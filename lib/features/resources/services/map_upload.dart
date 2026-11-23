import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/resources/services/map_files.dart';
import 'package:arise_application/translations/translated_text.dart';

/// Picks a 3D model (.glb) or a 2D image and uploads it as a map (a floor)
/// of a building. Used by the building page and by "Manage maps".
class MapUploader {
  static const _maxBytes = 50 * 1024 * 1024;

  static String _mime(String ext) {
    switch (ext) {
      case 'glb':
        return 'model/gltf-binary';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  static void _toast(BuildContext context, String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(tr(context, m))));
  }

  /// Asks for the floor name and, when [buildingId] is null, which building
  /// (or a new one).
  static Future<({String name, String? buildingId, String newBuilding})?>
      _askDetails(BuildContext context, String defaultName,
          {String? buildingId}) {
    final buildings = context.read<BuildingsCubit>().state.rows;
    final nameC = TextEditingController(text: defaultName);
    final newC = TextEditingController();
    String? chosen = buildingId;
    final fixed = buildingId != null;
    return showDialog<({String name, String? buildingId, String newBuilding})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add evacuation map'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameC,
                  maxLength: 100,
                  decoration: InputDecoration(
                      labelText: tr(ctx, 'Map / floor name'),
                      hintText: tr(ctx, 'e.g. Ground floor')),
                ),
                if (!fixed) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(chosen),
                    initialValue: chosen,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr(ctx, 'Part of building'),
                      helperText: buildings.isEmpty
                          ? tr(ctx, 'No buildings yet.')
                          : tr(ctx, 'Leave blank to create a new building.'),
                      helperMaxLines: 2,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None (new building)',
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      for (final b in buildings)
                        DropdownMenuItem<String?>(
                          value: b['id'] as String,
                          child: Text.verbatim(b['name'] as String),
                        ),
                    ],
                    onChanged: (v) => setState(() => chosen = v),
                  ),
                  if (chosen == null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newC,
                      maxLength: 80,
                      decoration: InputDecoration(
                          labelText: tr(ctx, 'New building name'),
                          hintText: tr(ctx, 'e.g. Science building')),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  final name = nameC.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, (
                    name: name,
                    buildingId: chosen,
                    newBuilding: newC.text.trim()
                  ));
                },
                child: const Text('Upload')),
          ],
        ),
      ),
    ).whenComplete(() {
      nameC.dispose();
      newC.dispose();
    });
  }

  /// [kind] is 'model' or 'image'. Pass [buildingId] to add to that building.
  /// Returns true when a map was uploaded.
  static Future<bool> upload(BuildContext context, String kind,
      {String? buildingId}) async {
    final maps = context.read<MapsCubit>();
    final buildings = context.read<BuildingsCubit>();
    final sb = Supabase.instance.client;
    // (dynamic: the result type differs between file_picker versions)
    final dynamic res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          kind == 'model' ? ['glb'] : ['png', 'jpg', 'jpeg', 'webp'],
    );
    final List<PlatformFile> list = res == null
        ? const []
        : (res is List
            ? res.cast<PlatformFile>()
            : List<PlatformFile>.from(res.files));
    if (list.isEmpty) return false;
    final file = list.first;
    final pickedPath = file.path;
    if (!context.mounted) return false;
    if (pickedPath == null) {
      _toast(context, "Couldn't read that file.");
      return false;
    }
    final local = File(pickedPath);
    final int fileSize = await local.length();
    if (!context.mounted) return false;
    if (fileSize > _maxBytes) {
      _toast(context, 'That file is over 50 MB.');
      return false;
    }
    final Uint8List bytes = await local.readAsBytes();
    if (!context.mounted) return false;

    final base = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.'))
        : file.name;
    final d = await _askDetails(context, base, buildingId: buildingId);
    if (d == null || !context.mounted) return false;

    final ext = (file.extension ?? '').toLowerCase();
    final path = '${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = sb.storage.from(MapFiles.bucket);

    // a small blocking spinner while the file goes up
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
          canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    String? createdBuilding;
    var ok = false;
    String? message;
    try {
      var bId = d.buildingId;
      if (bId == null) {
        final name = d.newBuilding.isNotEmpty ? d.newBuilding : d.name;
        try {
          final b = await sb
              .from('map_buildings')
              .insert({'name': name})
              .select()
              .single();
          bId = b['id'] as String;
          createdBuilding = bId;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            message = 'A building called "$name" already exists. '
                'Pick it from the list instead.';
            return false;
          }
          rethrow;
        }
      }
      await storage.uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: _mime(ext)));
      try {
        await maps.add({
          'name': d.name,
          'kind': kind,
          'path': path,
          'size_bytes': fileSize,
          'building_id': bId,
        });
      } catch (e) {
        await storage.remove([path]); // don't leave an orphan file
        rethrow;
      }
      await buildings.load();
      createdBuilding = null;
      ok = true;
      message = 'Map uploaded.';
    } catch (e) {
      if (createdBuilding != null) {
        try {
          await sb.from('map_buildings').delete().eq('id', createdBuilding);
        } catch (_) {}
      }
      message = 'Could not upload: $e';
    } finally {
      nav.pop(); // the spinner
    }
    if (context.mounted) _toast(context, message);
    return ok;
  }
}
