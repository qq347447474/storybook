/// Vocabulary screen (S3) widget tests: one card in focus, the flip, the gloss
/// fallback (decision ③), the dot rail, the previous/next ends, the stage
/// counter and the target-word browse guard on the dock CTA.
library;

import 'dart:async';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/ui/app_icon.dart';
import 'package:storyapp/ui/components/dock_cta.dart';
import 'package:storyapp/vocabulary/vocab_parts.dart';
import 'package:storyapp/vocabulary/vocabulary_screen.dart';

Chapter vocabChapter() {
  const para = Paragraph(
    id: 'ch1-p1',
    text: 'She made a paper boat.',
    audio: AudioTimeline(
      url: 'media/ch1-p1.mp3',
      durationMs: 1000,
      sentences: <SpokenSentence>[
        SpokenSentence(text: 'She made a paper boat.', startMs: 0, endMs: 1000),
      ],
    ),
  );
  VocabItem item(
    String id,
    String surface, {
    required bool isTarget,
    required Map<String, String> gloss,
    required String definition,
    required String sentence,
  }) =>
      VocabItem(
        id: id,
        lemma: surface.toLowerCase(),
        surfaceForm: surface,
        partOfSpeech: 'noun',
        senseKey: '${surface.toLowerCase()}:noun1',
        definition: definition,
        gloss: LocalizedText(gloss),
        sourceSentence: sentence,
        sourceParagraphId: 'ch1-p1',
        cefr: 'A2',
        isTarget: isTarget,
      );

  return Chapter(
    id: 'ch1',
    order: 1,
    title: 'A Rainy Morning',
    available: true,
    estimatedMinutes: 3,
    reading: const <Paragraph>[para],
    // Deliberately not target-first: the screen has to sort.
    vocabulary: <VocabItem>[
      item('v-zebra', 'zebra',
          isTarget: false,
          gloss: <String, String>{'en': 'a striped animal'},
          definition: 'an animal with stripes',
          sentence: 'A zebra walked by.'),
      item('v-boat', 'boat',
          isTarget: true,
          gloss: <String, String>{'zh-Hans': '船', 'en': 'a small boat'},
          definition: 'a thing that floats on water',
          sentence: 'She made a paper boat.'),
      item('v-rain', 'rain',
          isTarget: true,
          gloss: <String, String>{'zh-Hans': '雨', 'en': 'water from the sky'},
          definition: 'water falling from clouds',
          sentence: 'The rain ran down the glass.'),
    ],
    quiz: const <QuizItem>[],
    retell: const Retell(
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

Future<ReadingController> makeController(Directory tmp) async {
  final controller = ReadingController(
    bookId: 'the-paper-boat',
    chapter: vocabChapter(),
    packId: 'the-paper-boat',
    contentVersion: '1.0.0',
    progressStore: FileProgressStore(directory: tmp.path),
  );
  await controller.openChapter();
  // The single paragraph must be read first (reading -> vocabulary); S3 only
  // runs in the vocabulary stage.
  await controller.markParagraphRead('ch1-p1');
  expect(controller.state.stage, ChapterStage.vocabulary);
  return controller;
}

Widget wrap(Widget child) => MaterialApp(home: child);

Future<void> pumpVocab(
  WidgetTester tester,
  ReadingController controller,
  AppLocalizations l10n, {
  VoidCallback? onContinue,
}) async {
  await tester.pumpWidget(wrap(VocabularyScreen(
    controller: controller,
    l10n: l10n,
    defaultGloss: 'en',
    onContinueToQuiz: onContinue,
  )));
  await tester.pumpAndSettle();
}

bool hasBoldSpan(String surfaceForm, WidgetTester tester) {
  final Iterable<Text> rich = tester.widgetList<Text>(
    find.byWidgetPredicate((Widget w) => w is Text && w.textSpan != null),
  );
  bool walk(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text == surfaceForm &&
          span.style?.fontWeight == FontWeight.w700) {
        return true;
      }
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        if (walk(child)) return true;
      }
    }
    return false;
  }

  return rich.any((Text t) => walk(t.textSpan!));
}

AppDock dock(WidgetTester tester) =>
    tester.widget<AppDock>(find.byKey(const Key('vocab-continue')));

WordNavButton navButton(WidgetTester tester, String key) =>
    tester.widget<WordNavButton>(find.byKey(Key(key)));

