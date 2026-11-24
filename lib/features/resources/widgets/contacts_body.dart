import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/form_style.dart';
import 'package:arise_application/core/widgets/category_heading.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/resources/widgets/contact_logo.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';
import 'package:arise_application/features/resources/widgets/guideline_icon_picker.dart';
import 'package:arise_application/features/resources/widgets/guideline_editor.dart' show IconRow;
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);
const _green = Color(0xFF2E7D32);

/// The kinds of contact you can pick. The order here is the order on the page.
/// ('other' is only for older contacts that don't fit; it can't be picked.)
const _categories = <String, (IconData, Color, String)>{
  'school': (Icons.school, Color(0xFF3C6E87), 'School'),
  'hospital': (Icons.local_hospital, Color(0xFFC62828), 'Hospital'),
  'fire': (Icons.local_fire_department, Color(0xFFE65100), 'Fire Station'),
  'police': (Icons.local_police, Color(0xFF283593), 'Police Station'),
  'government': (Icons.account_balance, Color(0xFF5D4037), 'Government'),
  'other': (Icons.contact_phone, Color(0xFF546E7A), 'Other'),
};

/// older type names -> the current ones
String _catKey(Object? v) {
  switch ('$v') {
    case 'principal':
    case 'nurse':
      return 'school';
    case 'ambulance':
      return 'hospital';
  }
  return _categories.containsKey('$v') ? '$v' : 'other';
}

/// A heading of the contacts page: a built-in type or one somebody added.
class _Group {
  const _Group(this.key, this.icon, this.color, this.label,
      {this.spec, this.custom = false, this.customId});
  final String key;
  final IconData icon;
  final Color color;
  final String label;
  final String? spec; // icon of a custom category ('i:..', 't:..', 'u:..')
  final bool custom;
  final String? customId;
}

IconData _specIcon(String? spec) {
  if (spec != null && spec.startsWith('i:')) {
    return GuidelineIcons.map[spec.substring(2)] ?? Icons.contact_phone;
  }
  return Icons.contact_phone;
}

_Group _groupOf(Map<String, dynamic> r, List<Map<String, dynamic>> customs) {
  final cid = r['category_id'];
  if (cid != null) {
    for (final c in customs) {
      if (c['id'] == cid) {
        final spec = c['icon'] as String?;
        return _Group('c:$cid', _specIcon(spec), _blue, '${c['name']}',
            spec: spec, custom: true, customId: '$cid');
      }
    }
  }
  final k = _catKey(r['category']);
  final c = _categories[k]!;
  return _Group(k, c.$1, c.$2, c.$3);
}

int _rankOf(Map<String, dynamic> r, List<Map<String, dynamic>> customs) {
  // the School Emergency Response Team (sort_order 0) always comes first
  if (r['name'] == 'School Emergency Response Team' ||
      (r['sort_order'] is num && (r['sort_order'] as num) <= 0)) {
    return -1;
  }
  final g = _groupOf(r, customs);
  if (g.custom) {
    // custom categories sit after the built-in ones, before "Other"
    final i = customs.indexWhere((c) => c['id'] == g.customId);
    return 4500 + i;
  }
  final i = _categories.keys.toList().indexOf(g.key);
  return i < 0 ? 9000 : i * 1000;
}

/// Removes custom categories that no contact uses any more.
Future<void> _pruneCategories(
    ContactsCubit contacts, ContactCategoriesCubit cats) async {
  try {
    await cats.load();
    final used = {for (final r in contacts.state.rows) r['category_id']};
    for (final c in [...cats.state.rows]) {
      if (!used.contains(c['id'])) {
        await cats.remove(c['id'] as String);
        await GuidelineIconStore.removeAll([c['icon'] as String?]);
      }
    }
  } catch (_) {}
}

/// Emergency contacts: Principal, nurse, fire, police and others.
/// Anyone can tap the green button to dial. Only accounts allowed to edit
/// contacts (admins by default) can add, change or remove numbers.
/// Saved on the phone, so the list is there even with no signal.
class ContactsBody extends StatelessWidget {
  const ContactsBody({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (number.isEmpty) return;
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Number copied.')));
    }
  }

  Future<void> _copy(BuildContext context, String phone) async {
    if (phone.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Number copied.')));
    }
  }

