import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';
import 'package:arise_application/features/resources/data/guideline_text.dart';
import 'package:arise_application/features/resources/widgets/guideline_editor.dart';
import 'package:arise_application/translations/translated_text.dart';

const _blue = Color(0xFF3C6E87);

/// One disaster: its description, then the steps with their icons, in English
/// and Filipino. Teachers and admins can edit every part of it.
class GuidelineDetailPage extends StatelessWidget {
  const GuidelineDetailPage({super.key, required this.guidelineId});
  final String guidelineId;

  static Route<void> route(String id) => MaterialPageRoute(
      builder: (context) => GuidelineDetailPage(guidelineId: id));

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
    final canEdit = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.contentEdit));
    final guidelines = context.watch<GuidelinesCubit>().state;
    final itemsCubit = context.watch<GuidelineItemsCubit>();
    final matches =
        guidelines.rows.where((r) => r['id'] == guidelineId).toList();
    final g = matches.isEmpty ? null : matches.first;

    if (g == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          title: const Text('Guidelines'),
        ),
        body: Center(
          child: Text(guidelines.loaded
              ? 'This guideline no longer exists.'
              : 'Loading...'),
        ),
      );
    }

    final items = itemsCubit.of(guidelineId);
    final count = guidelines.rows.length;

    Future<void> move(int index, int delta) async {
      final to = index + delta;
      if (to < 0 || to >= items.length) return;
      final ids = [for (final r in items) r['id'] as String];
      final id = ids.removeAt(index);
      ids.insert(to, id);
      try {
        await itemsCubit.reorder(ids);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text.verbatim('$e')));
        }
      }
    }

    Future<void> onMenu(String action, int index) async {
      final row = items[index];
      switch (action) {
        case 'edit':
          await editGuidelineItem(context,
              guidelineId: guidelineId, row: row);
        case 'up':
          await move(index, -1);
        case 'down':
          await move(index, 1);
        case 'add':
          await editGuidelineItem(context,
              guidelineId: guidelineId, insertIndex: index + 1);
        case 'delete':
          await deleteGuidelineItem(context, row);
      }
    }

    PopupMenuButton<String> menu(int index, {Widget? child}) =>
        PopupMenuButton<String>(
          icon: child == null
              ? const Icon(Icons.more_vert, size: 20, color: Colors.grey)
              : null,
          padding: EdgeInsets.zero,
          onSelected: (a) => onMenu(a, index),
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text('Edit',
                  style: TextStyle(color: _blue))),
            PopupMenuItem(value: 'up', child: Text('Move up',
                  style: TextStyle(color: _blue))),
            PopupMenuItem(value: 'down', child: Text('Move down',
                  style: TextStyle(color: _blue))),
            PopupMenuItem(value: 'add', child: Text('Add a step below',
                  style: TextStyle(color: _blue))),
            PopupMenuItem(value: 'delete', child: Text('Delete',
                  style: TextStyle(color: _blue))),
          ],
          child: child,
        );

    final body = <Widget>[];
    final desc = (g['description'] as String?) ?? '';
    final descFil = (g['description_fil'] as String?) ?? '';
    // the big icon on top, the description centred below it
    body.add(Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Center(child: GuidelineIcon(spec: g['icon'] as String?, size: 120)),
          const SizedBox(height: 12),
          Text.verbatim(g['title'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _blue,
                  fontFamily: 'Geist')),
          if (desc.isNotEmpty || descFil.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Bilingual(en: desc, fil: descFil, center: true),
          ],
        ],
      ),
    ));

    var i = 0;
    while (i < items.length) {
      final r = items[i];
      final kind = r['kind'] as String? ?? 'item';
      if (kind == 'tile') {
        // neighbouring tiles share one row (like DUCK / COVER / HOLD)
        final start = i;
        while (i < items.length && items[i]['kind'] == 'tile') {
          i++;
        }
        body.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (var k = start; k < i; k++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: k == start ? 0 : 8),
                    child: _tile(items[k], canEdit ? (child) => menu(k, child: child) : null),
                  ),
                ),
            ],
          ),
        ));
        continue;
      }
      body.add(_row(context, r, canEdit ? (n) => menu(n) : null, i));
      i++;
    }

    if (items.isEmpty && canEdit) {
      body.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No steps yet. Tap "Add step".',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text.verbatim(g['title'] as String,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Geist')),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: tr(context, 'Edit'),
              icon: const Icon(Icons.edit),
              onPressed: () =>
                  editGuidelineEntry(context, row: g, count: count),
            ),
            IconButton(
              tooltip: tr(context, 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                if (await deleteGuidelineEntry(context, g)) nav.pop();
              },
            ),
          ],
        ],
      ),
      body: !itemsCubit.state.loaded && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, canEdit ? 96 : 24),
              children: body,
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () =>
                  editGuidelineItem(context, guidelineId: guidelineId),
              icon: const Icon(Icons.add),
              label: const Text('Add step'),
            )
          : null,
    );
  }

  Widget _tile(Map<String, dynamic> r, Widget Function(Widget child)? wrap) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: _blue, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GuidelineIcon(spec: r['icon'] as String?, size: 52),
          const SizedBox(height: 6),
          Text.verbatim((r['en'] as String?) ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Geist')),
        ],
      ),
    );
    return wrap == null ? tile : wrap(tile);
  }

  Widget _row(BuildContext context, Map<String, dynamic> r,
      Widget Function(int index)? menu, int index) {
    final kind = r['kind'] as String? ?? 'item';
    final fil = (r['fil'] as String?) ?? '';
    final en = pickLang((r['en'] as String?) ?? '', fil);
    final more = menu == null ? const SizedBox.shrink() : menu(index);

    switch (kind) {
      case 'section':
        return Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.08),
              border: Border.all(color: _blue, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Text.verbatim(_titleCase(en),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _blue,
                        fontFamily: 'Geist')),
              ),
              more,
            ]),
          ),
        );
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Row(children: [
            Expanded(
              child: Text.verbatim(en,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                      fontFamily: 'Geist')),
            ),
            more,
          ]),
        );
      case 'bullet':
        return Padding(
          padding: const EdgeInsets.only(left: 52, top: 2, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 14,
                      color: _blue,
                      fontFamily: 'Geist'),
                  children: [
                    const TextSpan(text: '•  '),
                    TextSpan(
                        text: en,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            more,
          ]),
        );
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Bilingual(en: en, fil: fil, boldEn: false)),
            more,
          ]),
        );
      default: // item
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GuidelineIcon(
                spec: r['icon'] as String?,
                fallback: Icons.circle_outlined,
                size: 48),
            const SizedBox(width: 12),
            Expanded(child: _Bilingual(en: en, fil: fil)),
            more,
          ]),
        );
    }
  }
}

