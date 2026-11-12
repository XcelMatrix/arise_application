import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/announcements/pages/announcements_page.dart';
import 'package:arise_application/features/alerts/pages/emergency_alert_page.dart';
import 'package:arise_application/features/chat/pages/rooms_page.dart';
import 'package:arise_application/features/admin/pages/admin_tools_page.dart';

/// One round "three dots" button. Tap it and Chat, Announcements and (for
/// teachers and admins) the Emergency alert pop up above it.
class HomeSpeedDial extends StatefulWidget {
  const HomeSpeedDial({
    super.key,
    required this.canChat,
    required this.canAlert,
    this.canAdmin = false,
  });

  final bool canChat;
  final bool canAlert;
  final bool canAdmin;

  @override
  State<HomeSpeedDial> createState() => _HomeSpeedDialState();
}

class _HomeSpeedDialState extends State<HomeSpeedDial>
    with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF3C6E87);
  static const _red = Color(0xFFB3261E);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _c.forward() : _c.reverse();
  }

  void _go(Route<void> route) {
    _toggle();
    Navigator.push(context, route);
  }

  Widget _item(String label, IconData icon, Color color, VoidCallback onTap) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      alignment: Alignment.centerRight,
      child: FadeTransition(
        opacity: _c,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E2A31)
                    : Colors.white,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Geist')),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                heroTag: 'dial_$label',
                mini: true,
                backgroundColor: color,
                onPressed: onTap,
                child: Icon(icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open || _c.isAnimating) ...[
          if (widget.canAdmin)
            _item('Admin tools', Icons.admin_panel_settings, const Color(0xFF455A64),
                () => _go(AdminToolsPage.route())),
          if (widget.canAlert)
            _item('Emergency alert', Icons.warning_amber_rounded, _red,
                () => _go(EmergencyAlertPage.route())),
          _item('Announcements', Icons.campaign, _blue,
              () => _go(AnnouncementsPage.route())),
          if (widget.canChat)
            _item('Chat', Icons.forum, _blue, () => _go(RoomsPage.route())),
        ],
        FloatingActionButton(
          heroTag: 'dial_main',
          tooltip: tr(context, _open ? 'Close' : 'More'),
          backgroundColor: _blue,
          onPressed: _toggle,
          child: Icon(_open ? Icons.close : Icons.menu,
              color: Colors.white),
        ),
      ],
    );
  }
}
