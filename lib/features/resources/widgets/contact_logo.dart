import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Round picture for an emergency contact: its logo when it has one, the
/// plain icon otherwise. The logo is saved on the phone the first time it is
/// seen, so it still shows with no signal.
class ContactLogo extends StatefulWidget {
  const ContactLogo({
    super.key,
    required this.path,
    required this.icon,
    required this.color,
    this.radius = 24,
  });

  /// file name in the "contact-logos" bucket (null = no logo)
  final String? path;
  final IconData icon;
  final Color color;
  final double radius;

  static const bucket = 'contact-logos';

  @override
  State<ContactLogo> createState() => _ContactLogoState();
}

class _ContactLogoState extends State<ContactLogo> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ContactLogo old) {
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
      final f = File('${dir.path}/contact_logos/${p.replaceAll('/', '_')}');
      if (!await f.exists()) {
        final bytes =
            await Supabase.instance.client.storage.from(ContactLogo.bucket).download(p);
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
    final r = widget.radius;
    if (_file == null) {
      return CircleAvatar(
        radius: r,
        backgroundColor: widget.color,
        child: Icon(widget.icon, color: Colors.white, size: r * 0.95),
      );
    }
    return Container(
      width: r * 2,
      height: r * 2,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        _file!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: r,
          backgroundColor: widget.color,
          child: Icon(widget.icon, color: Colors.white),
        ),
      ),
    );
  }
}
