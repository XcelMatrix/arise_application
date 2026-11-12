import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/announcements/widgets/announcement_widgets.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/announcements/cubit/announcements_cubit.dart';
import 'package:arise_application/features/announcements/pages/announcements_page.dart';

/// Announcements shown above the Home buttons, with a divider underneath.
class AnnouncementsSection extends StatelessWidget {
  const AnnouncementsSection({super.key});

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    final canPost = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.announce));
    final ann = context.watch<AnnouncementsCubit>().state;
    final shown = ann.items.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.campaign, color: _blue),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Announcements',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _blue,
                      fontFamily: 'Geist')),
            ),
            if (canPost)
              TextButton.icon(
                onPressed: () => showAnnouncementEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Post'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (!ann.loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: FlashingLogo(),
          )
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No announcements yet.',
                style: TextStyle(color: Colors.grey, fontFamily: 'Geist')),
          )
        else
          for (final a in shown) AnnouncementCard(item: a),
        if (ann.items.length > 2)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, AnnouncementsPage.route()),
              child: const Text('See all announcements'),
            ),
          ),
        const Divider(height: 24, thickness: 1),
      ],
    );
  }
}
