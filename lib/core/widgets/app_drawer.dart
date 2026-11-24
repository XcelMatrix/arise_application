import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/auth/services/auth_service.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/help/pages/about_page.dart';
import 'package:arise_application/features/calendar/pages/calendar_page.dart';
import 'package:arise_application/features/help/pages/guide_page.dart';
import 'package:arise_application/features/inbox/pages/inbox_page.dart';
import 'package:arise_application/features/account/pages/profile_page.dart';
import 'package:arise_application/features/settings/pages/settings_page.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/reports/pages/reports_page.dart';
import 'package:arise_application/features/resources/pages/event_log_page.dart';
import 'package:arise_application/features/chat/pages/rooms_page.dart';
import 'package:arise_application/features/alerts/pages/emergency_alert_page.dart';
import 'package:arise_application/features/admin/pages/admin_tools_page.dart';

/// Side menu opened from the profile-picture button.
/// Tap your picture to open your profile.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const _blue = Color(0xFF3C6E87);

  void _open(BuildContext context, Route<void> route) {
    final nav = Navigator.of(context);
    nav.pop(); // close the menu
    nav.push(route);
  }

  Future<void> _logout(BuildContext context) async {
    final nav = Navigator.of(context);
    nav.pop(); // close the menu
    await AuthService().signOut();
    nav.popUntil((route) => route.isFirst);
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: _blue),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: AppColors.text(context),
          fontFamily: 'Geist',
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  /// A rounded box that holds a few related menu items.
  Widget _group(BuildContext context, List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 1.2),
      ),
      child: Column(children: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // header: tap the picture / name to open your profile
          BlocBuilder<AccountCubit, AccountState>(
            builder: (context, account) {
              return Material(
                color: _blue,
                child: InkWell(
                  onTap: () => _open(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                        20, 24 + MediaQuery.of(context).padding.top, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: account.avatarUrl != null
                              ? Image.network(
                                  account.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                      Icons.person,
                                      size: 56,
                                      color: Color(0xFFACACAC)),
                                )
                              : const Icon(Icons.person,
                                  size: 56, color: Color(0xFFACACAC)),
                        ),
                        const SizedBox(height: 12),
                        Text.verbatim(
                          account.shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Geist',
                          ),
                        ),
                        if (account.username != null)
                          Text.verbatim(
                            '@${account.username}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE4F2F9),
                              fontFamily: 'Geist',
                            ),
                          ),
                        const SizedBox(height: 6),
                        const Text(
                          'View profile',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE4F2F9),
                            fontFamily: 'Geist',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: BlocBuilder<AccountCubit, AccountState>(
                      builder: (context, acc) => Column(
                        children: [
                          const SizedBox(height: 12),
                          // top: inbox, messages, settings
                          _group(context, [
                            BlocBuilder<InboxCubit, InboxState>(
                              builder: (context, inbox) => _item(
                                context,
                                icon: Icons.mail_outline,
                                label: 'Inbox',
                                trailing: inbox.unread > 0
                                    ? Badge(
                                        label: Text.verbatim('${inbox.unread}'))
                                    : null,
                                onTap: () =>
                                    _open(context, InboxPage.route()),
                              ),
                            ),
                            if (acc.canAccess(Feature.chat))
                              _item(
                                context,
                                icon: Icons.forum,
                                label: 'Messages',
                                onTap: () =>
                                    _open(context, RoomsPage.route()),
                              ),
                            _item(
                              context,
                              icon: Icons.settings,
                              label: 'Settings',
                              onTap: () =>
                                  _open(context, SettingsPage.route()),
                            ),
                          ]),
                          // middle: emergency alert, calendar, reports
                          _group(context, [
                            if (acc.canAccess(Feature.emergencyAlert))
                              _item(
                                context,
                                icon: Icons.warning_amber_rounded,
                                label: 'Alert',
                                onTap: () => _open(
                                    context, EmergencyAlertPage.route()),
                              ),
                            _item(
                              context,
                              icon: Icons.calendar_month,
                              label: 'Calendar',
                              onTap: () =>
                                  _open(context, CalendarPage.route()),
                            ),
                            if (acc.canAccess(Feature.attendance) ||
                                acc.canAccess(Feature.timedConsole))
                              _item(
                                context,
                                icon: Icons.summarize,
                                label: 'Reports',
                                onTap: () =>
                                    _open(context, ReportsPage.route()),
                              ),
                            if (acc.canAccess(Feature.timedConsole))
                              _item(
                                context,
                                icon: Icons.history,
                                label: 'History',
                                onTap: () =>
                                    _open(context, EventLogPage.route()),
                              ),
                            if (acc.rank >= 3)
                              _item(
                                context,
                                icon: Icons.admin_panel_settings,
                                label: 'Admin tools',
                                onTap: () =>
                                    _open(context, AdminToolsPage.route()),
                              ),
                          ]),
                          const Spacer(),
                          // bottom: about, help
                          _group(context, [
                            _item(
                              context,
                              icon: Icons.info_outline,
                              label: 'About',
                              onTap: () => _open(context, AboutPage.route()),
                            ),
                            _item(
                              context,
                              icon: Icons.help_outline,
                              label: 'Help',
                              onTap: () => _open(context, GuidePage.route()),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Divider(
                height: 2,
                thickness: 2,
                indent: 12,
                endIndent: 12,
                color: _blue),
          ),
          SafeArea(
            top: false,
            child: _item(
              context,
              icon: Icons.logout,
              label: 'Log out',
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}
