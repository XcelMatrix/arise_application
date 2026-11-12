// One-time helper that moves an existing project to the new folder layout.
//
// 1. Copy the new `lib/` folder from the update over your project's `lib/`.
// 2. From the project folder run:   dart run tool/migrate_structure.dart
//
// It (a) moves files that only exist in the old layout (your own files that
// are not part of the update) to their new place, (b) deletes old copies of
// files the update already replaced, (c) rewrites every
// `package:arise_application/...` import to the new paths and (d) removes
// empty old folders and the old `lib/l10n` folder.
import 'dart:io';

const moves = <String, String>{
  'auth_servers/auth_gate.dart': 'features/auth/pages/auth_gate.dart',
  'auth_servers/auth_service.dart': 'features/auth/services/auth_service.dart',
  'components/access_gate.dart': 'features/account/widgets/access_gate.dart',
  'components/alert_overlay.dart': 'features/alerts/widgets/alert_overlay.dart',
  'components/announcement_widgets.dart': 'features/announcements/widgets/announcement_widgets.dart',
  'components/announcements_section.dart': 'features/announcements/widgets/announcements_section.dart',
  'components/app_drawer.dart': 'core/widgets/app_drawer.dart',
  'components/back_or_logo.dart': 'core/widgets/back_or_logo.dart',
  'components/chat_image.dart': 'features/chat/widgets/chat_image.dart',
  'components/editable_content.dart': 'features/resources/widgets/editable_content.dart',
  'components/flashing_logo.dart': 'core/widgets/flashing_logo.dart',
  'components/home_speed_dial.dart': 'features/home/widgets/home_speed_dial.dart',
  'components/inbox_style.dart': 'features/inbox/widgets/inbox_style.dart',
  'components/map_marker_kinds.dart': 'features/resources/widgets/map_marker_kinds.dart',
  'components/notification_bell.dart': 'features/inbox/widgets/notification_bell.dart',
  'components/pending_teacher_requests.dart': 'features/inbox/widgets/pending_teacher_requests.dart',
  'components/profile_avatar.dart': 'features/account/widgets/profile_avatar.dart',
  'components/profile_menu_button.dart': 'features/account/widgets/profile_menu_button.dart',
  'components/search_button.dart': 'features/search/widgets/search_button.dart',
  'components/splash_gate.dart': 'core/widgets/splash_gate.dart',
  'components/top_banner.dart': 'features/inbox/widgets/top_banner.dart',
  'components/user_avatar.dart': 'features/account/widgets/user_avatar.dart',
  'cubits/account/account_cubit.dart': 'features/account/cubit/account_cubit.dart',
  'cubits/alerts/alert_cubit.dart': 'features/alerts/cubit/alert_cubit.dart',
  'cubits/announcements/announcements_cubit.dart': 'features/announcements/cubit/announcements_cubit.dart',
  'cubits/audit/audit_cubit.dart': 'features/console/cubit/audit_cubit.dart',
  'cubits/calendar/calendar_cubit.dart': 'features/calendar/cubit/calendar_cubit.dart',
  'cubits/chat/chat_cubit.dart': 'features/chat/cubit/chat_cubit.dart',
  'cubits/chat/chat_state.dart': 'features/chat/cubit/chat_state.dart',
  'cubits/connectivity/connectivity_cubit.dart': 'core/connectivity/connectivity_cubit.dart',
  'cubits/drill/drill_cubit.dart': 'features/console/cubit/drill_cubit.dart',
  'cubits/inbox/inbox_cubit.dart': 'features/inbox/cubit/inbox_cubit.dart',
  'cubits/profiles/profiles_cubit.dart': 'features/account/cubit/profiles_cubit.dart',
  'cubits/profiles/profiles_state.dart': 'features/account/cubit/profiles_state.dart',
  'cubits/rooms/rooms_cubit.dart': 'features/chat/cubit/rooms_cubit.dart',
  'cubits/rooms/rooms_state.dart': 'features/chat/cubit/rooms_state.dart',
  'cubits/rows/content_cubits.dart': 'core/data/content_cubits.dart',
  'cubits/rows/rows_cubit.dart': 'core/data/rows_cubit.dart',
  'cubits/settings/settings_cubit.dart': 'features/settings/cubit/settings_cubit.dart',
  'cubits/teacher_requests/teacher_requests_cubit.dart': 'features/inbox/cubit/teacher_requests_cubit.dart',
  'models/announcement.dart': 'features/announcements/models/announcement.dart',
  'models/attendance_models.dart': 'features/attendance/models/attendance_models.dart',
  'models/calendar_event.dart': 'features/calendar/models/calendar_event.dart',
  'models/drill_record.dart': 'features/console/models/drill_record.dart',
  'models/message.dart': 'features/chat/models/message.dart',
  'models/profile.dart': 'features/account/models/profile.dart',
  'models/room.dart': 'features/chat/models/room.dart',
  'pages/about_page.dart': 'features/help/pages/about_page.dart',
  'pages/admin_tools_page.dart': 'features/admin/pages/admin_tools_page.dart',
  'pages/announcements_page.dart': 'features/announcements/pages/announcements_page.dart',
  'pages/attendance_page.dart': 'features/attendance/pages/attendance_page.dart',
  'pages/attendance_report_page.dart': 'features/attendance/pages/attendance_report_page.dart',
  'pages/calendar_page.dart': 'features/calendar/pages/calendar_page.dart',
  'pages/chat_page.dart': 'features/chat/pages/chat_page.dart',
  'pages/class_lists_page.dart': 'features/attendance/pages/class_lists_page.dart',
  'pages/disaster_resources_page.dart': 'features/resources/pages/disaster_resources_page.dart',
  'pages/drill_history_page.dart': 'features/console/pages/drill_history_page.dart',
  'pages/emergency_alert_page.dart': 'features/alerts/pages/emergency_alert_page.dart',
  'pages/guide_page.dart': 'features/help/pages/guide_page.dart',
  'pages/home_page.dart': 'features/home/pages/home_page.dart',
  'pages/inbox_page.dart': 'features/inbox/pages/inbox_page.dart',
  'pages/login_page.dart': 'features/auth/pages/login_page.dart',
  'pages/pending_approval_page.dart': 'features/auth/pages/pending_approval_page.dart',
  'pages/profile_page.dart': 'features/account/pages/profile_page.dart',
  'pages/register_page.dart': 'features/auth/pages/register_page.dart',
  'pages/report_form_dialog.dart': 'features/attendance/widgets/report_form_dialog.dart',
  'pages/reset_password_page.dart': 'features/auth/pages/reset_password_page.dart',
  'pages/resources/disaster_guidelines_page.dart': 'features/resources/pages/disaster_guidelines_page.dart',
  'pages/resources/emergency_contacts_page.dart': 'features/resources/pages/emergency_contacts_page.dart',
  'pages/resources/evacuation_map_page.dart': 'features/resources/pages/evacuation_map_page.dart',
  'pages/resources/evacuation_maps_page.dart': 'features/resources/pages/evacuation_maps_page.dart',
  'pages/role_select_page.dart': 'features/auth/pages/role_select_page.dart',
  'pages/rooms_page.dart': 'features/chat/pages/rooms_page.dart',
  'pages/search_page.dart': 'features/search/pages/search_page.dart',
  'pages/settings_page.dart': 'features/settings/pages/settings_page.dart',
  'pages/timed_console_page.dart': 'features/console/pages/timed_console_page.dart',
  'pages/tour_page.dart': 'features/help/pages/tour_page.dart',
  'services/local_cache.dart': 'core/services/local_cache.dart',
  'services/map_files.dart': 'features/resources/services/map_files.dart',
  'services/reminder_service.dart': 'features/calendar/services/reminder_service.dart',
  'services/report_export.dart': 'features/console/services/report_export.dart',
  'theme/app_colors.dart': 'core/theme/app_colors.dart',
};

