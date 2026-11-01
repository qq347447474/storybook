/// [ClipWindow] — playing a window of one clip and stopping at its boundary.
///
/// Two behaviours are easy to get wrong on device and are pinned here:
/// the position stream of a real player *replays* its last value to every new
/// listener (a stale one from a previous playback must not stop the new one),
/// and the stop has to happen even when no position event arrives at all.
library;

import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/audio/clip_window.dart';

/// Media lookup that always resolves to a cached file.
class _FakeResolver implements MediaResolver {
  const _FakeResolver();

  @override
  Future<ResolvedMedia?> resolve(String url) async => ResolvedMedia(
        origin: MediaOrigin.cached,
        location: '/cache/$url',
      );
}

/// A player whose position stream behaves like just_audio's: every new
/// subscriber first receives the latest value, then live ones.
class _FakePlayer implements AudioPlayerService {
  _FakePlayer({Duration? replay}) {
    if (replay != null) _last = replay;
  }

  final List<String> calls = <String>[];
  final List<StreamController<Duration>> _listeners =
      <StreamController<Duration>>[];
  final StreamController<AudioPlaybackState> _states =
      StreamController<AudioPlaybackState>.broadcast();
  Duration _last = Duration.zero;

  /// Push a playhead position, remembering it as the replay value.
  void emit(Duration pos) {
    _last = pos;
    for (final StreamController<Duration> c in List.of(_listeners)) {
      c.add(pos);
    }
  }

  @override
  AudioPlaybackState get state => AudioPlaybackState.idle;

  @override
  Stream<AudioPlaybackState> get states => _states.stream;

  @override
  Stream<Duration> get positions {
    // BehaviourSubject semantics: replay the last value to this listener,
    // then forward live events. A broadcast `async*` would drop events that
    // fire before its own subscription to the source is in place.
    late final StreamController<Duration> ctl;
    ctl = StreamController<Duration>.broadcast(
      onListen: () => ctl.add(_last),
      onCancel: () => _listeners.remove(ctl),
    );
    _listeners.add(ctl);
    return ctl.stream;
  }

  @override
  Duration get duration => Duration.zero;

  @override
  Future<void> load(String location) async => calls.add('load:$location');

  @override
  Future<void> loadAsset(String assetKey) async =>
      calls.add('loadAsset:$assetKey');

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {}
}

void main() {
  test('a stale replayed position does not stop the new window', () async {
    // The previous playback ended at 22.8 s; this window ends at 4.39 s.
    final _FakePlayer player = _FakePlayer(replay: const Duration(milliseconds: 22880));
    final ClipWindow window = ClipWindow();

    final bool started = await window.play(
      resolver: const _FakeResolver(),
      player: player,
      url: 'media/ch1-p3.mp3',
      startMs: 0,
      endMs: 4390,
    );
    expect(started, isTrue);
    // Loaded and playing — and *not* stopped by the replayed 22 880 ms.
    expect(player.calls, contains('load:/cache/media/ch1-p3.mp3'));
    expect(player.calls, contains('play'));
    expect(player.calls.where((String c) => c == 'stop'), hasLength(1),
        reason: 'only the stop() before load, none from the stale replay');

    await window.dispose();
  });

  test('stops at the boundary once the playhead crosses it', () async {
    final _FakePlayer player = _FakePlayer();
    final ClipWindow window = ClipWindow();

    await window.play(
      resolver: const _FakeResolver(),
      player: player,
      url: 'media/ch1-p3.mp3',
      startMs: 0,
      endMs: 4390,
    );
    player.emit(Duration.zero); // real position, arms the watcher
    player.emit(const Duration(milliseconds: 3000));
    expect(player.calls.where((String c) => c == 'stop'), hasLength(1));

    player.emit(const Duration(milliseconds: 4500));
    // The stop is deliberately deferred off the listener (see [_requestHalt]),
    // so give it a timer turn to run.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(player.calls.where((String c) => c == 'stop'), hasLength(2),
        reason: 'the window is over: playback must stop');

    await window.dispose();
  });

  test('stops on the wall clock when no position arrives', () async {
    final _FakePlayer player = _FakePlayer();
    final ClipWindow window = ClipWindow();

    await window.play(
      resolver: const _FakeResolver(),
      player: player,
      url: 'media/ch1-p3.mp3',
      startMs: 0,
      // A short window keeps the test quick; the +300 ms slack is the point.
      endMs: 120,
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(player.calls.where((String c) => c == 'stop'), hasLength(2),
        reason: 'the timer is the backstop when the position stream is silent');

    await window.dispose();
  });

  test('watchdogs are armed even when play() only returns at the end', () async {
    // just_audio's `play()` future completes when playback completes, pauses
    // or stops. A player that models that (the future never completes until
    // `stop`) must still get stopped at the boundary — arming the watchdogs
    // after `await play()` would arm them once the clip had already ended.
    final _BlockingPlayer player = _BlockingPlayer();
    final ClipWindow window = ClipWindow();

    final Future<bool> started = window.play(
      resolver: const _FakeResolver(),
      player: player,
      url: 'media/ch1-p3.mp3',
      startMs: 0,
      endMs: 120,
    );
    // The wall clock fires at endMs + 300 ms and stops playback, which in turn
    // completes the blocked play().
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(player.calls.where((String c) => c == 'stop'), hasLength(2),
        reason: 'the window is over: the watchdog stopped a play() still pending');
    expect(await started, isTrue);

    await window.dispose();
  });
}

/// A player whose `play()` behaves like just_audio's: the future completes
/// only when playback completes, pauses or stops.
class _BlockingPlayer implements AudioPlayerService {
  final List<String> calls = <String>[];
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  final StreamController<AudioPlaybackState> _states =
      StreamController<AudioPlaybackState>.broadcast();
  Completer<void>? _playGate;

  @override
  AudioPlaybackState get state => AudioPlaybackState.idle;

  @override
  Stream<AudioPlaybackState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get duration => Duration.zero;

  @override
  Future<void> load(String location) async => calls.add('load:$location');

  @override
  Future<void> loadAsset(String assetKey) async =>
      calls.add('loadAsset:$assetKey');

  @override
  Future<void> play() async {
    calls.add('play');
    _playGate = Completer<void>();
    await _playGate!.future;
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playGate?.complete();
    _playGate = null;
  }

  @override
  Future<void> dispose() async {}
}
