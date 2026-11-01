/// Sentence highlight interval logic (docs/08 §4): pure interval
/// intersection, no timer approximation.
library;

import 'package:core_content/core_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/reading/sentence_highlight.dart';

List<SpokenSentence> three() => const <SpokenSentence>[
      SpokenSentence(text: 'one', startMs: 0, endMs: 1000),
      SpokenSentence(text: 'two', startMs: 1000, endMs: 2000),
      SpokenSentence(text: 'three', startMs: 2000, endMs: 3000),
    ];

void main() {
  test('playhead inside a sentence selects it', () {
    expect(sentenceIndexAt(0, three()), 0);
    expect(sentenceIndexAt(999, three()), 0);
    expect(sentenceIndexAt(1000, three()), 1);
    expect(sentenceIndexAt(1500, three()), 1);
    expect(sentenceIndexAt(2500, three()), 2);
  });

  test('intervals are half-open: a boundary belongs to the next sentence', () {
    expect(sentenceIndexAt(1000, three()), 1);
    expect(sentenceIndexAt(2000, three()), 2);
  });

  test('the very end of the timeline keeps the last sentence', () {
    expect(sentenceIndexAt(3000, three()), 2);
  });

  test('gaps between sentences highlight nothing', () {
    const withGap = <SpokenSentence>[
      SpokenSentence(text: 'one', startMs: 0, endMs: 1000),
      SpokenSentence(text: 'two', startMs: 2000, endMs: 3000),
    ];
    expect(sentenceIndexAt(1500, withGap), -1);
    expect(sentenceIndexAt(1000, withGap), -1);
  });

  test('empty timeline highlights nothing', () {
    expect(sentenceIndexAt(0, const <SpokenSentence>[]), -1);
  });
}
