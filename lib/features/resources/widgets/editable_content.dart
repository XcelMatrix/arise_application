import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/data/rows_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';

const _blue = Color(0xFF3C6E87);

Future<Map<String, String>?> _form(
  BuildContext context, {
  required String title,
  required List<(String key, String label, int lines, int max)> fields,
  Map<String, String> initial = const {},
  TextInputType? firstKeyboard,
}) async {
  final controllers = {
    for (final f in fields) f.$1: TextEditingController(text: initial[f.$1] ?? ''),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields)
              TextField(
                controller: controllers[f.$1],
                minLines: f.$3,
                maxLines: f.$3 + 4 > 8 ? 8 : f.$3 + 4,
                maxLength: f.$4,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: f.$1 == 'phone' ? TextInputType.phone : null,
                decoration: InputDecoration(labelText: tr(ctx, f.$2)),
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
  final out = {for (final e in controllers.entries) e.key: e.value.text.trim()};
  for (final c in controllers.values) {
    c.dispose();
  }
  return ok == true ? out : null;
}

Future<bool> _confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $what?'),
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
  return ok == true;
}

void _err(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text.verbatim('$e')));
}

Widget _offlineNote(RowsState s) => s.offline
    ? const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.grey),
          SizedBox(width: 6),
          Expanded(
            child: Text('Offline. Showing the last saved copy.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ]),
      )
    : const SizedBox.shrink();

/// Disaster guidelines list. Teachers/admins can add, edit and delete.
class GuidelinesBody extends StatelessWidget {
  const GuidelinesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.contentEdit));
    final s = context.watch<GuidelinesCubit>().state;
    final cubit = context.read<GuidelinesCubit>();

    Future<void> edit([Map<String, dynamic>? row]) async {
      final v = await _form(context,
          title: row == null ? 'Add guideline' : 'Edit guideline',
          fields: const [
            ('title', 'Title', 1, 120),
            ('body', 'Steps (one per line)', 5, 4000),
          ],
          initial: {
            'title': row?['title'] ?? '',
            'body': row?['body'] ?? '',
          });
      if (v == null || v['title']!.isEmpty || v['body']!.isEmpty) return;
      try {
        if (row == null) {
          await cubit.add({...v, 'sort_order': s.rows.length + 1});
        } else {
          await cubit.edit(row['id'] as String, v);
        }
      } catch (e) {
        if (context.mounted) _err(context, e);
      }
    }

    return Stack(
      children: [
        !s.loaded
            ? const FlashingLogo()
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, canEdit ? 90 : 16),
                children: [
                  _offlineNote(s),
                  if (s.rows.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No guidelines yet.',
                          style: TextStyle(color: Colors.grey)),
                    )),
                  for (final r in s.rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading:
                            const Icon(Icons.health_and_safety, color: _blue),
                        title: Text.verbatim(r['title'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                                fontFamily: 'Geist')),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in (r['body'] as String)
                              .split('\n')
                              .where((l) => l.trim().isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text.verbatim('•  '),
                                  Expanded(
                                      child: Text.verbatim(line.trim(),
                                          style: TextStyle(
                                              color: AppColors.body(context),
                                              fontFamily: 'Geist'))),
                                ],
                              ),
                            ),
                          if (canEdit)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => edit(r),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    if (!await _confirmDelete(
                                        context, 'this guideline')) return;
                                    try {
                                      await cubit.remove(r['id'] as String);
                                    } catch (e) {
                                      if (context.mounted) _err(context, e);
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  label: const Text('Delete'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add guideline'),
            ),
          ),
      ],
    );
  }
}

/// Emergency contacts list. Tap Call to dial; teachers/admins can edit.
class ContactsBody extends StatelessWidget {
  const ContactsBody({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+*#]'), '');
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Number copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.contentEdit));
    final s = context.watch<ContactsCubit>().state;
    final cubit = context.read<ContactsCubit>();

    Future<void> edit([Map<String, dynamic>? row]) async {
      final v = await _form(context,
          title: row == null ? 'Add contact' : 'Edit contact',
          fields: const [
            ('name', 'Name', 1, 120),
            ('phone', 'Phone number', 1, 40),
            ('note', 'Note (optional)', 2, 300),
          ],
          initial: {
            'name': row?['name'] ?? '',
            'phone': row?['phone'] ?? '',
            'note': row?['note'] ?? '',
          });
      if (v == null || v['name']!.isEmpty || v['phone']!.isEmpty) return;
      final values = {...v, 'note': v['note']!.isEmpty ? null : v['note']};
      try {
        if (row == null) {
          await cubit.add({...values, 'sort_order': s.rows.length + 1});
        } else {
          await cubit.edit(row['id'] as String, values);
        }
      } catch (e) {
        if (context.mounted) _err(context, e);
      }
    }

    return Stack(
      children: [
        !s.loaded
            ? const FlashingLogo()
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, canEdit ? 90 : 16),
                children: [
                  _offlineNote(s),
                  if (s.rows.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No contacts yet.',
                          style: TextStyle(color: Colors.grey)),
                    )),
                  for (final r in s.rows)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.verbatim(r['name'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.text(context),
                                        fontFamily: 'Geist')),
                                Text.verbatim(r['phone'] as String,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: _blue,
                                        fontFamily: 'Geist')),
                                if (r['note'] != null)
                                  Text.verbatim(r['note'] as String,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontFamily: 'Geist')),
                              ],
                            ),
                          ),
                          // phone button: opens the dialer with the number ready
                          Material(
                            color: const Color(0xFF2E7D32),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: tr(context, 'Call'),
                              icon: const Icon(Icons.phone, color: Colors.white),
                              onPressed: () =>
                                  _call(context, r['phone'] as String),
                            ),
                          ),
                          if (canEdit)
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') return edit(r);
                                if (!await _confirmDelete(context, 'this contact')) {
                                  return;
                                }
                                try {
                                  await cubit.remove(r['id'] as String);
                                } catch (e) {
                                  if (context.mounted) _err(context, e);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add contact'),
            ),
          ),
      ],
    );
  }
}
