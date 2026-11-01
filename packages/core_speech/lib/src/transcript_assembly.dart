/// Transcript assembly from VAD-segmented capture output.
///
/// Pure function: the text is the raw ASR output joined across segments
/// (decision ② — normalisation lives in `scoreRetell`); pause gaps are the
/// silence runs between consecutive VAD segments (docs/04 §2.3 pause rule).
library;

import 'package:core_scoring/core_scoring.dart';

import 'speech_types.dart';

/// Builds the scoring [Transcript] from one capture session.
///
/// - `text`: segment texts joined with single spaces (raw, unnormalised).
/// - `durationMs`: wall-clock recording duration from the capture.
/// - `pauseGapsMs`: positive silence runs between consecutive segments,
///   in timeline order. Overlapping segments (invalid VAD output) are
///   skipped rather than producing negative gaps.
Transcript transcriptFromCapture(SpeechCapture capture) {
  final List<SpeechSegment> segments =
      List<SpeechSegment>.of(capture.segments)
        ..sort((SpeechSegment a, SpeechSegment b) => a.startMs.compareTo(b.startMs));
  final List<String> texts = <String>[
    for (final SpeechSegment s in segments)
      if (s.text.trim().isNotEmpty) s.text.trim(),
  ];
  final List<int> gaps = <int>[];
  for (var i = 0; i + 1 < segments.length; i++) {
    final int gap = segments[i + 1].startMs - segments[i].endMs;
    if (gap > 0) gaps.add(gap);
  }
  return Transcript(
    text: texts.join(' '),
    durationMs: capture.durationMs,
    pauseGapsMs: gaps,
  );
}
