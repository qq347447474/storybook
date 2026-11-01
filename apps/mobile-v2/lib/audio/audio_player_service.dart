/// Audio playback abstraction for the reading screen.
///
/// The interface keeps widget tests free of platform channels: tests inject a
/// fake, production injects [JustAudioPlayerService] (just_audio). Platform
/// registration happens only in `apps/mobile` (C8).
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Audio state machine of `docs/08-ui-spec.md` §4:
/// idle -> loading -> playing <-> paused -> ended -> idle, plus error.
enum AudioPlaybackState {
  idle,
  loading,
  playing,
  paused,
  ended,
  error,
}

/// Playback engine used by the reading screen.
///
/// [load] never throws: failures surface as [AudioPlaybackState.error] on
/// [states] so the UI can show `err.audio` and a retry without crashing.
abstract class AudioPlayerService {
  AudioPlaybackState get state;

  /// State transitions of the audio machine.
  Stream<AudioPlaybackState> get states;

  /// Playhead position; callers derive sentence highlights from it by
  /// interval intersection (never by timer approximation).
  Stream<Duration> get positions;

  /// Duration of the currently loaded source.
  Duration get duration;

  /// Prepares [location] (file path or URL) for playback.
  Future<void> load(String location);

  /// Prepares a bundled asset ([ResolvedMedia.assetKey]) for playback.
  Future<void> loadAsset(String assetKey);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

/// just_audio-backed implementation.
class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
  }

  final AudioPlayer _player;
  final _states = StreamController<AudioPlaybackState>.broadcast();
  StreamSubscription<dynamic>? _stateSub;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  bool _loadFailed = false;
  double _speed = 1.0;

  StreamController<Duration>? _positions;
  StreamSubscription<PlaybackEvent>? _eventSub;
  Timer? _positionTimer;
  PlaybackEvent? _lastEvent;

  @override
  AudioPlaybackState get state => _state;

  @override
  Stream<AudioPlaybackState> get states => _states.stream;

  /// Real playhead position, extrapolated between platform events.
  ///
  /// just_audio's own `positionStream` caps its wall-clock extrapolation at
  /// the *estimated* source duration. For a VBR mp3 without a Xing header
  /// that estimate is up to a third short of the real stream (23 s of audio
  /// reported as 17 s), so the playhead freezes mid-paragraph while the
  /// audio keeps speaking — the sentence highlight stuck on one sentence
  /// while the rest was read aloud.
  ///
  /// The platform's `updatePosition` is the decoder's real position, so this
  /// ticker extrapolates from that and never clamps to an estimate.
  @override
  Stream<Duration> get positions {
    _positions ??= _createPositions();
    return _positions!.stream;
  }

  StreamController<Duration> _createPositions() {
    final StreamController<Duration> ctl =
        StreamController<Duration>.broadcast();
    _eventSub = _player.playbackEventStream.listen((PlaybackEvent event) {
      _lastEvent = event;
      if (!ctl.isClosed) ctl.add(_realPosition(event));
      _syncTicker(ctl);
    });
    return ctl;
  }

  /// The extrapolation timer runs only while audio is actually playing:
  /// a periodic timer that idles through pause/stop/idle would outlive the
  /// widget tree in tests and leak into the next one.
  void _syncTicker(StreamController<Duration> ctl) {
    final bool running = _player.playing &&
        _player.processingState == ProcessingState.ready;
    if (!running) {
      _positionTimer?.cancel();
      _positionTimer = null;
      return;
    }
    _positionTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      final PlaybackEvent? event = _lastEvent;
      if (event == null || ctl.isClosed) return;
      ctl.add(_realPosition(event));
    });
  }

  Duration _realPosition(PlaybackEvent event) {
    if (!_player.playing ||
        _player.processingState != ProcessingState.ready) {
      return event.updatePosition;
    }
    return event.updatePosition +
        (DateTime.now().difference(event.updateTime)) * _speed;
  }

  @override
  Duration get duration => _player.duration ?? Duration.zero;

  @override
  Future<void> load(String location) async {
    _loadFailed = false;
    _emit(AudioPlaybackState.loading);
    try {
      final AudioSource source = location.startsWith('http')
          ? AudioSource.uri(Uri.parse(location))
          : AudioSource.file(location);
      await _player.setAudioSource(source);
      _emit(AudioPlaybackState.paused);
    } on Exception catch (_) {
      _loadFailed = true;
      _emit(AudioPlaybackState.error);
    }
  }

  @override
  Future<void> loadAsset(String assetKey) async {
    _loadFailed = false;
    _emit(AudioPlaybackState.loading);
    try {
      await _player.setAudioSource(AudioSource.asset(assetKey));
      _emit(AudioPlaybackState.paused);
    } on Exception catch (_) {
      _loadFailed = true;
      _emit(AudioPlaybackState.error);
    }
  }

  @override
  Future<void> play() async {
    if (_loadFailed) return;
    try {
      await _player.play();
    } on Exception catch (_) {
      _emit(AudioPlaybackState.error);
    }
  }

  @override
  Future<void> pause() async {
    if (_loadFailed) return;
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_loadFailed) return;
    await _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _player.setSpeed(speed);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(AudioPlaybackState.idle);
  }

  @override
  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _eventSub?.cancel();
    await _positions?.close();
    await _stateSub?.cancel();
    await _states.close();
    await _player.dispose();
  }

  void _onPlayerState(PlayerState playerState) {
    if (_loadFailed) return;
    final AudioPlaybackState next;
    switch (playerState.processingState) {
      case ProcessingState.idle:
        next = AudioPlaybackState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        next = AudioPlaybackState.loading;
      case ProcessingState.ready:
        next =
            playerState.playing ? AudioPlaybackState.playing : AudioPlaybackState.paused;
      case ProcessingState.completed:
        next = AudioPlaybackState.ended;
    }
    _emit(next);
  }

  void _emit(AudioPlaybackState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}
