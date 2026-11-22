import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The picture of a building on the Evacuation Plan page. It is saved on the
/// phone the first time it is seen, so it still shows with no signal. Without
/// a picture (or while it loads) a plain building icon is shown.
class BuildingImage extends StatefulWidget {
  const BuildingImage({super.key, required this.path});

  /// file name in the "building-images" bucket (null = no picture)
  final String? path;

  static const bucket = 'building-images';

  @override
  State<BuildingImage> createState() => _BuildingImageState();
}

class _BuildingImageState extends State<BuildingImage> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BuildingImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _file = null;
      _load();
    }
  }

  Future<void> _load() async {
    final p = widget.path;
    if (p == null || p.isEmpty) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/building_images/${p.replaceAll('/', '_')}');
      if (!await f.exists()) {
        final bytes = await Supabase.instance.client.storage
            .from(BuildingImage.bucket)
            .download(p);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes, flush: true);
      }
      if (mounted && widget.path == p) setState(() => _file = f);
    } catch (_) {
      // offline and never saved: the icon stays
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    if (f != null) {
      return Image.file(f,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => const _Placeholder());
    }
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B8CA5), Color(0xFF3C6E87)],
        ),
      ),
      child: const Center(
          child: Icon(Icons.apartment, color: Colors.white70, size: 56)),
    );
  }
}

/// Uploads and removes building pictures.
class BuildingImageStore {
  static final _sb = Supabase.instance.client;

  /// saves a picture and returns the file name to store as image_path
  static Future<String> upload(Uint8List bytes) async {
    final png = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final name =
        '${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await _sb.storage.from(BuildingImage.bucket).uploadBinary(name, bytes,
        fileOptions:
            FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
    return name;
  }

  static Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _sb.storage.from(BuildingImage.bucket).remove([path]);
    } catch (_) {}
  }
}
