/// Reading screen (S2) widget tests: the **virtual timeline** (docs/13 D3),
/// sentence highlighting, sentence taps, paragraph auto-advance, the degraded
/// audio states and the read-to-continue guard.
///
/// Audio is faked: the timeline comes from the pack's own sentence timestamps,
/// so nothing here needs a decoder.
library;

import 'dart:async';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/reading/reading_screen.dart';
import 'package:storyapp/ui/app_illustration.dart';
import 'package:storyapp/ui/components/dock_cta.dart';
import 'package:storyapp/ui/components/reading_player.dart';
import 'package:storyapp/ui/media_image.dart';

const String _assetPrefix = 'assets/content/the-paper-boat/';

/// Resolves every URL to a bundled clip whose asset key mirrors the URL, so a
/// test can tell which paragraph the player loaded.
class FakeMediaResolver implements MediaResolver {
  FakeMediaResolver({this.available = true});

  bool available;
  int calls = 0;

  @override
  Future<ResolvedMedia?> resolve(String url) async {
    calls++;
    if (!available) return null;
    return ResolvedMedia(
      origin: MediaOrigin.bundled,
      location: url,
      assetKey: '$_assetPrefix$url',
    );
  }
}

class FakeAudioPlayerService implements AudioPlayerService {
  // Sync controllers: position/state events reach ReadingPlayback inside the
  // emitting call, so assertions never race a later microtask.
  final StreamController<AudioPlaybackState> _stateCtrl =
      StreamController<AudioPlaybackState>.broadcast(sync: true);
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast(sync: true);

  AudioPlaybackState _state = AudioPlaybackState.idle;
  Duration _duration = Duration.zero;
  String? loadedAsset;
  String? loaded;
  Duration? lastSeek;
  double speed = 1.0;
  int loadCalls = 0;
  int stopCalls = 0;
  bool failLoad = false;

  void emitState(AudioPlaybackState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void emitPosition(Duration p) => _posCtrl.add(p);

  @override
  AudioPlaybackState get state => _state;

  @override
  Stream<AudioPlaybackState> get states => _stateCtrl.stream;

  @override
  Stream<Duration> get positions => _posCtrl.stream;

  @override
  Duration get duration => _duration;

  @override
  Future<void> loadAsset(String assetKey) async {
    loadCalls++;
    loadedAsset = assetKey;
    if (failLoad) {
      emitState(AudioPlaybackState.error);
      return;
    }
    _duration = const Duration(milliseconds: 3000);
    emitState(AudioPlaybackState.paused);
  }

  @override
  Future<void> load(String location) async {
    loadCalls++;
    loaded = location;
    if (failLoad) {
      emitState(AudioPlaybackState.error);
      return;
    }
    _duration = const Duration(milliseconds: 3000);
    emitState(AudioPlaybackState.paused);
  }

  @override
  Future<void> play() async {
    if (failLoad) return;
    emitState(AudioPlaybackState.playing);
  }

  @override
  Future<void> pause() async {
    if (failLoad) return;
    emitState(AudioPlaybackState.paused);
  }

  @override
  Future<void> seek(Duration position) async {
    if (failLoad) return;
    lastSeek = position;
    emitPosition(position);
  }

  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> stop() async {
    stopCalls++;
    emitState(AudioPlaybackState.idle);
  }

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
    await _posCtrl.close();
  }
}

/// p1 = 0–3000 ms (two sentences), p2 = 0–1500 ms (one sentence).
/// Virtual chapter timeline: 0–3000 | 3000–4500, total 4500 ms.
Chapter buildChapter() {
  const Paragraph p1 = Paragraph(
    id: 'ch1-p1',
    text: 'Ada looked out the window. Rain ran down the glass.',
    audio: AudioTimeline(
      url: 'media/ch1-p1.mp3',
      durationMs: 3000,
      sentences: <SpokenSentence>[
        SpokenSentence(text: 'Ada looked out the window.', startMs: 0, endMs: 1500),
        SpokenSentence(text: 'Rain ran down the glass.', startMs: 1500, endMs: 3000),
      ],
    ),
  );
  const Paragraph p2 = Paragraph(
    id: 'ch1-p2',
    text: 'She wanted to play outside.',
    audio: AudioTimeline(
      url: 'media/ch1-p2.mp3',
      durationMs: 1500,
      sentences: <SpokenSentence>[
        SpokenSentence(text: 'She wanted to play outside.', startMs: 0, endMs: 1500),
      ],
    ),
  );
  return const Chapter(
    id: 'ch1',
    order: 1,
    title: 'A Rainy Morning',
    available: true,
    estimatedMinutes: 3,
    reading: <Paragraph>[p1, p2],
    vocabulary: <VocabItem>[],
    quiz: <QuizItem>[],
    retell: Retell(
      scenes: <Scene>[],
      rubric: Rubric(
        minWords: 10,
        maxSeconds: 60,
        conceptWeight: 0.6,
        fluencyWeight: 0.2,
        completenessWeight: 0.2,
        wpmTargetRange: <int>[70, 120],
      ),
    ),
  );
}

