import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';

/// The heading of a category: icon, title and a cyan line below. Used by the
/// Contacts and the Guidelines pages so both look exactly the same.
class CategoryHeading extends StatelessWidget {
  const CategoryHeading({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.first = false,
  });

  final Widget icon;
  final String title; // already translated
  final Widget? trailing;
  final bool first;

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            icon,
            const SizedBox(width: 8),
            Expanded(
              child: Text.verbatim(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                      fontFamily: 'Geist')),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 4),
          const Divider(color: _blue, thickness: 2, height: 2),
        ],
      ),
    );
  }
}
