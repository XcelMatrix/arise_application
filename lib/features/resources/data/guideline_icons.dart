import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _blue = Color(0xFF3C6E87);

/// The built-in icons a guideline can use (key -> icon). A key is stored in
/// the database as `i:<key>`. The defaults follow the Disaster Preparedness
/// Guidebook; editors can swap any of them in the app.
class GuidelineIcons {
  static const Map<String, IconData> map = {
    'radio': Icons.radio,
    'checklist': Icons.checklist,
    'home_repair': Icons.home_repair_service,
    'go_bag': Icons.backpack,
    'pets': Icons.pets,
    'evacuate': Icons.directions_run,
    'home': Icons.home,
    'power_off': Icons.power_off,
    'flashlight': Icons.flashlight_on,
    'window': Icons.window,
    'home_safe': Icons.home_work,
    'damaged': Icons.dangerous,
    'no_photo': Icons.no_photography,
    'electric': Icons.bolt,
    'water_storage': Icons.storage,
    'lightbulb': Icons.lightbulb,
    'bulletin': Icons.newspaper,
    'evac_site': Icons.health_and_safety,
    'plant': Icons.eco,
    'lock_home': Icons.lock,
    'drills': Icons.pan_tool,
    'plug': Icons.electrical_services,
    'wave': Icons.waves,
    'swim': Icons.pool,
    'stream': Icons.water,
    'car': Icons.directions_car,
    'missing': Icons.person_search,
    'ambulance': Icons.local_hospital,
    'phone': Icons.phone,
    'contaminated': Icons.warning_amber,
    'hard_hat': Icons.engineering,
    'table': Icons.table_restaurant,
    'landslide': Icons.landslide,
    'first_aid': Icons.medical_services,
    'chemicals': Icons.science,
    'tv': Icons.tv,
    'door': Icons.door_front_door,
    'building': Icons.apartment,
    'accessible': Icons.accessible,
    'tap': Icons.plumbing,
    'seismic': Icons.graphic_eq,
    'volume': Icons.volume_up,
    'hand_stop': Icons.front_hand,
    'volcano': Icons.volcano,
    'smoke': Icons.cloud,
    'dry': Icons.grass,
    'thermal': Icons.whatshot,
    'mask': Icons.masks,
    'roof': Icons.roofing,
    'leaf': Icons.park,
    'broom': Icons.cleaning_services,
    'fire_truck': Icons.fire_truck,
    'alarm': Icons.notifications_active,
    'exit': Icons.exit_to_app,
    'lpg': Icons.propane_tank,
    'wiring': Icons.construction,
    'no_smoking': Icons.smoke_free,
    'teach': Icons.school,
    'extinguisher': Icons.fire_extinguisher,
    'fire': Icons.local_fire_department,
    'call': Icons.call,
    'stairs': Icons.stairs,
    'door_hot': Icons.sensor_door,
    'stop_drop': Icons.sports_gymnastics,
    'signal': Icons.sos,
    'no_return': Icons.block,
    'checkup': Icons.monitor_heart,
    'docs': Icons.description,
    'cash': Icons.payments,
    'food': Icons.restaurant,
    'water_bottles': Icons.local_drink,
    'phone_charge': Icons.smartphone,
    'ropes': Icons.inventory_2,
    'clothing': Icons.checkroom,
    'bedding': Icons.bed,
    'special_needs': Icons.elderly,
    'cyclone': Icons.cyclone,
    'storm_surge': Icons.thunderstorm,
    'flood': Icons.flood,
    'earthquake': Icons.vibration,
    'tsunami': Icons.tsunami,
    'book': Icons.menu_book,
    'groups': Icons.groups,
    'duck': Icons.keyboard_double_arrow_down,
    'cover': Icons.shield,
    'hold': Icons.back_hand,
    'info': Icons.info_outline,
    'warning': Icons.warning,
    'check': Icons.check_circle,
    'place': Icons.place,
    'search': Icons.person_search,
    'spill': Icons.oil_barrel,
    'public': Icons.public,
    'star': Icons.star,
    'heart': Icons.favorite,
    'water_drop': Icons.water_drop,
    'school': Icons.school,
    'people': Icons.people,
    'campaign': Icons.campaign,
  };
}

/// What an icon is made of, as saved in the database:
///   null / ''     the default icon
///   `i:<key>`     one of the built-in icons
///   `t:<text>`    a number or a letter
///   `u:<file>`    a picture in the "guideline-icons" bucket
class GuidelineIcon extends StatefulWidget {
  const GuidelineIcon({
    super.key,
    required this.spec,
    this.fallback = Icons.health_and_safety,
    this.size = 40,
  });

  final String? spec;

  /// shown when there is no icon set (or a picture cannot be loaded)
  final IconData fallback;
  final double size;

  static const bucket = 'guideline-icons';

  @override
  State<GuidelineIcon> createState() => _GuidelineIconState();
}

class _GuidelineIconState extends State<GuidelineIcon> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GuidelineIcon old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec) {
      _file = null;
      _load();
    }
  }

  /// Pictures are saved on the phone the first time they are seen, so they
  /// still show with no signal.
  Future<void> _load() async {
    final s = widget.spec;
    if (s == null || !s.startsWith('u:')) return;
    final name = s.substring(2);
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/guideline_icons/${name.replaceAll('/', '_')}');
      if (!await f.exists()) {
        final bytes = await Supabase.instance.client.storage
            .from(GuidelineIcon.bucket)
            .download(name);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes, flush: true);
      }
      if (mounted && widget.spec == s) setState(() => _file = f);
    } catch (_) {
      // offline and never saved: the default icon stays
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final s = widget.spec ?? '';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF24323A) : const Color(0xFFE6EFF3);
    final fg = dark ? Colors.white : _blue;

    Widget inner;
    if (s.startsWith('t:') && s.length > 2) {
      inner = Text(s.substring(2),
          maxLines: 1,
          style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w800,
              color: fg,
              fontFamily: 'Geist'));
    } else if (s.startsWith('u:') && _file != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.22)),
        clipBehavior: Clip.antiAlias,
        child: Image.file(_file!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Icon(widget.fallback, color: fg, size: size * 0.6)),
      );
    } else {
      final key = s.startsWith('i:') ? s.substring(2) : '';
      inner = Icon(GuidelineIcons.map[key] ?? widget.fallback,
          color: fg, size: size * 0.6);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(size * 0.22)),
      child: inner,
    );
  }
}

/// Uploads and removes the pictures that replace icons.
class GuidelineIconStore {
  static final _sb = Supabase.instance.client;

  /// saves a picture and returns the icon value to store (`u:<file>`)
  static Future<String> upload(Uint8List bytes) async {
    final png = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final name =
        '${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
    await _sb.storage.from(GuidelineIcon.bucket).uploadBinary(name, bytes,
        fileOptions:
            FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
    return 'u:$name';
  }

  /// deletes the pictures behind these icon values (other values are ignored)
  static Future<void> removeAll(Iterable<String?> specs) async {
    final names = [
      for (final s in specs)
        if (s != null && s.startsWith('u:')) s.substring(2)
    ];
    if (names.isEmpty) return;
    try {
      await _sb.storage.from(GuidelineIcon.bucket).remove(names);
    } catch (_) {}
  }
}
