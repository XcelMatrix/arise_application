import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                                        context, 'this guideline')) {
                                      return;
                                    }
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
