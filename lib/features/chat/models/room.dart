import 'package:arise_application/features/chat/models/message.dart';

/// A chat room between the signed-in user and one other person.
class Room {
  Room({
    required this.id,
    required this.createdAt,
    required this.otherUserId,
    this.lastMessage,
  });

  final String id;
  final DateTime createdAt;

  /// the other person in the room
  final String otherUserId;

  /// newest message, shown under the name in the room list
  final Message? lastMessage;

  /// Builds a room from a `room_participants` row.
  Room.fromRoomParticipants(Map<String, dynamic> map)
      : id = map['room_id'] as String,
        otherUserId = map['profile_id'] as String,
        createdAt = DateTime.parse(map['created_at'] as String),
        lastMessage = null;

  Room copyWith({
    String? id,
    DateTime? createdAt,
    String? otherUserId,
    Message? lastMessage,
  }) {
    return Room(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      otherUserId: otherUserId ?? this.otherUserId,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}
