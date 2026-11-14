import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/announcements/cubit/announcements_cubit.dart';
import 'package:arise_application/features/announcements/models/announcement.dart';

const _blue = Color(0xFF3C6E87);

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Dialog to write (or edit) an announcement.
Future<void> showAnnouncementEditor(BuildContext context,
    {Announcement? existing}) async {
  final cubit = context.read<AnnouncementsCubit>();
  final title = TextEditingController(text: existing?.title ?? '');
  final body = TextEditingController(text: existing?.body ?? '');
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'New announcement' : 'Edit announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr(ctx, 'Title')),
            ),
            TextField(
              controller: body,
              maxLines: 5,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr(ctx, 'Message')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: Text(existing == null ? 'Post' : 'Save'),
        ),
      ],
    ),
  );
  final t = title.text.trim();
  final b = body.text.trim();
  title.dispose();
  body.dispose();
  if (ok != true) return;
  try {
    if (existing == null) {
      await cubit.post(t, b);
    } else {
      await cubit.update(existing.id, t, b);
    }
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
        SnackBar(content: Text.verbatim('${tr(context, 'Could not save')}: $e')));
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.item});
  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final account = context.watch<AccountCubit>().state;
    final canManage = account.canAccess(Feature.announce) &&
        (item.authorId == me || account.rank >= 3);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.soft(context),
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: _blue, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.verbatim(item.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _blue,
                        fontFamily: 'Geist')),
                const SizedBox(height: 4),
                Text.verbatim(item.body,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.body(context),
                        fontFamily: 'Geist')),
                const SizedBox(height: 6),
                Text.verbatim(
                  '${item.authorName.isEmpty ? '' : '${item.authorName} · '}${timeago.format(item.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey, fontFamily: 'Geist'),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              onSelected: (v) async {
                final cubit = context.read<AnnouncementsCubit>();
                if (v == 'edit') {
                  showAnnouncementEditor(context, existing: item);
                } else {
                  final sure = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete announcement?'),
                      content: const Text('This removes it for everyone.'),
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
                  if (sure != true) return;
                  try {
                    await cubit.delete(item.id);
                  } catch (e) {
                    if (context.mounted) {
                      _toast(context, '$e');
                    }
                  }
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
