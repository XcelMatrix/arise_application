import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/l10n/translated_text.dart';
import 'package:arise_application/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';

/// Wraps a page that is only for some accounts. Shows the page when the
/// account's role is allowed (see public.feature_access), otherwise a
/// "locked" screen. The database enforces the same rule; this is the UI side.
class AccessGate extends StatelessWidget {
  const AccessGate({super.key, required this.feature, required this.child});

  final String feature;
  final Widget child;

  static const _blue = Color(0xFF3C6E87);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
      builder: (context, account) {
        if (!account.loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _blue)),
          );
        }
        if (account.isTeacherPending || !account.canAccess(feature)) {
          return Scaffold(
            backgroundColor: AppColors.bg(context),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 64, color: _blue),
                      const SizedBox(height: 16),
                      const Text(
                        'Teachers and admins only',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _blue,
                          fontFamily: 'Geist',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Your account doesn't have access to this page.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Geist',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                        child: const Text('Back to home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
