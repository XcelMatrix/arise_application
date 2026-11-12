import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/translations/translated_text.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/auth/services/auth_service.dart';

/// Opened by the link in the "reset password" email.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (context) => const ResetPasswordPage());

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const _blue = Color(0xFF3C6E87);
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _visible = false;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    if (_pw.text.length < 6) return _toast('Password must be at least 6 characters.');
    if (_pw.text != _pw2.text) return _toast('Passwords do not match');
    setState(() => _busy = true);
    try {
      await AuthService().setNewPassword(_pw.text);
      if (!mounted) return;
      _toast('Password updated.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text.verbatim('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: tr(context, hint),
        hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Geist'),
        filled: true,
        fillColor: AppColors.field(context),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: _blue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('New password'),
        titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Geist'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Text('Choose a new password for your account.',
              style: TextStyle(fontFamily: 'Geist')),
          const SizedBox(height: 16),
          TextField(
            controller: _pw,
            obscureText: !_visible,
            enabled: !_busy,
            decoration: _dec('New password').copyWith(
              suffixIcon: IconButton(
                icon: Icon(_visible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pw2,
            obscureText: !_visible,
            enabled: !_busy,
            decoration: _dec('Confirm password'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save password',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
