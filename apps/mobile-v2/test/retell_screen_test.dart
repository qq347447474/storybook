/// Retell screen (S5) widget tests: the D2 four-phase machine — permission
/// pre-explanation, hold-to-record with the rubric-capped ring, too-short
/// toast, ASR degradation, ticked step chips, reduced-motion pulse removal,
/// hint levels, feedback without any score/ranking/verdict, interruption
/// discard (docs/09 §5), real progress persistence and the Done -> S6 handoff.
library;

import 'dart:async';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:core_speech/core_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/audio/mic_permission.dart';
import 'package:storyapp/audio/retell_audio_source.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/retell/retell_screen.dart';
import 'package:storyapp/ui/components/app_chip.dart';
import 'package:storyapp/ui/components/record_button.dart';

class FakeSpeechEngine extends SpeechEngineBase {
  FakeSpeechEngine({
    this.capture = const SpeechCapture(segments: <SpeechSegment>[], durationMs: 0),
    this.plannedPartials = const <SpeechPartial>[],
    this.modelsReady = true,
  });

  SpeechCapture capture;
  final List<SpeechPartial> plannedPartials;
  bool modelsReady;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> checkModels() async => modelsReady;

  @override
  Future<void> beginCapture() async {
    startCalls++;
    for (final SpeechPartial p in plannedPartials) {
      emitPartial(p);
    }
  }

  @override
  Future<SpeechCapture> endCapture() async {
    stopCalls++;
    return capture;
  }
}

class FakeRetellAudioSource implements RetellAudioSource {
  final StreamController<RecordingInterruption> _ctrl =
      StreamController<RecordingInterruption>.broadcast();
  int discardCalls = 0;
  String path = 'fake_recording.wav';

  void emitInterruption(RecordingInterruption e) => _ctrl.add(e);

  @override
  Stream<RecordingInterruption> get interruptions => _ctrl.stream;

  @override
  Future<void> start() async {}

  @override
  Future<String> stop() async => path;

  @override
  Future<void> discard() async {
    discardCalls++;
  }
}

class FakeMicPermission implements MicPermissionService {
  FakeMicPermission({this.state = MicPermissionState.granted});

  MicPermissionState state;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<MicPermissionState> check() async => state;

  @override
  Future<MicPermissionState> request() async {
    requestCalls++;
    return state;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

class FakeMediaResolver implements MediaResolver {
  FakeMediaResolver({this.result});

  ResolvedMedia? result;

  @override
  Future<ResolvedMedia?> resolve(String url) async => result;
}

class FakeAudioPlayerService implements AudioPlayerService {
  final StreamController<AudioPlaybackState> _s =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<Duration> _p =
      StreamController<Duration>.broadcast();
  String? loaded;

  @override
  AudioPlaybackState get state => AudioPlaybackState.idle;
  @override
  Stream<AudioPlaybackState> get states => _s.stream;
  @override
  Stream<Duration> get positions => _p.stream;
  @override
  Duration get duration => Duration.zero;
  @override
  Future<void> load(String location) async => loaded = location;
  @override
  Future<void> loadAsset(String assetKey) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await _s.close();
    await _p.close();
  }
}

Chapter retellChapter({int maxSeconds = 30}) => Chapter(
      id: 'ch1',
      order: 1,
      title: 'A Rainy Morning',
      available: true,
      estimatedMinutes: 3,
      reading: const <Paragraph>[
        Paragraph(
          id: 'ch1-p1',
          text: 'She made a paper boat.',
          audio: AudioTimeline(
            url: 'media/ch1-p1.mp3',
            durationMs: 1000,
            sentences: <SpokenSentence>[
              SpokenSentence(text: 'She made a paper boat.', startMs: 0, endMs: 1000),
            ],
          ),
        ),
      ],
      vocabulary: const <VocabItem>[],
      quiz: <QuizItem>[
        QuizItem(
          id: 'ch1-q1',
          skill: 'detail',
          prompt: 'Q?',
          options: const <String>['a', 'b', 'c', 'd'],
          answer: 0,
          explanation: LocalizedText(const <String, String>{'en': 'Because.'}),
          evidence: 'ch1-p1',
        ),
      ],
      retell: Retell(
        scenes: <Scene>[
          Scene(
            id: 'ch1-s1',
            order: 1,
            image: Media(
              url: 'media/ch1-s1.png',
              alt: LocalizedText(const <String, String>{'en': 'A paper boat'}),
            ),
            prompt: 'Tell about the boat.',
            concepts: <Concept>[
              Concept(
                id: 'c-boat',
                label: LocalizedText(const <String, String>{'en': 'boat'}),
                terms: const <String>['boat'],
                required: true,
              ),
              Concept(
                id: 'c-rain',
                label: LocalizedText(const <String, String>{'en': 'rain'}),
                terms: const <String>['rain'],
                required: true,
              ),
            ],
            hint1: LocalizedText(const <String, String>{'en': 'Think about water.'}),
            hint2: LocalizedText(const <String, String>{'en': 'It floats.'}),
            suggestedAnswer: 'She made a paper boat.',
            targetWordCount: 10,
          ),
        ],
        rubric: Rubric(
          minWords: 3,
          maxSeconds: maxSeconds,
          conceptWeight: 0.6,
          fluencyWeight: 0.2,
          completenessWeight: 0.2,
          wpmTargetRange: const <int>[70, 120],
        ),
      ),
    );

Future<ReadingController> controllerAtRetell(Directory tmp,
    {int maxSeconds = 30}) async {
  final controller = ReadingController(
    bookId: 'the-paper-boat',
    chapter: retellChapter(maxSeconds: maxSeconds),
    packId: 'the-paper-boat',
    contentVersion: '1.0.0',
    progressStore: FileProgressStore(directory: tmp.path),
  );
  await controller.openChapter();
  await controller.markParagraphRead('ch1-p1'); // -> vocabulary
  await controller.markVocabViewed('v-none'); // no targets -> quiz
  await controller.submitQuizAttempt(
    answers: const <String, int>{'ch1-q1': 0},
    result: gradeQuiz(controller.chapter.quiz, const <String, int>{'ch1-q1': 0}),
  );
  expect(controller.state.stage, ChapterStage.retell);
  return controller;
}

Widget wrap(RetellScreen screen) => MaterialApp(home: screen);

/// `reduceMotion` mirror of the settings switch (design-spec §6.6).
Widget wrapReduced(RetellScreen screen) => MaterialApp(
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: screen,
        ),
      ),
    );

