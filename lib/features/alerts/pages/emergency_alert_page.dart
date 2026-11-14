import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/features/alerts/pages/checkin_roster_page.dart';
import 'package:arise_application/features/alerts/pages/headcount_page.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart' show emergencyTypes;
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
  static const _red = Color(0xFFB3261E);
  String _kind = 'Fire';
  final _details = TextEditingController(); // optional extra line
  final _custom = TextEditingController(); // only for "Other"
  bool _busy = false;

  /// the message that will be sent (English; every phone translates it)
  String get _message =>
      _kind == 'Other' ? _custom.text.trim() : (alertTemplates[_kind] ?? '');

  @override
  void dispose() {
    _details.dispose();
    _custom.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: tr(context, label),
        filled: true,
        fillColor: AppColors.field(context),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
      );

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
      await context.read<AlertCubit>().send(_kind, _message, _details.text.trim());
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
        title: const Text('Emergency alert'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
          const Text('Type of emergency',
              style: TextStyle(color: Colors.grey, fontFamily: 'Geist')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in emergencyTypes)
                ChoiceChip(
                  label: Text(t),
                  selected: _kind == t,
                  selectedColor: _red,
                  labelStyle: TextStyle(
                      color: _kind == t ? Colors.white : null,
                      fontFamily: 'Geist'),
                  onSelected: (_) => setState(() => _kind = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_kind == 'Other')
            TextField(
              controller: _custom,
              minLines: 3,
              maxLines: 6,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Message to everyone'),
            )
          else
            // the standard message, shown in the sender's own language
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text.verbatim(Tr.t(_message),
                  style: TextStyle(
                      fontSize: 16,
                      color: AppColors.text(context),
                      fontFamily: 'Geist')),
            ),
          const SizedBox(height: 4),
          Text(
              _kind == 'Other'
                  ? 'This message is shown exactly as you type it, in every language.'
                  : 'Everyone sees this message in the language they chose in Settings.',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec('Extra details (optional), for example the building'),
          ),
          if (_kind != 'Other')
            // see how it will look in each language
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Preview in other languages',
                    style: const TextStyle(fontFamily: 'Geist')),
                children: [
                  for (final l in Tr.languages)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text.verbatim(
                          '${l.flag} ${l.nativeName}\n${Tr.inLanguage(l, _message)}',
                          style: TextStyle(color: AppColors.text(context))),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
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
