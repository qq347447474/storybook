/// Full chapter chain test: reading (S2) -> vocabulary (S3) -> quiz (S4),
/// walking the docs/07 §2.4 transition table row by row up to the retell
/// unlock point (S5 is not implemented yet).
library;

import 'dart:async';
import 'dart:io';

import 'package:core_content/core_content.dart';
import 'package:core_scoring/core_scoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storyapp/audio/audio_player_service.dart';
import 'package:storyapp/i18n/app_localizations.dart';
import 'package:storyapp/quiz/quiz_screen.dart';
import 'package:storyapp/reading/reading_controller.dart';
import 'package:storyapp/ui/components/unlock_panel.dart';
import 'package:storyapp/reading/reading_screen.dart';
import 'package:storyapp/vocabulary/vocabulary_screen.dart';

class FakeMediaResolver implements MediaResolver {
  @override
  Future<ResolvedMedia?> resolve(String url) async => null;
}

class FakeAudioPlayerService implements AudioPlayerService {
  final StreamController<AudioPlaybackState> _states =
      StreamController<AudioPlaybackState>.broadcast();
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();

  @override
  AudioPlaybackState get state => AudioPlaybackState.idle;

  @override
  Stream<AudioPlaybackState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

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
    await _states.close();
    await _positions.close();
  }
}