/// One text in the language chosen in Settings (English or Filipino).
class _Bilingual extends StatelessWidget {
  const _Bilingual(
      {required this.en,
      required this.fil,
      this.boldEn = true,
      this.center = false});
  final bool center;
  final String en;
  final String fil;
  final bool boldEn;

  @override
  Widget build(BuildContext context) {
    final text = pickLang(en, fil);
    if (text.isEmpty) return const SizedBox.shrink();
    return Text.verbatim(text,
        textAlign: center ? TextAlign.center : null,
        style: TextStyle(
            fontSize: 15,
            height: 1.3,
            fontWeight: boldEn ? FontWeight.w700 : FontWeight.w500,
            color: _blue,
            fontFamily: 'Geist'));
  }
}


const _smallWords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'nor', 'of', 'in', 'on', 'at', 'to',
  'for', 'by', 'with', 'from', 'as', 'vs',
  // Filipino
  'ng', 'sa', 'ang', 'mga', 'na', 'o', 'ay', 'para', 'ni', 'kay',
};

/// "BEFORE a typhoon and the storm" -> "Before a Typhoon and the Storm"
String _titleCase(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (w.isEmpty || RegExp(r'\d').hasMatch(w)) continue;
    final lower = w.toLowerCase();
    if (i > 0 && _smallWords.contains(lower)) {
      words[i] = lower;
      continue;
    }
    // capitalise the first letter, and the one after - / ( too
    final buf = StringBuffer();
    var up = true;
    for (final ch in lower.split('')) {
      buf.write(up && ch.toLowerCase() != ch.toUpperCase() ? ch.toUpperCase() : ch);
      up = ch == '-' || ch == '/' || ch == '(' ? true : (up && ch.toLowerCase() == ch.toUpperCase());
    }
    words[i] = buf.toString();
  }
  return words.join(' ');
}
