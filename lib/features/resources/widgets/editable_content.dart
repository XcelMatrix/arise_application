import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';
import 'package:arise_application/features/resources/data/guideline_text.dart';
import 'package:arise_application/features/resources/data/offline_guides.dart';
import 'package:arise_application/features/resources/pages/offline_guides_page.dart';
import 'package:arise_application/features/resources/pages/guideline_detail_page.dart';
import 'package:arise_application/features/resources/widgets/guideline_editor.dart';

const _blue = Color(0xFF3C6E87);

/// The disaster guidelines: one card per disaster (icon, title, short line).
/// Tapping opens the full guideline. Teachers/admins can add, edit, reorder
/// and delete.
class GuidelinesBody extends StatelessWidget {
  const GuidelinesBody({super.key});

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.contentEdit));
    final s = context.watch<GuidelinesCubit>().state;
    final cubit = context.read<GuidelinesCubit>();
    final catCubit = context.read<GuidelineCategoriesCubit>();
    final cats = [...context.watch<GuidelineCategoriesCubit>().state.rows]
      ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
          .compareTo((b['sort_order'] as num?) ?? 0));
    final rows = [...s.rows]..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
        .compareTo((b['sort_order'] as num?) ?? 0));
    final catIds = {for (final c in cats) c['id'] as String};
    // guidelines grouped by category (no / unknown category = null)
    final groups = <String?, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final c = r['category_id'] as String?;
      groups.putIfAbsent(catIds.contains(c) ? c : null, () => []).add(r);
    }

    void fail(Object e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text.verbatim('$e')));
      }
    }

    Future<void> moveIn(List<Map<String, dynamic>> group, int index, int delta) async {
      final to = index + delta;
      if (to < 0 || to >= group.length) return;
      final ids = [for (final r in group) r['id'] as String];
      ids.insert(to, ids.removeAt(index));
      try {
        await cubit.reorder(ids);
      } catch (e) {
        fail(e);
      }
    }

    Future<void> moveCat(int index, int delta) async {
      final to = index + delta;
      if (to < 0 || to >= cats.length) return;
      final ids = [for (final r in cats) r['id'] as String];
      ids.insert(to, ids.removeAt(index));
      try {
        await catCubit.reorder(ids);
      } catch (e) {
        fail(e);
      }
    }

    Widget emptyNote(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        );

    List<Widget> section(String? catId, int ci) {
      final group = groups[catId] ?? const <Map<String, dynamic>>[];
      final cat = catId == null ? null : cats[ci];
      return [
        if (cats.isNotEmpty)
          _categoryHeader(context, cat, ci, canEdit, cats.length, moveCat),
        if (group.isEmpty && canEdit && cat != null)
          emptyNote('No guidelines in this category yet.'),
        for (var i = 0; i < group.length; i++)
          _card(context, group[i], i, canEdit, rows.length,
              (idx, d) => moveIn(group, idx, d)),
      ];
    }

    return Stack(
      children: [
        !s.loaded
            ? const FlashingLogo()
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, canEdit ? 150 : 16),
                children: [
                  if (s.offline)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Icon(Icons.cloud_off, size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('Offline. Showing the last saved copy.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      ]),
                    ),
                  // never loaded (first run, no signal): the guides built into the
                  // app are shown so something is always available
                  if (rows.isEmpty && s.offline) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                          'These guides are saved in the app and work without internet.',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    for (final g in offlineGuides) _builtInCard(context, g),
                  ] else if (rows.isEmpty && cats.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No guidelines yet.',
                          style: TextStyle(color: Colors.grey)),
                    )),
                  // each category with its guidelines, in the order set here
                  for (var ci = 0; ci < cats.length; ci++)
                    ...section(cats[ci]['id'] as String, ci),
                  // guidelines without a category come last
                  if ((groups[null] ?? const []).isNotEmpty)
                    ...section(null, -1),
                ],
              ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add_guideline_category',
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  onPressed: () =>
                      editGuidelineCategory(context, count: cats.length),
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text('Add category'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'add_guideline',
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  onPressed: () =>
                      editGuidelineEntry(context, count: rows.length),
                  icon: const Icon(Icons.add),
                  label: const Text('Add guideline'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Title line of a category with its menu (editors). [cat] is null for the
  /// guidelines that have no category.
  Widget _categoryHeader(BuildContext context, Map<String, dynamic>? cat,
      int index, bool canEdit, int total,
      Future<void> Function(int, int) moveCat) {
    final title = cat == null
        ? tr(context, 'Other')
        : pickLang((cat['name'] as String?) ?? '', (cat['name_fil'] as String?) ?? '');
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(children: [
        Expanded(
          child: Text.verbatim(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                  fontFamily: 'Geist')),
        ),
        if (canEdit && cat != null)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            onSelected: (a) async {
              switch (a) {
                case 'edit':
                  await editGuidelineCategory(context, row: cat, count: total);
                case 'add':
                  await editGuidelineEntry(context,
                      count: context.read<GuidelinesCubit>().state.rows.length,
                      categoryId: cat['id'] as String);
                case 'up':
                  await moveCat(index, -1);
                case 'down':
                  await moveCat(index, 1);
                case 'delete':
                  await deleteGuidelineCategory(context, cat);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'edit', child: Text('Edit category',
                  style: TextStyle(color: _blue))),
              PopupMenuItem(value: 'add', child: Text('Add guideline here',
                  style: TextStyle(color: _blue))),
              PopupMenuItem(value: 'up', child: Text('Move up',
                  style: TextStyle(color: _blue))),
              PopupMenuItem(value: 'down', child: Text('Move down',
                  style: TextStyle(color: _blue))),
              PopupMenuItem(value: 'delete', child: Text('Delete category',
                  style: TextStyle(color: _blue))),
            ],
          ),
      ]),
    );
  }

  Widget _builtInCard(BuildContext context, OfflineGuide g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GuideDetailPage(guide: g))),
        leading: CircleAvatar(
            backgroundColor: g.color, child: Icon(g.icon, color: Colors.white)),
        title: Text.verbatim(g.title.text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontFamily: 'Geist')),
        subtitle: Text.verbatim(g.summary.text),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> r, int index,
      bool canEdit, int total, Future<void> Function(int, int) move) {
    final sub = pickLang((r['subtitle'] as String?) ?? '',
        (r['subtitle_fil'] as String?) ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, GuidelineDetailPage.route(r['id'] as String)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GuidelineIcon(spec: r['icon'] as String?, size: 76),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.verbatim(r['title'] as String,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text(context),
                            fontFamily: 'Geist')),
                    if (sub.isNotEmpty)
                      Text.verbatim(sub,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.body(context),
                              fontFamily: 'Geist')),
                  ],
                ),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (a) async {
                    switch (a) {
                      case 'edit':
                        await editGuidelineEntry(context, row: r, count: total);
                      case 'up':
                        await move(index, -1);
                      case 'down':
                        await move(index, 1);
                      case 'delete':
                        await deleteGuidelineEntry(context, r);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit',
                  style: TextStyle(color: _blue))),
                    PopupMenuItem(value: 'up', child: Text('Move up',
                  style: TextStyle(color: _blue))),
                    PopupMenuItem(value: 'down', child: Text('Move down',
                  style: TextStyle(color: _blue))),
                    PopupMenuItem(value: 'delete', child: Text('Delete',
                  style: TextStyle(color: _blue))),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
