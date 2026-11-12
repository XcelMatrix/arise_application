import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';

/// The kinds of marker a map can have (matches map_markers.kind in the database
/// and the 3D pins in `assets/markers/<key>.glb`).
class MarkerKind {
  const MarkerKind(this.key, this.label, this.icon, this.color);
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  static const all = <MarkerKind>[
    MarkerKind('exit', 'Exit', Icons.exit_to_app, Color(0xFF1AB34D)),
    MarkerKind('assembly', 'Assembly point', Icons.groups, Color(0xFF1A66E6)),
    MarkerKind('extinguisher', 'Fire extinguisher', Icons.fire_extinguisher,
        Color(0xFFD91A1A)),
    MarkerKind('firstaid', 'First aid', Icons.medical_services,
        Color(0xFFF2738C)),
    MarkerKind('stairs', 'Stairs', Icons.stairs, Color(0xFF8C40CC)),
    MarkerKind('hazard', 'Hazard', Icons.warning_amber, Color(0xFFFFB300)),
    MarkerKind('other', 'Other', Icons.place, Color(0xFF73808C)),
  ];

  static MarkerKind of(String? key) =>
      all.firstWhere((k) => k.key == key, orElse: () => all.last);

  String get asset => 'assets/markers/$key.glb';
}

/// Asks for a marker's kind and an optional label. Returns null if cancelled.
Future<({String kind, String label})?> showMarkerDialog(
  BuildContext context, {
  String title = 'Add marker',
  String kind = 'exit',
  String label = '',
  String confirm = 'Next',
}) {
  final c = TextEditingController(text: label);
  var selected = kind;
  return showDialog<({String kind, String label})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final k in MarkerKind.all)
                    ChoiceChip(
                      avatar: Icon(k.icon,
                          size: 18,
                          color: selected == k.key ? Colors.white : k.color),
                      label: Text(k.label),
                      selected: selected == k.key,
                      selectedColor: k.color,
                      labelStyle: TextStyle(
                          color: selected == k.key ? Colors.white : null),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => selected = k.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLength: 60,
                decoration: InputDecoration(
                    labelText: tr(ctx, 'Label (optional)'),
                    hintText: tr(ctx, 'e.g. North exit')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, (kind: selected, label: c.text.trim())),
              child: Text(confirm)),
        ],
      ),
    ),
  ).whenComplete(c.dispose);
}
