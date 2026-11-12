import 'dart:async';
import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/features/chat/models/message.dart';

part 'chat_state.dart';

/// Messages of one chat room: live list, send (text and/or photo), edit
/// your own text and delete your own messages.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(ChatInitial());

  static const bucket = 'chat-images';

  final _sb = Supabase.instance.client;
  StreamSubscription<List<Message>>? _sub;
  List<Message> _messages = [];
  String _roomId = '';
  String _myUserId = '';

  void setMessagesListener(String roomId) {
    _roomId = roomId;
    _myUserId = _sb.auth.currentUser!.id;
    _sub = _sb
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((m) => Message.fromMap(map: m, myUserId: _myUserId))
            .toList())
        .listen((messages) {
      _messages = messages;
      if (isClosed) return;
      emit(messages.isEmpty ? ChatEmpty() : ChatLoaded(messages));
    }, onError: (_) {
      if (!isClosed) emit(ChatError('Error loading messages'));
    });
  }

  /// Sends text, a photo, or both.
  Future<void> sendMessage(String text, {File? image}) async {
    final content = text.trim();
    if (content.isEmpty && image == null) return;
    String? path;
    try {
      if (image != null) {
        final dot = image.path.lastIndexOf('.');
        final ext = dot < 0 ? 'jpg' : image.path.substring(dot + 1).toLowerCase();
        // the file name starts with the sender's id (the storage policy uses it)
        path = '$_roomId/${_myUserId}_${DateTime.now().microsecondsSinceEpoch}.$ext';
        await _sb.storage.from(bucket).upload(path, image);
      }
      await _sb.from('messages').insert({
        'profile_id': _myUserId,
        'room_id': _roomId,
        'content': content,
        'image_path': ?path,
      });
    } catch (e) {
      if (path != null) {
        // don't leave an unused photo behind
        try {
          await _sb.storage.from(bucket).remove([path]);
        } catch (_) {}
      }
      if (!isClosed) emit(ChatError('Could not send the message'));
      _restore();
    }
  }

  Future<void> editMessage(String id, String text) async {
    final content = text.trim();
    final msg = _messages.where((m) => m.id == id).firstOrNull;
    if (msg == null) return;
    if (content.isEmpty && !msg.hasImage) return;
    if (content == msg.content) return;
    try {
      await _sb.from('messages').update({
        'content': content,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (_) {
      if (!isClosed) emit(ChatError('Could not edit the message'));
      _restore();
    }
  }

  Future<void> deleteMessage(String id) async {
    final msg = _messages.where((m) => m.id == id).firstOrNull;
    try {
      await _sb.from('messages').delete().eq('id', id);
      if (msg != null && msg.hasImage) {
        try {
          await _sb.storage.from(bucket).remove([msg.imagePath!]);
        } catch (_) {}
      }
      // the realtime stream may not report deletions: update the list now
      _messages = _messages.where((m) => m.id != id).toList();
      if (!isClosed) {
        emit(_messages.isEmpty ? ChatEmpty() : ChatLoaded(_messages));
      }
    } catch (_) {
      if (!isClosed) emit(ChatError('Could not delete the message'));
      _restore();
    }
  }

  /// Back to the message list after an error has been shown.
  void _restore() {
    if (isClosed) return;
    emit(_messages.isEmpty ? ChatEmpty() : ChatLoaded(_messages));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
