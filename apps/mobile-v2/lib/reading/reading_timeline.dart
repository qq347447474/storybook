/// The virtual reading timeline of S2 (docs/13 D3).
///
/// Content still ships **paragraph-level** audio with sentence timestamps; there
/// is no chapter-level clip. The screen therefore builds one virtual timeline
/// from the content's own timestamps — a paragraph lasts until its **last
/// sentence's `endMs`** — and maps global positions back onto
/// (paragraph, offset) pairs. Nothing here probes a player: the numbers are the
/// pack's, so the timeline is identical on every device and in tests.
library;

import 'package:core_content/core_content.dart';

/// Start offsets and lengths of every paragraph of one chapter.
class ReadingTimeline {
  ReadingTimeline(List<Paragraph> paragraphs)
      : _durations = <int>[
          for (final Paragraph p in paragraphs) _durationOf(p),
        ],
        _starts = <int>[] {
    int cursor = 0;
    for (final int d in _durations) {
      _starts.add(cursor);
      cursor += d;
    }
    totalMs = cursor;
  }

  /// Length of [paragraph] in ms: the end of its last sentence, or `0` when the
  /// paragraph carries no sentence timeline (nothing to play).
  static int _durationOf(Paragraph paragraph) {
    final List<SpokenSentence> sentences = paragraph.audio.sentences;
    if (sentences.isEmpty) return 0;
    final int end = sentences.last.endMs;
    return end > 0 ? end : 0;
  }

  final List<int> _durations;
  final List<int> _starts;

  /// Sum of every paragraph's length — the virtual chapter duration.
  late final int totalMs;

  int get length => _durations.length;

  bool get isEmpty => length == 0;

  /// Whether [index] has playable timestamps.
  bool hasAudio(int index) => _durationAt(index) > 0;

  int _durationAt(int index) =>
      index < 0 || index >= _durations.length ? 0 : _durations[index];

  int startOf(int index) =>
      index < 0 || index >= _starts.length ? 0 : _starts[index];

  int durationOf(int index) => _durationAt(index);

  /// Paragraph that owns [globalMs], clamped into the chapter.
  int indexAt(int globalMs) {
    if (isEmpty) return 0;
    if (globalMs <= 0) return 0;
    for (int i = 0; i < _starts.length; i++) {
      final int end = _starts[i] + _durations[i];
      if (globalMs < end) return i;
    }
    return _starts.length - 1;
  }

  /// In-paragraph offset of [globalMs].
  int offsetIn(int globalMs) {
    final int index = indexAt(globalMs);
    final int offset = globalMs - startOf(index);
    if (offset < 0) return 0;
    final int duration = _durationAt(index);
    if (duration > 0 && offset > duration) return duration;
    return offset;
  }

  /// Global position of an (paragraph, offset) pair.
  int globalOf(int index, int inParagraphMs) {
    final int offset = inParagraphMs < 0 ? 0 : inParagraphMs;
    return startOf(index) + offset;
  }

  /// First paragraph at or after [from] that has timestamps, or `-1`.
  int firstPlayableFrom(int from) {
    for (int i = from < 0 ? 0 : from; i < length; i++) {
      if (hasAudio(i)) return i;
    }
    return -1;
  }
}
