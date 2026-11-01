import 'dart:io';

import 'package:core_content/core_content.dart';

/// Parse a pack.json exactly the way the app does and report every error.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/check_pack.dart <pack.json> [appVersion]');
    exit(2);
  }
  final text = File(args[0]).readAsStringSync();
  final appVersion = args.length > 1 ? args[1] : '1.0.0';
  final result = parsePack(text, appVersion: appVersion);
  switch (result) {
    case PackOk():
      print('OK  books=${result.pack.books.length} '
          'contentVersion=${result.pack.contentVersion} '
          'locales.content=${result.pack.locales.content} '
          'locales.gloss=${result.pack.locales.gloss}');
      for (final b in result.pack.books) {
        print('  - ${b.id} "${b.title}" chapters=${b.chapters.length} '
            'level=${b.level.cefr} words=${b.level.wordCount}');
      }
    case PackInvalid():
      print('INVALID  ${result.errors.length} error(s):');
      for (final e in result.errors) {
        print('  ${e.code}  ${e.pointer}  ${e.message}');
      }
      exit(1);
  }
}
