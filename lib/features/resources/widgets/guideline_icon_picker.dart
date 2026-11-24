import 'dart:typed_data';
import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/form_style.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/features/resources/data/guideline_icons.dart';

/// What the person picked in [showIconPicker].
///   spec set        a built-in icon ('i:..') or a number / letter ('t:..')
///   image set       a new picture (the caller uploads it)
///   neither         go back to the default icon
class IconChoice {
  const IconChoice({this.spec, this.image});
  final String? spec;
  final Uint8List? image;
}

/// Asks which icon to use: one of the built-in icons, a picture from the
/// gallery, a number or a letter, or the default. Null means cancelled.
Future<IconChoice?> showIconPicker(BuildContext context, {String? current}) {
  final text = TextEditingController(
      text: (current != null && current.startsWith('t:'))
          ? current.substring(2)
          : '');
  return showDialog<IconChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Choose an icon'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 256,
                        maxHeight: 256,
                        imageQuality: 85);
                    if (f == null) return;
                    final b = await f.readAsBytes();
                    if (ctx.mounted) Navigator.pop(ctx, IconChoice(image: b));
                  },
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('Use a picture'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, const IconChoice()),
                  child: const Text('Default icon'),
                ),
              ],
            ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: text,
                  maxLength: 3,
                  decoration: InputDecoration(
                      labelText: tr(ctx, 'Or type a number or letter'),
                      counterText: ''),
                ),
              ),
              TextButton(
                onPressed: () {
                  final t = text.text.trim();
                  if (t.isEmpty) return;
                  Navigator.pop(ctx, IconChoice(spec: 't:$t'));
                },
                child: const Text('Use'),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: GridView.count(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final e in GuidelineIcons.map.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          Navigator.pop(ctx, IconChoice(spec: 'i:${e.key}')),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: current == 'i:${e.key}'
                                  ? const Color(0xFF3C6E87)
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Icon(e.value, color: const Color(0xFF3C6E87)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  ).whenComplete(() => disposeLater([text]));
}
