import 'dart:async';
import 'package:flutter/foundation.dart';
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

class EvacuationMapPage extends StatefulWidget {
  const EvacuationMapPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (context) => const EvacuationMapPage());
  }

  @override
  State<EvacuationMapPage> createState() => _EvacuationMapPageState();
}

class _EvacuationMapPageState extends State<EvacuationMapPage> {
  static const _blue = Color(0xFF3C6E87);

  // The one model shown on the map.
  static const String _modelAsset = "assets/ACAD2101.glb";

  /// Shown when AR can't run. Add this image to your project and list it
  /// under `assets:` in pubspec.yaml.
  static const String _fallbackImage = "assets/images/evacuation_map.png";

  /// If AR hasn't started after this long, switch to the image.
  static const Duration _arLoadTimeout = Duration(seconds: 10);

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

  ARNode? modelNode;

  bool _busy = false;

  // ---- AR failsafe state ----
  bool _arFailed = false;
  String _failReason = '';
  bool _arReady = false;
  int _arSessionId = 0; // bump to rebuild the AR view on retry
  Timer? _watchdog;

  // Current pose of the model
  Vector3 _objPosition = _defaultPosition.clone();
  double _objScale = _defaultScale;
  double _objRotationY = 0.0;

  double _scaleAtGestureStart = _defaultScale;
  double _lastGestureRotation = 0.0;

  /// AR only exists on Android / iOS.
  bool get _platformSupportsAr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_platformSupportsAr) {
      _arFailed = true;
      _failReason = "AR isn't supported on this device.";
    } else {
      _startWatchdog();
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    try {
      arSessionManager?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ---------------- failsafe ----------------

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_arLoadTimeout, () {
      if (mounted && !_arReady && !_arFailed) {
        _fallBack("AR took too long to start.");
      }
    });
  }

  /// Drop AR and show the map image instead.
  void _fallBack(String reason) {
    _watchdog?.cancel();
    try {
      arSessionManager?.dispose();
    } catch (_) {}
    arSessionManager = null;
    arObjectManager = null;
    modelNode = null;
    _arReady = false;
    _busy = false;
    if (!mounted) return;
    setState(() {
      _arFailed = true;
      _failReason = reason;
    });
  }

  void _retryAr() {
    if (!_platformSupportsAr) return;
    setState(() {
      _arFailed = false;
      _arReady = false;
      _arSessionId++;
    });
    _startWatchdog();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        backgroundColor: _blue,

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
      body: _arFailed ? _buildFallback() : _buildArView(context),
    );
  }

  /// Static evacuation map, shown when AR can't load.
  Widget _buildFallback() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFE4F2F9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "$_failReason Showing the evacuation map image instead.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: _blue,
                    fontFamily: 'Geist',
                  ),
                ),
              ),
              if (_platformSupportsAr)
                TextButton(
                  onPressed: _retryAr,
                  child: const Text("Try AR",
                      style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Geist')),
                ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.asset(
                _fallbackImage,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 72, color: _blue),
                      SizedBox(height: 12),
                      Text(
                        "Evacuation map image not found.\n"
                        "Add assets/images/evacuation_map.png",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _blue, fontFamily: 'Geist'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArView(BuildContext context) {
    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey(_arSessionId),
          child: ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Evacuation map"
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    _arButton(
                      modelNode == null ? "Show Model" : "Hide Model",
                      onModelButtonPressed,
                    ),
                    _arButton("Reset", _resetPose),
                  ],
                ),
                const SizedBox(height: 6),
                // manual escape hatch if AR looks wrong but didn't error
                _arButton(
                  "View map image",
                  () => _fallBack("Switched to the map image."),
                  icon: Icons.image_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _arButton(String label, VoidCallback? onPressed, {IconData? icon}) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: _blue,
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

  // ---------------- AR ----------------

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    _watchdog?.cancel();
    _arReady = true;

    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;

    // Native AR errors (ARCore missing/unsupported, session failed, ...).
    // Set dynamically so this still compiles if the plugin changes the type;
    // if the plugin has no onError the watchdog + try/catch still cover us.
    try {
      (arSessionManager as dynamic).onError = (String message) {
        debugPrint("AR session error: $message");
        _fallBack("AR couldn't start on this device.");
      };
    } catch (_) {}

    try {
      this.arSessionManager!.onInitialize(
            showFeaturePoints: false,
            showPlanes: true,
            customPlaneTexturePath: "assets/images/triangle.png",
            showWorldOrigin: true,
            handleTaps: false,
          );
      this.arObjectManager!.onInitialize();
    } catch (e) {
      debugPrint("AR init failed: $e");
      _fallBack("AR couldn't start on this device.");
    }
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
      uri: _modelAsset,
      scale: Vector3(_objScale, _objScale, _objScale),
      position: _objPosition,
      rotation: Vector4(0.0, 1.0, 0.0, _objRotationY),
    );
    final ok = await arObjectManager!.addNode(newNode);
    debugPrint("addNode($_modelAsset): $ok");
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
    } catch (e) {
      debugPrint("Model toggle failed: $e");
      _fallBack("The AR model couldn't be loaded.");
      return;
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }
}
