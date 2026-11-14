import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/alerts/cubit/checkin_cubit.dart';
import 'package:arise_application/features/alerts/pages/checkin_roster_page.dart';
import 'package:arise_application/features/alerts/pages/headcount_page.dart';
import 'package:arise_application/features/alerts/services/siren.dart';
import 'package:arise_application/main.dart' show navigatorKey;
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
            if (s.showing)
              Positioned.fill(child: _Warning(alert: s.active!))
            else if (s.active != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActiveBar(alert: s.active!),
              ),
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
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    // loud alarm on the alarm stream: works even on silent
    Siren.start();
    _buzz = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  @override
  void dispose() {
    Siren.stop();
    _buzz?.cancel();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LangScope.of(context); // rebuild when the language changes
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
                Text.verbatim(a.localKind.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Geist')),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text.verbatim(a.localMessage,
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
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: () {
                    setState(() => _muted = !_muted);
                    _muted ? Siren.stop() : Siren.start();
                  },
                  icon: Icon(_muted ? Icons.volume_up : Icons.volume_off),
                  label: Text(_muted ? 'Sound the alarm again' : 'Silence the alarm'),
                ),
                const SizedBox(height: 8),
                _CheckInButtons(alert: a, onDark: true),
                const SizedBox(height: 14),
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


/// Small bar at the bottom while an alert is still active but the full
/// warning was dismissed: students answer from here, staff open the roster.
class _ActiveBar extends StatelessWidget {
  const _ActiveBar({required this.alert});
  final EmergencyAlert alert;

  @override
  Widget build(BuildContext context) {
    LangScope.of(context);
    return Material(
      color: const Color(0xFF8E0000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.verbatim(
                        '${tr(context, 'EMERGENCY ALERT')}: ${alert.localKind}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Geist')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _CheckInButtons(alert: alert, onDark: true, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// "I'm safe" and "I need help" for everyone. Teachers and admins also get
/// a button that opens the list of who has answered.
class _CheckInButtons extends StatelessWidget {
  const _CheckInButtons(
      {required this.alert, this.onDark = false, this.compact = false});
  final EmergencyAlert alert;
  final bool onDark;
  final bool compact;

  Future<void> _send(BuildContext context, String status) async {
    final m = ScaffoldMessenger.maybeOf(context);
    try {
      await context.read<CheckInCubit>().submit(status);
      Siren.stop(); // they answered: no need to keep sounding
    } catch (e) {
      m?.showSnackBar(SnackBar(content: Text.verbatim('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.select<AccountCubit, bool>((c) => c.state.rank >= 2);
    final c = context.watch<CheckInCubit>().state;
    final answered = c.alertId == alert.id ? c.status : null;

    if (answered != null) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(answered == 'safe' ? Icons.check_circle : Icons.sos,
              color: Colors.white, size: 20),
          Text.verbatim(
              answered == 'safe'
                  ? tr(context, c.waiting ? 'Safe (will send when online)' : 'You are marked safe')
                  : tr(context, c.waiting ? 'Help request (will send when online)' : 'Help request sent'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          if (staff) _roster(context),
        ],
      );
    }

    final pad = EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16, vertical: compact ? 6 : 14);
    final safe = FilledButton.icon(
      style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32), padding: pad),
      onPressed: () => _send(context, 'safe'),
      icon: const Icon(Icons.check_circle, size: 20),
      label: const Text("I'm safe"),
    );
    final help = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white),
          padding: pad),
      onPressed: () => _send(context, 'help'),
      icon: const Icon(Icons.sos, size: 20),
      label: const Text('I need help'),
    );
    if (compact) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [safe, help, if (staff) _roster(context)],
      );
    }
    return Column(children: [
      Row(children: [
        Expanded(child: safe),
        const SizedBox(width: 10),
        Expanded(child: help),
      ]),
      if (staff) ...[const SizedBox(height: 8), _roster(context, wide: true)],
    ]);
  }

  Widget _roster(BuildContext context, {bool wide = false}) {
    void open() {
      final nav = navigatorKey.currentState;
      nav?.push(CheckInRosterPage.route(alert.id));
    }

    void openCount() =>
        navigatorKey.currentState?.push(HeadcountPage.route(alert.id));

    ButtonStyle style() => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54));

    return wide
        ? Column(children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: style(),
                onPressed: open,
                icon: const Icon(Icons.groups),
                label: const Text('See who is safe'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: style(),
                onPressed: openCount,
                icon: const Icon(Icons.fact_check),
                label: const Text('Class headcount'),
              ),
            ),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: tr(context, 'See who is safe'),
              color: Colors.white,
              onPressed: open,
              icon: const Icon(Icons.groups),
            ),
            IconButton(
              tooltip: tr(context, 'Class headcount'),
              color: Colors.white,
              onPressed: openCount,
              icon: const Icon(Icons.fact_check),
            ),
          ]);
  }
}
