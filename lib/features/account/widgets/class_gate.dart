import 'package:flutter/material.dart' hide Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/features/account/cubit/account_cubit.dart';
import 'package:arise_application/features/attendance/models/attendance_models.dart'
    show gradeOptions;
import 'package:arise_application/translations/translated_text.dart';

/// Students are asked for their grade and section once, right after they
/// log in. Everyone else goes straight to [child].
class ClassGate extends StatelessWidget {
  const ClassGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final needs = context.select<AccountCubit, bool>((c) => c.state.needsClass);
    return needs ? const ClassSetupPage() : child;
  }
}

/// Also opened from the profile page to change the class later.
class ClassSetupPage extends StatefulWidget {
  const ClassSetupPage({super.key, this.canClose = false});

  /// true when opened from the profile (shows a back button)
  final bool canClose;

  static Route<void> route() => MaterialPageRoute(
      builder: (_) => const ClassSetupPage(canClose: true));

  @override
  State<ClassSetupPage> createState() => _ClassSetupPageState();
}

class _ClassSetupPageState extends State<ClassSetupPage> {
  static const _blue = Color(0xFF3C6E87);
  String? _grade;
  final _section = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final a = context.read<AccountCubit>().state;
    if (a.grade != null && gradeOptions.contains(a.grade)) _grade = a.grade;
    _section.text = a.section ?? '';
  }

  @override
  void dispose() {
    _section.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final m = ScaffoldMessenger.of(context);
    if (_grade == null || _section.text.trim().isEmpty) {
      m.showSnackBar(
          SnackBar(content: Text(tr(context, 'Pick your grade and type your section.'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AccountCubit>().setClass(_grade!, _section.text);
      if (mounted && widget.canClose) Navigator.pop(context);
    } catch (e) {
      m.showSnackBar(SnackBar(
          content: Text.verbatim(e is PostgrestException ? e.message : '$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canClose,
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: AppBar(
          automaticallyImplyLeading: widget.canClose,
          backgroundColor: _blue,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Your class'),
          titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Geist'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const Icon(Icons.school, size: 72, color: _blue),
            const SizedBox(height: 16),
            const Text(
                'What is your grade and section? Your teachers use this to find you in their class lists and attendance.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _grade,
              decoration: InputDecoration(
                labelText: tr(context, 'Grade'),
                filled: true,
                fillColor: AppColors.field(context),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none),
              ),
              items: [
                for (final g in gradeOptions)
                  DropdownMenuItem(value: g, child: Text.verbatim(g)),
              ],
              onChanged: (v) => setState(() => _grade = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _section,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr(context, 'Section'),
                filled: true,
                fillColor: AppColors.field(context),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _blue),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