  void _err(BuildContext context, Object e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim('$e')));
  }

  Future<void> _edit(BuildContext context, ContactsCubit cubit, int count,
      [Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final phone = TextEditingController(text: '${row?['phone'] ?? ''}');
    final note = TextEditingController(text: '${row?['note'] ?? ''}');
    final catCubit = context.read<ContactCategoriesCubit>();
    final customs = [...catCubit.state.rows];
    final cur = row == null ? null : _groupOf(row, customs);
    // the type is typed (a new one is created) or picked from the arrow
    final typeCtl = TextEditingController(
        text: cur == null ? Tr.t('School') : (cur.custom ? cur.label : Tr.t(cur.label)));
    String? newCatIcon;
    Uint8List? newCatImage;

    /// what the typed text means: a built-in type, one of ours, or a new one
    ({String? builtin, String? customId}) match(String typed) {
      final t = typed.trim().toLowerCase();
      if (t.isEmpty) return (builtin: 'other', customId: null);
      for (final e in _categories.entries) {
        if (e.value.$3.toLowerCase() == t || Tr.t(e.value.$3).toLowerCase() == t) {
          return (builtin: e.key, customId: null);
        }
      }
      for (final c in customs) {
        if ('${c['name']}'.toLowerCase() == t) {
          return (builtin: null, customId: c['id'] as String);
        }
      }
      return (builtin: null, customId: null);
    }

    // logo: the one it has now, a newly picked one, or removed
    final oldLogo = row?['logo_path'] as String?;
    Uint8List? newLogo;
    var removeLogo = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(row == null ? 'Add contact' : 'Edit contact', style: kFormTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // the contact's logo (optional)
                Row(children: [
                  if (newLogo != null)
                    CircleAvatar(radius: 30, backgroundImage: MemoryImage(newLogo!))
                  else
                    ContactLogo(
                      path: removeLogo ? null : oldLogo,
                      icon: _groupOf({
                        'category': match(typeCtl.text).builtin ?? 'other',
                        'category_id': match(typeCtl.text).customId,
                      }, customs).icon,
                      color: _groupOf({
                        'category': match(typeCtl.text).builtin ?? 'other',
                        'category_id': match(typeCtl.text).customId,
                      }, customs).color,
                      radius: 30,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(spacing: 6, children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final f = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 512,
                              maxHeight: 512,
                              imageQuality: 85);
                          if (f == null) return;
                          final b = await f.readAsBytes();
                          setLocal(() {
                            newLogo = b;
                            removeLogo = false;
                          });
                        },
                        icon: const Icon(Icons.image, size: 18),
                        label: Text(newLogo != null ||
                                (oldLogo != null && !removeLogo)
                            ? 'Change logo'
                            : 'Add logo'),
                      ),
                      if (newLogo != null || (oldLogo != null && !removeLogo))
                        TextButton(
                          onPressed: () => setLocal(() {
                            newLogo = null;
                            removeLogo = true;
                          }),
                          child: const Text('Remove logo'),
                        ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                formField(
                  ctx,
                  typeCtl,
                  'Type',
                  hint: 'Type a new type or pick one',
                  max: 80,
                  caps: TextCapitalization.words,
                  onChanged: (_) => setLocal(() {}),
                  suffix: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down, color: kFormBlue),
                    tooltip: tr(ctx, 'Pick a type'),
                    onSelected: (v) => setLocal(() => typeCtl.text = v),
                    itemBuilder: (_) => [
                      for (final e in _categories.entries)
                        if (e.key != 'other')
                          PopupMenuItem(
                            value: Tr.t(e.value.$3),
                            child: Row(children: [
                              Icon(e.value.$1, size: 18, color: e.value.$2),
                              const SizedBox(width: 8),
                              Text(e.value.$3),
                            ]),
                          ),
                      for (final c in customs)
                        PopupMenuItem(
                          value: '${c['name']}',
                          child: Row(children: [
                            GuidelineIcon(
                                spec: c['icon'] as String?,
                                fallback: Icons.contact_phone,
                                size: 18),
                            const SizedBox(width: 8),
                            Text.verbatim('${c['name']}'),
                          ]),
                        ),
                    ],
                  ),
                ),
                // a type that does not exist yet gets its own icon
                if (typeCtl.text.trim().isNotEmpty &&
                    match(typeCtl.text).builtin == null &&
                    match(typeCtl.text).customId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(children: [
                      if (newCatImage != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(newCatImage!,
                              width: 40, height: 40, fit: BoxFit.contain),
                        )
                      else
                        GuidelineIcon(
                            spec: newCatIcon,
                            fallback: Icons.contact_phone,
                            size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: kFormBlue,
                              side: const BorderSide(color: kFormBlue),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          onPressed: () async {
                            final c =
                                await showIconPicker(ctx, current: newCatIcon);
                            if (c == null) return;
                            setLocal(() {
                              newCatIcon = c.spec;
                              newCatImage = c.image;
                            });
                          },
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Choose icon for this type'),
                        ),
                      ),
                    ]),
                  ),
                formField(ctx, name, 'Name',
                    max: 120, caps: TextCapitalization.words),
                formField(ctx, phone, 'Phone number',
                    max: 40, keyboard: TextInputType.phone),
                formField(ctx, note, 'Description (optional)',
                    max: 300, lines: 1),
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
    final values = <String, dynamic>{
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
    };
    final typed = typeCtl.text.trim();
    final m = match(typed);
    // let the dialog finish closing before the controllers go away
    disposeLater([name, phone, note, typeCtl]);
    if (ok != true) return;
    if ((values['name'] as String).isEmpty) return;
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      await (() async {
        // upload the new logo first; the contact only points at it once it is saved
        // the type: built-in, one of ours, or a new one that is created now
        if (m.builtin != null) {
          values['category'] = m.builtin;
          values['category_id'] = null;
        } else if (m.customId != null) {
          values['category'] = 'other';
          values['category_id'] = m.customId;
        } else {
          var icon = newCatIcon;
          if (newCatImage != null) {
            icon = await GuidelineIconStore.upload(newCatImage!);
          }
          values['category'] = 'other';
          values['category_id'] = await catCubit.insertRow({
            'name': typed,
            'icon': icon,
            'sort_order': customs.length + 1,
          });
          await catCubit.load();
        }
        String? logoPath = oldLogo;
        if (newLogo != null) {
          final b = newLogo!;
          final png = b.length > 3 && b[0] == 0x89 && b[1] == 0x50;
          logoPath =
              '${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
          await Supabase.instance.client.storage
              .from(ContactLogo.bucket)
              .uploadBinary(logoPath, b,
                  fileOptions:
                      FileOptions(contentType: png ? 'image/png' : 'image/jpeg'));
        } else if (removeLogo) {
          logoPath = null;
        }
        values['logo_path'] = logoPath;
        if (row == null) {
          await cubit.add({...values, 'sort_order': count + 1});
        } else {
          await cubit.edit(row['id'] as String, values);
        }
        await _pruneCategories(cubit, catCubit);
        // tidy up the picture that is no longer used
        if (oldLogo != null && oldLogo != logoPath) {
          try {
            await Supabase.instance.client.storage
                .from(ContactLogo.bucket)
                .remove([oldLogo]);
          } catch (_) {}
        }
      })()
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (context.mounted) {
        _err(context,
            'Saving took too long. Check your connection and try again.');
      }
    } catch (e) {
      if (context.mounted) _err(context, e);
    } finally {
      if (nav.canPop()) nav.pop();
    }
  }

  Future<void> _delete(BuildContext context, ContactsCubit cubit,
      Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this contact?'),
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
      await cubit.remove(row['id'] as String);
      if (context.mounted) {
        await _pruneCategories(cubit, context.read<ContactCategoriesCubit>());
      }
      final logo = row['logo_path'] as String?;
      if (logo != null && logo.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from(ContactLogo.bucket)
              .remove([logo]);
        } catch (_) {}
      }
    } catch (e) {
      if (context.mounted) _err(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.contactsEdit));
    final s = context.watch<ContactsCubit>().state;
    final cubit = context.read<ContactsCubit>();
    final customs = context.watch<ContactCategoriesCubit>().state.rows;

    final rows = [...s.rows]..sort((a, b) {
        final c = _rankOf(a, customs).compareTo(_rankOf(b, customs));
        if (c != 0) return c;
        final o = ((a['sort_order'] as num?) ?? 0)
            .compareTo((b['sort_order'] as num?) ?? 0);
        return o != 0 ? o : '${a['name']}'.compareTo('${b['name']}');
      });

    return Stack(
      children: [
        !s.loaded
            ? const FlashingLogo()
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, canEdit ? 90 : 16),
                children: [
                  if (s.offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        const Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Offline. Showing the last saved copy.',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ),
                      ]),
                    ),
                  if (rows.isEmpty)
                    Center(
                        child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No contacts yet.',
                          style: const TextStyle(color: Colors.grey)),
                    )),
                  // a heading for each type of contact
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i == 0 ||
                        _groupOf(rows[i], customs).key !=
                            _groupOf(rows[i - 1], customs).key)
                      _header(context, _groupOf(rows[i], customs), i == 0, canEdit),
                    _tile(context, cubit, rows[i], canEdit, customs),
                  ],
                ],
              ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () => _edit(context, cubit, rows.length),
              icon: const Icon(Icons.add),
              label: const Text('Add contact'),
            ),
          ),
      ],
    );
  }

  void _fail(BuildContext context, Object e) {
    if (!context.mounted) return;
    final msg = e is PostgrestException && e.code == '23505'
        ? Tr.t('A type with that name already exists.')
        : '$e';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(msg)));
  }

  /// Rename a type you added and change its icon.
  Future<void> _editType(BuildContext context, String id) async {
    final catCubit = context.read<ContactCategoriesCubit>();
    final row = catCubit.state.rows.firstWhere((r) => r['id'] == id);
    final name = TextEditingController(text: '${row['name']}');
    final oldIcon = row['icon'] as String?;
    var icon = oldIcon;
    Uint8List? image;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Edit type', style: kFormTitle),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              IconRow(
                spec: icon,
                image: image,
                fallback: Icons.contact_phone,
                onPick: () async {
                  final c = await showIconPicker(ctx, current: icon);
                  if (c == null) return;
                  setLocal(() {
                    icon = c.spec;
                    image = c.image;
                  });
                },
              ),
              formField(ctx, name, 'Type', max: 80, caps: TextCapitalization.words),
            ]),
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
    final n = name.text.trim();
    disposeLater([name]);
    if (ok != true || n.isEmpty) return;
    try {
      var newIcon = icon;
      if (image != null) newIcon = await GuidelineIconStore.upload(image!);
      await catCubit.edit(id, {'name': n, 'icon': newIcon});
      if (oldIcon != null && oldIcon != newIcon) {
        await GuidelineIconStore.removeAll([oldIcon]);
      }
    } catch (e) {
      _fail(context, e);
    }
  }

  Future<void> _moveType(BuildContext context, String id, int delta) async {
    final catCubit = context.read<ContactCategoriesCubit>();
    final rows = [...catCubit.state.rows]..sort((a, b) =>
        ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0));
    final i = rows.indexWhere((r) => r['id'] == id);
    final to = i + delta;
    if (i < 0 || to < 0 || to >= rows.length) return;
    final ids = [for (final r in rows) r['id'] as String];
    ids.insert(to, ids.removeAt(i));
    try {
      await catCubit.reorder(ids);
    } catch (e) {
      _fail(context, e);
    }
  }

  /// Deletes a type you added. Its contacts are kept, under "Other".
  Future<void> _deleteType(BuildContext context, String id) async {
    final catCubit = context.read<ContactCategoriesCubit>();
    final contacts = context.read<ContactsCubit>();
    final icon = catCubit.state.rows
        .firstWhere((r) => r['id'] == id, orElse: () => {})['icon'] as String?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this type? Its contacts are kept, under Other.'),
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
      await catCubit.remove(id);
      await contacts.load();
      await GuidelineIconStore.removeAll([icon]);
    } catch (e) {
      if (context.mounted) _fail(context, e);
    }
  }

  Widget _header(BuildContext context, _Group cat, bool first, bool canEdit) {
    return CategoryHeading(
      first: first,
      icon: CategoryIcon(spec: cat.spec, fallback: cat.icon, size: 22),
      title: cat.custom ? cat.label : tr(context, cat.label),
      trailing: canEdit && cat.custom
          ? PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (a) {
                  final id = cat.customId!;
                  switch (a) {
                    case 'edit':
                      _editType(context, id);
                    case 'up':
                      _moveType(context, id, -1);
                    case 'down':
                      _moveType(context, id, 1);
                    case 'delete':
                      _deleteType(context, id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit type')),
                  PopupMenuItem(value: 'up', child: Text('Move up')),
                  PopupMenuItem(value: 'down', child: Text('Move down')),
                  PopupMenuItem(value: 'delete', child: Text('Delete type')),
                ],
              )
          : null,
    );
  }

  Widget _tile(BuildContext context, ContactsCubit cubit,
      Map<String, dynamic> r, bool canEdit, List<Map<String, dynamic>> customs) {
    final cat = _groupOf(r, customs);
    final phone = '${r['phone'] ?? ''}'.trim();
    final hasNumber = phone.isNotEmpty;
    final note = r['note'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border.all(color: AppColors.border(context), width: 1.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ContactLogo(
            path: r['logo_path'] as String?,
            icon: cat.icon,
            color: cat.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onLongPress: () => _copy(context, phone),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // names and notes of the standard contacts are translated;
                  // anything an admin typed is shown as written
                  Text('${r['name']}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.text(context),
                          fontFamily: 'Geist')),
                  hasNumber
                      ? Text.verbatim(phone,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _blue,
                              fontFamily: 'Geist'))
                      : Text('No number yet',
                          style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontFamily: 'Geist')),
                  if (note != null && note.isNotEmpty)
                    Text(note,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'Geist')),
                ],
              ),
            ),
          ),
          // one tap: opens the phone dialer with the number ready
          Material(
            color: hasNumber ? _green : Colors.grey,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: tr(context, 'Call'),
              icon: const Icon(Icons.phone, color: Colors.white),
              onPressed: hasNumber ? () => _call(context, phone) : null,
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  _edit(context, cubit, 0, r);
                } else {
                  _delete(context, cubit, r);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