/// Scrolls [finder] into view (the hint column sits below the fold on the
/// 800x600 test surface) and settles.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// A hold that clears the 800 ms floor of `RecordButton.minHold`.
///
/// The key's hold ticker starts on the first frame after the press, so the
/// hold is measured across two pumps (same shape as `overlay_components_test`).
Future<void> holdRecord(WidgetTester tester, {int pumpMs = 900}) async {
  final gesture = await tester
      .startGesture(tester.getCenter(find.byKey(const Key('retell-record-button'))));
  await tester.pump();
  await tester.pump(Duration(milliseconds: pumpMs));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Deterministic settle for the confirm dialog's 240 ms transition.
Future<void> pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('retell_screen_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('hold-to-record -> local ASR -> counts and chips only (no score)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await controllerAtRetell(tmp);
    final engine = FakeSpeechEngine(
      capture: const SpeechCapture(
        segments: <SpeechSegment>[
          SpeechSegment(startMs: 0, endMs: 2000, text: 'I love the boat'),
        ],
        durationMs: 3000,
      ),
    );

    await tester.pumpWidget(wrap(RetellScreen(
      controller: controller,
      engine: engine,
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    // Media missing -> placeholder (C6); the question stays content language.
    expect(find.byKey(const Key('retell-image-placeholder')), findsOneWidget);
    expect(find.text('Tell about the boat.'), findsOneWidget);

    await holdRecord(tester);
    expect(engine.startCalls, 1);
    expect(engine.stopCalls, 1);

    expect(find.byKey(const Key('retell-feedback')), findsOneWidget);
    expect(find.text('You mentioned 1 of 2 ideas.'), findsOneWidget);
    expect(find.text('rain'), findsOneWidget, reason: 'missing point chip');
    expect(find.text('boat'), findsNothing, reason: 'hit point is not listed');
    expect(find.text(l10n.t('retell.feedback.fluency')), findsOneWidget);
    // Red line: no total score / percentage / pass-fail wording.
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('score'), findsNothing);
    expect(find.text('Correct'), findsNothing);
  });

  testWidgets('countdown ring follows rubric.maxSeconds and auto-stops at it',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await controllerAtRetell(tmp, maxSeconds: 3);
    final engine = FakeSpeechEngine(
      capture: const SpeechCapture(
        segments: <SpeechSegment>[
          SpeechSegment(startMs: 0, endMs: 2000, text: 'I love the boat'),
        ],
        durationMs: 3000,
      ),
    );
    await tester.pumpWidget(wrap(RetellScreen(
      controller: controller,
      engine: engine,
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    // D2: the ring length is the rubric cap, not a fixed 30 s.
    final RecordButton key =
        tester.widget<RecordButton>(find.byKey(const Key('retell-record-button')));
    expect(key.maxSeconds, 3);
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('retell-record-button'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('retell-countdown')), findsOneWidget);
    expect(engine.stopCalls, 0);

    await tester.pump(const Duration(seconds: 4));
    // The cap fires while the finger is still down; release before settling —
    // a held key keeps its hold ticker scheduling frames for ever.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(engine.stopCalls, 1, reason: 'auto-stop at the cap');
    expect(find.byKey(const Key('retell-feedback')), findsOneWidget);
  });

  testWidgets('a press under 800 ms discards the take and toasts',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final engine = FakeSpeechEngine();
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: engine,
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('retell-record-button'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await tester.pump();

    expect(find.text(l10n.t('s5.tooShort')), findsOneWidget);
    expect(find.byKey(const Key('retell-feedback')), findsNothing);
    expect(engine.stopCalls, 1, reason: 'the discarded take still closed cleanly');
  });

  testWidgets('ASR not connected degrades to reference points, never a score',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(modelsReady: false),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    await holdRecord(tester);
    expect(find.byKey(const Key('retell-asr-note')), findsOneWidget);
    expect(find.text(l10n.t('s5.asrNote')), findsOneWidget);
    expect(find.text('You mentioned 0 of 2 ideas.'), findsOneWidget);
    expect(find.text('boat'), findsOneWidget);
    expect(find.text('rain'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('score'), findsNothing);
  });

  testWidgets('four step chips show up all ticked', (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retell-steps')), findsOneWidget);
    expect(find.byType(AppChip), findsNWidgets(4));
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Retell'), findsOneWidget);
  });

  testWidgets('reduced motion removes the recording pulse ring',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrapReduced(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('retell-record-button'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('retell-record-button')), findsOneWidget);
    expect(find.byKey(RecordButton.pulseKey), findsNothing,
        reason: 'reduceMotion must stop the pulse (design-spec §6.6)');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('hints reveal in two separate levels, never side by side',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retell-hint1-text')), findsNothing);
    expect(find.byKey(const Key('retell-hint2-text')), findsNothing);

    TextButton hint2() =>
        tester.widget<TextButton>(find.byKey(const Key('retell-hint2')));
    expect(hint2().onPressed, isNull);

    await reveal(tester, find.byKey(const Key('retell-hint1')));
    await tester.tap(find.byKey(const Key('retell-hint1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retell-hint1-text')), findsOneWidget);
    expect(find.text('Think about water.'), findsOneWidget);
    expect(hint2().onPressed, isNotNull);

    await reveal(tester, find.byKey(const Key('retell-hint2')));
    await tester.tap(find.byKey(const Key('retell-hint2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retell-hint2-text')), findsOneWidget);
    expect(find.text('It floats.'), findsOneWidget);
    expect(find.byKey(const Key('retell-hint1-text')), findsNothing,
        reason: 'design-spec §4.6: the two hint panels never coexist');
  });

  testWidgets('permission pre-explanation on first press, consent before OS ask',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final engine = FakeSpeechEngine();
    final permission = FakeMicPermission(state: MicPermissionState.denied);
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: engine,
      audio: FakeRetellAudioSource(),
      permission: permission,
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('retell-record-button')));
    await pumpDialog(tester);
    expect(find.text(l10n.t('s5.permTitle')), findsOneWidget);
    expect(find.text(l10n.t('s5.permBody')), findsOneWidget);
    expect(engine.startCalls, 0, reason: 'nothing records before consent');

    // "Not now" closes the dialog and still records nothing.
    await tester.tap(find.text(l10n.t('s5.permDeny')));
    await tester.pumpAndSettle();
    expect(engine.startCalls, 0);

    // Allow -> the OS request runs; permanent denial opens the settings bar.
    permission.state = MicPermissionState.permanentlyDenied;
    await tester.tap(find.byKey(const Key('retell-record-button')));
    await pumpDialog(tester);
    await tester.tap(find.text(l10n.t('s5.permAllow')));
    await tester.pumpAndSettle();
    expect(permission.requestCalls, 1);
    expect(find.byKey(const Key('retell-perm-banner')), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('empty recognition -> noSpeech feedback and NO attempt (§8)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await controllerAtRetell(tmp);
    await tester.pumpWidget(wrap(RetellScreen(
      controller: controller,
      engine: FakeSpeechEngine(), // empty capture
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    await holdRecord(tester);
    expect(find.text('I did not hear anything. Try again closer to the microphone.'),
        findsOneWidget);
    expect(controller.state.retellAttempts, isEmpty,
        reason: 'docs/09 §8: empty recognition is not an attempt');
    expect(controller.state.stage, ChapterStage.retell);
  });

  testWidgets('call interruption discards the half recording and asks retry',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await controllerAtRetell(tmp);
    final engine = FakeSpeechEngine(
      capture: const SpeechCapture(
        segments: <SpeechSegment>[
          SpeechSegment(startMs: 0, endMs: 100, text: 'half'),
        ],
        durationMs: 100,
      ),
    );
    final audio = FakeRetellAudioSource();
    await tester.pumpWidget(wrap(RetellScreen(
      controller: controller,
      engine: engine,
      audio: audio,
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('retell-record-button'))));
    await tester.pump();
    audio.emitInterruption(RecordingInterruption.callOrSeized);
    await tester.pump(); // deliver the stream event
    await gesture.up();
    await tester.pumpAndSettle();
    expect(audio.discardCalls, greaterThan(0), reason: '半截音频不留');
    expect(find.byKey(const Key('retell-retry-note')), findsOneWidget);
    expect(find.byKey(const Key('retell-feedback')), findsNothing);
    expect(controller.state.retellAttempts, isEmpty);
  });

  testWidgets('attempt persists per-scene progress and completes the chapter',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await controllerAtRetell(tmp);
    final store = FileProgressStore(directory: tmp.path);
    await tester.pumpWidget(wrap(RetellScreen(
      controller: controller,
      engine: FakeSpeechEngine(
        capture: const SpeechCapture(
          segments: <SpeechSegment>[
            SpeechSegment(startMs: 0, endMs: 2000, text: 'boat and rain here'),
          ],
          durationMs: 3000,
        ),
      ),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();

    await holdRecord(tester);
    expect(controller.state.stage, ChapterStage.complete,
        reason: 'any recorded attempt completes');
    expect(controller.state.bestRetellScore, greaterThan(0));

    final doc = await store.load('the-paper-boat');
    final entry = doc.chapters['the-paper-boat/ch1']!;
    expect(entry.status, 'complete');
    expect(entry.retell, hasLength(1));
    expect(entry.retell.single.sceneId, 'ch1-s1');
    expect(entry.retell.single.attempts, 1);
    expect(entry.retell.single.bestScore, greaterThan(0));
    expect(entry.retell.single.lastWordCount, 4);
    expect(entry.retell.single.lastDurationMs, 3000);
  });

  testWidgets('Done CTA hands off to S6', (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    int done = 0;
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(),
      defaultGloss: 'en',
      l10n: l10n,
      onDone: () => done += 1,
    )));
    await tester.pumpAndSettle();

    expect(find.text(l10n.t('s5.done')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retell-continue')));
    await tester.pumpAndSettle();
    expect(done, 1);
  });

  testWidgets('bundled scene image renders via Image.asset (T7d-2)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    await tester.pumpWidget(wrap(RetellScreen(
      controller: await controllerAtRetell(tmp),
      engine: FakeSpeechEngine(),
      audio: FakeRetellAudioSource(),
      permission: FakeMicPermission(),
      player: FakeAudioPlayerService(),
      mediaResolver: FakeMediaResolver(
        result: const ResolvedMedia(
          origin: MediaOrigin.bundled,
          location: 'media/ch1-s1.png',
          assetKey: 'assets/content/the-paper-boat/media/ch1-s1.png',
        ),
      ),
      defaultGloss: 'en',
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    final Image image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<AssetImage>());
    expect(find.byKey(const Key('retell-image-placeholder')), findsNothing);
  });

  test('same transcript scores identically every time (A4 deterministic)', () {
    const transcript = Transcript(
      text: 'I love the boat',
      durationMs: 3000,
      pauseGapsMs: <int>[],
    );
    final chapter = retellChapter();
    final a = scoreRetell(
        transcript: transcript,
        scenes: chapter.retell.scenes,
        rubric: chapter.retell.rubric);
    final b = scoreRetell(
        transcript: transcript,
        scenes: chapter.retell.scenes,
        rubric: chapter.retell.rubric);
    expect(a.total, b.total);
    expect(a.concept, b.concept);
    expect(a.fluency, b.fluency);
    expect(a.completeness, b.completeness);
    expect(a.missingConceptIds, b.missingConceptIds);
    expect(a.feedbackKeys, b.feedbackKeys);
  });
}
