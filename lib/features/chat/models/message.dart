/// One chat message: text, an image, or both.
class Message {
  Message({
    required this.id,
    required this.profileId,
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.imagePath,
    this.editedAt,
  });

  final String id;
  final String profileId;
  final String content;
  final DateTime createdAt;

  /// true if the signed-in user wrote it
  final bool isMine;

  /// path inside the private `chat-images` bucket, if a photo was sent
  final String? imagePath;

  /// set when the text was edited after sending
  final DateTime? editedAt;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get edited => editedAt != null;

  /// Short text for lists ("Photo" when there is only an image).
  String get preview => content.isNotEmpty ? content : (hasImage ? 'Photo' : '');

  Message.fromMap({
    required Map<String, dynamic> map,
    required String myUserId,
  })  : id = map['id'].toString(),
        profileId = map['profile_id'] as String,
        content = (map['content'] as String?) ?? '',
        createdAt = DateTime.parse(map['created_at'] as String),
        isMine = myUserId == map['profile_id'],
        imagePath = map['image_path'] as String?,
        editedAt = map['edited_at'] == null
            ? null
            : DateTime.parse(map['edited_at'] as String);
}
