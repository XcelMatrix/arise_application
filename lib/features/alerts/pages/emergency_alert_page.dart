import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/app_drawer.dart';
import 'package:arise_application/features/account/widgets/profile_menu_button.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/alerts/pages/checkin_roster_page.dart';
import 'package:arise_application/features/alerts/pages/headcount_page.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';

/// Teachers and admins broadcast an emergency alert from here.
class EmergencyAlertPage extends StatefulWidget {
  const EmergencyAlertPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const EmergencyAlertPage());

  @override
  State<EmergencyAlertPage> createState() => _EmergencyAlertPageState();
}

class _EmergencyAlertPageState extends State<EmergencyAlertPage> {
  static const _red = Color(0xFF3C6E87); // the app's dark cyan
  String _kind = 'Fire';
  final _details = TextEditingController(); // optional extra line
  final _english = TextEditingController(text: alertTemplates['Fire']);
  final _filipino = TextEditingController(); // optional Filipino version
  bool _busy = false;

  /// the message that will be sent (English)
  String get _message => _english.text.trim();

  @override
  void dispose() {
    _details.dispose();
    _english.dispose();
    _filipino.dispose();
    super.dispose();
  }

  /// picking a type fills in its standard English message (still editable)
  void _pickKind(String k) {
    final old = alertTemplates[_kind] ?? '';
    setState(() {
      _kind = k;
      if (_english.text.trim().isEmpty || _english.text.trim() == old) {
        _english.text = alertTemplates[k] ?? '';
      }
    });
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: tr(context, label),
        labelStyle: const TextStyle(color: _red, fontFamily: 'Geist'),
        alignLabelWithHint: true,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _red),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _red),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _red, width: 2),
        ),
      );

  /// a titled box, so the page reads as separate sections
  Widget _section(IconData icon, String title, List<Widget> children,
      {String? hint}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border.all(color: _red.withValues(alpha: 0.6), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _red, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _red,
                      fontFamily: 'Geist')),
            ),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint,
                style: const TextStyle(
                    fontSize: 12, color: _red, fontFamily: 'Geist')),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    if (_message.isEmpty) return _toast('Write a message first');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send emergency alert?'),
        content: const Text(
            'This warns everyone using the app right away. Only send it for a real emergency or an announced drill.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send alert',
                  style: TextStyle(color: _red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AlertCubit>().send(
          _kind, _message, _details.text.trim(), _filipino.text.trim());
      _toast('Alert sent to everyone.');
    } catch (e) {
      _toast('Could not send: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear(String id) async {
    setState(() => _busy = true);
    try {
      await context.read<AlertCubit>().clear(id);
      _toast('All clear sent.');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = context.watch<AlertCubit>().state.active;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _red,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Emergency Alert'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
        actions: const [ProfileMenuButton()],
      ),
      endDrawer: const AppDrawer(),
      body: ListView(
        // extra room at the bottom so the phone's navigation buttons never
        // cover the Send button
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 40 + MediaQuery.of(context).viewPadding.bottom),
        children: [
          if (active != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('An alert is active',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _red,
                          fontFamily: 'Geist')),
                  const SizedBox(height: 4),
                  Text.verbatim('${active.localKind}: ${active.localMessage}'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white),
                        onPressed: _busy ? null : () => _clear(active.id),
                        child: const Text('Send all clear'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                            context, CheckInRosterPage.route(active.id)),
                        icon: const Icon(Icons.groups),
                        label: const Text('See who is safe'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                            context, HeadcountPage.route(active.id)),
                        icon: const Icon(Icons.fact_check),
                        label: const Text('Class headcount'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          _section(Icons.category, 'Type of Emergency', [
            DropdownButtonFormField<String>(
              key: ValueKey(_kind),
              initialValue: _kind,
              isExpanded: true,
              style: const TextStyle(color: _red, fontFamily: 'Geist', fontSize: 16),
              decoration: _dec('Type of Emergency'),
              items: [
                for (final t in alertKinds)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => _pickKind(v ?? _kind),
            ),
          ]),
          _section(
            Icons.campaign,
            'Message',
            [
              TextField(
                controller: _english,
                style: const TextStyle(color: _red, fontFamily: 'Geist'),
                minLines: 3,
                maxLines: 6,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: _dec('English message'),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _filipino,
                style: const TextStyle(color: _red, fontFamily: 'Geist'),
                minLines: 3,
                maxLines: 6,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('Filipino message (optional)'),
              ),
            ],
            hint:
                'People using the app in English see the English message. People using Filipino see the Filipino message; if you leave it empty they see the English one.',
          ),
          _section(Icons.place, 'Details (optional)', [
            TextField(
              controller: _details,
              style: const TextStyle(color: _red, fontFamily: 'Geist'),
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('For example the building'),
            ),
          ]),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Send emergency alert',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
