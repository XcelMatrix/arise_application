import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/announcements/widgets/announcement_widgets.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/announcements/cubit/announcements_cubit.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  static const _blue = Color(0xFF3C6E87);

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const AnnouncementsPage());

  @override
  Widget build(BuildContext context) {
    final canPost = context.select<AccountCubit, bool>(
        (c) => c.state.canAccess(Feature.announce));
    final ann = context.watch<AnnouncementsCubit>().state;
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Announcements'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              onPressed: () => showAnnouncementEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Post'),
            )
          : null,
      body: !ann.loaded
          ? const FlashingLogo()
          : ann.items.isEmpty
              ? const Center(
                  child: Text('No announcements yet.',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Geist')))
              : RefreshIndicator(
                  onRefresh: () => context.read<AnnouncementsCubit>().load(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [for (final a in ann.items) AnnouncementCard(item: a)],
                  ),
                ),
    );
  }
}
