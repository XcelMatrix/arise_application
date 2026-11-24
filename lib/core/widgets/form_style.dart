import 'package:flutter/material.dart' hide Text;
import 'package:arise_application/core/theme/app_colors.dart';
import 'package:arise_application/translations/translated_text.dart';

/// One look for every add / edit form dialog (same as "Add Attendance"):
/// dark cyan title and text, rounded boxes with a cyan border.
const kFormBlue = Color(0xFF3C6E87);
const kFormText = TextStyle(color: kFormBlue, fontFamily: 'Geist');
const kFormTitle =
    TextStyle(fontFamily: 'Geist', color: kFormBlue, fontWeight: FontWeight.bold);

InputDecoration formDec(BuildContext context, String label,
    {String? hint, Widget? suffix}) {
  OutlineInputBorder b(double w) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: kFormBlue, width: w),
      );
  return InputDecoration(
    labelText: tr(context, label),
    hintText: hint == null ? null : tr(context, hint),
    labelStyle: kFormText,
    hintStyle: TextStyle(
        color: kFormBlue.withValues(alpha: 0.6), fontFamily: 'Geist'),
    counterText: '',
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.field(context).withValues(alpha: 0.35),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: b(1),
    enabledBorder: b(1),
    focusedBorder: b(2),
  );
}

/// A labelled text box with the shared look and the gap above it.
Widget formField(BuildContext context, TextEditingController c, String label,
        {String? hint,
        int lines = 1,
        int max = 4000,
        TextCapitalization caps = TextCapitalization.sentences,
        TextInputType? keyboard,
        Widget? suffix,
        ValueChanged<String>? onChanged,
        double top = 12}) =>
    Padding(
      padding: EdgeInsets.only(top: top),
      child: TextField(
        controller: c,
        style: kFormText,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        maxLength: max,
        keyboardType: keyboard,
        textCapitalization: caps,
        onChanged: onChanged,
        decoration: formDec(context, label, hint: hint, suffix: suffix),
      ),
    );

/// Frees text controllers after the dialog has finished closing. Disposing
/// them straight away (e.g. when the phone's back button closes the dialog)
/// can leave a text box using a dead controller and freeze the app.
void disposeLater(Iterable<TextEditingController> controllers) {
  Future.delayed(const Duration(milliseconds: 800), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}
