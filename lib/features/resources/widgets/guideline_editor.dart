import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/widgets/form_style.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';
import 'package:arise_application/features/resources/widgets/guideline_icon_picker.dart';

/// Kinds of step a guideline can have (matches guideline_items.kind).
const guidelineKinds = <(String, String)>[
  ('item', 'Step with icon'),
  ('bullet', 'Small bullet'),
  ('section', 'Section title (BEFORE / DURING / AFTER)'),
  ('heading', 'Sub-heading'),
  ('text', 'Paragraph'),
  ('tile', 'Big label tile'),
];

void _toast(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text.verbatim('$e')));
}

Future<bool> _confirm(BuildContext context, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
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

/// The icon line of an edit form: the current icon and a button to change it.
class _IconRow extends StatelessWidget {
  const _IconRow({
    required this.spec,
    required this.image,
    required this.fallback,
    required this.onPick,
  });
  final String? spec;
  final Uint8List? image;
  final IconData fallback;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (image != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(image!, width: 48, height: 48, fit: BoxFit.contain),
        )
      else
        GuidelineIcon(spec: spec, fallback: fallback, size: 48),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(
            foregroundColor: kFormBlue,
            side: const BorderSide(color: kFormBlue),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Change icon'),
      ),
    ]);
  }
}

Widget _field(BuildContext ctx, TextEditingController c, String label,
        {int lines = 1, int max = 4000}) =>
    formField(ctx, c, label, lines: lines, max: max);

/// Add or edit a disaster (title, icon, description, subtitle).
Future<void> editGuidelineEntry(BuildContext context,
    {Map<String, dynamic>? row,
    required int count,
    String? categoryId}) async {
  final cubit = context.read<GuidelinesCubit>();
  final cats = [...context.read<GuidelineCategoriesCubit>().state.rows]
    ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
        .compareTo((b['sort_order'] as num?) ?? 0));
  String? catId = (row?['category_id'] as String?) ?? categoryId;
  if (!cats.any((c) => c['id'] == catId)) catId = null;
  // the category is typed (a new one is created) or picked from the arrow
  final catName = TextEditingController(
      text: catId == null
          ? ''
          : '${cats.firstWhere((c) => c['id'] == catId)['name']}');
  final catFil = TextEditingController();
  String? existingCat(String typed) {
    final t = typed.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final c in cats) {
      if ('${c['name']}'.toLowerCase() == t ||
          '${c['name_fil'] ?? ''}'.toLowerCase() == t) {
        return c['id'] as String;
      }
    }
    return null;
  }
  String s(String k) => (row?[k] as String?) ?? '';
  final title = TextEditingController(text: s('title'));
  final sub = TextEditingController(text: s('subtitle'));
  final subFil = TextEditingController(text: s('subtitle_fil'));
  final desc = TextEditingController(text: s('description'));
  final descFil = TextEditingController(text: s('description_fil'));
  final oldIcon = row?['icon'] as String?;
  var icon = oldIcon;
  Uint8List? image;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(row == null ? 'Add guideline' : 'Edit guideline', style: kFormTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconRow(
                spec: icon,
                image: image,
                fallback: Icons.health_and_safety,
                onPick: () async {
                  final c = await showIconPicker(ctx, current: icon);
                  if (c == null) return;
                  setLocal(() {
                    icon = c.spec;
                    image = c.image;
                  });
                },
              ),
              formField(
                ctx,
                catName,
                'Category',
                hint: 'Type a new category or pick one',
                max: 80,
                caps: TextCapitalization.words,
                onChanged: (_) => setLocal(() {}),
                suffix: cats.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down, color: kFormBlue),
                        tooltip: tr(ctx, 'Pick a category'),
                        onSelected: (v) => setLocal(() => catName.text = v),
                        itemBuilder: (_) => [
                          for (final c in cats)
                            PopupMenuItem(
                                value: '${c['name']}',
                                child: Text.verbatim('${c['name']}')),
                        ],
                      ),
              ),
              // a category that does not exist yet can also get a Filipino name
              if (catName.text.trim().isNotEmpty &&
                  existingCat(catName.text) == null)
                _field(ctx, catFil, 'Category name in Filipino', max: 80),
              _field(ctx, title, 'Title', max: 120),
              _field(ctx, sub, 'Short line under the title', max: 200),
              _field(ctx, subFil, 'Short line in Filipino', max: 200),
              _field(ctx, desc, 'Description', lines: 3),
              _field(ctx, descFil, 'Description in Filipino', lines: 3),
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
  final v = {
    'title': title.text.trim(),
    'subtitle': sub.text.trim(),
    'subtitle_fil': subFil.text.trim(),
    'description': desc.text.trim(),
    'description_fil': descFil.text.trim(),
  };
  final typedCat = catName.text.trim();
  final typedCatFil = catFil.text.trim();
  disposeLater([title, sub, subFil, desc, descFil, catName, catFil]);
  if (ok != true || v['title']!.isEmpty) return;
  try {
    // a typed category that is new gets created now
    catId = existingCat(typedCat);
    if (typedCat.isNotEmpty && catId == null && context.mounted) {
      catId = await context.read<GuidelineCategoriesCubit>().insertRow({
        'name': typedCat,
        'name_fil': typedCatFil.isEmpty ? null : typedCatFil,
        'sort_order': cats.length + 1,
      });
      await context.read<GuidelineCategoriesCubit>().load();
    }
    var newIcon = icon;
    if (image != null) newIcon = await GuidelineIconStore.upload(image!);
    final values = <String, dynamic>{
      'title': v['title'],
      'subtitle': v['subtitle']!.isEmpty ? null : v['subtitle'],
      'subtitle_fil': v['subtitle_fil']!.isEmpty ? null : v['subtitle_fil'],
      'description': v['description']!.isEmpty ? null : v['description'],
      'description_fil':
          v['description_fil']!.isEmpty ? null : v['description_fil'],
      'icon': newIcon,
      'category_id': catId,
    };
    if (row == null) {
      await cubit.add({...values, 'sort_order': count + 1});
    } else {
      await cubit.edit(row['id'] as String, values);
    }
    if (oldIcon != null && oldIcon != newIcon) {
      await GuidelineIconStore.removeAll([oldIcon]);
    }
  } catch (e) {
    if (context.mounted) _toast(context, e);
  }
}

