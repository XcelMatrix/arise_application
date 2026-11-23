import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
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

/// Notifications: chat messages and Console reports.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const InboxPage());
  }
}

class _InboxPageState extends State<InboxPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _blue = Color(0xFF3C6E87);

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
        actions: const [ProfileMenuButton()],
      ),
      endDrawer: const AppDrawer(),
      body: Column(
        children: [
          const PendingTeacherRequests(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: _blue, fontFamily: 'Geist'),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, color: _blue),
                      hintText: tr(context, 'Search inbox'),
                      hintStyle: const TextStyle(color: _blue),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _blue)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _blue)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: _blue, width: 2)),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: _blue),
                  onSelected: (v) {
                    final cubit = context.read<InboxCubit>();
                    if (v == 'read') cubit.markAllRead();
                    if (v == 'clear') cubit.clear();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'read',
                        child: Text('Mark all as read',
                            style: TextStyle(color: _blue))),
                    PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear inbox',
                            style: TextStyle(color: _blue))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          final q = _query.toLowerCase();
          final items = q.isEmpty
              ? state.items
              : [
                  for (final it in state.items)
                    if (it.title.toLowerCase().contains(q) ||
                        it.body.toLowerCase().contains(q))
                      it
                ];
          if (state.items.isNotEmpty && items.isEmpty) {
            return Center(
              child: Text(tr(context, 'No matching notifications.'),
                  style:
                      const TextStyle(color: Colors.grey, fontFamily: 'Geist')),
            );
          }
          if (state.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No notifications yet.\nNew chat messages, announcements and Console reports will show up here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontFamily: 'Geist'),
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
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
