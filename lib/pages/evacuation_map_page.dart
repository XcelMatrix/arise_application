import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:arise_application/pages/home_page.dart';
import 'package:arise_application/pages/profile_page.dart';

class _ModelOption {
  final String label;
  final String asset;

  const _ModelOption({
    required this.label,
    required this.asset,
  });
}

class EvacuationMapPage extends StatefulWidget {
  const EvacuationMapPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const EvacuationMapPage());
  }

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState();
}

class _EvacuationMapPageState extends State<EvacuationMapPage> {
  static const List<_ModelOption> _models = [
    _ModelOption(label: "ACAD2101", asset: "assets/ACAD2101.glb"),
    _ModelOption(label: "Duck", asset: "assets/Duck.glb"),
  ];

  // Starting position
  static final Vector3 _defaultPosition = Vector3(0.0, -0.3, -1.0);

  // Starting scale for every model
  static const double _defaultScale = 0.5;

  // Scale limits for pinch-to-zoom
  static const double _minScale = 0.01;
  static const double _maxScale = 5.0;

  static const double _dragMetresPerPixel = 0.002;

  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;

  int _currentIndex = 0;

  ARNode? modelNode;

  bool _busy = false;

  // Current pose of the model
  Vector3 _objPosition = _defaultPosition.clone();
  double _objScale = _defaultScale;
  double _objRotationY = 0.0;

  double _scaleAtGestureStart = _defaultScale;
  double _lastGestureRotation = 0.0;

  _ModelOption get _currentModel => _models[_currentIndex];

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ARISE white logo
        leading: IconButton(
          icon: Image.asset(
            "assets/icons/icon_white.png",
            width: 48,
            height: 48,
          ),
          color: Colors.white,
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          ),
        ),
        backgroundColor: const Color(0xFF3C6E87),

        // Page title
        title: const Text("Evacuation Map"),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamily: 'Geist',
        ),
        centerTitle: true,

        // Profile button
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
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
            ),
          ),

          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Model: ${_currentModel.label} "
                      "(${_currentIndex + 1}/${_models.length})"
                      "${modelNode == null ? "  •  hidden" : ""}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Drag to move  •  Pinch to zoom  •  Twist to rotate",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: FractionalOffset.bottomCenter,
            child: Container(
              width: double.infinity,
              // Extra bottom padding keeps the buttons clear of the phone's
              // navigation bar / gesture area.
              padding: EdgeInsets.fromLTRB(
                8,
                12,
                8,
                12 + MediaQuery.of(context).viewPadding.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _arButton("Previous", () => _switchModel(-1),
                          icon: Icons.chevron_left),
                      _arButton("Next", () => _switchModel(1),
                          icon: Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _arButton(
                        modelNode == null ? "Show Model" : "Hide Model",
                        onModelButtonPressed,
                      ),
                      _arButton("Reset", _resetPose),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arButton(String label, VoidCallback? onPressed, {IconData? icon}) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3C6E87),
      foregroundColor: Colors.white,
    );
    final text = Text(label, textAlign: TextAlign.center);
    if (icon == null) {
      return ElevatedButton(style: style, onPressed: onPressed, child: text);
    }
    return ElevatedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon),
      label: text,
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          customPlaneTexturePath: "assets/images/triangle.png",
          showWorldOrigin: true,
          handleTaps: false,
        );
    this.arObjectManager!.onInitialize();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleAtGestureStart = _objScale;
    _lastGestureRotation = 0.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (modelNode == null || _busy) return;

    if (details.pointerCount >= 2) {
      _objScale = (_scaleAtGestureStart * details.scale)
          .clamp(_minScale, _maxScale)
          .toDouble();

      _objRotationY += details.rotation - _lastGestureRotation;
      _lastGestureRotation = details.rotation;
    } else {

      _objPosition.x += details.focalPointDelta.dx * _dragMetresPerPixel;
      _objPosition.y -= details.focalPointDelta.dy * _dragMetresPerPixel;
    }

    _applyPose();
  }

  void _applyPose() {
    if (modelNode == null) return;
    final transform = Matrix4.identity();
    transform.setTranslation(_objPosition);
    transform.rotateY(_objRotationY);
    transform.scaleByVector3(Vector3(_objScale, _objScale, _objScale));
    modelNode!.transform = transform;
  }

  void _resetPose() {
    _objPosition = _defaultPosition.clone();
    _objScale = _defaultScale;
    _objRotationY = 0.0;
    _applyPose();
  }

  Future<void> _removeCurrentNode() async {
    if (modelNode != null) {
      await arObjectManager!.removeNode(modelNode!);
      modelNode = null;
    }
  }

  Future<void> _addCurrentModel() async {
    final newNode = ARNode(
      type: NodeType.localGLTF2, // also handles .glb assets
      uri: _currentModel.asset,
      scale: Vector3(_objScale, _objScale, _objScale),
      position: _objPosition,
      rotation: Vector4(0.0, 1.0, 0.0, _objRotationY),
    );
    final ok = await arObjectManager!.addNode(newNode);
    debugPrint("addNode(${_currentModel.asset}): $ok");
    modelNode = (ok ?? false) ? newNode : null;
  }

  Future<void> onModelButtonPressed() async {
    if (_busy || arObjectManager == null) return;
    _busy = true;
    try {
      if (modelNode != null) {
        await _removeCurrentNode();
      } else {
        await _addCurrentModel();
      }
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _switchModel(int step) async {
    if (_busy || arObjectManager == null) return;
    _busy = true;
    try {
      final wasShown = modelNode != null;
      await _removeCurrentNode();

      _currentIndex = (_currentIndex + step) % _models.length;
      if (_currentIndex < 0) _currentIndex += _models.length;

      _objPosition = _defaultPosition.clone();
      _objScale = _defaultScale;
      _objRotationY = 0.0;

      if (wasShown) {
        await _addCurrentModel();
      }
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }
}
