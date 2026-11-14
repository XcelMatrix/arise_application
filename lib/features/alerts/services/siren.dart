import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart' show debugPrint;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

/// The alarm sound for the full-screen emergency warning.
///
/// It is played on Android's ALARM audio stream, not the media or ringer
/// stream, so it still sounds when the phone is on silent or vibrate, and the
/// alarm volume is raised to the maximum while it plays. (Android's
/// "Do Not Disturb: total silence" mode can still block every sound.)
class Siren {
  static final AudioPlayer _player = AudioPlayer();
  static bool _on = false;

  static bool get playing => _on;

  static Future<void> start() async {
    if (_on) return;
    _on = true;
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
    } catch (e) {
      debugPrint('Could not raise the alarm volume: $e');
    }
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/siren.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Siren could not play: $e');
    }
  }

  static Future<void> stop() async {
    if (!_on) return;
    _on = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
