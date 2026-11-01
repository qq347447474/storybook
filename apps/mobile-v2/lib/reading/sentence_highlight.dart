/// Sentence highlight by interval intersection (`docs/08-ui-spec.md` §4).
///
/// The current sentence is derived purely from the playhead position and the
/// sentence time spans — never by timer approximation.
library;

import 'package:core_content/core_content.dart';

/// Index of the sentence whose `[startMs, endMs)` interval contains
/// [positionMs], or -1 when the playhead sits in a gap.
///
/// Half-open intervals: a playhead exactly at a sentence end belongs to the
/// next sentence. At the very end of the timeline (`positionMs` equals the
/// last `endMs`) the last sentence stays highlighted.
int sentenceIndexAt(int positionMs, List<SpokenSentence> sentences) {
  for (var i = 0; i < sentences.length; i++) {
    final SpokenSentence s = sentences[i];
    if (positionMs >= s.startMs && positionMs < s.endMs) return i;
  }
  if (sentences.isNotEmpty && positionMs == sentences.last.endMs) {
    return sentences.length - 1;
  }
  return -1;
}
