/// The S2 playback engine (docs/13 D3).
///
/// Owns everything that touches media and the decoder, so the screen stays a
/// layout: resolving paragraph audio, walking paragraphs on the **virtual
/// timeline** (`ReadingTimeline`), mapping a seek fraction back onto
/// (paragraph, offset), skipping paragraphs whose audio is missing, and keeping
/// the speed.
///
/// The pack has no chapter-level clip; the playhead the UI shows is therefore
/// `sum of earlier paragraphs + offset inside the active one`. A paragraph ends
/// at its last sentence's `endMs` (content timestamps, never a decoder probe).
library;

import 'dart:async';

import 'package:core_content/core_content.dart';
import 'package:flutter/foundation.dart';

import '../audio/audio_player_service.dart';
import 'reading_timeline.dart';

class ReadingPlayback extends ChangeNotifier {
  ReadingPlayback({
    required this.paragraphs,
    required this.resolver,
    required this.player,
  }) {
    _stateSub = player.states.listen(_onPlayerState);
    _positionSub = player.positions.listen(_onPosition);
  }

  /// Paragraphs of the chapter, in reading order.
  final List<Paragraph> paragraphs;
  final MediaResolver resolver;
  final AudioPlayerService player;

  /// Virtual chapter timeline built from the content's own timestamps.
  late final ReadingTimeline timeline = ReadingTimeline(paragraphs);

  final Map<String, ResolvedMedia?> _media = <String, ResolvedMedia?>{};
  final Set<String> _resolving = <String>{};
  final Set<String> _failed = <String>{};

  int _active = 0;
  Duration _inParagraph = Duration.zero;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  double _speed = 1.0;
  bool _started = false;
  bool _disposed = false;

  /// True once the position safety net has fired for the active paragraph,
  /// so a stale `ended` cannot double-advance past the next one.
  bool _atDeclaredEnd = false;

  /// Offset the active paragraph was opened at; positions further beyond
  /// `offset + 2 s` that arrive before any fresh sample belong to the
  /// previous clip and are ignored.
  int _openOffsetMs = 0;
  bool _positionsLive = false;
  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  /// Paragraph the player is loaded on.
  int get active => _active;

  /// True once playback has begun (drives the sentence highlight).
  bool get started => _started;

  /// Position inside the active paragraph.
  Duration get positionInParagraph => _inParagraph;

  /// Virtual position across the chapter.
  Duration get globalPosition => Duration(
        milliseconds: timeline.globalOf(_active, _inParagraph.inMilliseconds),
      );

  /// Virtual chapter duration.
  Duration get totalDuration => Duration(milliseconds: timeline.totalMs);

  AudioPlaybackState get state => _state;

  bool get isPlaying => _state == AudioPlaybackState.playing;

  double get speed => _speed;

  /// Media of [paragraphId]; `null` means "unavailable" (placeholder + retry).
  ResolvedMedia? mediaOf(String paragraphId) => _media[paragraphId];

  bool isResolving(String paragraphId) => _resolving.contains(paragraphId);

  bool failed(String paragraphId) => _failed.contains(paragraphId);

  /// True when at least one paragraph has timestamps, media **and** a load that
  /// has not failed — the gate of the player's enabled state (§4.3 "音频缺失：
  /// 播放器禁用").
  bool get playable {
    for (int i = 0; i < paragraphs.length; i++) {
      final String id = paragraphs[i].id;
      if (_media[id] != null && !_failed.contains(id) && timeline.hasAudio(i)) {
        return true;
      }
    }
    return false;
  }

  /// Resolves every paragraph's audio up front so skipping is instant.
  Future<void> start() async {
    for (final Paragraph p in paragraphs) {
      await _ensureResolved(p.id);
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await player.pause();
      return;
    }
    if (_started && mediaOf(paragraphs[_active].id) != null) {
      await player.setSpeed(_speed);
      await player.play();
      return;
    }
    final int first = timeline.firstPlayableFrom(0);
    if (first >= 0) await open(first, offsetMs: 0);
  }