Chapter chainChapter() {
  const p1 = Paragraph(
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
  VocabItem target(String id, String surface) => VocabItem(
        id: id,
        lemma: surface,
        surfaceForm: surface,
        partOfSpeech: 'noun',
        senseKey: '$surface:noun1',
        definition: 'definition of $surface',
        gloss: LocalizedText(<String, String>{'zh-Hans': surface, 'en': surface}),
        sourceSentence: 'She made a paper boat.',
        sourceParagraphId: 'ch1-p1',
        cefr: 'A2',
        isTarget: true,
      );
  QuizItem question(int n, int answer) => QuizItem(
        id: 'ch1-q$n',
        skill: 'detail',
        prompt: 'Question $n prompt?',
        options: const <String>['alpha', 'beta', 'gamma', 'delta'],
        answer: answer,
        explanation: LocalizedText(<String, String>{'en': 'Because.'}),
        evidence: 'ch1-p1',
      );
  return Chapter(
    id: 'ch1',
    order: 1,
    title: 'A Rainy Morning',
    available: true,
    estimatedMinutes: 3,
    reading: const <Paragraph>[p1],
    vocabulary: <VocabItem>[target('v-boat', 'boat'), target('v-rain', 'rain')],
    quiz: <QuizItem>[
      question(1, 0),
      question(2, 1),
      question(3, 2),
      question(4, 3),
      question(5, 0),
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
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('chapter_chain_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('walking the docs/07 transition table up to the unlock point',
      (WidgetTester tester) async {
    // Phone-sized portrait surface: the "read" signal is paragraph visibility,
    // and a wide desktop window pushed the story below the first frame.
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final l10n = (await tester.runAsync(() => AppLocalizations.load('en')))!;
    final controller = ReadingController(
      bookId: 'the-paper-boat',
      chapter: chainChapter(),
      packId: 'the-paper-boat',
      contentVersion: '1.0.0',
      progressStore: FileProgressStore(directory: tmp.path),
    );
    await controller.openChapter();
    expect(controller.state.stage, ChapterStage.reading,
        reason: 'unread -> reading when the chapter opens');

    Widget buildQuiz() => QuizScreen(
          controller: controller,
          l10n: l10n,
          defaultGloss: 'en',
        );
    Widget buildVocabulary() => VocabularyScreen(
          controller: controller,
          l10n: l10n,
          defaultGloss: 'en',
          onContinueToQuiz: () => Navigator.of(tester.element(
                  find.byType(VocabularyScreen)))
              .push(MaterialPageRoute<void>(builder: (_) => buildQuiz())),
        );

    await tester.pumpWidget(MaterialApp(
      home: ReadingScreen(
        controller: controller,
        mediaResolver: FakeMediaResolver(),
        audioPlayer: FakeAudioPlayerService(),
        l10n: l10n,
        bookTitle: 'The Paper Boat',
        onContinueToVocabulary: () => Navigator.of(
                tester.element(find.byType(ReadingScreen)))
            .push(MaterialPageRoute<void>(builder: (_) => buildVocabulary())),
      ),
    ));
    await tester.pumpAndSettle();

    // The single paragraph was visible on first layout -> vocabulary stage.
    expect(controller.state.stage, ChapterStage.vocabulary,
        reason: 'reading -> vocabulary when every paragraph is read');

    await tester.tap(find.descendant(
      of: find.byKey(const Key('reading-continue')),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VocabularyScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('vocab-card-v-boat')));
    await tester.pumpAndSettle();
    // S3 shows one card at a time (§4.4): walk to the second target first.
    await tester.tap(find.byKey(const Key('vocab-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vocab-card-v-rain')));
    await tester.pumpAndSettle();
    expect(controller.state.stage, ChapterStage.quiz,
        reason: 'vocabulary -> quiz after every target word is browsed');

    // The dock owns the CTA now; the key on the dock names the control.
    await tester.tap(find.descendant(
      of: find.byKey(const Key('vocab-continue')),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QuizScreen), findsOneWidget);

    // D1 (docs/13): every question must be answered correctly before the next
    // one; the run is graded once, when the last answer is right.
    final Finder quizCta = find.descendant(
      of: find.byKey(const Key('quiz-dock')),
      matching: find.byType(FilledButton),
    );
    for (final int option in <int>[0, 1, 2, 3]) {
      await tester.tap(find.byKey(Key('quiz-option-$option')));
      await tester.pumpAndSettle();
      await tester.tap(quizCta); // Check
      await tester.pumpAndSettle();
      await tester.tap(quizCta); // Next question
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('quiz-option-0')));
    await tester.pumpAndSettle();
    await tester.tap(quizCta); // Check on the last question
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700)); // 650 ms panel delay
    await tester.pumpAndSettle();

    expect(controller.state.stage, ChapterStage.retell,
        reason: 'quiz -> retell once every answer is right (stop here, S5)');
    expect(find.byType(UnlockPanel), findsOneWidget);

    // Close the panel (this chain wires no retell route yet).
    await tester.tap(find.descendant(
      of: find.byType(UnlockPanel),
      matching: find.byType(FilledButton),
    ));
    await tester.pumpAndSettle();

    // The persisted document reflects the whole walk-through.
    final doc = await FileProgressStore(directory: tmp.path)
        .load('the-paper-boat');
    final entry = doc.chapters['the-paper-boat/ch1']!;
    expect(entry.status, 'retell');
    expect(entry.readParagraphs, <String>['ch1-p1']);
    expect(entry.quiz.attempts, 1);
    expect(entry.quiz.correct, 5);
  });

  test('re-read keeps the statistics and is immediately actionable', () async {
    final chapter = chainChapter();
    final controller = ReadingController(
      bookId: 'the-paper-boat',
      chapter: chapter,
      packId: 'the-paper-boat',
      contentVersion: '1.0.0',
      progressStore: FileProgressStore(directory: tmp.path),
    );
    await controller.openChapter();
    await controller.markParagraphRead('ch1-p1'); // -> vocabulary
    await controller.markVocabViewed('v-boat');
    await controller.markVocabViewed('v-rain'); // -> quiz
    await controller.submitQuizAttempt(
      answers: const <String, int>{
        'ch1-q1': 0,
        'ch1-q2': 1,
        'ch1-q3': 2,
        'ch1-q4': 3,
        'ch1-q5': 0,
      },
      result: gradeQuiz(chapter.quiz, const <String, int>{
        'ch1-q1': 0,
        'ch1-q2': 1,
        'ch1-q3': 2,
        'ch1-q4': 3,
        'ch1-q5': 0,
      }),
    );
    expect(controller.state.stage, ChapterStage.retell);
    await controller.submitRetellAttempt(
      sceneId: 'ch1-s1',
      attempt: const RetellAttempt(
        durationMs: 9000,
        wordCount: 33,
        concept: 0.6,
        fluency: 0.5,
        completeness: 0.5,
        total: 0.55,
        missingConceptIds: <String>[],
      ),
    );
    expect(controller.state.stage, ChapterStage.complete);

    // S6 "read it again": the stage alone moves back, every statistic and
    // the read paragraphs survive.
    await controller.reopenForReading();
    expect(controller.state.stage, ChapterStage.reading);
    expect(controller.state.bestRetellScore, 0.55);
    expect(controller.state.retellAttempts, hasLength(1));
    expect(controller.state.readParagraphIds, <String>['ch1-p1']);
    expect(controller.quizStats?.attempts, 1);
    expect(controller.quizStats?.wrongItemIds, isEmpty);

    // The reopen is persisted — a fresh load lands on the re-read step.
    final doc = await FileProgressStore(directory: tmp.path)
        .load('the-paper-boat');
    expect(doc.chapters['the-paper-boat/ch1']!.status, 'reading');

    // "Next" is available at once: readParagraphIds kept the all-read guard
    // satisfied, so the first re-mark advances reading -> vocabulary.
    await controller.markParagraphRead('ch1-p1');
    expect(controller.state.stage, ChapterStage.vocabulary);
  });
}
