import 'package:flutter/material.dart';
import 'package:arise_application/pages/evacuation_map_page.dart';
import 'package:arise_application/pages/profile_page.dart';
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
        title: const Text("Home"),
      ),
      body: ListView(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => EvacuationMapPage()
              )),

              child: const Center(child: Text("Evacuation Map Page")),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const ProfilePage()
              )),

              child: const Center(child: Text("Profile Page")),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => const TimedConsolePage()
              )),

              child: const Center(child: Text("Timed Console Page")),
          ),
        ]
      )
    );
  }
}
