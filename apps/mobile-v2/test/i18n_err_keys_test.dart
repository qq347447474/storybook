/// Regression guard (T7d): the boot error-screen key `err.content` must
/// exist and be non-empty in every locale — the raw-key-name echo on the
/// real device traced back to an empty fallback catalog, and a missing key
/// would reproduce the same symptom.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('err.content exists non-empty in every locale (regression guard)', () {
    for (final String locale in <String>['en', 'zh-Hans', 'qps-ploc']) {
      final Map<String, dynamic> catalog = json.decode(
        File('../../i18n/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(catalog.containsKey('err.content'), isTrue,
          reason: '$locale must define err.content');
      expect((catalog['err.content'] as String).trim(), isNotEmpty,
          reason: '$locale err.content must not be empty');
      if (locale == 'qps-ploc') {
        expect(catalog['err.content'], contains('⟦'),
            reason: 'ploc values are wrapped (A3)');
      }
    }
  });
}
