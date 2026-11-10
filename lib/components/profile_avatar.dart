import 'package:flutter/material.dart';
import 'package:arise_application/models/profile.dart';

/// A user's picture, or their initials when they have none.
/// Shows a spinner while the profile is still loading (profile == null).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius});

  final Profile? profile;
  final double? radius;

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) {
      return CircleAvatar(
        radius: radius,
        child: const Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

    final url = p.avatarUrl;
    return CircleAvatar(
      radius: radius,
      // the picture is drawn over the initials; if it can't load, the
      // initials stay visible
      foregroundImage:
          (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
      onForegroundImageError: (url != null && url.isNotEmpty)
          ? (_, _) {}
          : null,
      child: Text(p.initials),
    );
  }
}
