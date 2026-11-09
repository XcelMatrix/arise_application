import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/auth_servers/auth_service.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';

/// Shown instead of the app while a teacher account is waiting for approval
/// (or was declined).
class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key, required this.rejected});

  final bool rejected;

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rejected ? Icons.block : Icons.hourglass_top,
                  size: 72,
                  color: _blue,
                ),
                const SizedBox(height: 20),
                Text(
                  rejected ? 'Request declined' : 'Waiting for approval',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                    fontFamily: 'Geist',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  rejected
                      ? 'Your teacher request was not approved. Please contact '
                          'your administrator.'
                      : 'Your teacher account has to be approved before you '
                          'can use the app. Check back once you have been '
                          'approved.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontFamily: 'Geist',
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => context.read<AccountCubit>().load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  child: const Text('Log out',
                      style: TextStyle(color: _blue, fontFamily: 'Geist')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
