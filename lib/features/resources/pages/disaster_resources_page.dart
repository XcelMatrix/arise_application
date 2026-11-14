import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/resources/pages/offline_guides_page.dart';
import 'package:arise_application/features/resources/pages/event_log_page.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/resources/pages/evacuation_map_page.dart';
import 'package:arise_application/features/resources/pages/emergency_contacts_page.dart';
import 'package:arise_application/features/resources/pages/disaster_guidelines_page.dart';

class DisasterResourcesPage extends StatefulWidget {
  const DisasterResourcesPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const DisasterResourcesPage());
  }

  @override
  State<DisasterResourcesPage> createState() => _DisasterResourcesPageState();
}

class _DisasterResourcesPageState extends State<DisasterResourcesPage> {
  final int _currentIndex = 3;

  /// True if the signed-in account's role allows this feature.
  bool _allowed(String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your account level doesn't have access to this."),
    ));
  }

  /// Bottom-bar positions this account can use (student-locked ones hidden).
  List<int> _visibleNav(BuildContext context, {bool listen = true}) {
    final a = listen
        ? context.watch<AccountCubit>().state
        : context.read<AccountCubit>().state;
    return [
      0,
      if (a.canAccess(Feature.attendance)) 1,
      if (a.canAccess(Feature.timedConsole)) 2,
      3,
    ];
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
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
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        // ARISE white logo linking back to Home
        leading: const BackOrLogo(),
        backgroundColor: const Color(0xFF3C6E87),

        // Page title
        title: const Text("Resources"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist',
        ),
        centerTitle: true,

        // Profile button
        actions: <Widget>[
          const ProfileMenuButton()
        ],
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const SizedBox(height: 8),

            // Evacuation Map Button
            _buildResourceCard(
              context,
              title: "Evacuation Map",
              icon: Icons.location_on,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EvacuationMapPage()));
              },
            ),

            const SizedBox(height: 26),

            // Emergency Contacts Button
            _buildResourceCard(
              context,
              title: "Emergency Contacts",
              icon: Icons.phone_rounded,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyContactsPage()));
              },
            ),

            const SizedBox(height: 26),

            // Disaster Guidelines Button
            _buildResourceCard(
              context,
              title: "Disaster Guidelines",
              icon: Icons.menu_book_rounded,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DisasterGuidelinesPage()));
              },
            ),

            const SizedBox(height: 26),

            // Offline emergency guides (built into the app)
            _buildResourceCard(
              context,
              title: "Emergency guides",
              icon: Icons.medical_services,
              onTap: () {
                Navigator.push(context, OfflineGuidesPage.route());
              },
            ),

            const SizedBox(height: 26),

            // Past alerts and drills
            _buildResourceCard(
              context,
              title: "Event log",
              icon: Icons.history,
              onTap: () {
                Navigator.push(context, EventLogPage.route());
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _visibleNav(context).indexOf(_currentIndex),
        onTap: (i) => _onItemTapped(_visibleNav(context, listen: false)[i]),
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
            .where((e) => _visibleNav(context).contains(e.key))
            .map((e) => e.value)
            .toList(),
      ),
    );
  }

  // Card layout matching the style from your screenshot reference
  Widget _buildResourceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.card(context), // Light card background color
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Darker rounded container for the icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF3C6E87),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 46,
              ),
            ),
            const SizedBox(width: 24),
            // Title text
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text(context),
                  fontFamily: 'Geist',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}