import 'package:arise_application/translations/translation.dart';

/// Picks the text that matches the language chosen in Settings.
/// Filipino shows the Filipino text; every other language shows English.
/// If the wanted version is empty, the other one is used so nothing is blank.
String pickLang(String en, String fil) {
  final filipino = Tr.current.code == 'fil';
  final want = filipino ? fil : en;
  if (want.trim().isNotEmpty) return want;
  return filipino ? en : fil;
}
