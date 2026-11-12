import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/features/announcements/widgets/announcements_section.dart';
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/auth/pages/pending_approval_page.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/home/widgets/home_speed_dial.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const HomePage());
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<AccountCubit>().load();
  }

  /// True if the signed-in account's rank allows this feature.
  /// (The database enforces the same rule with RLS; this is just the UI side.)
  bool _allowed(String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied() {
    final loaded = context.read<AccountCubit>().state.loaded;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loaded
          ? "Your account level doesn't have access to this."
          : "Checking your account, try again in a moment."),
    ));
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        break;
      case 1:
        if (!_allowed(Feature.attendance)) return _denied();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
        break;
      case 2:
        if (!_allowed(Feature.timedConsole)) return _denied();
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
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, account) {
        // wait until we know the account's role / approval status
        if (!account.loaded) {
          return const Scaffold(
            body: FlashingLogo(),
          );
        }
        // teacher accounts stay locked until approved
        if (account.isTeacherPending) {
          return PendingApprovalPage(
            rejected: account.teacherRequestStatus == 'rejected',
          );
        }

        final canAttendance = account.canAccess(Feature.attendance);
        final canConsole = account.canAccess(Feature.timedConsole);
        final canChat = account.canAccess(Feature.chat);
        // student-locked tabs and cards are hidden, not just greyed out
        final visible = <int>[0, if (canAttendance) 1, if (canConsole) 2, 3];

        return Scaffold(
          endDrawer: const AppDrawer(),
          appBar: AppBar(

            // ARISE white logo
            leading: const BackOrLogo(),
            backgroundColor: Color(0xFF3C6E87),

            // Page title
            title: const Text("Home"),
            titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Geist'
            ),
            centerTitle: true,

            // Profile button (shows your picture if you have one)
            actions: <Widget>[
          const ProfileMenuButton()
            ]
          ),
          body: Center(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                const AnnouncementsSection(),
                const SizedBox(height: 8),

                // go to evacuation maps
                _buildGoogleClassroomCard(
                  context,
                  title: "Evacuation Map",
                  description: "View emergency routes and safe zones.",
                  imagePath: "assets/images/evacuation_banner.png",
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const DisasterResourcesPage()
                  )),
                ),

                if (canAttendance) ...[
                const SizedBox(height: 26),
                _buildGoogleClassroomCard(
                  context,
                  title: "Attendance Report",
                  description: "Check your daily and historical attendance records.",
                  imagePath: "assets/images/attendance_banner.png",
                  onTap: () {
                    if (!_allowed(Feature.attendance)) return _denied();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const AttendancePage()
                    ));
                  },
                ),
                ],

                if (canConsole) ...[
                const SizedBox(height: 26),
                _buildGoogleClassroomCard(
                  context,
                  title: "Console",
                  description: "Access programmed terminal sessions and tools.",
                  imagePath: "assets/images/console_banner.png",
                  onTap: () {
                    if (!_allowed(Feature.timedConsole)) return _denied();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const TimedConsolePage()
                    ));
                  },
                ),
                ],
                const SizedBox(height: 20),
              ],
            )
          ),

          // one three-dots button: Chat, Announcements and the Emergency
          // alert (teachers and admins) pop up from it
          floatingActionButton: HomeSpeedDial(
            canChat: canChat,
            canAlert: account.canAccess(Feature.emergencyAlert),
            canAdmin: account.rank >= 3,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: visible.indexOf(_currentIndex),
            onTap: (i) => _onItemTapped(visible[i]),
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
            ]
                .asMap()
                .entries
                .where((e) => visible.contains(e.key))
                .map((e) => e.value)
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildGoogleClassroomCard(
    BuildContext context, {
    required String title,
    required String description,
    required String imagePath,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF3C6E87));
              },
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xAA000000)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (locked)
              Container(
                color: const Color(0x99000000),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.lock, color: Colors.white, size: 24),
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Geist',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFE0E0E0),
                      fontFamily: 'Geist',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
