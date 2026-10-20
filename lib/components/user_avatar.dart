import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/profiles/profiles_cubit.dart';

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
          return CircleAvatar(
            child:
                user == null ? Center(child: CircularProgressIndicator(color: Color(0xFF3C6E87))) : Text(user.username.substring(0, 2)),
          );
        } else {
          return const CircleAvatar(child: Center(child: CircularProgressIndicator(color: Color(0xFF3C6E87))));
        }
      },
    );
  }
}