/// Deletes a disaster with all its steps (and their pictures).
/// Returns true when it was deleted.
Future<bool> deleteGuidelineEntry(
    BuildContext context, Map<String, dynamic> row) async {
  final items = context.read<GuidelineItemsCubit>();
  final cubit = context.read<GuidelinesCubit>();
  if (!await _confirm(context, 'Delete this guideline and all its steps?')) {
    return false;
  }
  try {
    final icons = <String?>[
      row['icon'] as String?,
      for (final r in items.of(row['id'] as String)) r['icon'] as String?,
    ];
    await cubit.remove(row['id'] as String);
    await GuidelineIconStore.removeAll(icons);
    return true;
  } catch (e) {
    if (context.mounted) _toast(context, e);
    return false;
  }
}

/// Add a step (at [insertIndex], default the end) or edit [row].
Future<void> editGuidelineItem(
  BuildContext context, {
  required String guidelineId,
  Map<String, dynamic>? row,
  int? insertIndex,
}) async {
  final cubit = context.read<GuidelineItemsCubit>();
  var kind = (row?['kind'] as String?) ?? 'item';
  final en = TextEditingController(text: (row?['en'] as String?) ?? '');
  final fil = TextEditingController(text: (row?['fil'] as String?) ?? '');
  final oldIcon = row?['icon'] as String?;
  var icon = oldIcon;
  Uint8List? image;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final hasIcon = kind == 'item' || kind == 'tile';
        final hasFil = kind != 'tile';
        return AlertDialog(
          title: Text(row == null ? 'Add step' : 'Edit step', style: kFormTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final k in guidelineKinds)
                      ChoiceChip(
                        label: Text(k.$2),
                        selected: kind == k.$1,
                        onSelected: (_) => setLocal(() => kind = k.$1),
                      ),
                  ],
                ),
                if (hasIcon) ...[
                  const SizedBox(height: 10),
                  _IconRow(
                    spec: icon,
                    image: image,
                    fallback: Icons.circle_outlined,
                    onPick: () async {
                      final c = await showIconPicker(ctx, current: icon);
                      if (c == null) return;
                      setLocal(() {
                        icon = c.spec;
                        image = c.image;
                      });
                    },
                  ),
                ],
                _field(ctx, en, 'English', lines: 2),
                if (hasFil) _field(ctx, fil, 'Filipino', lines: 2),
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
        );
      },
    ),
  );
  final enText = en.text.trim();
  final filText = fil.text.trim();
  disposeLater([en, fil]);
  if (ok != true || (enText.isEmpty && filText.isEmpty)) return;
  try {
    final usesIcon = kind == 'item' || kind == 'tile';
    var newIcon = usesIcon ? icon : null;
    if (usesIcon && image != null) {
      newIcon = await GuidelineIconStore.upload(image!);
    }
    final values = <String, dynamic>{
      'kind': kind,
      'en': enText,
      'fil': kind == 'tile' ? '' : filText,
      'icon': newIcon,
    };
    if (row == null) {
      await cubit.insertAt(guidelineId,
          insertIndex ?? cubit.of(guidelineId).length, values);
    } else {
      await cubit.edit(row['id'] as String, values);
    }
    if (oldIcon != null && oldIcon != newIcon) {
      await GuidelineIconStore.removeAll([oldIcon]);
    }
  } catch (e) {
    if (context.mounted) _toast(context, e);
  }
}

