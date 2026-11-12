import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/features/account/widgets/profile_avatar.dart';
import 'package:arise_application/features/account/cubit/profiles_cubit.dart';

/// Widget that will display a user's avatar
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfilesCubit, ProfilesState>(
      builder: (context, state) {
        if (state is ProfilesLoaded) {
          final user = state.profiles[userId];
          return ProfileAvatar(profile: user);
        } else {
          return const ProfileAvatar(profile: null);
        }
      },
    );
  }
}