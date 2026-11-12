part of 'profiles_cubit.dart';

@immutable
abstract class ProfilesState {}

class ProfilesInitial extends ProfilesState {}

class ProfilesLoaded extends ProfilesState {
  ProfilesLoaded({required this.profiles});

  /// profiles loaded so far, by user id
  final Map<String, Profile?> profiles;
}
