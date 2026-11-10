import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';

/// About the app.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const AboutPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _blue,
        title: const Text("About"),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset("assets/icons/icon_white.png"),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              "ARISE",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _blue,
                fontFamily: 'Geist',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              "Your guide to disaster preparedness: evacuation map, emergency contacts, guidelines, and drill attendance.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.text(context),
                fontFamily: 'Geist',
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _Block(
            icon: Icons.info_outline,
            title: "What ARISE does",
            body:
                "ARISE helps your school get ready for disasters and respond to them. Find evacuation routes, read safety guidelines, reach emergency contacts, and run evacuation drills with live attendance.",
          ),
          const _Block(
            icon: Icons.view_in_ar,
            title: "Evacuation Map (AR)",
            body:
                "See the evacuation map in augmented reality, or as a picture if AR is not available on your device.",
          ),
          const _Block(
            icon: Icons.health_and_safety,
            title: "Disaster Resources and Guidelines",
            body:
                "Emergency contacts and what to do before, during and after a disaster.",
          ),
          const _Block(
            icon: Icons.assignment_turned_in,
            title: "Attendance and Timed Console",
            body:
                "Teachers record who is present, absent, missing or injured. Reports appear live in the Timed Console, which times the whole evacuation.",
          ),
          const _Block(
            icon: Icons.forum,
            title: "Chat",
            body: "Teachers and admins can message each other inside the app.",
          ),
          const _Block(
            icon: Icons.verified_user,
            title: "Accounts and roles",
            body:
                "Students, teachers and admins each see what they need. Teacher accounts are approved before they unlock.",
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text(context),
                    fontFamily: 'Geist',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.text(context),
                    fontFamily: 'Geist',
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
