import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/inbox/cubit/inbox_cubit.dart';

/// The profile-picture button in the top bar. Opens the side menu
/// (the page's `endDrawer: const AppDrawer()`).
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, account) {
        return BlocBuilder<InboxCubit, InboxState>(
          builder: (context, inbox) {
            return Builder(
              builder: (context) => Badge(
                isLabelVisible: inbox.unread > 0,
                label: Text.verbatim('${inbox.unread}'),
                offset: const Offset(-4, 4),
                child: IconButton(
                  icon: account.avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            account.avatarUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.person, size: 36),
                          ),
                        )
                      : const Icon(Icons.person),
                  iconSize: 36,
                  color: const Color(0xFFACACAC),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFD9D9D9),
                    fixedSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  tooltip: tr(context, 'Menu'),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
