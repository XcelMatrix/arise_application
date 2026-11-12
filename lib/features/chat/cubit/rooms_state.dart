part of 'rooms_cubit.dart';

@immutable
abstract class RoomState {}

class RoomsLoading extends RoomState {}

class RoomsLoaded extends RoomState {
  RoomsLoaded({required this.newUsers, required this.rooms});

  /// people the user has no room with yet
  final List<Profile> newUsers;
  final List<Room> rooms;
}

class RoomsEmpty extends RoomState {
  RoomsEmpty({required this.newUsers});
  final List<Profile> newUsers;
}

class RoomsError extends RoomState {
  RoomsError(this.message);
  final String message;
}
