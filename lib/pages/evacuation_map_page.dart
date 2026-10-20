import 'package:flutter/material.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:arise_application/pages/profile_page.dart';
import 'package:gameframework/gameframework.dart';

class EvacuationMapPage extends StatefulWidget {
  const EvacuationMapPage({super.key});

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState();
}

class _EvacuationMapPageState extends State<EvacuationMapPage> {
  GameEngineController? _controller;
  bool _isARReady = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isARReady = true;
        });
      }
    });
  }

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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          ),
        ),
        backgroundColor: const Color(0xFF3C6E87),
        title: const Text("AR Evacuation Plans"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist',
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.person),
            iconSize: 36,
            color: const Color(0xFFACACAC),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFD9D9D9),
              fixedSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
          ),
        ],
      ),
      body: _isARReady
          ? Stack(
              children: [
                // Game Framework Widget using the AR messaging snippet
                GameWidget(
                  engineType: GameEngineType.unity,
                  onEngineCreated: (controller) {
                    _controller = controller;
                    debugPrint("Game Framework Engine created successfully!");
                    
                    // Triggers the StartAR method on the 'ARManager' script in Unity
                    controller.sendMessage('ARManager', 'StartAR', '');
                  },
                  onMessage: (message) {
                    debugPrint('Message from engine: ${message.method} - ${message.data}');
                  },
                  config: const GameEngineConfig(
                    fullscreen: false,
                    runImmediately: true,
                    unloadOnDispose: true,
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Game Framework AR active. Point your camera at the floor.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3C6E87),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}