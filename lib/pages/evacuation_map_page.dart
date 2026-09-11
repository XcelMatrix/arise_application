import 'package:flutter/material.dart';

class EvacuationMapPage extends StatefulWidget {
  const EvacuationMapPage({super.key});

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState ();
}

class _EvacuationMapPageState extends State<EvacuationMapPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Evacuation Map"),
      ),
      body: const Center(
        child: Text("This is the Evacuation Map Page"),
      ),
    );
  }
}