import 'package:flutter/material.dart';

class TimedConsolePage extends StatefulWidget {
  const TimedConsolePage({super.key});

  @override
  State<TimedConsolePage> createState() => _TimedConsolePageState();
}

class _TimedConsolePageState extends State<TimedConsolePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Timed Console"),
      ),
      body: const Center(
        child: Text("This is the Timed Console Page"),
      ),
    );
  }
}