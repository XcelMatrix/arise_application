import 'package:flutter/material.dart';
import 'package:arise_application/components/app_drawer.dart';
import 'package:arise_application/components/profile_menu_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:arise_application/pages/attendance_page.dart';
import 'package:arise_application/pages/timed_console_page.dart';
import 'package:arise_application/pages/resources/evacuation_map_page.dart';
import 'package:arise_application/pages/resources/emergency_contacts_page.dart';
import 'package:arise_application/pages/resources/disaster_guidelines_page.dart';

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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/icons/icon_white.png", width: 48, height: 48),
        ),
        backgroundColor: const Color(0xFF3C6E87),

        // Page title
        title: const Text("Disaster Resources"),
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

            const SizedBox(height: 16),

            // Emergency Contacts Button
            _buildResourceCard(
              context,
              title: "Emergency Contacts",
              icon: Icons.phone_rounded,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyContactsPage()));
              },
            ),

            const SizedBox(height: 16),

            // Disaster Guidelines Button
            _buildResourceCard(
              context,
              title: "Disaster Guidelines",
              icon: Icons.menu_book_rounded,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DisasterGuidelinesPage()));
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal),
            label: 'Console',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: 'Resources',
          ),
        ],
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
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5F8), // Light card background color
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF3C6E87),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            // Title text
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C4C5E),
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