Future<void> deleteGuidelineItem(
    BuildContext context, Map<String, dynamic> row) async {
  final cubit = context.read<GuidelineItemsCubit>();
  if (!await _confirm(context, 'Delete this step?')) return;
  try {
    await cubit.remove(row['id'] as String);
    await GuidelineIconStore.removeAll([row['icon'] as String?]);
  } catch (e) {
    if (context.mounted) _toast(context, e);
  }
}

/// Add or edit a category of guidelines (name in English and Filipino).
Future<void> editGuidelineCategory(BuildContext context,
    {Map<String, dynamic>? row, required int count}) async {
  final cubit = context.read<GuidelineCategoriesCubit>();
  final name = TextEditingController(text: (row?['name'] as String?) ?? '');
  final nameFil =
      TextEditingController(text: (row?['name_fil'] as String?) ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(row == null ? 'Add category' : 'Edit category', style: kFormTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(ctx, name, 'Category name', max: 80),
            _field(ctx, nameFil, 'Category name in Filipino', max: 80),
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
  final n = name.text.trim();
  final nf = nameFil.text.trim();
  disposeLater([name, nameFil]);
  if (ok != true || n.isEmpty) return;
  try {
    final values = {'name': n, 'name_fil': nf.isEmpty ? null : nf};
    if (row == null) {
      await cubit.add({...values, 'sort_order': count + 1});
    } else {
      await cubit.edit(row['id'] as String, values);
    }
  } catch (e) {
    if (context.mounted) _toast(context, e);
  }
}

/// Deletes a category. Its guidelines are kept, without a category.
Future<void> deleteGuidelineCategory(
    BuildContext context, Map<String, dynamic> row) async {
  final cubit = context.read<GuidelineCategoriesCubit>();
  final guidelines = context.read<GuidelinesCubit>();
  if (!await _confirm(context,
      'Delete this category? Its guidelines are kept, without a category.')) {
    return;
  }
  try {
    await cubit.remove(row['id'] as String);
    await guidelines.load(); // they moved out of the category
  } catch (e) {
    if (context.mounted) _toast(context, e);
  }
}
