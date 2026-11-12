/// Pulls a person's shown name out of a `profiles(...)` embed:
/// display name if they set one, otherwise their username.
String shownNameFromProfile(dynamic profile) {
  if (profile is List) profile = profile.isEmpty ? null : profile.first;
  if (profile is! Map) return '';
  var details = profile['profile_details'];
  if (details is List) details = details.isEmpty ? null : details.first;
  final display = details is Map ? details['display_name'] as String? : null;
  if (display != null && display.trim().isNotEmpty) return display.trim();
  return (profile['username'] as String?) ?? '';
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? authorId;
  final String authorName;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.authorName = '',
  });

  factory Announcement.fromRow(Map<String, dynamic> row) {
    return Announcement(
      id: row['id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      createdAt:
          DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now(),
      authorId: row['created_by'] as String?,
      authorName: shownNameFromProfile(row['profiles']),
    );
  }
}
