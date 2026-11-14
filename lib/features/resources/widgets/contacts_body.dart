import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
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
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);
const _green = Color(0xFF2E7D32);

/// The kinds of contact. The order here is the order on the page.
const _categories = <String, (IconData, Color, String)>{
  'principal': (Icons.school, Color(0xFF3C6E87), 'Principal'),
  'nurse': (Icons.medical_services, Color(0xFFC62828), 'School nurse'),
  'fire': (Icons.local_fire_department, Color(0xFFE65100), 'Fire station'),
  'police': (Icons.local_police, Color(0xFF283593), 'Police station'),
  'ambulance': (Icons.emergency, Color(0xFFAD1457), 'Ambulance'),
  'hotline': (Icons.support_agent, Color(0xFF00695C), 'Hotline'),
  'other': (Icons.contact_phone, Color(0xFF546E7A), 'Other'),
};

int _rankOf(Map<String, dynamic> r) {
  final i = _categories.keys.toList().indexOf('${r['category'] ?? 'other'}');
  return i < 0 ? _categories.length : i;
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
    var category = '${row?['category'] ?? 'other'}';
    if (!_categories.containsKey(category)) category = 'other';

    // logo: the one it has now, a newly picked one, or removed
    final oldLogo = row?['logo_path'] as String?;
    Uint8List? newLogo;
    var removeLogo = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(row == null ? 'Add contact' : 'Edit contact'),
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
                      icon: _categories[category]!.$1,
                      color: _categories[category]!.$2,
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
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(labelText: tr(ctx, 'Type')),
                  items: [
                    for (final e in _categories.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Row(children: [
                          Icon(e.value.$1, size: 18, color: e.value.$2),
                          const SizedBox(width: 8),
                          Text(e.value.$3),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => category = v ?? 'other'),
                ),
                TextField(
                  controller: name,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr(ctx, 'Name')),
                ),
                TextField(
                  controller: phone,
                  maxLength: 40,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: tr(ctx, 'Phone number')),
                ),
                TextField(
                  controller: note,
                  maxLength: 300,
                  minLines: 1,
                  maxLines: 4,
                  decoration:
                      InputDecoration(labelText: tr(ctx, 'Note (optional)')),
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
      ),
    );
    final values = {
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'note': note.text.trim().isEmpty ? null : note.text.trim(),
      'category': category,
    };
    name.dispose();
    phone.dispose();
    note.dispose();
    if (ok != true) return;
    if ((values['name'] as String).isEmpty) return;
    try {
      // upload the new logo first; the contact only points at it once it is saved
      String? logoPath = oldLogo;
      if (newLogo != null) {
        final b = newLogo!;
        final png = b.length > 3 && b[0] == 0x89 && b[1] == 0x50;
        logoPath = '${DateTime.now().millisecondsSinceEpoch}.${png ? 'png' : 'jpg'}';
        await Supabase.instance.client.storage.from(ContactLogo.bucket).uploadBinary(
            logoPath, b,
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
      // tidy up the picture that is no longer used
      if (oldLogo != null && oldLogo != logoPath) {
        try {
          await Supabase.instance.client.storage
              .from(ContactLogo.bucket)
              .remove([oldLogo]);
        } catch (_) {}
      }
    } catch (e) {
      if (context.mounted) _err(context, e);
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

    final rows = [...s.rows]..sort((a, b) {
        final c = _rankOf(a).compareTo(_rankOf(b));
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
                  for (final r in rows) _tile(context, cubit, r, canEdit),
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

  Widget _tile(BuildContext context, ContactsCubit cubit,
      Map<String, dynamic> r, bool canEdit) {
    final cat = _categories['${r['category'] ?? 'other'}'] ??
        _categories['other']!;
    final phone = '${r['phone'] ?? ''}'.trim();
    final hasNumber = phone.isNotEmpty;
    final note = r['note'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ContactLogo(
            path: r['logo_path'] as String?,
            icon: cat.$1,
            color: cat.$2,
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
