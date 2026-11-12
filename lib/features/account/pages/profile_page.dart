import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/widgets/back_or_logo.dart';
import 'package:arise_application/core/widgets/flashing_logo.dart';
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/translations/translation.dart';
import 'package:arise_application/features/auth/services/auth_service.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _blue = Color(0xFF3C6E87);

  // get auth service
  final authService = AuthService();

  final _nameController = TextEditingController();
  bool _nameTouched = false;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<AccountCubit>();
    _nameController.text = account.state.displayName ?? '';
    account.load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// "Joined November 9, 2026" (from the sign-up date), or null if unknown.
  String? _joinedText(BuildContext context) {
    final raw = Supabase.instance.client.auth.currentUser?.createdAt;
    if (raw == null) return null;
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return null;
    final months = Tr.months;
    return '${tr(context, 'Registered since')} ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Asks for a password in a small dialog; returns it, or null if cancelled.
  Future<String?> _askPassword(String title, String message) async {
    final c = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            TextField(
              controller: c,
              obscureText: true,
              decoration: InputDecoration(labelText: tr(ctx, 'Current password')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Continue')),
        ],
      ),
    );
    c.dispose();
    return (pw == null || pw.isEmpty) ? null : pw;
  }

  Future<void> _changePassword() async {
    final current = await _askPassword(
        'Change password', 'Enter your current password first.');
    if (current == null) return;
    try {
      await authService.confirmPassword(current);
    } catch (_) {
      return _toast('That password is not correct.');
    }
    if (!mounted) return;
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              obscureText: true,
              decoration: InputDecoration(labelText: tr(ctx, 'New password')),
            ),
            TextField(
              controller: b,
              obscureText: true,
              decoration: InputDecoration(labelText: tr(ctx, 'Confirm password')),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save password')),
        ],
      ),
    );
    final pw = a.text;
    final same = pw == b.text;
    a.dispose();
    b.dispose();
    if (ok != true) return;
    if (pw.length < 6) return _toast('Password must be at least 6 characters.');
    if (!same) return _toast('Passwords do not match');
    try {
      await authService.setNewPassword(pw);
      _toast('Password updated.');
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This permanently deletes your account, profile and saved class lists. It cannot be undone. Your chat messages are removed too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFB3261E)))),
        ],
      ),
    );
    if (sure != true) return;
    final pw = await _askPassword(
        'Confirm', 'Enter your password to delete your account.');
    if (pw == null) return;
    try {
      await authService.confirmPassword(pw);
    } catch (_) {
      return _toast('That password is not correct.');
    }
    try {
      await authService.deleteMyAccount();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _toast('$e');
    }
  }

  // logout button pressed
  void logout() async {
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    try {
      await context.read<AccountCubit>().saveDisplayName(_nameController.text);
      _nameTouched = false;
      _toast('Display name saved');
    } catch (e) {
      _toast('Could not save name: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final cubit = context.read<AccountCubit>();
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _uploading = true);
      await cubit.uploadAvatar(file);
      _toast('Profile picture updated');
    } catch (e) {
      _toast('Could not update picture: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    final cubit = context.read<AccountCubit>();
    setState(() => _uploading = true);
    try {
      await cubit.removeAvatar();
      _toast('Profile picture removed');
    } catch (e) {
      _toast('Could not remove picture: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _avatarMenu(bool hasAvatar) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: _blue),
              title: Text(hasAvatar ? 'Choose a new photo' : 'Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: _blue),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountCubit, AccountState>(
      // fill the field once the saved name arrives, unless the user is typing
      listenWhen: (a, b) => a.displayName != b.displayName,
      listener: (context, state) {
        if (!_nameTouched) _nameController.text = state.displayName ?? '';
      },
      builder: (context, account) {
        return Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            leading: const BackOrLogo(),
            backgroundColor: _blue,
            title: const Text("Profile"),
            titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Geist'
            ),
            centerTitle: true,
          ),
          body: Center(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              children: [
                // avatar (tap to add / change / remove)
                Center(
                  child: GestureDetector(
                    onTap: _uploading
                        ? null
                        : () => _avatarMenu(account.avatarUrl != null),
                    child: Stack(
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _uploading
                              ? const FlashingLogo()
                              : account.avatarUrl != null
                                  ? Image.network(
                                      account.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person,
                                        size: 96,
                                        color: Color(0xFFACACAC),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 96,
                                      color: Color(0xFFACACAC),
                                    ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // shown name + username + role
                Center(
                  child: Text(
                    account.shownName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _blue,
                      fontFamily: 'Geist',
                    ),
                  ),
                ),
                if (account.username != null)
                  Center(
                    child: Text(
                      '@${account.username}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.grey, fontFamily: 'Geist'),
                    ),
                  ),
                if (account.roleName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.soft(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          account.roleName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _blue,
                            fontFamily: 'Geist',
                          ),
                        ),
                      ),
                    ),
                  ),

                // when the account was created
                if (_joinedText(context) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text.verbatim(
                          _joinedText(context)!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontFamily: 'Geist',
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // display name field
                const Text(
                  'Display name',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey, fontFamily: 'Geist'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  enabled: !_saving,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _nameTouched = true,
                  decoration: InputDecoration(
                    hintText: tr(context, "How your name appears"),
                    hintStyle: TextStyle(
                        fontSize: 16, color: Colors.grey, fontFamily: 'Geist'),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.field(context),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _saveName,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Save name",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'Geist'),
                        ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _changePassword,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Change password'),
                ),

                const SizedBox(height: 24),

                // logout button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.soft(context),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: logout,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout, color: _blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Log out",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _blue,
                          fontFamily: 'Geist',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _deleteAccount,
                  icon: const Icon(Icons.delete_forever,
                      size: 20, color: Color(0xFFB3261E)),
                  label: const Text('Delete my account',
                      style: TextStyle(color: Color(0xFFB3261E))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
