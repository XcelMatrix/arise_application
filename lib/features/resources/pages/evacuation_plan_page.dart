import 'dart:async';
import 'dart:typed_data';
import 'package:arise_application/core/widgets/save_progress.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/form_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';
import 'package:arise_application/features/resources/pages/evacuation_map_page.dart';
import 'package:arise_application/features/resources/services/map_files.dart';
import 'package:arise_application/features/resources/widgets/building_image.dart';
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);

/// The Evacuation Plan hub: one picture button per building. Tapping a
/// building opens its map. Teachers and admins can add buildings and change
/// their name and picture.
class EvacuationPlanPage extends StatefulWidget {
  const EvacuationPlanPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const EvacuationPlanPage());

  @override
  State<EvacuationPlanPage> createState() => _EvacuationPlanPageState();
}

class _EvacuationPlanPageState extends State<EvacuationPlanPage> {
  final _sb = Supabase.instance.client;

  bool _allowed(String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your account level doesn't have access to this."),
    ));
  }

  List<int> _visibleNav(BuildContext context, {bool listen = true}) {
    final a = listen
        ? context.watch<AccountCubit>().state
        : context.read<AccountCubit>().state;
    return [
      0,
      if (a.canAccess(Feature.attendance)) 1,
      if (a.canAccess(Feature.timedConsole)) 2,
      3,
    ];
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomePage()));
      case 1:
        if (!_allowed(Feature.attendance)) return _denied();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AttendancePage()));
      case 2:
        if (!_allowed(Feature.timedConsole)) return _denied();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const TimedConsolePage()));
      case 3:
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DisasterResourcesPage()));
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(tr(context, m))));
  }

  /// Add (row == null) or edit a building: its name and picture.
  Future<void> _edit({Map<String, dynamic>? row}) async {
    final cubit = context.read<BuildingsCubit>();
    final count = cubit.state.rows.length;
    final nameC = TextEditingController(text: (row?['name'] as String?) ?? '');
    final descC =
        TextEditingController(text: (row?['description'] as String?) ?? '');
    final oldImage = row?['image_path'] as String?;
    Uint8List? picked;
    var removed = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(row == null ? 'Add building' : 'Edit building', style: kFormTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: picked != null
                        ? Image.memory(picked!, fit: BoxFit.cover)
                        : BuildingImage(path: removed ? null : oldImage),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1280,
                          maxHeight: 1280,
                          imageQuality: 85);
                      if (f == null) return;
                      final b = await f.readAsBytes();
                      setLocal(() {
                        picked = b;
                        removed = false;
                      });
                    },
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('Choose picture'),
                  ),
                  if (picked != null || (!removed && oldImage != null))
                    TextButton(
                      onPressed: () => setLocal(() {
                        picked = null;
                        removed = true;
                      }),
                      child: const Text('Remove picture'),
                    ),
                ]),
                formField(ctx, nameC, 'Building name',
                    hint: 'e.g. Science building',
                    max: 80,
                    caps: TextCapitalization.words),
                formField(ctx, descC, 'Description (optional)',
                    lines: 3, max: 600),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    final name = nameC.text.trim();
    final desc = descC.text.trim();
    // let the dialog finish closing before the controller goes away
    disposeLater([nameC, descC]);
    if (ok != true || name.isEmpty || !mounted) return;

    String? uploaded;
    final err = await runWithProgress(context, () async {
      String? imagePath = removed ? null : oldImage;
      if (picked != null) {
        uploaded = await BuildingImageStore.upload(picked!);
        imagePath = uploaded;
      }
      if (row == null) {
        await cubit.add({
          'name': name,
          'description': desc.isEmpty ? null : desc,
          'image_path': imagePath,
          'sort_order': count + 1,
        });
      } else {
        await cubit
            .edit(row['id'] as String, {
          'name': name,
          'description': desc.isEmpty ? null : desc,
          'image_path': imagePath,
        });
      }
      uploaded = null;
      if (oldImage != null && oldImage != imagePath) {
        await BuildingImageStore.remove(oldImage);
      }
    });
    if (err != null) {
      if (uploaded != null) await BuildingImageStore.remove(uploaded);
      if (err is TimeoutException) {
        _toast('Saving took too long. Check your connection and try again.');
      } else if (err is PostgrestException) {
        _toast(err.code == '23505'
            ? 'A building with that name already exists.'
            : err.message);
      } else {
        _toast('$err');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final buildings = context.read<BuildingsCubit>();
    final mapsCubit = context.read<MapsCubit>();
    final maps = [
      for (final m in mapsCubit.state.rows)
        if (m['building_id'] == b['id']) m
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this building?'),
        content: Text.verbatim(
            '${b['name']}\n\n${tr(ctx, 'All its maps and markers are deleted too.')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await buildings.remove(b['id'] as String); // maps + markers go with it
      final paths = [for (final m in maps) m['path'] as String];
      if (paths.isNotEmpty) {
        await _sb.storage.from(MapFiles.bucket).remove(paths);
      }
      await BuildingImageStore.remove(b['image_path'] as String?);
      await mapsCubit.load();
    } catch (e) {
      _toast('$e');
    }
  }

  Widget _card(Map<String, dynamic> b, bool canEdit, Set<String> hasModel,
      Set<String> hasImage) {
    final id = b['id'] as String;
    return Material(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _blue, width: 2)),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      color: _blue,
      child: InkWell(
        onTap: () => Navigator.push(context, EvacuationMapPage.route(id)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BuildingImage(path: b['image_path'] as String?),
            // darker strip so the name is readable on any picture
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text.verbatim(
                        b['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Geist'),
                      ),
                    ),
                    if (hasModel.contains(id))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child:
                            Icon(Icons.view_in_ar, color: Colors.white, size: 18),
                      ),
                    if (hasImage.contains(id))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.map_outlined,
                            color: Colors.white, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            if (canEdit)
              Positioned(
                top: 2,
                right: 2,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'edit') _edit(row: b);
                    if (v == 'delete') _delete(b);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.mapEdit));
    final buildings = context.watch<BuildingsCubit>().state;
    final maps = context.watch<MapsCubit>().state;
    final hasModel = {
      for (final m in maps.rows)
        if (m['kind'] == 'model') m['building_id'] as String
    };
    final hasImage = {
      for (final m in maps.rows)
        if (m['kind'] == 'image') m['building_id'] as String
    };

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const BackOrLogo(),
        backgroundColor: _blue,
        title: const Text('Evacuation Plan'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: const [ProfileMenuButton()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _visibleNav(context).indexOf(3),
        onTap: (i) => _onItemTapped(_visibleNav(context, listen: false)[i]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: _blue,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFACACAC),
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontFamily: 'Geist', fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontFamily: 'Geist', fontSize: 11),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: tr(context, 'Home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_turned_in),
              label: tr(context, 'Attendance')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.terminal), label: tr(context, 'Console')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.health_and_safety),
              label: tr(context, 'Resources')),
        ]
            .asMap()
            .entries
            .where((e) => _visibleNav(context).contains(e.key))
            .map((e) => e.value)
            .toList(),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_business),
              label: const Text('Add building'),
            )
          : null,
      body: !buildings.loaded
          ? const FlashingLogo()
          : buildings.rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                        canEdit
                            ? 'No buildings yet. Tap "Add building".'
                            : 'No buildings have been added yet.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) {
                    final w = (box.maxWidth - 32 - 14) / 2;
                    return SingleChildScrollView(
                      padding:
                          EdgeInsets.fromLTRB(16, 16, 16, canEdit ? 96 : 16),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final b in buildings.rows)
                            SizedBox(
                              width: w,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 1,
                                    child: _card(b, canEdit, hasModel, hasImage),
                                  ),
                                  // the whole description, however long
                                  if ('${b['description'] ?? ''}'.trim().isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(4, 8, 4, 0),
                                      child: Text.verbatim(
                                        '${b['description']}'.trim(),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.3,
                                            color: _blue,
                                            fontFamily: 'Geist'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
