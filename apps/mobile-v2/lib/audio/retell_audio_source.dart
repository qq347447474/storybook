/// Mic capture seam for the S5 retell screen (C8: the real `record`-package
/// binding is registered in `apps/mobile` main; tests inject a fake).
///
/// The recording is written to the app support directory only (docs/09 §6)
/// and deleted as soon as the attempt is superseded or the screen is left.
/// ASR itself lives inside `SpeechEngine` — this seam only owns the audio
/// file used for playback and the platform interruption events.
library;

/// Why a running capture was killed by the platform (docs/09 §5).
enum RecordingInterruption {
  /// Call or another app seized the microphone: stop, DISCARD the partial
  /// audio, prompt a retry.
  callOrSeized,

  /// App moved to background: stop recording (no foreground service).
  background,

  /// Permission was revoked mid-session: back to guidance, discard.
  permissionRevoked,
}

abstract class RetellAudioSource {
  /// Starts recording into a fresh file; resolves when capture is running.
  Future<void> start();

  /// Finalises the recording and returns its file path (for playback).
  Future<String> stop();

  /// Deletes the current recording (privacy / interruption paths).
  Future<void> discard();

  /// Platform interruption events while [start]..[stop] is active.
  Stream<RecordingInterruption> get interruptions;
}
