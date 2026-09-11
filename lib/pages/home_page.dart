import 'package:flutter/material.dart';
import 'package:arise_application/pages/profile_page.dart';
import 'package:arise_application/pages/evacuation_map_page.dart';
import 'package:arise_application/pages/attendance_page.dart';
import 'package:arise_application/pages/messaging_page.dart';
import 'package:arise_application/pages/timed_console_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
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
        title: const Text("Home"),
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
            const SizedBox(height: 36),

            // go to evacuation maps
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => const EvacuationMapPage()
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BAEC1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 55,
                        color: Color(0xFF3C6E87),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text(
                        "Evacuation Map",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C6E87),
                          fontFamily: 'Geist'
                        )
                      )
                    )
                  ]
                ),
              )
            ),

            const SizedBox(height: 24),

            // go to attendance report
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => const AttendancePage()
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BAEC1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in,
                        size: 55,
                        color: Color(0xFF3C6E87),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text(
                        "Attendance Report",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C6E87),
                          fontFamily: 'Geist'
                        )
                      )
                    )
                  ]
                ),
              )
            ),

            const SizedBox(height: 24),

            // go to messaging
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => const MessagingPage()
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BAEC1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 55,
                        color: Color(0xFF3C6E87),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text(
                        "Chat Messages",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C6E87),
                          fontFamily: 'Geist'
                        )
                      )
                    )
                  ]
                ),
              )
            ),

            const SizedBox(height: 24),

            // go to timed console
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (context) => const TimedConsolePage()
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F2F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8BAEC1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.terminal,
                        size: 55,
                        color: Color(0xFF3C6E87),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Text(
                        "Timed Console",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3C6E87),
                          fontFamily: 'Geist'
                        )
                      )
                    )
                  ]
                ),
              )
            ),
          ],
        )
      ),
    );
  }
}