WordDots dots(WidgetTester tester) =>
    tester.widget<WordDots>(find.byType(WordDots));

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('vocabulary_screen_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('target words are shown before non-target words',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await pumpVocab(tester, controller, l10n);

    // One card in focus: the first target word, not the pack's first entry.
    expect(find.byKey(const Key('vocab-card-v-boat')), findsOneWidget);
    expect(find.byKey(const Key('vocab-card-v-zebra')), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();

    // The non-target word is last.
    expect(find.byKey(const Key('vocab-card-v-zebra')), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('the back shows the gloss in the gloss locale + bold target',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await pumpVocab(tester, controller, l10n);

    // Front: the word and the nudge, no meaning yet (§4.4 front face).
    expect(find.text('boat'), findsOneWidget);
    expect(find.text('Tap the card to see the meaning'), findsOneWidget);
    expect(find.text('船'), findsNothing);

    await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
    await tester.pumpAndSettle();

    // Back: zh-Hans gloss (the settings gloss locale) + story sentence with the
    // target picked out in bold.
    expect(find.text('船'), findsOneWidget);
    // The example box: label + story sentence, target picked out in bold.
    expect(find.text('In the story'), findsOneWidget);
    expect(find.textContaining('She made a paper boat'), findsOneWidget);
    expect(hasBoldSpan('boat', tester), isTrue);
  });

  testWidgets('gloss falls back to locales.defaultGloss (decision 3)',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await pumpVocab(tester, controller, l10n);

    // The zebra gloss only carries 'en'; glossLocale is zh-Hans.
    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vocab-card-v-zebra')));
    await tester.pumpAndSettle();

    expect(find.text('a striped animal'), findsOneWidget);
  });

  testWidgets('the dot rail fills as cards are browsed, and the ends are inert',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await pumpVocab(tester, controller, l10n);

    expect(dots(tester).count, 3);
    expect(dots(tester).current, 0);
    expect(dots(tester).seen, isEmpty);

    // First card: previous is disabled, next is not.
    expect(navButton(tester, 'vocab-prev').onPressed, isNull);
    expect(navButton(tester, 'vocab-next').onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
    await tester.pumpAndSettle();
    expect(dots(tester).seen, <int>{0});

    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    expect(dots(tester).current, 1);
    expect(navButton(tester, 'vocab-prev').onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    // Last card: next is disabled.
    expect(navButton(tester, 'vocab-next').onPressed, isNull);
  });

  testWidgets('the stage bar counts 2 / 4', (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    await pumpVocab(tester, controller, l10n);

    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.byKey(const Key('stage-close')), findsOneWidget);
  });

  testWidgets('the quiz CTA stays disabled until every target word is browsed',
      (WidgetTester tester) async {
    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = await makeController(tmp);
    var continued = false;
    await pumpVocab(tester, controller, l10n,
        onContinue: () => continued = true);

    expect(dock(tester).onPrimaryPressed, isNull,
        reason: 'guard: no target browsed yet');

    await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
    await tester.pumpAndSettle();
    expect(dock(tester).onPrimaryPressed, isNull,
        reason: 'guard: one target still unseen');

    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vocab-card-v-rain')));
    await tester.pumpAndSettle();

    expect(dock(tester).onPrimaryPressed, isNotNull,
        reason: 'all targets browsed');
    expect(controller.state.stage, ChapterStage.quiz);

    await tester.tap(find.descendant(
      of: find.byKey(const Key('vocab-continue')),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(continued, isTrue);
  });

  // --- speaker wiring -------------------------------------------------
  //
  // The front speaker says the headword; the back speaker cuts its sentence
  // out of the paragraph clip the pack already carries, so it works for packs
  // generated before any vocabulary audio existed.
  group('VocabularyScreen speakers', () {
    testWidgets('the example speaker plays the sentence window of the clip',
        (WidgetTester tester) async {
      final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
      final _FakePlayer player = _FakePlayer();
      // Sync: the test zone is fake-async, so a real `await` on I/O never
      // resolves (the rest of this file creates its temp dir the same way).
      final Directory tmp =
          Directory.systemTemp.createTempSync('vocab-audio');
      final ReadingController controller = await makeController(tmp);
      await tester.pumpWidget(wrap(VocabularyScreen(
        controller: controller,
        l10n: l10n,
        defaultGloss: 'en',
        mediaResolver: const _FakeResolver(),
        audioPlayer: player,
      )));
      await tester.pumpAndSettle();

      // Flip the card: the example speaker lives on the back face.
      await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
      await tester.pumpAndSettle();

      final Finder back = _speakerBy('Hear the sentence');
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();

      // The paragraph clip carries the sentence at 0..1000 ms: load the clip
      // and play it. No seek — the sentence starts at 0.
      expect(player.calls, contains('load:/cache/media/ch1-p1.mp3'));
      expect(player.calls, contains('play'));
      expect(player.calls.where((String c) => c.startsWith('seek:')), isEmpty);

      // The boundary is ours to enforce. The first position is always ignored
      // (a real player replays its previous value), so arm it, then cross it.
      player.positionSink.add(Duration.zero);
      await tester.pumpAndSettle();
      player.positionSink.add(const Duration(milliseconds: 1500));
      // The stop runs off a timer (see ClipWindow._requestHalt), so advance
      // the fake clock for it instead of pumping frames.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(player.calls.where((String c) => c == 'stop'), hasLength(2),
          reason: 'the window is over: playback stops');
    });

    testWidgets('the word speaker stays disabled without a word clip',
        (WidgetTester tester) async {
      final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
      final _FakePlayer player = _FakePlayer();
      // Sync: the test zone is fake-async, so a real `await` on I/O never
      // resolves (the rest of this file creates its temp dir the same way).
      final Directory tmp =
          Directory.systemTemp.createTempSync('vocab-audio');
      final ReadingController controller = await makeController(tmp);
      await tester.pumpWidget(wrap(VocabularyScreen(
        controller: controller,
        l10n: l10n,
        defaultGloss: 'en',
        mediaResolver: const _FakeResolver(),
        audioPlayer: player,
      )));
      await tester.pumpAndSettle();

      final Finder front = _speakerBy('Hear the word');
      expect(front, findsOneWidget);
      // No clip in the fixture: the button is inert instead of pretending.
      final InkWell ink = tester.widget<InkWell>(front);
      expect(ink.onTap, isNull);
      expect(player.calls, isEmpty);
    });

    testWidgets('the example speaker plays the standalone example clip whole',
        (WidgetTester tester) async {
      final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
      final _FakePlayer player = _FakePlayer();
      final Directory tmp =
          Directory.systemTemp.createTempSync('vocab-audio');
      // Same chapter as the shared fixture, but the target card carries its
      // own recording of the example sentence.
      final Chapter base = vocabChapter();
      final Chapter chapter = Chapter(
        id: base.id,
        order: base.order,
        title: base.title,
        available: base.available,
        estimatedMinutes: base.estimatedMinutes,
        reading: base.reading,
        vocabulary: <VocabItem>[
          for (final VocabItem v in base.vocabulary)
            if (v.id == 'v-boat')
              VocabItem(
                id: v.id,
                lemma: v.lemma,
                surfaceForm: v.surfaceForm,
                partOfSpeech: v.partOfSpeech,
                senseKey: v.senseKey,
                definition: v.definition,
                gloss: v.gloss,
                sourceSentence: v.sourceSentence,
                sourceParagraphId: v.sourceParagraphId,
                cefr: v.cefr,
                isTarget: v.isTarget,
                exampleAudio: const ClipRef(
                  url: 'media/v-boat-example.mp3',
                  durationMs: 1400,
                ),
              )
            else
              v,
        ],
        quiz: base.quiz,
        retell: base.retell,
      );
      final ReadingController controller = ReadingController(
        bookId: 'the-paper-boat',
        chapter: chapter,
        packId: 'the-paper-boat',
        contentVersion: '1.0.0',
        progressStore: FileProgressStore(directory: tmp.path),
      );
      await controller.openChapter();
      await controller.markParagraphRead('ch1-p1');

      await tester.pumpWidget(wrap(VocabularyScreen(
        controller: controller,
        l10n: l10n,
        defaultGloss: 'en',
        mediaResolver: const _FakeResolver(),
        audioPlayer: player,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
      await tester.pumpAndSettle();
      await tester.tap(_speakerBy('Hear the sentence'));
      await tester.pumpAndSettle();

      // The standalone clip plays whole: no seek, no paragraph file involved.
      expect(player.calls, contains('load:/cache/media/v-boat-example.mp3'));
      expect(player.calls, contains('play'));
      expect(player.calls.where((String c) => c.startsWith('seek:')), isEmpty);
      expect(
          player.calls.where((String c) => c.contains('ch1-p1')), isEmpty,
          reason: 'the paragraph clip must not be touched');
    });
  });
}

// --- fakes --------------------------------------------------------------

/// Media lookup that always succeeds with a cached file.
class _FakeResolver implements MediaResolver {
  const _FakeResolver();

  @override
  Future<ResolvedMedia?> resolve(String url) async => ResolvedMedia(
        origin: MediaOrigin.cached,
        location: '/cache/$url',
      );
}

/// Records what the screen asked the player to do.
class _FakePlayer implements AudioPlayerService {
  final List<String> calls = <String>[];
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();

  /// Test hook: push a playhead position.
  StreamSink<Duration> get positionSink => _positions.sink;
  final StreamController<AudioPlaybackState> _states =
      StreamController<AudioPlaybackState>.broadcast();

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

Finder _speakerBy(String semanticLabel) => find.ancestor(
      of: find.byWidgetPredicate(
        (Widget w) => w is AppIcon && w.semanticLabel == semanticLabel,
      ),
      matching: find.byType(InkWell),
    );
