class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  /// User ID of the profile
  final String id;

  /// Username of the profile (the handle the app uses)
  final String username;

  /// Date and time when the profile was created
  final DateTime createdAt;

  /// Name shown in the app. Editable on the profile page.
  final String? displayName;

  /// Profile picture, if the user added one.
  final String? avatarUrl;

  /// The display name if there is one, otherwise the username.
  String get shownName {
    final d = displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    return username;
  }

  /// First two letters of the shown name (safe for short names).
  String get initials {
    final n = shownName.trim();
    if (n.isEmpty) return '?';
    return n.length >= 2 ? n.substring(0, 2) : n;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Works with a plain profiles row, or one fetched with
  /// `select('*, profile_details(display_name, avatar_url)')`.
  Profile.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        username = map['username'],
        createdAt = DateTime.parse(map['created_at']),
        displayName = _details(map)?['display_name'] as String?,
        avatarUrl = _details(map)?['avatar_url'] as String?;

  static Map<String, dynamic>? _details(Map<String, dynamic> map) {
    final d = map['profile_details'];
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is List && d.isNotEmpty && d.first is Map) {
      return Map<String, dynamic>.from(d.first as Map);
    }
    return null;
  }

  Profile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? displayName,
    String? avatarUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      username: name ?? username,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
