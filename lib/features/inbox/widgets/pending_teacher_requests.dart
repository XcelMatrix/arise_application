import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:arise_application/features/inbox/cubit/teacher_requests_cubit.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';

/// Pending teacher-account requests, shown at the top of the Inbox for
/// teachers and admins. Approve or decline right here.
class PendingTeacherRequests extends StatelessWidget {
  const PendingTeacherRequests({super.key});

  static const _blue = Color(0xFF3C6E87);

  String _name(TeacherRequest r) => r.name.isNotEmpty ? r.name : r.username;

  Future<void> _decide(
      BuildContext context, TeacherRequest r, bool approve) async {
    final cubit = context.read<TeacherRequestsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve this teacher?' : 'Decline this request?'),
        content: Text.verbatim(_name(r)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(approve ? 'Approve' : 'Decline')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      approve ? await cubit.approve(r.userId) : await cubit.reject(r.userId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text.verbatim('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // the cubit only loads for accounts allowed to review, so this is
    // empty (and invisible) for everyone else
    final pending = context.watch<TeacherRequestsCubit>().state.pending;
    if (pending.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.soft(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.how_to_reg, color: _blue),
            const SizedBox(width: 8),
            const Text('Teacher requests',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _blue,
                    fontFamily: 'Geist')),
          ]),
          const SizedBox(height: 8),
          for (final r in pending)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.verbatim(_name(r),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text(context),
                                fontFamily: 'Geist')),
                        Text.verbatim(
                            '@${r.username} · ${timeago.format(r.requestedAt)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontFamily: 'Geist')),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Decline'),
                    icon: const Icon(Icons.close, color: Color(0xFFB3261E)),
                    onPressed: () => _decide(context, r, false),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Approve'),
                    icon: const Icon(Icons.check_circle,
                        color: Color(0xFF2E7D32)),
                    onPressed: () => _decide(context, r, true),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
