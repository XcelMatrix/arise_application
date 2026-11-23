import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/resources/services/map_files.dart';
import 'package:arise_application/features/resources/services/map_upload.dart';
import 'package:arise_application/core/theme/app_colors.dart';

/// Teachers and admins upload evacuation maps (3D models and 2D images),
/// put them in a building (each map in a building is one floor) and
/// choose which floor opens first.
class EvacuationMapsPage extends StatefulWidget {
  const EvacuationMapsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const EvacuationMapsPage());

  @override
  State<EvacuationMapsPage> createState() => _EvacuationMapsPageState();
}

class _EvacuationMapsPageState extends State<EvacuationMapsPage> {
  static const _blue = Color(0xFF3C6E87);
  final _sb = Supabase.instance.client;
  bool _busy = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(tr(context, m))));
  }

  static String _size(int? b) {
    if (b == null) return '';
    final mb = b / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(b / 1024).round()} KB';
  }

  Future<void> _upload(String kind) async {
    setState(() => _busy = true);
    try {
      await MapUploader.upload(context, kind);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _use(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      await _sb.rpc('set_current_map', params: {'p_id': row['id']});
      if (!mounted) return;
      await context.read<MapsCubit>().load();
      _toast('Now the first floor shown.');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(Map<String, dynamic> row, {bool building = false}) async {
    final c = TextEditingController(text: row['name'] as String);
    final d = TextEditingController(text: '${row['description'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(building ? 'Edit building' : 'Edit floor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                maxLength: building ? 80 : 100,
                decoration: InputDecoration(labelText: tr(ctx, 'Name')),
              ),
              TextField(
                controller: d,
                minLines: 3,
                maxLines: 8,
                maxLength: 600,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    labelText: tr(ctx, 'Description (optional)')),
              ),
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
    );
    final name = c.text.trim();
    final desc = d.text.trim();
    Future.delayed(const Duration(milliseconds: 600), () {
      c.dispose();
      d.dispose();
    });
    if (ok != true || name.isEmpty || !mounted) return;
    final values = {'name': name, 'description': desc.isEmpty ? null : desc};
    try {
      if (building) {
        await context.read<BuildingsCubit>().edit(row['id'] as String, values);
      } else {
        await context.read<MapsCubit>().edit(row['id'] as String, values);
      }
    } on PostgrestException catch (e) {
      _toast(e.code == '23505' ? 'That name is already used.' : e.message);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text.verbatim(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      ) ??
      false;

  Future<void> _delete(Map<String, dynamic> row) async {
    final cubit = context.read<MapsCubit>();
    if (!await _confirm('Delete this map?', row['name'] as String)) return;
    setState(() => _busy = true);
    try {
      await cubit.remove(row['id'] as String);
      await _sb.storage.from(MapFiles.bucket).remove([row['path'] as String]);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBuilding(
      Map<String, dynamic> b, List<Map<String, dynamic>> maps) async {
    final cubit = context.read<BuildingsCubit>();
    final mapsCubit = context.read<MapsCubit>();
    final ok = await _confirm(
        'Delete this building?',
        '${b['name']}\n\n${tr(context, 'All its maps and markers are deleted too.')}');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await cubit.remove(b['id'] as String); // maps + markers go with it
      final paths = [for (final m in maps) m['path'] as String];
      if (paths.isNotEmpty) {
        await _sb.storage.from(MapFiles.bucket).remove(paths);
      }
      await mapsCubit.load();
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _mapTile(Map<String, dynamic> r) {
    final isModel = r['kind'] == 'model';
    return ListTile(
      dense: true,
      leading: Icon(isModel ? Icons.view_in_ar : Icons.map_outlined, color: _blue),
      title: Text.verbatim(r['name'] as String,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
              fontFamily: 'Geist')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.verbatim(
              '${isModel ? '3D' : '2D'} · ${_size((r['size_bytes'] as num?)?.toInt())}'),
          if ('${r['description'] ?? ''}'.trim().isNotEmpty)
            Text.verbatim('${r['description']}'.trim()),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (r['is_current'] == true)
            const Chip(
              label: Text('First shown',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              backgroundColor: _blue,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'use') _use(r);
              if (v == 'rename') _rename(r);
              if (v == 'delete') _delete(r);
            },
            itemBuilder: (_) => [
              if (r['is_current'] != true)
                const PopupMenuItem(value: 'use', child: Text('Show this floor first')),
              const PopupMenuItem(value: 'rename', child: Text('Edit name and description')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _building(Map<String, dynamic> b, List<Map<String, dynamic>> maps) {
    maps = [...maps]..sort((a, c) =>
        (a['created_at'] as String).compareTo(c['created_at'] as String));
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.apartment, color: _blue),
            title: Text.verbatim(b['name'] as String,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                    fontFamily: 'Geist')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.verbatim('${maps.length} ${tr(context, maps.length == 1 ? 'map' : 'maps')}'),
                if ('${b['description'] ?? ''}'.trim().isNotEmpty)
                  Text.verbatim('${b['description']}'.trim()),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => v == 'rename'
                  ? _rename(b, building: true)
                  : _deleteBuilding(b, maps),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Edit name and description')),
                PopupMenuItem(value: 'delete', child: Text('Delete building')),
              ],
            ),
          ),
          if (maps.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('No maps in this building yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          for (final m in maps) _mapTile(m),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maps = context.watch<MapsCubit>().state;
    final buildings = context.watch<BuildingsCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Manage evacuation maps'),
        titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: !maps.loaded || !buildings.loaded
          ? const FlashingLogo()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_busy) const LinearProgressIndicator(color: _blue),
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                      'Each building can have several maps (one per floor). '
                      'Exits, assembly points and other markers are added from '
                      'the Evacuation Plan page. Files up to 50 MB.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _blue),
                        onPressed: _busy ? null : () => _upload('model'),
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('Upload 3D model'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _blue),
                        onPressed: _busy ? null : () => _upload('image'),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Upload 2D image'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (buildings.rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                        'Nothing uploaded yet. The built-in map is used until you upload one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                for (final b in buildings.rows)
                  _building(b,
                      [for (final m in maps.rows) if (m['building_id'] == b['id']) m]),
              ],
            ),
    );
  }
}
