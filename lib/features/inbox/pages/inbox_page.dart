import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';
import 'package:arise_application/features/inbox/widgets/inbox_style.dart';
import 'package:arise_application/features/announcements/pages/announcements_page.dart';
import 'package:arise_application/features/inbox/widgets/pending_teacher_requests.dart';
import 'package:arise_application/features/chat/pages/rooms_page.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';

/// Notifications: chat messages and Timed Console reports.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const InboxPage());
  }

  /// where tapping a notification goes
  Route<void>? _targetFor(InboxItem item) {
    switch (item.kind) {
      case InboxKind.chat:
        return RoomsPage.route();
      case InboxKind.announcement:
        return AnnouncementsPage.route();
      case InboxKind.request:
        return null; // approved or declined right here in the Inbox
      case InboxKind.console:
        return MaterialPageRoute(
            builder: (context) => const TimedConsolePage());
    }
  }

  // chat names and messages are shown exactly as written
  Widget _t(bool verbatim, String text,
      {TextStyle? style, int? maxLines, TextOverflow? overflow}) {
    return verbatim
        ? Text.verbatim(text,
            style: style, maxLines: maxLines, overflow: overflow)
        : Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _blue,
        title: const Text("Inbox"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist',
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (v) {
              final cubit = context.read<InboxCubit>();
              if (v == 'read') cubit.markAllRead();
              if (v == 'clear') cubit.clear();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'read', child: Text('Mark all as read')),
              PopupMenuItem(value: 'clear', child: Text('Clear inbox')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const PendingTeacherRequests(),
          Expanded(
            child: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No notifications yet.\nNew chat messages, announcements and Timed Console reports will show up here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontFamily: 'Geist'),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = state.items[i];
              final verbatim = inboxIsVerbatim(item);
              return ListTile(
                tileColor: item.read ? null : AppColors.soft(context),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: inboxColor(item),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    inboxIcon(item),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: _t(verbatim,
                  item.title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.normal : FontWeight.bold,
                    fontFamily: 'Geist',
                  ),
                ),
                subtitle: _t(verbatim,
                  item.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Geist'),
                ),
                trailing: Text(
                  format(item.time, locale: 'en_short'),
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey, fontFamily: 'Geist'),
                ),
                onTap: () {
                  context.read<InboxCubit>().markRead(item.id);
                  final target = _targetFor(item);
                  if (target != null) Navigator.push(context, target);
                },
              );
            },
          );
        },
      )),
        ],
      ),
    );
  }
}
