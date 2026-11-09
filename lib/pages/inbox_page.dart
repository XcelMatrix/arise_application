import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart';
import 'package:arise_application/cubits/inbox/inbox_cubit.dart';
import 'package:arise_application/models/attendance_models.dart';
import 'package:arise_application/pages/rooms_page.dart';
import 'package:arise_application/pages/timed_console_page.dart';

/// Notifications: chat messages and Timed Console reports.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const InboxPage());
  }

  Color _levelColor(ConsoleLevel level) {
    switch (level) {
      case ConsoleLevel.success:
        return const Color(0xFF2E7D32);
      case ConsoleLevel.warning:
        return const Color(0xFFE65100);
      case ConsoleLevel.alert:
        return const Color(0xFFB3261E);
      default:
        return _blue;
    }
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
      body: BlocBuilder<InboxCubit, InboxState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  "No notifications yet.\nNew chat messages and Timed Console reports will show up here.",
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
              final isChat = item.kind == InboxKind.chat;
              return ListTile(
                tileColor: item.read ? null : const Color(0xFFE4F2F9),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isChat ? _blue : _levelColor(item.level),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isChat ? Icons.forum : Icons.terminal,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.normal : FontWeight.bold,
                    fontFamily: 'Geist',
                  ),
                ),
                subtitle: Text(
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
                  Navigator.push(
                    context,
                    isChat
                        ? RoomsPage.route()
                        : MaterialPageRoute(
                            builder: (context) => const TimedConsolePage()),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
