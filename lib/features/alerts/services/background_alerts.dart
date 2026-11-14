import 'dart:typed_data';
import 'package:flutter/widgets.dart' show debugPrint;
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/translations/translation.dart';

/// Emergency alerts while the app is closed, without Firebase.
///
/// Android keeps a small "standby" foreground service running (you see a quiet
/// notification). Every 15 seconds it asks the database for the active alert
/// ([public_active_alert] in 15_class_checkin_backup.sql) and, when there is a
/// new one, shows a loud notification in the language picked in Settings.
/// It runs in its own isolate, so it works after the app is swiped away and
/// after the phone restarts.
class AlertBackground {
  static const _sessionKey = 'arise_bg_session'; // signed in
  static const _urlKey = 'url';
  static const _anonKey = 'key';

  static String _url = '';
  static String _key = '';

  /// Call once in main() before runApp.
  static void init({required String url, required String key}) {
    _url = url;
    _key = key;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'arise_standby',
        channelName: 'ARISE standby',
        channelDescription: 'Keeps ARISE ready to warn you about emergencies.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the service after login, stop it after logout.
  static Future<void> sync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // always on while signed in; there is no switch for it
      final on = Supabase.instance.client.auth.currentSession != null;
      await prefs.setBool(_sessionKey, on);

      final running = await FlutterForegroundTask.isRunningService;
      if (!on) {
        if (running) await FlutterForegroundTask.stopService();
        return;
      }

      var perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        perm = await FlutterForegroundTask.requestNotificationPermission();
      }
      if (perm != NotificationPermission.granted) return;

      // ask Android once not to stop the service to save battery
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations &&
          !(prefs.getBool('arise_battery_asked') ?? false)) {
        await prefs.setBool('arise_battery_asked', true);
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      await FlutterForegroundTask.saveData(key: _urlKey, value: _url);
      await FlutterForegroundTask.saveData(key: _anonKey, value: _key);
      if (!running) {
        await FlutterForegroundTask.startService(
          serviceId: 4201,
          serviceTypes: [ForegroundServiceTypes.specialUse],
          notificationTitle: 'ARISE is on standby',
          notificationText: 'Ready to warn you about emergencies.',
          callback: ariseAlertServiceStart,
        );
      }
      await setAppForeground(true);
    } catch (e) {
      debugPrint('Background alerts could not start: $e');
    }
  }

  /// Tell the service whether the app is on screen (then the app shows the
  /// alert itself and the service stays quiet).
  static Future<void> setAppForeground(bool open) async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask({'fg': open});
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void ariseAlertServiceStart() {
  FlutterForegroundTask.setTaskHandler(_AlertTaskHandler());
}

/// Runs inside the foreground service (a separate isolate).
class _AlertTaskHandler extends TaskHandler {
  static const _notifId = 4242;
  // the siren file is android/app/src/main/res/raw/arise_siren.wav (see README)
  static const _siren = RawResourceAndroidNotificationSound('arise_siren');
  static const _channel = AndroidNotificationChannel(
    'arise_alerts_v2', // new id: Android keeps a channel's sound once created
    'Emergency alerts',
    description: 'Fire, earthquake, lockdown and other emergency alerts.',
    importance: Importance.max,
    playSound: true,
    sound: _siren,
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  final _notifications = FlutterLocalNotificationsPlugin();
  SupabaseClient? _sb;
  bool _appOpen = false;
  String? _lastSeen;
  String _lastRemind = '';
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _check();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _check();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sb?.dispose();
    _sb = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['fg'] is bool) _appOpen = data['fg'] as bool;
  }

  Future<SupabaseClient?> _client() async {
    if (_sb != null) return _sb;
    final url = await FlutterForegroundTask.getData<String>(key: 'url');
    final key = await FlutterForegroundTask.getData<String>(key: 'key');
    if (url == null || key == null || url.isEmpty) return null;
    return _sb = SupabaseClient(url, key);
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // pick up what the app saved
      if (prefs.getBool('arise_bg_session') != true) return;

      final sb = await _client();
      if (sb == null) return;
      final rows = await sb.rpc('public_active_alert');
      if (rows is! List || rows.isEmpty) {
        if (_lastSeen != null) {
          await _notifications.cancel(id: _notifId); // all clear
          _lastSeen = null;
        }
        return;
      }
      final a = Map<String, dynamic>.from(rows.first as Map);
      final id = '${a['id']}';
      final remind = '${a['reminded_at'] ?? ''}';
      final isNew = id != _lastSeen;
      final isReminder = !isNew && remind.isNotEmpty && remind != _lastRemind;
      if (!isNew && !isReminder) return;
      _lastRemind = remind;

      // answered "I'm safe" / "I need help" on this phone: no reminder needed
      final answered = prefs.getString('arise_checkin_alert') == id;
      if (isReminder && (answered || _appOpen)) return;
      // new alert: skip if the app is open or the person already saw it
      if (isNew && (_appOpen || prefs.getString('arise_alert_dismissed') == id)) {
        _lastSeen = id;
        return;
      }

      // wording in the language chosen in Settings
      Tr.current = Tr.byCode(prefs.getString('arise_lang_code'));
      final translations = a['translations'];
      String? written;
      if (translations is Map) {
        written = translations[Tr.current.code]?.toString();
      }
      final standard = (written != null && written.trim().isNotEmpty)
          ? written
          : Tr.t('${a['message']}');
      final details = '${a['details'] ?? ''}'.trim();
      final message = details.isEmpty ? standard : '$standard\n$details';

      // raise the alarm volume so the siren is heard on a quiet phone
      try {
        await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
      } catch (_) {}

      await _notifications.show(
        id: _notifId,
        title: '${isReminder ? '${Tr.t('REMINDER')} · ' : ''}${Tr.t('EMERGENCY ALERT')}: ${Tr.t('${a['kind']}')}',
        body: message,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            visibility: NotificationVisibility.public,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            sound: _siren,
            // keep sounding until the person opens or dismisses it
            additionalFlags: Int32List.fromList(<int>[4]),
            vibrationPattern: Int64List.fromList([0, 600, 300, 600, 300, 600]),
            styleInformation: BigTextStyleInformation(message),
            ongoing: false,
          ),
        ),
      );
      _lastSeen = id;
    } catch (e) {
      debugPrint('Alert check failed (will retry): $e');
    } finally {
      _busy = false;
    }
  }
}
