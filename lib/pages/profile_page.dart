import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:arise_application/auth_servers/auth_service.dart';
import 'package:arise_application/cubits/account/account_cubit.dart';
import 'package:arise_application/pages/home_page.dart';

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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(
              icon: Image.asset(
                "assets/icons/icon_white.png",
                width: 48,
                height: 48,
              ),
              color: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const HomePage()
              )),
            ),
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
                              ? const Center(
                                  child: CircularProgressIndicator(color: _blue))
                              : account.avatarUrl != null
                                  ? Image.network(
                                      account.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
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
                          color: const Color(0xFFE4F2F9),
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
                  decoration: const InputDecoration(
                    hintText: "How your name appears",
                    hintStyle: TextStyle(
                        fontSize: 16, color: Colors.grey, fontFamily: 'Geist'),
                    counterText: '',
                    filled: true,
                    fillColor: Color(0xFFD3D3D3),
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

                const SizedBox(height: 24),

                // logout button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE4F2F9),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
