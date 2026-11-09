import 'package:flutter/material.dart';
import 'package:arise_application/pages/home_page.dart';

/// "How to use ARISE" – shown after logging in, and from About in the side menu.
class GuidePage extends StatelessWidget {
  const GuidePage({super.key, this.firstRun = false});

  /// True when shown as the welcome screen (shows a Get started button).
  final bool firstRun;

  static Route<void> route({bool firstRun = false}) {
    return MaterialPageRoute(builder: (context) => GuidePage(firstRun: firstRun));
  }

  /// Leave the guide: after logging in this goes to Home, otherwise back.
  void _leave(BuildContext context) {
    if (firstRun) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset("assets/icons/icon_white.png",
              width: 48, height: 48),
        ),
        backgroundColor: _blue,
        title: Text(firstRun ? "Welcome" : "How to use ARISE"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _leave(context),
            child: Text(
              firstRun ? "Skip" : "Close",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Geist'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: const [
                  _Intro(),
                  SizedBox(height: 16),
                  _Section(
                    icon: Icons.navigation,
                    title: "Getting around",
                    lines: [
                      "Use the bar at the bottom to switch between Home, Attendance, Console and Map.",
                      "Tap the ARISE logo at the top of a page to go back Home.",
                      "Tap the person icon to open your profile, change your display name or picture, or log out.",
                    ],
                  ),
                  _Section(
                    icon: Icons.view_in_ar,
                    title: "Evacuation Map controls",
                    lines: [
                      "Drag to move the map.",
                      "Pinch to zoom in and out.",
                      "Twist with two fingers to rotate.",
                      "Show / Hide Model places or removes the map in your room.",
                      "Reset puts the map back where it started.",
                      "If AR can't start on your device, a map image is shown instead. Use View map image to switch yourself, or Try AR to switch back.",
                    ],
                  ),
                  _Section(
                    icon: Icons.assignment_turned_in,
                    title: "Taking attendance (teachers)",
                    lines: [
                      "Tap Add Attendance and fill in the date and time, grade, section, evacuation site and type of emergency.",
                      "Open the report and add your students. Their grade and section are filled in for you.",
                      "Set each student to Present, Absent, Missing or Injured.",
                      "When everyone is marked, tap Send to deliver the report to the Timed Console.",
                      "Use the menu in the corner to mark everyone present, edit the details or delete the report.",
                    ],
                  ),
                  _Section(
                    icon: Icons.terminal,
                    title: "Timed Console (teachers)",
                    lines: [
                      "Reports from every section appear here as they are sent.",
                      "Tap Start to begin a drill. The clock runs until every report has been sent.",
                      "When all sections are in, the console shows how long the evacuation took.",
                      "Tap Cancel to stop a drill that was started by mistake.",
                    ],
                  ),
                  _Section(
                    icon: Icons.forum,
                    title: "Chat (teachers)",
                    lines: [
                      "Tap the chat button on Home to open a room and message other teachers.",
                    ],
                  ),
                  _Section(
                    icon: Icons.verified_user,
                    title: "Accounts",
                    lines: [
                      "Students can use the disaster resources and the evacuation map.",
                      "Attendance, Timed Console and Chat are for teachers and admins.",
                      "Teacher accounts must be approved before they unlock. You'll see a waiting screen until then.",
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _leave(context),
                  child: Text(
                    firstRun ? "Continue to Home" : "Close",
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontFamily: 'Geist'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          "ARISE",
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C6E87),
              fontFamily: 'Geist'),
        ),
        SizedBox(height: 6),
        Text(
          "Your guide to disaster preparedness: evacuation map, emergency contacts, guidelines, and drill attendance.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, color: Color(0xFF2C4C5E), fontFamily: 'Geist'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon, required this.title, required this.lines});

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C6E87),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C4C5E),
                      fontFamily: 'Geist'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ",
                      style: TextStyle(color: Color(0xFF3C6E87))),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C4C5E),
                          fontFamily: 'Geist'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
