import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';
import 'package:arise_application/components/app_drawer.dart';
import 'package:arise_application/components/profile_menu_button.dart';
import 'package:arise_application/pages/attendance_page.dart';
import 'package:arise_application/pages/timed_console_page.dart';
import 'package:arise_application/pages/disaster_resources_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/components/access_gate.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/components/profile_avatar.dart';
import 'package:arise_application/cubits/profiles/profiles_cubit.dart';
import 'package:arise_application/cubits/rooms/rooms_cubit.dart';
import 'package:arise_application/models/profile.dart';
import 'package:arise_application/pages/chat_page.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:timeago/timeago.dart';

/// Displays the list of chat threads
class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(
      builder: (context) => BlocProvider<RoomCubit>(
        create: (context) => RoomCubit()..initializeRooms(context),
        child: const RoomsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AccessGate(
        feature: Feature.chat,
        child: Builder(builder: _page),
      );

  static const int _currentIndex = 0;

  /// True if the signed-in account's role allows this feature.
  bool _allowed(BuildContext context, String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your account level doesn't have access to this."),
    ));
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        if (!_allowed(context, Feature.attendance)) return _denied(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
        break;
      case 2:
        if (!_allowed(context, Feature.timedConsole)) return _denied(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TimedConsolePage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DisasterResourcesPage()),
        );
        break;
    }
  }

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(

        // ARISE white logo
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/icons/icon_white.png", width: 48, height: 48),
        ),
        backgroundColor: Color(0xFF3C6E87),

        // Page title
        title: const Text("Messages"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist'
        ),
        centerTitle: true,

        // Profile button
        actions: <Widget>[
const ProfileMenuButton()
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => _onItemTapped(context, i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF3C6E87),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFACACAC),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Geist',
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: tr(context, 'Home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: tr(context, 'Attendance'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal),
            label: tr(context, 'Console'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: tr(context, 'Resources'),
          ),
        ],
      ),
      body: BlocBuilder<RoomCubit, RoomState>(
        builder: (context, state) {
          if (state is RoomsLoading) {
            return  Center(child: CircularProgressIndicator(color: Color(0xFF3C6E87)));
          } else if (state is RoomsLoaded) {
            final newUsers = state.newUsers;
            final rooms = state.rooms;
            return BlocBuilder<ProfilesCubit, ProfilesState>(
              builder: (context, state) {
                if (state is ProfilesLoaded) {
                  final profiles = state.profiles;
                  return Column(
                    children: [
                      _NewUsers(newUsers: newUsers),
                      Expanded(
                        child: ListView.builder(
                          itemCount: rooms.length,
                          itemBuilder: (context, index) {
                            final room = rooms[index];
                            final otherUser = profiles[room.otherUserId];

                            return ListTile(
                              onTap: () => Navigator.of(context)
                                  .push(ChatPage.route(room.id)),
                              leading: ProfileAvatar(profile: otherUser),
                              title: otherUser == null
                                  ? const Text('Loading...')
                                  : Text.verbatim(otherUser.shownName),
                              subtitle: room.lastMessage != null
                                  ? Text.verbatim(
                                      room.lastMessage!.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : const Text('Room created'),
                              trailing: Text(format(
                                  room.lastMessage?.createdAt ?? room.createdAt,
                                  locale: 'en_short')),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  return  Center(child: CircularProgressIndicator(color: Color(0xFF3C6E87)));
                }
              },
            );
          } else if (state is RoomsEmpty) {
            final newUsers = state.newUsers;
            return Column(
              children: [
                _NewUsers(newUsers: newUsers),
                const Expanded(
                  child: Center(
                    child: Text('Start a chat by tapping on available users'),
                  ),
                ),
              ],
            );
          } else if (state is RoomsError) {
            return Center(child: Text(state.message));
          }
          throw UnimplementedError();
        },
      ),
    );
  }
}

class _NewUsers extends StatelessWidget {
  const _NewUsers({
    required this.newUsers,
  });

  final List<Profile> newUsers;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: newUsers
            .map<Widget>((user) => InkWell(
                  onTap: () async {
                    final roomCubit = context.read<RoomCubit>();

                    try {

                      final roomId = await roomCubit.createRoom(user.id);

                      if (!context.mounted) return;

                      Navigator.of(context).push(ChatPage.route(roomId));
                    } catch (error) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: Failed creating a new room ($error)")));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          ProfileAvatar(profile: user),
                          const SizedBox(height: 8),
                          Text.verbatim(
                            user.shownName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
