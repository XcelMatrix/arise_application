// Finds every language file in lib/translations/languages/ and writes
// lib/translations/registry.dart, so a new language only needs a new file.
//
// Usage (from the project folder):  dart run tool/generate_translations.dart
//
// Each language file must declare one top-level variable that holds an
// AppTranslation, written like:   final spanish = AppTranslation(
import 'dart:io';

void main() {
  final dir = Directory('lib/translations/languages');
  if (!dir.existsSync()) {
    stderr.writeln('Run this from the project folder (lib/translations/languages not found).');
    exit(1);
  }
  final entries = <(String file, String variable)>[];
  final declaration = RegExp(r'^(?:final|const)\s+(?:AppTranslation\s+)?(\w+)\s*=\s*AppTranslation\(',
      multiLine: true);
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    if (name == 'english.dart') continue; // built in
    final m = declaration.firstMatch(f.readAsStringSync());
    if (m == null) {
      stderr.writeln('Skipped $name: no "final x = AppTranslation(" found.');
      continue;
    }
    entries.add((name, m.group(1)!));
  }

  final b = StringBuffer()
    ..writeln('// GENERATED FILE - do not edit by hand.')
    ..writeln('// Add a language file to lib/translations/languages/ and run:')
    ..writeln('//   dart run tool/generate_translations.dart')
    ..writeln("import 'package:arise_application/translations/translation.dart';");
  for (final e in entries) {
    b.writeln("import 'package:arise_application/translations/languages/${e.$1}';");
  }
  b
    ..writeln()
    ..writeln('final List<AppTranslation> allTranslations = [');
  for (final e in entries) {
    b.writeln('  ${e.$2},');
  }
  b.writeln('];');
  File('lib/translations/registry.dart').writeAsStringSync(b.toString());
  stdout.writeln('Registered ${entries.length} language(s): ${entries.map((e) => e.$2).join(', ')}');
}