/// Whole old folders whose other files should follow (your own extras).
const folderFallback = <String, String>{
  'theme': 'core/theme',
  'models': 'features/shared/models',
};

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run this from the project folder (lib/ not found).');
    exit(1);
  }
  final importMap = <String, String>{...moves};

  // (a) + (b)
  var moved = 0, removed = 0;
  for (final e in moves.entries) {
    final oldF = File('lib/${e.key}');
    final newF = File('lib/${e.value}');
    if (!oldF.existsSync()) continue;
    if (newF.existsSync()) {
      oldF.deleteSync();
      removed++;
    } else {
      newF.parent.createSync(recursive: true);
      oldF.renameSync(newF.path);
      moved++;
    }
  }
  // other files left in a known old folder
  for (final e in folderFallback.entries) {
    final dir = Directory('lib/${e.key}');
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.replaceAll('\\', '/').substring('lib/'.length);
      final to = '${e.value}/${rel.substring(e.key.length + 1)}';
      final target = File('lib/$to');
      target.parent.createSync(recursive: true);
      if (!target.existsSync()) {
        f.renameSync(target.path);
        importMap[rel] = to;
        moved++;
      }
    }
  }
  final l10n = Directory('lib/l10n');
  if (l10n.existsSync()) {
    l10n.deleteSync(recursive: true);
    stdout.writeln('Removed the old lib/l10n folder (replaced by lib/translations).');
  }

  // (c)
  var rewritten = 0;
  final pattern = RegExp(r"'package:arise_application/([^']+)'");
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final text = f.readAsStringSync();
    final out = text.replaceAllMapped(pattern, (m) {
      final to = importMap[m.group(1)];
      return to == null ? m.group(0)! : "'package:arise_application/$to'";
    });
    if (out != text) {
      f.writeAsStringSync(out);
      rewritten++;
    }
  }

  // (d) empty folders, deepest first
  final dirs = lib.listSync(recursive: true).whereType<Directory>().toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final d in dirs) {
    if (d.listSync().isEmpty) d.deleteSync();
  }

  stdout.writeln('Moved $moved file(s), removed $removed old copy(ies), '
      'updated imports in $rewritten file(s).');
  stdout.writeln('Done. Run: flutter pub get && flutter analyze');
}
