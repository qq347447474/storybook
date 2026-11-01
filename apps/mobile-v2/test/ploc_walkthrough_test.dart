/// A3 pseudolocalization walkthrough (docs/10 A3): with the `qps-ploc`
/// catalog, every screen must render UI copy wrapped in ⟦⟧ with zero bare
/// English. Content data (story text, prompts, options, word entries) is
/// L1 content language and stays English by design (L2).
library;

import 'dart:async';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/completion/completion_screen.dart';
import 'package:storyapp/contents/contents_screen.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/library/library_screen.dart';
import 'package:storyapp/quiz/quiz_screen.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/reading/reading_screen.dart';
import 'package:storyapp/settings/app_settings.dart';
import 'package:storyapp/settings/settings_screen.dart';
import 'package:storyapp/vocabulary/vocabulary_screen.dart';

// ---- fixture strings that are CONTENT data (never ploc-wrapped) ----
const String contentTitle = 'The Paper Boat';
const String contentChapterTitle = 'A Rainy Morning';
const String contentParagraph = 'She made a paper boat.';
const String contentSentence = 'She made a paper boat.';
const String contentSurface = 'boat';
const String contentDefinition = 'a thing that floats on water';
const String contentGloss = '船';

/// Part-of-speech chips come from the pack, not from the catalog.
const String contentPos = 'noun';
const String contentAlt = 'A girl at a window';
const String contentPrompt = 'Where is the boat?';
const String contentExplanation = 'The story says so.';
const String contentOptionA = 'alpha';
const String contentOptionB = 'beta';
const String contentOptionC = 'gamma';
const String contentOptionD = 'delta';

/// Language codes are data, not copy.
const Set<String> localeTags = <String>{'en', 'zh-Hans', 'qps-ploc'};

final Set<String> allowlist = <String>{
  contentTitle,
  contentChapterTitle,
  contentParagraph, // equals contentSentence in this fixture (deduped)
  contentSurface,
  contentDefinition,
  contentGloss,
  contentPos,
  contentAlt,
  contentPrompt,
  contentExplanation,
  contentOptionA,
  contentOptionB,
  contentOptionC,
  contentOptionD,
  ...localeTags,
};

/// Numeric/symbol displays (time, counters, speed chip, badges) carry no
/// language and are exempt. `×` is the speed-rate sign in `1×` / `0.75×`.
final RegExp symbolOnly = RegExp(r'^[0-9A-D:.,/x× %·+-]+$');

void expectNoBareEnglish(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
  for (final Text t in texts) {
    final String value =
        t.data ?? t.textSpan?.toPlainText() ?? '';
    if (value.isEmpty) continue;
    if (value.contains('⟦')) continue; // properly pseudolocalized
    if (symbolOnly.hasMatch(value)) continue;
    if (allowlist.contains(value)) continue; // content data
    fail('bare UI copy on screen (A3): "$value"');
  }
  // Tooltips are UI copy too (IconButton tooltips, chips).
  for (final Tooltip tip in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    final String message = tip.message ?? '';
    if (message.isEmpty) continue;
    if (message.contains('⟦')) continue;
    if (allowlist.contains(message)) continue;
    fail('bare tooltip copy on screen (A3): "$message"');
  }
}

Paragraph oneParagraph() => const Paragraph(
      id: 'ch1-p1',
      text: contentParagraph,
      audio: AudioTimeline(
        url: 'media/ch1-p1.mp3',
        durationMs: 1000,
        sentences: <SpokenSentence>[
          SpokenSentence(text: contentSentence, startMs: 0, endMs: 1000),
        ],
      ),
    );

