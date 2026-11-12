import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/translations/translated_text.dart';

/// Splash screen when the app opens: blue screen, white flashing logo.
/// Shows [child] (the login / home gate) after a moment.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const _blue = Color(0xFF3C6E87);
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _done
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : const Scaffold(
              key: ValueKey('splash'),
              backgroundColor: _blue,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FlashingLogo(size: 110, color: Colors.white),
                    SizedBox(height: 18),
                    Text('ARISE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            letterSpacing: 6,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Geist')),
                  ],
                ),
              ),
            ),
    );
  }
}
