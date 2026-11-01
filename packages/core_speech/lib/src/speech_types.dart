/// Speech capture types shared by engine bindings (`docs/07-modules.md` §4).
///
/// VAD contract: the engine runs voice activity detection internally. The
/// upper layer only ever sees [SpeechSegment]s with silence already trimmed;
/// pause gaps for scoring are derived from the silence runs BETWEEN
/// consecutive segments (see `transcriptFromCapture`).
library;

/// One partial recognition hypothesis streamed while recording.
class SpeechPartial {
  const SpeechPartial({required this.text, required this.isFinal});

  /// Raw recognition text (no normalisation — that happens inside
  /// `scoreRetell`, decision ②).
  final String text;

  /// True for the segment-final hypothesis of a VAD segment.
  final bool isFinal;
}

/// One VAD-segmented speech chunk (silence trimmed at both ends).
class SpeechSegment {
  const SpeechSegment({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  /// Start of speech inside the recording timeline.
  final int startMs;

  /// End of speech inside the recording timeline.
  final int endMs;

  /// Raw recognition text of this segment.
  final String text;
}

/// Everything a capture session produced, as reported by the binding when
/// recording stops.
class SpeechCapture {
  const SpeechCapture({
    required this.segments,
    required this.durationMs,
  });

  /// Speech segments ordered by [SpeechSegment.startMs].
  final List<SpeechSegment> segments;

  /// Wall-clock duration of the whole recording (ms).
  final int durationMs;
}

/// Lifecycle of an engine:
/// `idle -> ready -> listening -> ready ...` plus a terminal `disposed`.
enum SpeechEngineState {
  idle,
  ready,
  listening,
  disposed,
}
