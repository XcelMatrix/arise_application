import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/attendance/pages/attendance_page.dart';
import 'package:arise_application/features/console/pages/timed_console_page.dart';
import 'package:arise_application/features/resources/pages/disaster_resources_page.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:ar_flutter_plugin_plus/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:arise_application/features/home/pages/home_page.dart';
import 'package:arise_application/features/resources/pages/evacuation_maps_page.dart';
import 'package:arise_application/features/resources/services/map_files.dart';
import 'package:arise_application/core/data/content_cubits.dart';
import 'package:arise_application/core/data/rows_cubit.dart';
import 'package:arise_application/features/resources/widgets/map_marker_kinds.dart';

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

  // ---- what is shown: a building, and one floor (map) of it per mode ----
  String? _buildingId;
  String? _modelFloorId;
  String? _imageFloorId;
  Map<String, dynamic>? _modelRow;
  Map<String, dynamic>? _imageRow;
  String? _modelFileName; // saved copy of the 3D model (null = not downloaded)
  File? _imageFile;

  // ---- adding a marker ----
  String? _placeKind; // set while waiting for the tap that places it
  String _placeLabel = '';
  final Map<String, ARNode> _markerNodes = {};
  double _markerSize = 1.0; // 3D pin size, adjustable in AR

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

  bool get _canEdit => context.read<AccountCubit>().state.canAccess(Feature.mapEdit);

  List<Map<String, dynamic>> _allMaps() => context.read<MapsCubit>().state.rows;

  /// Buildings that have at least one map.
  List<Map<String, dynamic>> _buildingsWithMaps() {
    final ids = {for (final m in _allMaps()) m['building_id']};
    return context
        .read<BuildingsCubit>()
        .state
        .rows
        .where((b) => ids.contains(b['id']))
        .toList();
  }

  /// The floors (maps) of the chosen building for one mode, oldest first.
  List<Map<String, dynamic>> _floors(String kind) {
    final list = _allMaps()
        .where((r) => r['kind'] == kind && r['building_id'] == _buildingId)
        .toList()
      ..sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));
    return list;
  }

  Map<String, dynamic>? _selectedRow(String kind) {
    final floors = _floors(kind);
    if (floors.isEmpty) return null;
    final id = kind == 'model' ? _modelFloorId : _imageFloorId;
    return floors.firstWhere((r) => r['id'] == id,
        orElse: () => floors.firstWhere((r) => r['is_current'] == true,
            orElse: () => floors.first));
  }

  List<Map<String, dynamic>> _markersOf(Map<String, dynamic>? map,
      {required bool threeD}) {
    if (map == null) return const [];
    return context
        .read<MarkersCubit>()
        .state
        .rows
        .where((m) =>
            m['map_id'] == map['id'] &&
            (threeD ? m['pos_x'] != null : m['x'] != null))
        .toList();
  }

  /// Works out which building / floors to show and gets their files.
  Future<void> _loadSelected() async {
    if (!mounted) return;
    final maps = context.read<MapsCubit>().state;
    if (!maps.loaded) return;
    final withMaps = _buildingsWithMaps();
    if (_buildingId == null || !withMaps.any((b) => b['id'] == _buildingId)) {
      _buildingId = withMaps.isEmpty ? null : withMaps.first['id'] as String;
    }
    final m = _selectedRow('model');
    final i = _selectedRow('image');
    File? img;
    if (i != null) img = await MapFiles.ensure(i);
    String? modelName;
    if (m != null && await MapFiles.ensure(m) != null) {
      modelName = MapFiles.fileName(m);
    }
    if (!mounted) return;
    final modelChanged = _modelRow?['id'] != m?['id'];
    setState(() {
      _imageRow = i;
      _imageFile = img;
      _modelRow = m;
      _modelFileName = modelName;
    });
    if (modelChanged && modelNode != null) await _reloadModel();
    MapFiles.tidy(maps.rows.map(MapFiles.fileName));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSelected());
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
    _markerNodes.clear();
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

  int _currentIndex = 3;

  /// True if the signed-in account's role allows this feature.
  bool _allowed(String feature) =>
      context.read<AccountCubit>().state.canAccess(feature);

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Your account level doesn't have access to this."),
    ));
  }

  /// Bottom-bar positions this account can use (student-locked ones hidden).
  List<int> _visibleNav(BuildContext context, {bool listen = true}) {
    final a = listen
        ? context.watch<AccountCubit>().state
        : context.read<AccountCubit>().state;
    return [
      0,
      if (a.canAccess(Feature.attendance)) 1,
      if (a.canAccess(Feature.timedConsole)) 2,
      3,
    ];
  }

  void _onItemTapped(int index) {

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        break;
      case 1:
        if (!_allowed(Feature.attendance)) return _denied();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
        break;
      case 2:
        if (!_allowed(Feature.timedConsole)) return _denied();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TimedConsolePage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DisasterResourcesPage()),
        );
        break;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // rebuild when maps, buildings or markers change
    context.watch<MapsCubit>();
    context.watch<BuildingsCubit>();
    context.watch<MarkersCubit>();
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        // ARISE white logo
        leading: const BackOrLogo(),
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
          // teachers/admins: upload and choose the maps everyone sees
          if (context.select<AccountCubit, bool>(
              (c) => c.state.canAccess(Feature.mapEdit)))
            IconButton(
              tooltip: tr(context, 'Manage maps'),
              icon: const Icon(Icons.edit_location_alt, color: Colors.white),
              onPressed: () async {
                await Navigator.push(context, EvacuationMapsPage.route());
                _loadSelected(); // pick up whatever was changed
              },
            ),
          const ProfileMenuButton(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _visibleNav(context).indexOf(_currentIndex),
        onTap: (i) => _onItemTapped(_visibleNav(context, listen: false)[i]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF3C6E87),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFFACACAC),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Geist',
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: tr(context, 'Home'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: tr(context, 'Attendance'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.terminal),
            label: tr(context, 'Console'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety),
            label: tr(context, 'Resources'),
          ),
        ]
            .asMap()
            .entries
            .where((e) => _visibleNav(context).contains(e.key))
            .map((e) => e.value)
            .toList(),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MapsCubit, RowsState>(listener: (_, _) => _loadSelected()),
          BlocListener<BuildingsCubit, RowsState>(
              listener: (_, _) => _loadSelected()),
          BlocListener<MarkersCubit, RowsState>(listener: (_, _) {
            if (modelNode != null) _syncMarkers();
          }),
        ],
        child: _arFailed ? _buildFallback() : _buildArView(context),
      ),
    );
  }

  // ---------------- building / floor chooser + markers (shared) ----------------

  Widget _selector({required bool ar}) {
    final buildings = _buildingsWithMaps();
    if (buildings.isEmpty) return const SizedBox.shrink();
    final kind = ar ? 'model' : 'image';
    final floors = _floors(kind);
    final selected = _selectedRow(kind);

    InputDecoration deco(String label) => InputDecoration(
          labelText: tr(context, label),
          isDense: true,
          filled: true,
          fillColor: AppColors.card(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        );

    return Container(
      width: double.infinity,
      color: ar ? Colors.black.withValues(alpha: 0.45) : AppColors.soft(context),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey(_buildingId),
              initialValue: _buildingId,
              isExpanded: true,
              decoration: deco('Building'),
              dropdownColor: AppColors.card(context),
              items: [
                for (final b in buildings)
                  DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text.verbatim(b['name'] as String,
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v == null || v == _buildingId) return;
                setState(() {
                  _buildingId = v;
                  _modelFloorId = null;
                  _imageFloorId = null;
                });
                _loadSelected();
              },
            ),
          ),
          if (floors.length > 1) ...[
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(selected?['id'] as String?),
                initialValue: selected?['id'] as String?,
                isExpanded: true,
                decoration: deco('Floor'),
                dropdownColor: AppColors.card(context),
                items: [
                  for (final f in floors)
                    DropdownMenuItem(
                        value: f['id'] as String,
                        child: Text.verbatim(f['name'] as String,
                            overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    if (ar) {
                      _modelFloorId = v;
                    } else {
                      _imageFloorId = v;
                    }
                  });
                  _loadSelected();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeBanner() {
    final k = MarkerKind.of(_placeKind);
    return Material(
      color: k.color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Icon(k.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _arFailed
                    ? 'Tap the map to place the marker.'
                    : 'Tap a surface in AR to place the marker.',
                style: const TextStyle(color: Colors.white, fontFamily: 'Geist'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _placeKind = null),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPlacing() async {
    final r = await showMarkerDialog(context);
    if (r == null || !mounted) return;
    setState(() {
      _placeKind = r.kind;
      _placeLabel = r.label;
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text.verbatim(tr(context, m))));
  }

  /// 2D: a tap on the image places the marker (x, y are fractions 0..1).
  Future<void> _place2d(double fx, double fy) async {
    final kind = _placeKind;
    final map = _imageRow;
    if (kind == null || map == null) return;
    setState(() => _placeKind = null);
    try {
      await context.read<MarkersCubit>().add({
        'map_id': map['id'],
        'kind': kind,
        'label': _placeLabel.isEmpty ? null : _placeLabel,
        'x': fx.clamp(0.0, 1.0),
        'y': fy.clamp(0.0, 1.0),
      });
    } catch (e) {
      _toast('Could not add the marker: $e');
    }
  }

  /// Tap on an existing marker: details, and edit / delete for editors.
  Future<void> _markerTapped(Map<String, dynamic> m) async {
    final k = MarkerKind.of(m['kind'] as String?);
    final label = (m['label'] as String?) ?? '';
    final cubit = context.read<MarkersCubit>();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(k.icon, color: k.color),
          const SizedBox(width: 10),
          Expanded(child: Text(k.label)),
        ]),
        content: label.isEmpty ? null : Text.verbatim(label),
        actions: [
          if (_canEdit) ...[
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'delete'),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.red))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'edit'),
                child: const Text('Edit')),
          ],
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
    if (!mounted) return;
    try {
      if (action == 'delete') {
        await cubit.remove(m['id'] as String);
      } else if (action == 'edit') {
        final r = await showMarkerDialog(context,
            title: 'Edit marker',
            kind: m['kind'] as String,
            label: label,
            confirm: 'Save');
        if (r == null) return;
        await cubit.edit(m['id'] as String,
            {'kind': r.kind, 'label': r.label.isEmpty ? null : r.label});
      }
    } catch (e) {
      _toast('$e');
    }
  }

  /// Static evacuation map, shown when AR can't load.
  Widget _buildFallback() {
    return Column(
      children: [
        if (_placeKind != null) _placeBanner(),
        _selector(ar: false),
        Container(
          width: double.infinity,
          color: AppColors.soft(context),
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
        Expanded(child: _imageArea()),
      ],
    );
  }

  Widget _imageArea() {
    final anyImage = _allMaps().any((r) => r['kind'] == 'image');
    ImageProvider? provider;
    String? note;
    if (!anyImage) {
      provider = const AssetImage(_fallbackImage); // nothing uploaded: built-in
    } else if (_imageFile != null) {
      provider = FileImage(_imageFile!);
    } else {
      note = _imageRow == null
          ? 'No 2D map for this building yet.'
          : 'This map needs a connection the first time it is opened.';
    }
    if (provider == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(note!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _blue, fontFamily: 'Geist')),
        ),
      );
    }
    final markers = _markersOf(_imageRow, threeD: false);
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: _MarkedImage(
            image: provider,
            markers: markers,
            onMarkerTap: _markerTapped,
            onPlace: _placeKind != null && _imageRow != null ? _place2d : null,
          ),
        ),
        if (_canEdit && _imageRow != null && _placeKind == null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add_marker_2d',
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: _startPlacing,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add marker'),
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

        // while placing a marker the AR view itself must get the tap
        if (_placeKind == null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
            ),
          ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(children: [
            _selector(ar: true),
            if (_placeKind != null) _placeBanner(),
          ]),
        ),

        Align(
          alignment: FractionalOffset.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
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
                if (_canEdit && modelNode != null && _modelRow != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _arButton("Add marker", _placeKind == null ? _startPlacing : null,
                          icon: Icons.add_location_alt),
                      Row(children: [
                        IconButton(
                          tooltip: 'Smaller pins',
                          color: Colors.white,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            _markerSize = (_markerSize / 1.5).clamp(0.05, 200.0);
                            _updateMarkerPoses();
                          },
                        ),
                        const Icon(Icons.location_on, color: Colors.white),
                        IconButton(
                          tooltip: 'Larger pins',
                          color: Colors.white,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            _markerSize = (_markerSize * 1.5).clamp(0.05, 200.0);
                            _updateMarkerPoses();
                          },
                        ),
                      ]),
                    ],
                  ),
                ],
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

    // taps on a detected surface place a marker (only while placing)
    try {
      (arSessionManager as dynamic).onPlaneOrPointTap =
          (List<dynamic> hits) => _onArTap(hits);
    } catch (_) {}

    try {
      this.arSessionManager!.onInitialize(
            showFeaturePoints: false,
            showPlanes: true,
            customPlaneTexturePath: "assets/images/triangle.png",
            showWorldOrigin: true,
            handleTaps: true,
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

  Matrix4 _modelMatrix() {
    final transform = Matrix4.identity();
    transform.setTranslation(_objPosition);
    transform.rotateY(_objRotationY);
    transform.scaleByVector3(Vector3(_objScale, _objScale, _objScale));
    return transform;
  }

  void _applyPose() {
    if (modelNode == null) return;
    modelNode!.transform = _modelMatrix();
    _updateMarkerPoses();
  }

  // ---- 3D markers: pins that sit at fixed spots on the model ----

  double get _pinScale => _objScale * _markerSize;

  /// Moves the pins so they stay on the model when it is moved / scaled.
  void _updateMarkerPoses() {
    if (_markerNodes.isEmpty) return;
    final model = _modelMatrix();
    for (final r in _markersOf(_modelRow, threeD: true)) {
      final node = _markerNodes[r['id']];
      if (node == null) continue;
      final pos = model.transform3(Vector3((r['pos_x'] as num).toDouble(),
          (r['pos_y'] as num).toDouble(), (r['pos_z'] as num).toDouble()));
      final t = Matrix4.identity();
      t.setTranslation(pos);
      t.scaleByVector3(Vector3.all(_pinScale));
      node.transform = t;
    }
  }

  Future<void> _clearMarkerNodes() async {
    final om = arObjectManager;
    final nodes = _markerNodes.values.toList();
    _markerNodes.clear();
    if (om == null) return;
    for (final n in nodes) {
      try {
        await om.removeNode(n);
      } catch (_) {}
    }
  }

  /// Puts a 3D pin (`assets/markers/<kind>.glb`) on every marker of this model.
  Future<void> _syncMarkers() async {
    final om = arObjectManager;
    if (om == null) return;
    await _clearMarkerNodes();
    if (modelNode == null || _modelRow == null) return;
    final model = _modelMatrix();
    for (final r in _markersOf(_modelRow, threeD: true)) {
      final pos = model.transform3(Vector3((r['pos_x'] as num).toDouble(),
          (r['pos_y'] as num).toDouble(), (r['pos_z'] as num).toDouble()));
      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: MarkerKind.of(r['kind'] as String?).asset,
        scale: Vector3.all(_pinScale),
        position: pos,
      );
      try {
        if (await om.addNode(node) ?? false) _markerNodes[r['id'] as String] = node;
      } catch (e) {
        debugPrint('Pin failed: $e');
      }
    }
  }

  /// A tap on a detected surface while placing: save it in model coordinates.
  Future<void> _onArTap(List<dynamic> hits) async {
    final kind = _placeKind;
    final map = _modelRow;
    if (kind == null || map == null || modelNode == null || hits.isEmpty) return;
    try {
      final world = (hits.first.worldTransform as Matrix4).getTranslation();
      final local = Matrix4.inverted(_modelMatrix()).transform3(world.clone());
      setState(() => _placeKind = null);
      await context.read<MarkersCubit>().add({
        'map_id': map['id'],
        'kind': kind,
        'label': _placeLabel.isEmpty ? null : _placeLabel,
        'pos_x': local.x,
        'pos_y': local.y,
        'pos_z': local.z,
      });
    } catch (e) {
      _toast('Could not add the marker: $e');
    }
  }

  Future<void> _reloadModel() async {
    if (arObjectManager == null) return;
    _busy = true;
    try {
      await _removeCurrentNode();
      await _addCurrentModel();
      await _syncMarkers();
    } catch (e) {
      debugPrint('Model reload failed: $e');
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  void _resetPose() {
    _objPosition = _defaultPosition.clone();
    _objScale = _defaultScale;
    _objRotationY = 0.0;
    _applyPose();
  }

  Future<void> _removeCurrentNode() async {
    await _clearMarkerNodes();
    if (modelNode != null) {
      await arObjectManager!.removeNode(modelNode!);
      modelNode = null;
    }
  }

  Future<bool> _tryAddNode(NodeType type, String uri) async {
    final node = ARNode(
      type: type,
      uri: uri,
      scale: Vector3(_objScale, _objScale, _objScale),
      position: _objPosition,
      rotation: Vector4(0.0, 1.0, 0.0, _objRotationY),
    );
    try {
      final ok = await arObjectManager!.addNode(node);
      debugPrint("addNode($uri): $ok");
      if (ok ?? false) {
        modelNode = node;
        return true;
      }
    } catch (e) {
      debugPrint("addNode($uri) failed: $e");
    }
    return false;
  }

  /// The chosen floor's model (saved copy, then online). The built-in
  /// model is only used while nothing at all has been uploaded.
  Future<void> _addCurrentModel() async {
    modelNode = null;
    final row = _modelRow;
    if (row != null) {
      if (_modelFileName != null &&
          await _tryAddNode(NodeType.fileSystemAppFolderGLB, _modelFileName!)) {
        return;
      }
      final url = await MapFiles.signedUrl(row);
      if (url != null && await _tryAddNode(NodeType.webGLB, url)) return;
      _toast("This model couldn't be loaded.");
      return;
    }
    if (!_allMaps().any((r) => r['kind'] == 'model')) {
      await _tryAddNode(NodeType.localGLTF2, _modelAsset); // built-in
    } else {
      _toast('No 3D model for this building yet.');
    }
  }

  Future<void> onModelButtonPressed() async {
    if (_busy || arObjectManager == null) return;
    _busy = true;
    try {
      if (modelNode != null) {
        await _removeCurrentNode();
      } else {
        await _addCurrentModel();
        await _syncMarkers();
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


/// A map image with its 2D markers on top. Markers are stored as fractions of
/// the image, so they stay in the right place at any screen size or zoom.
class _MarkedImage extends StatefulWidget {
  const _MarkedImage({
    required this.image,
    required this.markers,
    required this.onMarkerTap,
    this.onPlace,
  });

  final ImageProvider image;
  final List<Map<String, dynamic>> markers;
  final void Function(Map<String, dynamic>) onMarkerTap;

  /// set while a marker is being placed: called with the tapped fraction
  final void Function(double x, double y)? onPlace;

  @override
  State<_MarkedImage> createState() => _MarkedImageState();
}

class _MarkedImageState extends State<_MarkedImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_MarkedImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener!);
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _size =
          Size(info.image.width.toDouble(), info.image.height.toDouble()));
    });
    _stream = stream..addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return LayoutBuilder(builder: (context, box) {
      final fitted = applyBoxFit(BoxFit.contain, size, box.biggest).destination;
      final w = fitted.width, h = fitted.height;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onPlace == null
                ? null
                : (d) => widget.onPlace!(
                    d.localPosition.dx / w, d.localPosition.dy / h),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                    child: Image(image: widget.image, fit: BoxFit.fill)),
                for (final m in widget.markers)
                  Positioned(
                    left: (m['x'] as num).toDouble() * w - 18,
                    top: (m['y'] as num).toDouble() * h - 18,
                    child: _Pin2d(marker: m, onTap: () => widget.onMarkerTap(m)),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _Pin2d extends StatelessWidget {
  const _Pin2d({required this.marker, required this.onTap});
  final Map<String, dynamic> marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = MarkerKind.of(marker['kind'] as String?);
    final label = (marker['label'] as String?) ?? '';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: k.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 4),
                ],
              ),
              child: Icon(k.icon, color: Colors.white, size: 20),
            ),
            if (label.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text.verbatim(label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.black87,
                        fontFamily: 'Geist')),
              ),
          ],
        ),
      ),
    );
  }
}
