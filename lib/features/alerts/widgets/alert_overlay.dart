import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';

/// Full-screen emergency warning drawn over everything in the app.
/// It flashes and vibrates until the person taps "I understand".
class AlertOverlay extends StatelessWidget {
  const AlertOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertCubit, AlertState>(
      builder: (context, s) {
        return Stack(
          children: [
            child,
            if (s.showing) Positioned.fill(child: _Warning(alert: s.active!)),
          ],
        );
      },
    );
  }
}

class _Warning extends StatefulWidget {
  const _Warning({required this.alert});
  final EmergencyAlert alert;

  @override
  State<_Warning> createState() => _WarningState();
}

class _WarningState extends State<_Warning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  Timer? _buzz;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    });
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _flash,
        builder: (context, child) => Container(
          color: Color.lerp(
              const Color(0xFF8E0000), const Color(0xFFD50000), _flash.value),
          child: child,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 110),
                const SizedBox(height: 12),
                const Text('EMERGENCY ALERT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Geist')),
                const SizedBox(height: 8),
                Text(a.kind.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist')),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text.verbatim(a.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Geist')),
                  ),
                ),
                const SizedBox(height: 14),
                if (a.senderName.isNotEmpty)
                  Text.verbatim(a.senderName,
                      style: const TextStyle(
                          color: Colors.white70, fontFamily: 'Geist')),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8E0000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.read<AlertCubit>().dismiss(),
                    child: const Text('I understand',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
