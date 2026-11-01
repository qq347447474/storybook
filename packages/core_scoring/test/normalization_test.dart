/// Normalization pipeline unit tests (decision ②: fixed English rules).
///
/// White-box tests against `src/normalization.dart`; behavior is also pinned
/// indirectly by `retell_scoring_test.dart`.
library;

import 'package:core_scoring/src/normalization.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeWords', () {
    test('lowercases everything', () {
      expect(normalizeWords('The Rain RAINED'), <String>[
        'the',
        'rain',
        'rained',
      ]);
    });

    test("expands I'm to i am", () {
      expect(normalizeWords("I'm happy"), <String>['i', 'am', 'happy']);
    });

    test('expands can\'t to can not', () {
      expect(normalizeWords("we can't go"), <String>[
        'we',
        'can',
        'not',
        'go',
      ]);
    });

    test('expands common suffix contractions', () {
      expect(normalizeWords("they're here"), <String>['they', 'are', 'here']);
      expect(normalizeWords("we've won"), <String>['we', 'have', 'won']);
      expect(normalizeWords("i'll see"), <String>['i', 'will', 'see']);
      expect(normalizeWords("he'd know"), <String>['he', 'would', 'know']);
      expect(normalizeWords("it's fine"), <String>['it', 'is', 'fine']);
    });

    test('expands n\'t contractions', () {
      expect(normalizeWords("don't stop"), <String>['do', 'not', 'stop']);
      expect(normalizeWords("isn't it"), <String>['is', 'not', 'it']);
    });

    test('converts numbers to words', () {
      expect(normalizeWords('3'), <String>['three']);
      expect(normalizeWords('12'), <String>['twelve']);
      expect(normalizeWords('21'), <String>['twenty', 'one']);
      expect(normalizeWords('105'), <String>['one', 'hundred', 'five']);
    });

    test('strips punctuation into spaces', () {
      expect(normalizeWords('rain, wind; and... "sun"!'), <String>[
        'rain',
        'wind',
        'and',
        'sun',
      ]);
    });

    test('handles mixed sentence end to end', () {
      expect(
        normalizeWords("Ada's 3 boats, can't you see?"),
        <String>['ada', 'is', 'three', 'boats', 'can', 'not', 'you', 'see'],
      );
    });
  });

  group('stemWord', () {
    test('rain family unifies', () {
      expect(stemWord('rain'), stemWord('raining'));
      expect(stemWord('rain'), stemWord('rained'));
      expect(stemWord('rain'), stemWord('rains'));
    });

    test('walk family unifies', () {
      expect(stemWord('walk'), stemWord('walked'));
      expect(stemWord('walk'), stemWord('walking'));
    });

    test('consonant doubling is undone', () {
      expect(stemWord('run'), stemWord('running'));
      expect(stemWord('stop'), stemWord('stopped'));
    });

    test('plural forms unify', () {
      expect(stemWord('boat'), stemWord('boats'));
      expect(stemWord('story'), stemWord('stories'));
      expect(stemWord('glass'), stemWord('glasses'));
    });

    test('is deterministic', () {
      for (final w in <String>['rain', 'raining', 'train', 'boats', 'walked']) {
        expect(stemWord(w), stemWord(w));
      }
    });
  });
}
