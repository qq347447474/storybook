/// Plays a *window* of a clip — `startMs..endMs` inside one audio file — and
/// stops at the boundary (design-spec §4.4: the card's back speaker reads the
/// example sentence, not the whole paragraph).
///
/// The paragraph clip is a single file, so a sentence is a seek and a stop.
/// Both halves need care on device:
///
/// * **start**: a `BehaviorSubject`-backed position stream replays the last
///   value to every new listener. A stale position from the paragraph the
///   learner just read would cross `endMs` on arrival and stop playback the
///   instant it begins, so the first event is ignored.
/// * **stop**: the position stream ticks at most every 200 ms and only while
///   playing, so a wall-clock timer armed with the window's own length is the
///   backstop; the earliest of the two wins. Both watchdogs are armed BEFORE
///   playback is requested: just_audio's `play()` future completes only when
///   playback completes, pauses or stops, so arming after `await play()` arms
///   them once the clip has already ended — the window then talks past its
///   boundary to the end of the file.
library;

import 'dart:async';

import 'package:core_content/core_content.dart';

import 'audio_player_service.dart';

/// One playing window. Call [dispose] when the screen goes away.
class ClipWindow {
  ClipWindow();

  StreamSubscription<Duration>? _positions;
  Timer? _timer;
  AudioPlayerService? _player;
  bool _stopping = false;

  /// Bumped by [dispose] so a halt queued by a superseded window can never
  /// stop the playback that replaced it (the player is shared).
  int _generation = 0;

  /// Play `startMs..endMs` of [url]. Returns false when the media cannot be
  /// resolved — the caller keeps its UI quiet rather than pretending.
  Future<bool> play({
    required MediaResolver resolver,
    required AudioPlayerService player,
    required String url,
    required int startMs,
    required int endMs,
  }) async {
    await dispose();
    _player = player;
    try {
      await player.stop();
      final ResolvedMedia? media = await resolver.resolve(url);
      if (media == null) return false;
      if (media.origin == MediaOrigin.bundled) {
        await player.loadAsset(media.assetKey!);
      } else {
        await player.load(media.location);
      }
      if (startMs > 0) {
        await player.seek(Duration(milliseconds: startMs));
      }
      // Arm the stop guarantees BEFORE requesting playback. just_audio's
      // `play()` future completes only when playback completes, pauses or
      // stops, so awaiting it first would arm the watchdogs once the clip had
      // already ended and the window would run to the end of the file.
      _arm(player, startMs, endMs);
      await player.play();
      return true;
    } catch (_) {
      await dispose();
      return false;
    }
  }

  void _arm(AudioPlayerService player, int startMs, int endMs) {
    bool armed = false;
    _positions = player.positions.listen((Duration pos) {
      if (!armed) {
        // First event: whatever it says, it is not evidence about *this*
        // playback. A replayed position from the previous one arrives here and
        // would otherwise stop the clip the instant it begins.
        armed = true;
        return;
      }
      if (pos.inMilliseconds >= endMs) {
        _requestHalt();
      }
    });

    // Backstop: the window's own length plus slack for the platform's start
    // latency. The position watcher is usually first; this guarantees a stop
    // even when it is silent.
    final int spanMs = endMs - startMs;
    _timer = Timer(Duration(milliseconds: spanMs + 300), _requestHalt);
  }

  /// Stop from outside the position callback.
  ///
  /// Halting *inside* the listener cancels the very subscription that is
  /// delivering the event, and the stop can be queued behind that cancellation
  /// — the clip then talks past its boundary even though the watcher fired.
  void _requestHalt() {
    if (_stopping) return;
    _stopping = true;
    final int generation = _generation;
    Timer.run(() {
      // The window may have been replaced while this halt was queued; its
      // playback is not ours to stop.
      if (generation != _generation) return;
      unawaited(_halt());
    });
  }

  Future<void> _halt() async {
    final AudioPlayerService? player = _player;
    _timer?.cancel();
    _timer = null;
    // `stop`, not `pause`: the window is over, the source should not linger in
    // a resumable state that would keep talking if anything else calls play().
    // Stopping comes first — cancelling the subscription must never gate it.
    await player?.stop();
    await _positions?.cancel();
    _positions = null;
    _stopping = false;
  }

  Future<void> dispose() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    await _positions?.cancel();
    _positions = null;
    final AudioPlayerService? player = _player;
    _player = null;
    _stopping = false;
    // Closing the window must not leave audio talking: the player is shared,
    // and stopping it here is exactly what the next `play()` does first.
    await player?.stop();
  }
}
