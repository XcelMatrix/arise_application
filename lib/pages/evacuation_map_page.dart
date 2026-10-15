import 'package:flutter/material.dart';
import 'package:augen/augen.dart';
import 'package:permission_handler/permission_handler.dart';

class EvacuationMapPage extends StatefulWidget {
  const EvacuationMapPage({super.key});

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState();
}

class _EvacuationMapPageState extends State<EvacuationMapPage> {
  AugenController? _controller;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });

    if (!_hasPermission) {
      // Handle the case when permission is denied
      debugPrint('Camera permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: !_hasPermission
          ? const Center(
              child: Text(
                'Camera permission is required to view the AR content.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
      : Stack(
        children: [
          AugenView(
            onViewCreated: (controller) {
              _controller = controller;
              _initAR();
            },  

            config: ARSessionConfig(
              planeDetection: true,
              lightEstimation: true,
            ),
          ),
            
          Positioned.fill(
            child: GestureDetector(
              onTapUp: _onTap,
              child: Container(color: Colors.transparent),
            ),
          ),
        ]
      )
    );
  }

  Future<void> _initAR() async {
    final supported = await _controller!.isARSupported();
    if (!supported) return;

    await _controller!.initialize(
      ARSessionConfig(planeDetection: true, lightEstimation: true),
    );

    // React to detected planes
    _controller!.planesStream.listen((planes) {
      debugPrint('Detected ${planes.length} planes');
    });
    
  }

  Future<void> _onTap(TapUpDetails details) async {
    final screenX = details.globalPosition.dx;
    final screenY = details.globalPosition.dy;

    final results = await _controller!.hitTest(screenX, screenY);
    if (results.isNotEmpty) {
      await _controller!.addModelFromAsset(
        id: 'ACAD2306',
        assetPath: 'assets/models/ACAD2306.glb',
        position: Vector3(0, 0, -1),
        scale: Vector3(0.1, 0.1, 0.1),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  
}
