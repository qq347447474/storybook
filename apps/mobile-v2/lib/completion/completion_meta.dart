/// Pure derivations behind S6 (design-spec §4.7).
///
/// The completion screen shows no score and no rating (`docs/04` §3), so every
/// number it *does* show has to come from the content itself: the closing line
/// of the chapter and the number of target words it taught.
library;

import 'package:core_content/core_content.dart';

/// Longest closing line the quote card will render before it is trimmed — the
/// card is 300 dp wide, so anything past this stops being a "quote".
const int _quoteLimit = 140;

/// First sentence of the **last** non-empty paragraph of [chapter], verbatim in
/// the content language (docs/03 §1: story text is never translated).
///
/// Returns `''` when the chapter ships no reading text; the caller then hides
/// the whole card instead of rendering an empty frame.
String closingQuote(Chapter chapter) {
  for (int i = chapter.reading.length - 1; i >= 0; i--) {
    final String text = chapter.reading[i].text.trim();
    if (text.isEmpty) continue;
    // Split on the same boundary S0's summary uses: a period followed by a
    // space. A one-sentence paragraph keeps its full text (trailing period
    // included), so the quote always closes.
    final int stop = text.indexOf('. ');
    final String first = stop > 0 ? text.substring(0, stop + 1) : text;
    return first.length > _quoteLimit
        ? '${first.substring(0, _quoteLimit - 1)}…'
        : first;
  }
  return '';
}

/// Target vocabulary the chapter taught.
///
/// Falls back to the full vocabulary count when a pack marks nothing as
/// `isTarget` (old packs), and to `0` when the chapter has no words at all —
/// the body sentence is then dropped rather than claiming "0 new words".
int targetWordCount(Chapter chapter) {
  int targets = 0;
  for (final VocabItem item in chapter.vocabulary) {
    if (item.isTarget) targets++;
  }
  return targets > 0 ? targets : chapter.vocabulary.length;
}