Future<(ReadingController, FileProgressStore)> makeController(
    Directory tmp) async {
  final store = FileProgressStore(directory: tmp.path);
  final controller = ReadingController(
    bookId: 'the-paper-boat',
    chapter: buildChapter(),
    packId: 'the-paper-boat',
    contentVersion: '1.0.0',
    progressStore: store,
  );
  await controller.openChapter();
  return (controller, store);
}

Widget wrap(Widget child) => MaterialApp(home: child);

/// Phone-sized portrait surface so the 16:9 plate, the player and the story
/// card all fit the first frame — the "read" signal is visibility, and a
/// 800×600 desktop window pushed every paragraph below the fold.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required ReadingController controller,
  required MediaResolver resolver,
  required AudioPlayerService audio,
  required AppLocalizations l10n,
  String? coverUrl,
  VoidCallback? onContinue,
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(wrap(ReadingScreen(
    controller: controller,
    mediaResolver: resolver,
    audioPlayer: audio,
    l10n: l10n,
    bookTitle: 'The Paper Boat',
    coverUrl: coverUrl,
    onContinueToVocabulary: onContinue,
  )));
  await tester.pumpAndSettle();
}

/// The player's 46 dp play key — the circle button, not the speed pill.
Finder playButton() => find.descendant(
      of: find.byType(ReadingPlayer),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is FilledButton &&
            w.style?.shape?.resolve(const <WidgetState>{}) is CircleBorder,
      ),
    );

