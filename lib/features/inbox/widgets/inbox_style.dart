import 'package:flutter/material.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart';

/// Icon + colour for each kind of notification (bell preview + Inbox page).
IconData inboxIcon(InboxItem item) {
  switch (item.kind) {
    case InboxKind.chat:
      return Icons.forum;
    case InboxKind.console:
      return Icons.terminal;
    case InboxKind.announcement:
      return Icons.campaign;
    case InboxKind.request:
      return Icons.how_to_reg;
  }
}

Color inboxColor(InboxItem item) {
  switch (item.kind) {
    case InboxKind.chat:
    case InboxKind.request:
      return const Color(0xFF3C6E87);
    case InboxKind.announcement:
      return const Color(0xFFE65100);
    case InboxKind.console:
      switch (item.level) {
        case ConsoleLevel.success:
          return const Color(0xFF2E7D32);
        case ConsoleLevel.warning:
          return const Color(0xFFE65100);
        case ConsoleLevel.alert:
          return const Color(0xFFB3261E);
        default:
          return const Color(0xFF3C6E87);
      }
  }
}

/// Chat messages and announcements are people's own words: never translate.
bool inboxIsVerbatim(InboxItem item) =>
    item.kind == InboxKind.chat || item.kind == InboxKind.announcement;