Chapter oneChapter() => Chapter(
      id: 'ch1',
      order: 1,
      title: contentChapterTitle,
      available: true,
      estimatedMinutes: 3,
      reading: <Paragraph>[oneParagraph()],
      vocabulary: <VocabItem>[
        VocabItem(
          id: 'v-boat',
          lemma: 'boat',
          surfaceForm: contentSurface,
          partOfSpeech: 'noun',
          senseKey: 'boat:noun1',
          definition: contentDefinition,
          gloss: LocalizedText(<String, String>{'zh-Hans': contentGloss}),
          sourceSentence: contentSentence,
          sourceParagraphId: 'ch1-p1',
          cefr: 'A2',
          isTarget: true,
        ),
      ],
      quiz: <QuizItem>[
        QuizItem(
          id: 'ch1-q1',
          skill: 'detail',
          prompt: contentPrompt,
          options: const <String>[
            contentOptionA,
            contentOptionB,
            contentOptionC,
            contentOptionD
          ],
          answer: 0,
          explanation:
              LocalizedText(<String, String>{'en': contentExplanation}),
          evidence: 'ch1-p1',
        ),
      ],
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

Book oneBook() => Book(
      id: 'b1',
      title: contentTitle,
      series: const Series(id: 's1', name: 'Sample', order: 1),
      level: const Level(
        cefr: 'A2',
        wordCount: 282,
        avgSentenceLen: 9.1,
        ttr: 0.5,
        newWordDensity: 35.5,
        targetWpm: 100,
      ),
      attribution: const Attribution(
        author: 'A',
        license: 'proprietary',
        generator: 'ai-assisted',
        sourceNote: 'n',
      ),
      cover: Cover(
        url: 'media/cover.png',
        aspect: 1.5,
        alt: LocalizedText(const <String, String>{'en': contentAlt}),
      ),
      chapters: <Chapter>[oneChapter()],
    );

class FakeMediaResolver implements MediaResolver {
  @override
  Future<ResolvedMedia?> resolve(String url) async => null;
}

class FakeAudioPlayerService implements AudioPlayerService {
  final StreamController<AudioPlaybackState> _s =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<Duration> _p =
      StreamController<Duration>.broadcast();
  @override
  AudioPlaybackState get state => AudioPlaybackState.idle;
  @override
  Stream<AudioPlaybackState> get states => _s.stream;
  @override
  Stream<Duration> get positions => _p.stream;
  @override
  Duration get duration => Duration.zero;
  @override
  Future<void> load(String location) async {}
  String? loadedAsset;

  @override
  Future<void> loadAsset(String assetKey) async {
    loadedAsset = assetKey;
  }
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

Future<AppLocalizations> plocOf(WidgetTester tester) async =>
    (await tester.runAsync(() => AppLocalizations.load('qps-ploc')))!;

Future<ReadingController> controllerFor(Directory tmp) async {
  final controller = ReadingController(
    bookId: 'b1',
    chapter: oneChapter(),
    packId: 'b1',
    contentVersion: '1.0.0',
    progressStore: FileProgressStore(directory: tmp.path),
  );
  await controller.openChapter();
  await controller.markParagraphRead('ch1-p1'); // -> vocabulary
  await controller.markVocabViewed('v-boat'); // -> quiz (only target)
  return controller;
}

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ploc_walkthrough');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('S0 library has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    await tester.pumpWidget(wrap(LibraryScreen(
      pack: ContentPack(
        schemaVersion: 1,
        contentVersion: '1.0.0',
        minAppVersion: '1.0.0',
        locales: const Locales(
            content: <String>['en-US'],
            gloss: <String>['zh-Hans', 'en'],
            defaultGloss: 'zh-Hans'),
        books: <Book>[oneBook()],
      ),
      bookStarted: const <String, bool>{},
      l10n: l10n,
      onOpenBook: (_) {},
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S1 contents has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    await tester.pumpWidget(wrap(ContentsScreen(
      book: oneBook(),
      chapterStages: const <String, ChapterStage>{
        'ch1': ChapterStage.reading,
      },
      l10n: l10n,
      onOpenChapter: (_) {},
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S2 reading has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    final controller = await controllerFor(tmp);
    await tester.pumpWidget(wrap(ReadingScreen(
      controller: controller,
      mediaResolver: FakeMediaResolver(),
      audioPlayer: FakeAudioPlayerService(),
      l10n: l10n,
      bookTitle: contentTitle,
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S3 vocabulary has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    final controller = await controllerFor(tmp);
    await tester.pumpWidget(wrap(VocabularyScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'zh-Hans',
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
    await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S4 quiz has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    final controller = await controllerFor(tmp);
    await tester.pumpWidget(wrap(QuizScreen(
      controller: controller,
      l10n: l10n,
      defaultGloss: 'en',
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
    await tester.tap(find.byKey(const Key('quiz-option-1')));
    await tester.pumpAndSettle();
    // D1: the dock CTA checks the answer; a miss shows the warning card plus
    // the evidence sentence, so both the feedback and the quote are checked.
    await tester.tap(find.descendant(
      of: find.byKey(const Key('quiz-dock')),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S6 completion has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    await tester.pumpWidget(wrap(CompletionScreen(
      reduceMotion: true,
      l10n: l10n,
      onDone: () {},
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });

  testWidgets('S7 settings has no bare English in qps-ploc',
      (WidgetTester tester) async {
    final l10n = await plocOf(tester);
    await tester.pumpWidget(wrap(SettingsScreen(
      settings: AppSettings(
        store: FileProgressStore(directory: tmp.path),
        packId: 'b1',
        appVersion: '9.9.9',
      ),
      glossLocales: const <String>['zh-Hans', 'en'],
      l10n: l10n,
    )));
    await tester.pumpAndSettle();
    expectNoBareEnglish(tester);
  });
}