/// Highlight fill of `sentence-p-s`; `null` means "not the current sentence".
/// The key sits on the sentence run; the wash is painted by its [Container].
Color? colorOf(WidgetTester tester, String key) {
  final Container container = tester.widget<Container>(
    find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('reading_screen_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('seek 0.75 of the virtual timeline lands in the second paragraph',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    // 0.75 × 4500 = 3375 ms → paragraph 2, offset 375 ms.
    tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).onSeek!(0.75);
    await tester.pumpAndSettle();

    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');
    expect(audio.lastSeek, const Duration(milliseconds: 375));
    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).position,
      const Duration(milliseconds: 3375),
    );
  });

  testWidgets('the sentence highlight follows the playhead', (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p1.mp3');

    audio.emitPosition(const Duration(milliseconds: 1600)); // sentence 2
    await tester.pumpAndSettle();
    expect(colorOf(tester, 'sentence-0-1'), isNotNull);
    expect(colorOf(tester, 'sentence-0-0'), isNull);
    expect(find.text('2 / 3'), findsOneWidget); // sentence counter

    audio.emitPosition(const Duration(milliseconds: 500)); // sentence 1
    await tester.pumpAndSettle();
    expect(colorOf(tester, 'sentence-0-0'), isNotNull);
    expect(colorOf(tester, 'sentence-0-1'), isNull);
  });

  testWidgets('a runaway player position cannot push the bar past the total',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();

    // A container whose metadata lies about its length (VBR without a Xing
    // header) can report positions past the paragraph's declared end. The
    // pack's timeline is the source of truth: clamp to p1's end (3000) and
    // keep the last sentence highlighted instead of walking off the chart.
    // Paused so this exercises the clamp alone — the playing-state safety
    // net has its own test below.
    audio.emitPosition(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    audio.emitState(AudioPlaybackState.paused);
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 4200));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).position,
      const Duration(milliseconds: 3000),
    );
    expect(colorOf(tester, 'sentence-0-1'), isNotNull);

    // Roll on to the last paragraph; the same overshoot clamps to the chapter
    // total (4500) — the bar can never run past its own end time.
    audio.emitState(AudioPlaybackState.ended);
    await tester.pumpAndSettle();
    audio.emitState(AudioPlaybackState.paused);
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 90000));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).position,
      const Duration(milliseconds: 4500),
    );
  });

  testWidgets('tapping a sentence jumps to its paragraph and startMs',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();

    // Sentence in the SAME paragraph: a plain seek.
    await tester.ensureVisible(find.byKey(const Key('sentence-0-1')));
    await tester.tap(find.byKey(const Key('sentence-0-1')));
    await tester.pumpAndSettle();
    expect(audio.lastSeek, const Duration(milliseconds: 1500));

    // Sentence in the OTHER paragraph: load it, then start at its first word.
    await tester.ensureVisible(find.byKey(const Key('sentence-1-0')));
    await tester.tap(find.byKey(const Key('sentence-1-0')));
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');
    expect(audio.state, AudioPlaybackState.playing);
  });

  testWidgets('the end of a paragraph rolls on to the next one',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p1.mp3');

    audio.emitPosition(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 3000));
    audio.emitState(AudioPlaybackState.ended);
    await tester.pumpAndSettle();

    // The virtual position carried on instead of stopping at the seam.
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');
    expect(audio.state, AudioPlaybackState.playing);
    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).position,
      const Duration(milliseconds: 3000),
    );
  });

  testWidgets(
      'a position that reaches the declared end advances even without `ended`',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p1.mp3');

    // A container that overstates its length never delivers `ended` at the
    // real end: the playhead creeps to the pack's declared boundary while the
    // player still claims to be playing. That must roll the paragraph on.
    audio.emitPosition(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 2800));
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');
    expect(audio.state, AudioPlaybackState.playing);

    // A stale `ended` from the previous source must not skip the paragraph
    // the safety net just moved to.
    audio.emitState(AudioPlaybackState.ended);
    await tester.pumpAndSettle();
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');

    // Same again at the chapter's last paragraph: no next, so the player is
    // stopped instead of sitting on a phantom 173-second tail.
    audio.emitPosition(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    audio.emitPosition(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).position,
      const Duration(milliseconds: 4500),
    );
    expect(audio.state, AudioPlaybackState.paused);
    expect(audio.loadedAsset, '${_assetPrefix}media/ch1-p2.mp3');
  });

  testWidgets('leaving the reading screen stops the narration (no background)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final FakeAudioPlayerService audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();
    expect(audio.state, AudioPlaybackState.playing);
    final int stopsWhilePlaying = audio.stopCalls;

    // Pop the screen: the shared player must be stopped on the way out so the
    // narration does not keep talking in the background.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(audio.stopCalls, greaterThan(stopsWhilePlaying));
    expect(audio.state, AudioPlaybackState.idle);
  });

  testWidgets('missing audio disables the player but keeps the body readable',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final resolver = FakeMediaResolver(available: false);
    final audio = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: resolver,
      audio: audio,
      l10n: l10n,
    );

    expect(
      tester.widget<ReadingPlayer>(find.byType(ReadingPlayer)).enabled,
      isFalse,
    );
    expect(find.byKey(const Key('audio-placeholder-ch1-p1')), findsOneWidget);
    expect(find.text(l10n.t('err.audio')), findsOneWidget);
    // The story itself is never blocked (C6).
    expect(find.text('Ada looked out the window.'), findsOneWidget);
    expect(find.text('She wanted to play outside.'), findsOneWidget);

    final int before = resolver.calls;
    await tester.ensureVisible(find.byKey(const Key('audio-retry-ch1-p1')));
    await tester.tap(find.byKey(const Key('audio-retry-ch1-p1')));
    await tester.pumpAndSettle();
    expect(resolver.calls, greaterThan(before));
  });

  testWidgets('a load error surfaces err.audio with a retry',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final audio = FakeAudioPlayerService()..failLoad = true;
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: audio,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('audio-error-ch1-p1')), findsOneWidget);
    expect(find.text(l10n.t('err.audio')), findsOneWidget);
    expect(find.text('Ada looked out the window.'), findsOneWidget);

    final int before = audio.loadCalls;
    await tester.ensureVisible(find.byKey(const Key('audio-retry-ch1-p1')));
    await tester.tap(find.byKey(const Key('audio-retry-ch1-p1')));
    await tester.pumpAndSettle();
    expect(audio.loadCalls, greaterThan(before));
  });

  testWidgets('reading every paragraph unlocks the dock CTA',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    var continued = false;
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: FakeAudioPlayerService(),
      l10n: l10n,
      onContinue: () => continued = true,
    );

    // Both short paragraphs were visible on first layout -> recorded as read.
    expect(controller.state.readParagraphIds,
        containsAll(<String>['ch1-p1', 'ch1-p2']));
    expect(controller.state.stage, ChapterStage.vocabulary);

    final AppDock dock =
        tester.widget<AppDock>(find.byKey(const Key('reading-continue')));
    expect(dock.onPrimaryPressed, isNotNull);

    await tester.tap(find.descendant(
      of: find.byKey(const Key('reading-continue')),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(continued, isTrue);
  });

  testWidgets('bundled audio loads by asset key, not file path (T7d-2)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final player = FakeAudioPlayerService();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: player,
      l10n: l10n,
    );

    await tester.tap(playButton());
    await tester.pumpAndSettle();
    expect(player.loadedAsset, '${_assetPrefix}media/ch1-p1.mp3');
    expect(player.loaded, isNull, reason: 'file path not used for bundled');
  });

  test('progress writes use <bookId>/<chapterId> keys and atomic rename',
      () async {
    final store = FileProgressStore(directory: tmp.path);
    final controller = ReadingController(
      bookId: 'the-paper-boat',
      chapter: buildChapter(),
      packId: 'the-paper-boat',
      contentVersion: '1.0.0',
      progressStore: store,
    );
    await controller.openChapter();
    await controller.markParagraphRead('ch1-p1');
    await controller.save();

    final File file =
        File('${tmp.path}${Platform.pathSeparator}the-paper-boat.progress.json');
    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse,
        reason: 'temp file renamed away');
    final String raw = file.readAsStringSync();
    expect(RegExp(r'"the-paper-boat/ch1"\s*:').hasMatch(raw), isTrue);
  });

  testWidgets('the story plate shows the pack cover, not the bundled default',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    final FakeMediaResolver resolver = FakeMediaResolver();
    await pumpScreen(
      tester,
      controller: controller,
      resolver: resolver,
      audio: FakeAudioPlayerService(),
      l10n: l10n,
      coverUrl: 'media/the-paper-boat-cover.png',
    );

    // The pack's own art resolved -> MediaImage paints it. The bundled
    // `scene-rain-window` plate is only the fallback for packs with no art.
    expect(find.byType(MediaImage), findsOneWidget);
    expect(resolver.calls, greaterThan(0));
  });

  testWidgets('the story plate falls back to the bundled art without a cover',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final (controller, _) = await makeController(tmp);
    await pumpScreen(
      tester,
      controller: controller,
      resolver: FakeMediaResolver(),
      audio: FakeAudioPlayerService(),
      l10n: l10n,
      // No coverUrl: legacy pack. The default plate stands in.
    );

    expect(find.byType(MediaImage), findsNothing);
    expect(find.byType(AppIllustration), findsOneWidget);
  });

  testWidgets('the chapter scene plate outranks the cover on the story plate',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final Directory tmp2 = Directory.systemTemp.createTempSync('read-art');
    addTearDown(() => tmp2.deleteSync(recursive: true));
    final Chapter base = buildChapter();
    final Chapter withScene = Chapter(
      id: base.id,
      order: base.order,
      title: base.title,
      available: base.available,
      estimatedMinutes: base.estimatedMinutes,
      reading: base.reading,
      vocabulary: base.vocabulary,
      quiz: base.quiz,
      retell: Retell(
        scenes: <Scene>[
          Scene(
            id: 'ch1-scene1',
            order: 1,
            image: Media(
              url: 'media/ch1-s1.svg',
              alt: LocalizedText(<String, String>{'en': 'a quiet control room'}),
            ),
            prompt: 'Describe the room.',
            concepts: const <Concept>[],
            hint1: LocalizedText(const <String, String>{}),
            hint2: LocalizedText(const <String, String>{}),
            suggestedAnswer: 'It is quiet.',
            targetWordCount: 20,
          ),
        ],
        rubric: base.retell.rubric,
      ),
    );
    final ReadingController controller = ReadingController(
      bookId: 'the-paper-boat',
      chapter: withScene,
      packId: 'the-paper-boat',
      contentVersion: '1.0.0',
      progressStore: FileProgressStore(directory: tmp2.path),
    );
    await controller.openChapter();

    final List<String> resolved = <String>[];
    final _RecordingResolver resolver = _RecordingResolver(resolved);
    await pumpScreen(
      tester,
      controller: controller,
      resolver: resolver,
      audio: FakeAudioPlayerService(),
      l10n: l10n,
      coverUrl: 'media/the-paper-boat-cover.png',
    );

    // The chapter's own scene plate is the first candidate; the cover is only
    // reached when the scene is missing.
    expect(resolved.first, 'media/ch1-s1.svg');
    expect(resolved, isNot(contains('media/the-paper-boat-cover.png')));
    expect(find.byType(MediaImage), findsOneWidget);
  });
}

/// Records resolve order so a test can assert which pack URL was preferred.
class _RecordingResolver implements MediaResolver {
  _RecordingResolver(this.seen);

  final List<String> seen;

  @override
  Future<ResolvedMedia?> resolve(String url) async {
    seen.add(url);
    return ResolvedMedia(
      origin: MediaOrigin.bundled,
      location: url,
      assetKey: '$_assetPrefix$url',
    );
  }
}
