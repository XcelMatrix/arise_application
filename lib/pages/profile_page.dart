import 'package:flutter/material.dart';
import 'package:arise_application/auth_servers/auth_service.dart';
import 'package:arise_application/pages/home_page.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // get auth service
  final authService = AuthService();

  // logout button pressed
  void logout() async {
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    // get user email
    final currentEmail = authService.getCurrentUserEmail();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset(
            "assets/icons/icon_white.png",
            width: 48,
            height: 48,
          ),
          color: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const HomePage()
          )),
        ),
        backgroundColor: Color(0xFF3C6E87),
        title: const Text("Profile"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist'
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person),
            iconSize: 36,
            color: const Color(0xFFACACAC),
            style: IconButton.styleFrom(
              backgroundColor: Color(0xFFD9D9D9),
              fixedSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const ProfilePage()
            )),
          )
        ]
      ),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          children: [

            // profile + email address
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 84,
                      color: Color(0xFFACACAC),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      currentEmail.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3C6E87),
                        fontFamily: 'Geist'
                      )
                    )
                  )
                ]
              ),
            ),

            const SizedBox(height: 24),

            // logout button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4F2F9),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: logout,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.logout,
                    color: Color(0xFF3C6E87),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Log out",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3C6E87),
                      fontFamily: 'Geist',
                    ),
                  ),
                ],
              ),
            ),
          ]
        ),
      )
    );
  }
}