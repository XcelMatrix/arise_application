import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/cubits/inbox/inbox_cubit.dart';
import 'package:arise_application/pages/guide_page.dart';
import 'package:arise_application/pages/inbox_page.dart';
import 'package:arise_application/pages/profile_page.dart';

/// Side menu opened from the profile-picture button: Inbox, Profile, About.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const _blue = Color(0xFF3C6E87);

  void _open(BuildContext context, Route<void> route) {
    final nav = Navigator.of(context);
    nav.pop(); // close the menu
    nav.push(route);
  }

  @override
  Widget build(BuildContext context) {
    const itemStyle = TextStyle(
      fontSize: 16,
      color: Color(0xFF2C4C5E),
      fontFamily: 'Geist',
    );

    return Drawer(
      child: Column(
        children: [
          BlocBuilder<AccountCubit, AccountState>(
            builder: (context, account) {
              return Container(
                width: double.infinity,
                color: _blue,
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
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 56,
                                  color: Color(0xFFACACAC)),
                            )
                          : const Icon(Icons.person,
                              size: 56, color: Color(0xFFACACAC)),
                    ),
                    const SizedBox(height: 12),
                    Text(
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
                      Text(
                        '@${account.username}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE4F2F9),
                          fontFamily: 'Geist',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // inbox (with unread count)
          BlocBuilder<InboxCubit, InboxState>(
            builder: (context, inbox) => ListTile(
              title: const Text('Inbox', style: itemStyle),
              trailing: inbox.unread > 0
                  ? Badge(label: Text('${inbox.unread}'))
                  : null,
              onTap: () => _open(context, InboxPage.route()),
            ),
          ),
          ListTile(
            title: const Text('Profile', style: itemStyle),
            onTap: () =>
                _open(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
          ListTile(
            title: const Text('About', style: itemStyle),
            onTap: () => _open(context, GuidePage.route()),
          ),
        ],
      ),
    );
  }
}