  /// Seek to a `0..1` fraction of the **virtual** duration.
  Future<void> seekFraction(double fraction) async {
    final int total = timeline.totalMs;
    if (total <= 0) return;
    final int globalMs = (fraction * total).round().clamp(0, total);
    final int index = timeline.indexAt(globalMs);
    final int offset = timeline.offsetIn(globalMs);
    if (index == _active && _started && mediaOf(paragraphs[index].id) != null) {
      await player.seek(Duration(milliseconds: offset));
      return;
    }
    await open(index, offsetMs: offset, play: _started || isPlaying);
  }

  /// Tapping a sentence starts playback at its first word (§4.3).
  Future<void> playSentence(int paragraphIndex, int sentenceIndex) async {
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) return;
    final List<SpokenSentence> sentences =
        paragraphs[paragraphIndex].audio.sentences;
    if (sentenceIndex < 0 || sentenceIndex >= sentences.length) return;
    final int startMs = sentences[sentenceIndex].startMs;
    if (paragraphIndex == _active &&
        _started &&
        mediaOf(paragraphs[paragraphIndex].id) != null) {
      await player.seek(Duration(milliseconds: startMs));
      await player.play();
      return;
    }
    await open(paragraphIndex, offsetMs: startMs);
  }

  Future<void> cycleSpeed() async {
    const List<double> steps = <double>[0.75, 1.0, 1.25, 1.5];
    final int next = (steps.indexOf(_speed) + 1) % steps.length;
    _speed = steps[next];
    notifyListeners();
    await player.setSpeed(_speed);
  }

  /// Clears a failed resolution/load and tries again (C6 retry).
  ///
  /// A clip that resolved but failed to load must be handed back to the
  /// player — re-resolving alone would leave the learner staring at the same
  /// grey row.
  Future<void> retry(String paragraphId) async {
    _media.remove(paragraphId);
    _failed.remove(paragraphId);
    notifyListeners();
    final ResolvedMedia? media = await _ensureResolved(paragraphId);
    if (_disposed || media == null) return;
    final int index =
        paragraphs.indexWhere((Paragraph p) => p.id == paragraphId);
    if (index < 0) return;
    await open(
      index,
      offsetMs: index == _active ? _inParagraph.inMilliseconds : 0,
    );
  }

  /// Loads [index] and, when asked, plays from [offsetMs].
  Future<void> open(int index, {required int offsetMs, bool play = true}) async {
    if (index < 0 || index >= paragraphs.length) return;
    final Paragraph paragraph = paragraphs[index];
    final ResolvedMedia? media = await _ensureResolved(paragraph.id);
    if (_disposed) return;
    if (media == null) {
      // Silent skip: the rest of the chapter is still playable (§4.3).
      final int next = timeline.firstPlayableFrom(index + 1);
      if (next >= 0) return open(next, offsetMs: 0, play: play);
      notifyListeners();
      return;
    }
    await player.stop();
    if (_disposed) return;
    _active = index;
    _started = true;
    _atDeclaredEnd = false;
    _openOffsetMs = offsetMs;
    _positionsLive = false;
    _inParagraph = Duration(milliseconds: offsetMs);
    notifyListeners();

    final String? assetKey = media.assetKey;
    if (media.origin == MediaOrigin.bundled && assetKey != null) {
      await player.loadAsset(assetKey);
    } else {
      await player.load(media.location);
    }
    await player.setSpeed(_speed);
    if (offsetMs > 0) {
      await player.seek(Duration(milliseconds: offsetMs));
    }
    if (play) await player.play();
  }

  Future<ResolvedMedia?> _ensureResolved(String paragraphId) async {
    if (_media.containsKey(paragraphId)) return _media[paragraphId];
    if (_resolving.contains(paragraphId)) return null;
    _resolving.add(paragraphId);
    notifyListeners();
    ResolvedMedia? resolved;
    try {
      resolved = await resolver.resolve(_urlOf(paragraphId));
    } on Exception catch (_) {
      resolved = null;
    }
    if (_disposed) return resolved;
    _resolving.remove(paragraphId);
    _media[paragraphId] = resolved;
    notifyListeners();
    return resolved;
  }

  String _urlOf(String paragraphId) {
    for (final Paragraph p in paragraphs) {
      if (p.id == paragraphId) return p.audio.url;
    }
    return '';
  }

  void _onPosition(Duration position) {
    if (_disposed) return;
    final int raw = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    final int limit = timeline.durationOf(_active);

    // Samples from the previous clip can still land after `open()` has
    // switched paragraphs — a 3 s tail on the previous paragraph would look
    // like an instant end on a 1.5 s one. Ignore anything implausibly far
    // past the open offset until a fresh sample proves the stream is live.
    if (!_positionsLive) {
      if (raw > _openOffsetMs + 2000) return;
      _positionsLive = true;
    }

    // The pack's own timeline is the source of truth for the chapter progress
    // bar: clamp so no player quirk can drag the playhead past a paragraph's
    // declared length — and therefore past the chapter total (the bar kept
    // running past its own 1:33 end on files whose container metadata lied
    // about their length).
    int ms = raw;
    if (ms < 0) ms = 0;
    if (limit > 0 && ms > limit) ms = limit;
    _inParagraph = Duration(milliseconds: ms);
    notifyListeners();

    // Safety net for a container that overstates its own length: just_audio
    // then never emits `ended` at the real end, auto-advance stalls on the
    // paragraph and the learner hears silence for the rest of the chapter
    // (the-runaway-moon-base ch1-p2: an 8 kbps first frame made 23.6 s of
    // audio look like 173 s, so p3/p4 never started). When the playhead
    // reaches the pack's declared end while the player still claims to be
    // playing, treat that as the paragraph boundary ourselves.
    if (limit > 0 &&
        raw >= limit &&
        _state == AudioPlaybackState.playing &&
        !_atDeclaredEnd) {
      _atDeclaredEnd = true;
      _skipToNext(play: true, forceStop: true);
    }
  }

  void _onPlayerState(AudioPlaybackState state) {
    if (_disposed) return;
    if (state == AudioPlaybackState.ended) {
      // Two ways `ended` is not a real paragraph boundary:
      // 1. the position safety net already rolled us on (`_atDeclaredEnd`);
      // 2. a stale `ended` from the previous source landed after `open()`
      //    moved to a new paragraph — the playhead sits at its start, nowhere
      //    near its end. Keep the playing state instead of tearing it down.
      if (_atDeclaredEnd) return;
      final int limit = timeline.durationOf(_active);
      if (limit > 0 && _inParagraph.inMilliseconds < limit - 1000) return;
    }
    _state = state;
    notifyListeners();
    if (state == AudioPlaybackState.error) {
      // Surface the failure with a retry instead of walking past it: a clip
      // that fails to load is not the same as one the pack never shipped.
      if (paragraphs.isNotEmpty) _failed.add(paragraphs[_active].id);
      notifyListeners();
    } else if (state == AudioPlaybackState.ended) {
      _skipToNext(play: true);
    }
  }

  void _skipToNext({required bool play, bool forceStop = false}) {
    final int next = timeline.firstPlayableFrom(_active + 1);
    if (next < 0) {
      _inParagraph = Duration(milliseconds: timeline.durationOf(_active));
      notifyListeners();
      // End of chapter driven by the position safety net: the player is
      // still "playing" silence toward a phantom duration. Stop it so the
      // control doesn't sit on a play state with nothing to play.
      if (forceStop) unawaited(player.pause());
      return;
    }
    unawaited(open(next, offsetMs: 0, play: play));
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
