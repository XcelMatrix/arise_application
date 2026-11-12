import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/alerts/cubit/alert_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
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
  static const _templates = {
    'Fire': 'Fire reported. Evacuate now using the nearest safe exit and go to your evacuation site.',
    'Earthquake': 'Earthquake. Drop, cover and hold on. Evacuate to the open area once the shaking stops.',
    'Flood': 'Flooding. Move to higher ground and wait for instructions.',
    'Typhoon': 'Typhoon warning. Stay indoors and away from windows.',
    'Lockdown': 'Lockdown. Lock doors, stay quiet and stay away from windows until the all-clear.',
    'Other': '',
  };

  String _kind = 'Fire';
  final _message = TextEditingController(text: _templates['Fire']);
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return _toast('Write a message first');
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
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await context.read<AlertCubit>().send(_kind, _message.text.trim());
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
                  Text.verbatim('${active.kind}: ${active.message}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white),
                    onPressed: _busy ? null : () => _clear(active.id),
                    child: const Text('Send all clear'),
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
                  onSelected: (_) => setState(() {
                    _kind = t;
                    _message.text = _templates[t] ?? '';
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            minLines: 4,
            maxLines: 7,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr(context, 'Message to everyone'),
              filled: true,
              fillColor: AppColors.field(context),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide.none,
              ),
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
