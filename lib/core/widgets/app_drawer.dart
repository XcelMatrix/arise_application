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
          const SizedBox(height: 8),

          // inbox (mail icon, unread count)
          BlocBuilder<InboxCubit, InboxState>(
            builder: (context, inbox) => _item(
              context,
              icon: Icons.mail_outline,
              label: 'Inbox',
              trailing:
                  inbox.unread > 0 ? Badge(label: Text.verbatim('${inbox.unread}')) : null,
              onTap: () => _open(context, InboxPage.route()),
            ),
          ),
          _item(
            context,
            icon: Icons.calendar_month,
            label: 'Calendar',
            onTap: () => _open(context, CalendarPage.route()),
          ),
          _item(
            context,
            icon: Icons.settings,
            label: 'Settings',
            onTap: () => _open(context, SettingsPage.route()),
          ),
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

          const Spacer(),
          const Divider(height: 1),
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
